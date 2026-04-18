import Foundation

/// Detects and executes inline voice commands within transcript text.
/// Commands like "new paragraph", "new line", "period" are converted
/// to their text equivalents.
public struct CommandParser {
    public init() {}

    /// Process text for inline commands, returning the modified text.
    public func process(_ text: String) -> String {
        var result = text

        // Punctuation commands
        let punctuationCommands: [(String, String)] = [
            ("new paragraph", "\n\n"),
            ("new line", "\n"),
            ("period", "."),
            ("full stop", "."),
            ("comma", ","),
            ("question mark", "?"),
            ("exclamation mark", "!"),
            ("exclamation point", "!"),
            ("colon", ":"),
            ("semicolon", ";"),
            ("open quote", "\""),
            ("close quote", "\""),
            ("open parenthesis", "("),
            ("close parenthesis", ")"),
            ("dash", "—"),
            ("hyphen", "-"),
            ("ellipsis", "…"),
        ]

        for (command, replacement) in punctuationCommands {
            // Match case-insensitively with optional surrounding spaces
            if let regex = try? NSRegularExpression(
                pattern: #"\s*\b\#(NSRegularExpression.escapedPattern(for: command))\b\s*"#,
                options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        // Capitalize after new paragraph/new line insertions
        let pipeline = TextCleanupPipeline()
        result = pipeline.capitalizeSentences(result)

        return result
    }

    /// Check if text contains any rewrite commands that need LLM processing.
    /// Returns the command name if found, nil otherwise.
    /// These are for V1.5+ when local LLM is available.
    public func detectRewriteCommand(_ text: String) -> RewriteCommand? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower.hasPrefix("make this shorter") || lower.hasPrefix("make it shorter") {
            return .makeShorter
        }
        if lower.hasPrefix("make this more professional")
            || lower.hasPrefix("make it more professional")
        {
            return .makeProfessional
        }
        if lower.hasPrefix("make this more casual") || lower.hasPrefix("make it more casual") {
            return .makeCasual
        }
        if lower.hasPrefix("turn into bullet points") || lower.hasPrefix("make bullet points")
            || lower.hasPrefix("bullet points")
        {
            return .bulletPoints
        }
        if lower.hasPrefix("summarize this") || lower.hasPrefix("summarize") {
            return .summarize
        }

        return nil
    }
}

/// Rewrite commands that require LLM processing (V1.5+).
public enum RewriteCommand: String, CaseIterable {
    case makeShorter = "make_shorter"
    case makeProfessional = "make_professional"
    case makeCasual = "make_casual"
    case bulletPoints = "bullet_points"
    case summarize = "summarize"

    public var displayName: String {
        switch self {
        case .makeShorter: return "Make Shorter"
        case .makeProfessional: return "Make Professional"
        case .makeCasual: return "Make Casual"
        case .bulletPoints: return "Bullet Points"
        case .summarize: return "Summarize"
        }
    }
}
