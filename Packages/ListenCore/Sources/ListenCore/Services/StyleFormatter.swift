import Foundation

/// Applies style-specific formatting rules to cleaned text based on a StylePreset.
public struct StyleFormatter {
    public init() {}

    /// Apply style formatting to already-cleaned text.
    public func format(_ text: String, style: StylePreset) -> String {
        var result = text

        if style.removeFillers {
            let pipeline = TextCleanupPipeline()
            result = pipeline.removeFillerWords(result)
        }

        if style.formalize {
            result = formalize(result)
        }

        if style.concise {
            result = makeConcise(result)
        }

        if style.emailFormat {
            result = wrapAsEmail(result)
        }

        return result
    }

    /// Apply the named built-in style.
    public func formatWithBuiltInStyle(_ text: String, styleName: String) -> String {
        let presets = StylePreset.builtInPresets()
        guard let preset = presets.first(where: { $0.name == styleName }) else {
            return text
        }
        return format(text, style: preset)
    }

    // MARK: - Style Rules

    /// Make text more formal: expand contractions, remove casual phrases.
    private func formalize(_ text: String) -> String {
        var result = text

        let contractions: [(String, String)] = [
            ("can't", "cannot"),
            ("won't", "will not"),
            ("don't", "do not"),
            ("doesn't", "does not"),
            ("isn't", "is not"),
            ("aren't", "are not"),
            ("wasn't", "was not"),
            ("weren't", "were not"),
            ("haven't", "have not"),
            ("hasn't", "has not"),
            ("didn't", "did not"),
            ("wouldn't", "would not"),
            ("couldn't", "could not"),
            ("shouldn't", "should not"),
            ("I'm", "I am"),
            ("I've", "I have"),
            ("I'll", "I will"),
            ("I'd", "I would"),
            ("you're", "you are"),
            ("you've", "you have"),
            ("you'll", "you will"),
            ("he's", "he is"),
            ("she's", "she is"),
            ("it's", "it is"),
            ("we're", "we are"),
            ("we've", "we have"),
            ("we'll", "we will"),
            ("they're", "they are"),
            ("they've", "they have"),
            ("they'll", "they will"),
            ("that's", "that is"),
            ("there's", "there is"),
            ("here's", "here is"),
            ("what's", "what is"),
            ("who's", "who is"),
            ("let's", "let us"),
        ]

        for (contraction, expanded) in contractions {
            // Case-insensitive replacement
            if let regex = try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: contraction),
                options: .caseInsensitive)
            {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: expanded
                )
            }
        }

        return result
    }

    /// Remove verbose phrases and tighten language.
    private func makeConcise(_ text: String) -> String {
        var result = text

        let verbosePhrases: [(String, String)] = [
            ("in order to", "to"),
            ("due to the fact that", "because"),
            ("at this point in time", "now"),
            ("in the event that", "if"),
            ("for the purpose of", "for"),
            ("on a daily basis", "daily"),
            ("at the present time", "currently"),
            ("in the near future", "soon"),
            ("a large number of", "many"),
            ("the vast majority of", "most"),
            ("in spite of the fact that", "although"),
            ("with regard to", "regarding"),
            ("on the other hand", "however"),
            ("as a matter of fact", "in fact"),
            ("it is important to note that", "notably"),
            ("I just wanted to say that", ""),
            ("I think that", ""),
            ("basically", ""),
            ("essentially", ""),
        ]

        for (verbose, concise) in verbosePhrases {
            if let regex = try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: verbose), options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: concise
                )
            }
        }

        // Clean up any double spaces from removals
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result
    }

    /// Wrap text in email-style format if it doesn't already have a greeting.
    private func wrapAsEmail(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // Don't double-wrap if already has greeting
        let greetings = [
            "hi ", "hello ", "hey ", "dear ", "good morning", "good afternoon", "good evening",
        ]
        let hasGreeting = greetings.contains(where: { lower.hasPrefix($0) })

        if hasGreeting {
            return trimmed
        }

        return "Hi,\n\n\(trimmed)\n\nBest regards"
    }
}
