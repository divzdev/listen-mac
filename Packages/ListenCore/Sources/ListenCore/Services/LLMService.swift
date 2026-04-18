import Foundation

#if canImport(Security)
    import Security
#endif

/// Multi-backend LLM service supporting OpenAI API and local Ollama.
/// Falls back gracefully when no LLM is available.
public actor LLMService {
    public enum Backend: String, CaseIterable, Codable, Sendable {
        case openai = "openai"
        case ollama = "ollama"
        case none = "none"

        public var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .ollama: return "Ollama (Local)"
            case .none: return "Disabled"
            }
        }
    }

    public enum LLMError: LocalizedError {
        case notAvailable
        case requestFailed(String)
        case invalidResponse
        case missingAPIKey

        public var errorDescription: String? {
            switch self {
            case .notAvailable: return "LLM service is not available."
            case .requestFailed(let msg): return "LLM request failed: \(msg)"
            case .invalidResponse: return "Invalid response from LLM."
            case .missingAPIKey: return "API key is required for this backend."
            }
        }
    }

    private var backend: Backend
    private var ollamaURL: URL
    private var ollamaModelName: String
    private var openAIModel: String
    private var openAIBaseURL: URL
    private let session: URLSession

    // MARK: - Init

    public init(
        backend: Backend = .none,
        ollamaHost: String = "http://localhost:11434",
        ollamaModel: String = "llama3.1:8b",
        openAIModel: String = "gpt-4o-mini",
        openAIBaseURL: String = "https://api.openai.com/v1"
    ) {
        self.backend = backend
        self.ollamaURL = URL(string: ollamaHost) ?? URL(string: "http://localhost:11434")!
        self.ollamaModelName = ollamaModel
        self.openAIModel = openAIModel
        self.openAIBaseURL = URL(string: openAIBaseURL) ?? URL(string: "https://api.openai.com/v1")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Keychain (API Key)

    private static let keychainService = "com.divyam.listen.mac.llm"

    public static func saveAPIKey(_ key: String, forBackend backend: Backend) {
        let account = "apikey-\(backend.rawValue)"
        let data = Data(key.utf8)

        // Delete old
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard !key.isEmpty else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    public static func loadAPIKey(forBackend backend: Backend) -> String? {
        let account = "apikey-\(backend.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Availability

    public func isAvailable() async -> Bool {
        switch backend {
        case .none:
            return false
        case .ollama:
            let url = ollamaURL.appendingPathComponent("api/tags")
            do {
                let (_, response) = try await session.data(from: url)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }
        case .openai:
            guard let key = LLMService.loadAPIKey(forBackend: .openai), !key.isEmpty else {
                return false
            }
            let url = openAIBaseURL.appendingPathComponent("models")
            var request = URLRequest(url: url)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            do {
                let (_, response) = try await session.data(for: request)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }
        }
    }

    /// List models available from the current backend.
    public func availableModels() async -> [String] {
        switch backend {
        case .none:
            return []
        case .ollama:
            let url = ollamaURL.appendingPathComponent("api/tags")
            do {
                let (data, _) = try await session.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let models = json?["models"] as? [[String: Any]] ?? []
                return models.compactMap { $0["name"] as? String }
            } catch {
                return []
            }
        case .openai:
            guard let key = LLMService.loadAPIKey(forBackend: .openai), !key.isEmpty else {
                return []
            }
            let url = openAIBaseURL.appendingPathComponent("models")
            var request = URLRequest(url: url)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await session.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let models = json?["data"] as? [[String: Any]] ?? []
                return models.compactMap { $0["id"] as? String }
                    .filter { $0.hasPrefix("gpt-") }
                    .sorted()
            } catch {
                return []
            }
        }
    }

    // MARK: - Generate

    public func generate(prompt: String, system: String? = nil) async throws -> String {
        switch backend {
        case .none:
            throw LLMError.notAvailable
        case .ollama:
            return try await generateOllama(prompt: prompt, system: system)
        case .openai:
            return try await generateOpenAI(prompt: prompt, system: system)
        }
    }

    private func generateOllama(prompt: String, system: String?) async throws -> String {
        let url = ollamaURL.appendingPathComponent("api/generate")
        var body: [String: Any] = [
            "model": ollamaModelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 1024,
            ],
        ]
        if let system { body["system"] = system }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.requestFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = json["response"] as? String
        else {
            throw LLMError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateOpenAI(prompt: String, system: String?) async throws -> String {
        guard let key = LLMService.loadAPIKey(forBackend: .openai), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        let url = openAIBaseURL.appendingPathComponent("chat/completions")
        var messages: [[String: String]] = []
        if let system {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])

        let body: [String: Any] = [
            "model": openAIModel,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1024,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw LLMError.requestFailed(
                "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0): \(errBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Response Cleaning

    /// Detect if the LLM returned meta-commentary instead of corrected text.
    /// E.g. "There is no error to fix in this sentence. It appears to be..."
    func isMetaCommentary(_ response: String, originalText: String) -> Bool {
        let lower = response.lowercased()

        // If the response is significantly longer than the original and contains
        // explanatory phrases, it's almost certainly meta-commentary
        let metaPhrases = [
            "there is no error",
            "there are no error",
            "no grammatical error",
            "no grammar error",
            "no spelling error",
            "no errors to fix",
            "no corrections needed",
            "no changes needed",
            "no changes necessary",
            "no changes required",
            "already correct",
            "already grammatically correct",
            "is grammatically correct",
            "is correct as written",
            "is correct as-is",
            "appears to be correct",
            "seems correct",
            "doesn't need",
            "does not need",
            "doesn't require",
            "does not require",
            "no issues found",
            "no errors found",
            "text is fine",
            "sentence is correct",
            "it appears to be an expression",
            "this text is already",
            "the text is correct",
            "the sentence is correct",
            "the original text",
            "nothing to correct",
            "nothing to fix",
        ]

        for phrase in metaPhrases {
            if lower.contains(phrase) {
                return true
            }
        }

        // If the response is much longer than the original (>2x) and doesn't
        // look like actual corrected text, it's likely explanation
        if response.count > originalText.count * 2 && response.count > 100 {
            // Check if it reads like an explanation rather than corrected text
            let explanatoryStarts = [
                "there ", "this ", "the text", "the sentence", "i ",
                "note:", "note ", "it appears", "it seems",
            ]
            for prefix in explanatoryStarts {
                if lower.hasPrefix(prefix) {
                    return true
                }
            }
        }

        return false
    }

    /// Strips common LLM meta-text preambles and postambles that models sometimes add
    /// despite being told to output only the corrected/rewritten text.
    func cleanLLMResponse(_ raw: String, originalText: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the entire response is meta-commentary, return the original
        if isMetaCommentary(text, originalText: originalText) {
            return originalText
        }

        // Remove wrapping quotes if the original didn't have them
        if text.hasPrefix("\"") && text.hasSuffix("\"") && !originalText.hasPrefix("\"") {
            text = String(text.dropFirst().dropLast())
        }

        // Common preamble patterns LLMs prepend despite instructions.
        // Match case-insensitively and strip everything up to and including the colon/newline.
        let preamblePatterns: [String] = [
            #"^(?:here(?:'s| is)(?: the)? (?:the )?(?:corrected|rewritten|revised|fixed|formatted|updated|shortened|professional|casual|summarized) (?:version|text|output)[:\s]*\n*)"#,
            #"^(?:here(?:'s| is) (?:your|the) (?:text|response)[:\s]*\n*)"#,
            #"^(?:(?:the )?corrected (?:version|text)[:\s]*\n*)"#,
            #"^(?:(?:the )?rewritten (?:version|text)[:\s]*\n*)"#,
            #"^(?:sure[!,.]?\s*(?:here(?:'s| is)[^:]*:)?\s*\n*)"#,
            #"^(?:of course[!,.]?\s*(?:here(?:'s| is)[^:]*:)?\s*\n*)"#,
            #"^(?:certainly[!,.]?\s*(?:here(?:'s| is)[^:]*:)?\s*\n*)"#,
        ]

        for pattern in preamblePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    let matchEnd = text.index(text.startIndex, offsetBy: match.range.upperBound)
                    text = String(text[matchEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Remove trailing explanation blocks (e.g., "I made the following changes:\n- Changed...")
        let postamblePatterns: [String] = [
            #"\n+(?:i (?:made|have made|applied|did) the following (?:changes|corrections|edits)[:\s]*)[\s\S]*$"#,
            #"\n+(?:(?:the )?changes (?:i )?(?:made|applied)[:\s]*)[\s\S]*$"#,
            #"\n+(?:note[:\s][\s\S]*)$"#,
            #"\n+(?:explanation[:\s][\s\S]*)$"#,
            #"\n+(?:changes[:\s]*\n\s*[-•])[\s\S]*$"#,
            #"\n+(?:here (?:are|is) (?:a )?(?:list|summary) of (?:the )?changes[\s\S]*)$"#,
            #"\n+(?:key changes[\s\S]*)$"#,
        ]

        for pattern in postamblePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - High-level Tasks

    public func rewrite(_ text: String, command: RewriteCommand) async throws -> String {
        let system =
            "You are a writing assistant. Rewrite the given text exactly as requested. IMPORTANT: Output ONLY the rewritten text. Do NOT include any preamble like \"Here is the rewritten text\" or explanations of changes. Just output the text itself."
        let prompt: String
        switch command {
        case .makeShorter:
            prompt =
                "Make this text shorter and more concise while preserving the meaning:\n\n\(text)"
        case .makeProfessional:
            prompt = "Rewrite this text in a professional, formal tone:\n\n\(text)"
        case .makeCasual:
            prompt = "Rewrite this text in a casual, friendly tone:\n\n\(text)"
        case .bulletPoints:
            prompt = "Convert this text into clear bullet points:\n\n\(text)"
        case .summarize:
            prompt = "Summarize this text in 1-2 sentences:\n\n\(text)"
        }
        let raw = try await generate(prompt: prompt, system: system)
        return cleanLLMResponse(raw, originalText: text)
    }

    public func fixGrammar(_ text: String) async throws -> String {
        // Skip LLM for text that's too short to meaningfully correct
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount < 2 || trimmed.count < 3 {
            return trimmed
        }

        let system =
            "You are a grammar checker. Fix any grammar, spelling, and punctuation errors. IMPORTANT: Output ONLY the corrected text, nothing else. Do NOT explain, comment, or say things like \"There are no errors\". If the text is already correct, output it unchanged."
        let raw = try await generate(prompt: "Fix the grammar:\n\n\(text)", system: system)
        return cleanLLMResponse(raw, originalText: text)
    }

    public func contextFormat(_ text: String, appName: String?) async throws -> String {
        let context =
            appName.map { "The user is typing in \($0)." }
            ?? "The user is typing in an unknown application."
        let system =
            "You are a writing assistant. Format the given text appropriately for the context. \(context) IMPORTANT: Output ONLY the formatted text. Do NOT include any preamble or explanations. Just output the text itself."
        let raw = try await generate(
            prompt: "Format this text appropriately:\n\n\(text)", system: system)
        return cleanLLMResponse(raw, originalText: text)
    }

    // MARK: - Config

    public func updateConfig(
        backend: Backend,
        ollamaHost: String = "http://localhost:11434",
        ollamaModel: String = "llama3.1:8b",
        openAIModel: String = "gpt-4o-mini",
        openAIBaseURL: String = "https://api.openai.com/v1"
    ) {
        self.backend = backend
        self.ollamaURL = URL(string: ollamaHost) ?? URL(string: "http://localhost:11434")!
        self.ollamaModelName = ollamaModel
        self.openAIModel = openAIModel
        self.openAIBaseURL = URL(string: openAIBaseURL) ?? URL(string: "https://api.openai.com/v1")!
    }

    public var currentBackend: Backend { backend }
}
