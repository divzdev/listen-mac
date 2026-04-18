import Combine
import ListenCore
import SwiftData
import SwiftUI
import UserNotifications

/// Central app state shared across all views via EnvironmentObject.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Dictation State

    enum DictationStatus: String {
        case idle
        case listening
        case processing
        case rewriting
    }

    @Published var status: DictationStatus = .idle
    @Published var partialTranscript: String = ""
    @Published var selectedStyle: String =
        UserDefaults.standard.string(forKey: "defaultStyle") ?? "Casual"
    {
        didSet {
            UserDefaults.standard.set(selectedStyle, forKey: "defaultStyle")
            print("[Listen] Style changed to: \(selectedStyle)")
        }
    }
    @Published var isModelLoaded: Bool = false
    @Published var modelLoadProgress: String = ""
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0
    @Published var totalDictations: Int = 0
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(
        forKey: "hasCompletedOnboarding")
    @Published var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published var isLLMAvailable: Bool = false
    @Published var llmStatus: String = ""
    @Published var lastDictationText: String = ""
    @Published var lastDictationRaw: String = ""
    @Published var selectedMicrophoneID: String? = UserDefaults.standard.string(
        forKey: "selectedMicrophoneID")

    // MARK: - Services

    let transcriptionService: TranscriptionService
    let textCleanup = TextCleanupPipeline()
    let styleFormatter = StyleFormatter()
    let snippetExpander = SnippetExpander()
    let commandParser = CommandParser()
    let grammarService = GrammarService()
    let audioCapture = AudioCaptureService()
    let hotKeyManager = HotKeyManager()
    let textInsertion = TextInsertionService()
    let overlayController = TranscriptOverlayController()
    let llmService: LLMService

    /// ModelContext injected from the SwiftUI environment after app launches.
    var modelContext: ModelContext?

    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: Task<Void, Never>?

    var statusIcon: String {
        switch status {
        case .idle: return "mic"
        case .listening: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .rewriting: return "sparkles"
        }
    }

    init() {
        let modelName = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
        self.transcriptionService = TranscriptionService(modelName: modelName)

        let llmBackendRaw = UserDefaults.standard.string(forKey: "llmBackend") ?? "none"
        let llmBackend = LLMService.Backend(rawValue: llmBackendRaw) ?? .none
        let llmHost = UserDefaults.standard.string(forKey: "ollamaHost") ?? "http://localhost:11434"
        let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.1:8b"
        let openAIModel = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4o-mini"
        let openAIBase =
            UserDefaults.standard.string(forKey: "openAIBaseURL") ?? "https://api.openai.com/v1"
        self.llmService = LLMService(
            backend: llmBackend,
            ollamaHost: llmHost,
            ollamaModel: ollamaModel,
            openAIModel: openAIModel,
            openAIBaseURL: openAIBase
        )
    }

    // MARK: - Lifecycle

    func setup() {
        // Pre-request microphone permission immediately
        audioCapture.requestPermission()

        // Load the Whisper model
        Task {
            do {
                print("[Listen] Loading Whisper model...")
                modelLoadProgress = "Downloading & loading model…"
                try await transcriptionService.loadModel()
                isModelLoaded = true
                modelLoadProgress = ""
                print("[Listen] Model loaded successfully")
            } catch {
                print("[Listen] Model load FAILED: \(error)")
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                modelLoadProgress = ""
            }
        }

        // Check LLM availability
        Task {
            isLLMAvailable = await llmService.isAvailable()
        }

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }

        // Wire up hotkey
        applyTriggerMethod()
        applyDictationMode()
        hotKeyManager.onRecordingStarted = { [weak self] in
            self?.startDictation()
        }
        hotKeyManager.onRecordingStopped = { [weak self] in
            self?.stopDictation()
        }
        hotKeyManager.onSafetyTimeout = { [weak self] in
            print("[Listen] Safety timeout triggered — forcing stop")
            self?.forceIdle()
        }
        hotKeyManager.register()

        // Wire up silence detection → auto-stop
        audioCapture.onSilenceDetected = { [weak self] in
            guard let self, self.status == .listening else { return }
            let autoStop = UserDefaults.standard.bool(forKey: "autoStopOnSilence")
            if autoStop {
                self.stopDictation()
            }
        }

        // Observe audio level for UI metering and overlay
        audioCapture.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self else { return }
                self.audioLevel = level
                // Safety: if we're getting real audio levels while idle, something is wrong — force stop
                if level > 0.001 && self.status == .idle && self.audioCapture.isRecording {
                    print("[Listen] WARNING: audio active while idle, forcing stop")
                    self.audioCapture.forceStopEngine()
                    self.audioLevel = 0.0
                    return
                }
                // Update overlay with real audio level while listening
                if self.status == .listening {
                    let text =
                        self.partialTranscript.isEmpty ? "Listening…" : self.partialTranscript
                    self.overlayController.update(text: text, audioLevel: level)
                }
            }
            .store(in: &cancellables)

        // Stream partial transcript updates from the service
        transcriptionService.$partialText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self, self.status == .listening else {
                    return
                }
                if !text.isEmpty {
                    self.partialTranscript = text
                    self.overlayController.update(text: text)
                }
            }
            .store(in: &cancellables)

        // Apply silence detector settings
        let timeout = UserDefaults.standard.double(forKey: "silenceTimeout")
        if timeout > 0 {
            audioCapture.updateSilenceSettings(threshold: 0.01, duration: timeout)
        }

        // Seed built-in style presets on first launch
        seedBuiltInPresetsIfNeeded()
    }

    /// Read the dictation mode setting and apply it.
    func applyDictationMode() {
        let mode = UserDefaults.standard.string(forKey: "dictationMode") ?? "holdToTalk"
        hotKeyManager.mode = mode == "toggle" ? .toggle : .holdToTalk
    }

    /// Read the trigger method setting and apply it.
    func applyTriggerMethod() {
        let method = UserDefaults.standard.string(forKey: "triggerMethod") ?? "fnKey"
        hotKeyManager.triggerMethod = method == "customHotkey" ? .customHotkey : .fnKey
    }

    // MARK: - Dictation Flow

    func startDictation() {
        print("[Listen] startDictation: status=\(status.rawValue), isModelLoaded=\(isModelLoaded)")
        guard status == .idle else {
            print("[Listen] Cannot start: not idle")
            return
        }
        guard isModelLoaded else {
            print("[Listen] Cannot start: model not loaded yet")
            errorMessage = "Model still loading, please wait…"
            return
        }
        status = .listening
        partialTranscript = ""
        errorMessage = nil
        recordingStartTime = Date()

        audioCapture.startRecording()

        // Show overlay if enabled
        let showOverlay = UserDefaults.standard.object(forKey: "showOverlay") as? Bool ?? true
        if showOverlay {
            overlayController.show(text: "Listening…")
        }
        print("[Listen] Now listening...")
    }

    func stopDictation() {
        guard status == .listening else {
            print("[Listen] stopDictation: not listening, status=\(status.rawValue)")
            return
        }
        print("[Listen] stopDictation: stopping recording...")
        status = .processing
        partialTranscript = ""
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        let audioBuffer = audioCapture.stopRecording()
        print(
            "[Listen] Got \(audioBuffer.count) samples (\(String(format: "%.1f", Double(audioBuffer.count) / 16000.0))s of audio)"
        )

        guard audioBuffer.count > 1600 else {
            // Less than 0.1s of audio — too short
            print("[Listen] Audio too short, discarding")
            overlayController.dismiss()
            status = .idle
            return
        }

        // Update overlay
        overlayController.update(text: "Processing…")

        // Detect focused app before transcription
        let focusedApp = NSWorkspace.shared.frontmostApplication
        let appName = focusedApp?.localizedName
        let appBundleID = focusedApp?.bundleIdentifier

        // Resolve style: per-app profile overrides global
        let effectiveStyle = resolveStyle(forBundleID: appBundleID)

        // Fetch snippets from storage
        let snippets: [Snippet] = {
            guard let ctx = modelContext else { return [] }
            return (try? ctx.fetch(FetchDescriptor<Snippet>())) ?? []
        }()

        Task {
            do {
                let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
                print("[Listen] Transcribing \(audioBuffer.count) samples, lang=\(lang)...")
                let rawText = try await transcriptionService.transcribe(
                    audioArray: audioBuffer,
                    language: lang == "auto" ? nil : lang
                )
                print("[Listen] Transcription result: \"\(rawText)\"")

                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    print("[Listen] Empty transcription, discarding")
                    overlayController.dismiss()
                    status = .idle
                    return
                }

                // Discard Whisper noise artifacts (hallucinations from silence/noise)
                let trimmedRaw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                let whisperNoisePatterns: Set<String> = [
                    "you", "thank you", "thanks", "bye", "okay",
                    "thank you for watching", "thanks for watching",
                    "subscribe", "like and subscribe",
                    ".", "..", "...", "!", "?", "-",
                    "(silence)", "[silence]", "(inaudible)", "[inaudible]",
                    "(music)", "[music]", "(applause)", "[applause]",
                    "(laughing)", "[laughing]", "(coughing)", "[coughing]",
                    "(sighs)", "(breathing)", "(noise)",
                    "blank_audio", "[blank_audio]", "(blank_audio)",
                    "blank audio", "[blank audio]",
                ]
                let lowered = trimmedRaw.lowercased()
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if whisperNoisePatterns.contains(lowered)
                    || trimmedRaw.allSatisfy({ $0.isPunctuation || $0.isWhitespace })
                    || lowered.contains("blank_audio")
                    || lowered.contains("blank audio")
                {
                    print("[Listen] Whisper noise artifact detected: \"\(rawText)\", discarding")
                    overlayController.dismiss()
                    status = .idle
                    return
                }

                // Check for rewrite commands first
                if let rewriteCommand = commandParser.detectRewriteCommand(rawText) {
                    await handleRewriteCommand(rewriteCommand, appName: appName)
                    return
                }

                var processed = processTranscript(
                    rawText, snippets: snippets, styleName: effectiveStyle)

                // Apply grammar correction if enabled
                let grammarEnabled =
                    UserDefaults.standard.object(forKey: "grammarCorrection") as? Bool ?? true
                if grammarEnabled {
                    if self.isLLMAvailable {
                        // Use LLM for AI-powered grammar correction
                        print("[Listen] Applying LLM grammar correction...")
                        do {
                            processed = try await self.llmService.fixGrammar(processed)
                            print("[Listen] LLM grammar correction applied successfully")
                        } catch {
                            print(
                                "[Listen] LLM grammar failed, falling back to rule-based: \(error.localizedDescription)"
                            )
                            processed = self.grammarService.correct(processed)
                        }
                    } else {
                        // Rule-based fallback when no LLM is available
                        processed = self.grammarService.correct(processed)
                    }
                }

                print("[Listen] Inserting text: \"\(processed)\"")
                // Small delay to ensure the target app has focus back
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                textInsertion.insertText(processed)

                // Store for re-dictate
                lastDictationText = processed
                lastDictationRaw = rawText

                // Save to history
                saveDictationEntry(
                    text: processed,
                    rawText: rawText,
                    duration: duration,
                    appBundleID: appBundleID,
                    appName: appName,
                    styleName: effectiveStyle
                )

                overlayController.dismiss()
                status = .idle
                partialTranscript = ""
                totalDictations += 1

                // Send notification
                sendCompletionNotification(text: processed)
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                overlayController.dismiss()
                status = .idle
            }
        }
    }

    /// Cancel an ongoing dictation without inserting text.
    func cancelDictation() {
        guard status == .listening else { return }
        _ = audioCapture.stopRecording()
        overlayController.dismiss()
        status = .idle
        partialTranscript = ""
    }

    /// Force everything to idle state — safety net for stuck states.
    func forceIdle() {
        print("[Listen] forceIdle: ensuring clean state")
        audioCapture.stopRecording()
        audioCapture.forceStopEngine()
        overlayController.dismiss()
        status = .idle
        partialTranscript = ""
        audioLevel = 0.0
    }

    /// Re-insert the last dictation text into the focused app.
    func reDictate() {
        guard !lastDictationText.isEmpty, status == .idle else { return }
        textInsertion.insertText(lastDictationText)
    }

    // MARK: - Rewrite Commands (Phase 2 LLM)

    private func handleRewriteCommand(_ command: RewriteCommand, appName: String?) async {
        guard isLLMAvailable else {
            errorMessage = "LLM not available. Start Ollama to use rewrite commands."
            overlayController.dismiss()
            status = .idle
            return
        }

        guard !lastDictationText.isEmpty else {
            errorMessage = "Nothing to rewrite. Dictate some text first."
            overlayController.dismiss()
            status = .idle
            return
        }

        status = .rewriting
        overlayController.update(text: "Rewriting with AI…")

        do {
            let rewritten = try await llmService.rewrite(lastDictationText, command: command)
            textInsertion.insertText(rewritten)
            lastDictationText = rewritten
            overlayController.dismiss()
            status = .idle
            sendCompletionNotification(text: "Rewrote: \(command.displayName)")
        } catch {
            errorMessage = "Rewrite failed: \(error.localizedDescription)"
            overlayController.dismiss()
            status = .idle
        }
    }

    /// Rewrite the last dictation with a specific command (called from UI).
    func rewriteLastDictation(command: RewriteCommand) {
        Task {
            await handleRewriteCommand(command, appName: nil)
        }
    }

    // MARK: - Per-App Style Profiles (Phase 1)

    /// Look up per-app style profile, fall back to selected global style.
    func resolveStyle(forBundleID: String?) -> String {
        guard let bundleID = forBundleID, let ctx = modelContext else {
            return selectedStyle
        }
        let descriptor = FetchDescriptor<AppStyleProfile>(
            predicate: #Predicate { $0.appBundleID == bundleID }
        )
        if let profile = try? ctx.fetch(descriptor).first {
            return profile.styleName
        }
        return selectedStyle
    }

    // MARK: - Text Processing

    /// Apply cleanup, commands, snippets, and style formatting.
    func processTranscript(_ raw: String, snippets: [Snippet] = [], styleName: String? = nil)
        -> String
    {
        var text = raw

        // 1. Parse inline commands (new paragraph, period, etc.)
        text = commandParser.process(text)

        // 2. Basic cleanup
        text = textCleanup.clean(text)

        // 3. Expand snippets
        text = snippetExpander.expand(text, using: snippets)

        // 4. Apply style
        let style = styleName ?? selectedStyle
        text = styleFormatter.formatWithBuiltInStyle(text, styleName: style)

        return text
    }

    // MARK: - Notifications

    private func sendCompletionNotification(text: String) {
        let showNotification =
            UserDefaults.standard.object(forKey: "showNotification") as? Bool ?? false
        guard showNotification else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dictation Complete"
        content.body = String(text.prefix(100))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private func saveDictationEntry(
        text: String,
        rawText: String,
        duration: Double,
        appBundleID: String?,
        appName: String?,
        styleName: String? = nil
    ) {
        guard let ctx = modelContext else { return }
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        let entry = DictationEntry(
            text: text,
            rawText: rawText,
            duration: duration,
            appBundleID: appBundleID,
            appName: appName,
            styleName: styleName ?? selectedStyle,
            language: lang
        )
        ctx.insert(entry)
        try? ctx.save()
    }

    private func seedBuiltInPresetsIfNeeded() {
        guard let ctx = modelContext else { return }
        let existing = (try? ctx.fetchCount(FetchDescriptor<StylePreset>())) ?? 0
        if existing == 0 {
            for preset in StylePreset.builtInPresets() {
                ctx.insert(preset)
            }
            try? ctx.save()
        }
    }

    /// Reload the transcription model (e.g. after user changes model in settings).
    func reloadModel() {
        isModelLoaded = false
        errorMessage = nil
        Task {
            do {
                let name = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
                modelLoadProgress = "Switching to \(name) model…"
                try await transcriptionService.loadModel(name: name)
                isModelLoaded = true
                modelLoadProgress = ""
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                modelLoadProgress = ""
            }
        }
    }

    /// Check and update accessibility permission status.
    func refreshAccessibilityStatus() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// Select a specific microphone input device.
    func selectMicrophone(deviceID: String) {
        selectedMicrophoneID = deviceID
        UserDefaults.standard.set(deviceID, forKey: "selectedMicrophoneID")
        audioCapture.setPreferredDevice(uniqueID: deviceID)
    }

    /// Get the user's first name for personalized greeting.
    var userFirstName: String {
        let fullName = NSFullUserName()
        return fullName.components(separatedBy: " ").first ?? fullName
    }

    /// Refresh LLM availability status.
    func refreshLLMStatus() {
        Task {
            isLLMAvailable = await llmService.isAvailable()
            llmStatus = isLLMAvailable ? "Connected" : "Not available"
        }
    }

    /// Update LLM configuration.
    func updateLLMConfig() {
        let backendRaw = UserDefaults.standard.string(forKey: "llmBackend") ?? "none"
        let backend = LLMService.Backend(rawValue: backendRaw) ?? .none
        let host = UserDefaults.standard.string(forKey: "ollamaHost") ?? "http://localhost:11434"
        let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.1:8b"
        let openAIModel = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4o-mini"
        let openAIBase =
            UserDefaults.standard.string(forKey: "openAIBaseURL") ?? "https://api.openai.com/v1"
        Task {
            await llmService.updateConfig(
                backend: backend,
                ollamaHost: host,
                ollamaModel: ollamaModel,
                openAIModel: openAIModel,
                openAIBaseURL: openAIBase
            )
            refreshLLMStatus()
        }
    }
}
