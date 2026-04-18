import Foundation
import NaturalLanguage

/// Rule-based grammar correction using NaturalLanguage framework + patterns.
/// Used as a fast fallback when LLM is not available.
public struct GrammarService {
    public init() {}

    /// Apply rule-based grammar corrections.
    public func correct(_ text: String) -> String {
        var result = text

        result = fixSubjectVerbAgreement(result)
        result = fixCommonMisspellings(result)
        result = fixArticles(result)
        result = fixDoubleWords(result)
        result = fixCapitalization(result)

        return result
    }

    /// Detect the language of the text.
    public func detectLanguage(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    // MARK: - Rules

    private func fixSubjectVerbAgreement(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            (#"\b[Ii] is\b"#, "I am"),
            (#"\b[Hh]e are\b"#, "he is"),
            (#"\b[Ss]he are\b"#, "she is"),
            (#"\b[Ii]t are\b"#, "it is"),
            (#"\b[Tt]hey is\b"#, "they are"),
            (#"\b[Ww]e is\b"#, "we are"),
            (#"\b[Yy]ou is\b"#, "you are"),
            (#"\b[Ii] has\b(?! been)"#, "I have"),
            (#"\b[Tt]hey has\b(?! been)"#, "they have"),
            (#"\b[Ww]e has\b(?! been)"#, "we have"),
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        return result
    }

    private func fixCommonMisspellings(_ text: String) -> String {
        var result = text
        let corrections: [(String, String)] = [
            (#"\b[Tt]eh\b"#, "the"),
            (#"\b[Rr]ecieve"#, "receive"),
            (#"\b[Ss]eperate"#, "separate"),
            (#"\b[Oo]ccur+ance"#, "occurrence"),
            (#"\b[Aa]comod"#, "accommod"),
            (#"\b[Dd]efinately"#, "definitely"),
            (#"\b[Nn]ecessery"#, "necessary"),
            (#"\b[Oo]ccassion"#, "occasion"),
            (#"\b[Uu]ntill?\b"#, "until"),
            (#"\b[Ww]hich ever\b"#, "whichever"),
            (#"\b[Aa]lot\b"#, "a lot"),
        ]
        for (pattern, replacement) in corrections {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        return result
    }

    private func fixArticles(_ text: String) -> String {
        var result = text
        // "a" before vowel sounds → "an"
        if let regex = try? NSRegularExpression(pattern: #"\b[Aa] ([aeiouAEIOU]\w)"#) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "an $1"
            )
        }
        // "an" before consonant sounds → "a"  (simplified)
        if let regex = try? NSRegularExpression(
            pattern: #"\b[Aa]n ([bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]\w)"#)
        {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "a $1"
            )
        }
        return result
    }

    private func fixDoubleWords(_ text: String) -> String {
        var result = text
        // Remove repeated words: "the the" → "the"
        if let regex = try? NSRegularExpression(
            pattern: #"\b(\w+)\s+\1\b"#, options: .caseInsensitive)
        {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }
        return result
    }

    private func fixCapitalization(_ text: String) -> String {
        var result = text
        // Capitalize "I" standing alone
        if let regex = try? NSRegularExpression(pattern: #"\bi\b"#) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "I"
            )
        }
        return result
    }
}
