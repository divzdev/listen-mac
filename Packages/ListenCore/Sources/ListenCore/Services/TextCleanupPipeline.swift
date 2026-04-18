import Foundation

/// Deterministic text cleanup rules applied to raw transcripts.
/// Handles capitalization, punctuation, filler removal, and number formatting.
public struct TextCleanupPipeline {
    public init() {}

    /// Apply all cleanup rules to raw transcript text.
    public func clean(_ text: String) -> String {
        var result = text

        result = normalizeWhitespace(result)
        result = removeFillerWords(result)
        result = capitalizeSentences(result)
        result = fixPunctuation(result)
        result = formatNumbers(result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Individual Rules

    /// Collapse multiple spaces and normalize line breaks.
    public func normalizeWhitespace(_ text: String) -> String {
        var result = text
        // Collapse multiple spaces into one
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        // Collapse multiple newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result
    }

    /// Remove common filler words: "um", "uh", "like" (when used as filler), "you know".
    public func removeFillerWords(_ text: String) -> String {
        // Patterns that match fillers at word boundaries
        let fillerPatterns: [(pattern: String, replacement: String)] = [
            (#"\b[Uu]mm?\b"#, ""),
            (#"\b[Uu]hh?\b"#, ""),
            (#"\b[Yy]ou know\b"#, ""),
            (#"\b[Ll]ike,?\s"#, " "),  // "like" as filler, not as verb
            (#"\b[Ss]o,?\s(?=[A-Z])"#, ""),  // "So" at sentence start as filler
            (#"\b[Aa]ctually,?\s"#, ""),  // "actually" as filler
        ]

        var result = text
        for (pattern, replacement) in fillerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        return normalizeWhitespace(result)
    }

    /// Capitalize the first letter of each sentence.
    public func capitalizeSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = ""
        var capitalizeNext = true

        for char in text {
            if capitalizeNext && char.isLetter {
                result.append(char.uppercased())
                capitalizeNext = false
            } else {
                result.append(char)
            }

            if char == "." || char == "!" || char == "?" || char == "\n" {
                capitalizeNext = true
            }
        }

        return result
    }

    /// Fix common punctuation issues.
    public func fixPunctuation(_ text: String) -> String {
        var result = text

        // Remove space before punctuation
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")
        result = result.replacingOccurrences(of: " :", with: ":")
        result = result.replacingOccurrences(of: " ;", with: ";")

        // Ensure space after punctuation (unless end of string or another punctuation)
        let punctuation: [Character] = [".", ",", "!", "?", ":", ";"]
        var fixed = ""
        let chars = Array(result)
        for (i, char) in chars.enumerated() {
            fixed.append(char)
            if punctuation.contains(char), i + 1 < chars.count {
                let next = chars[i + 1]
                if next != " " && next != "\n" && !punctuation.contains(next) {
                    fixed.append(" ")
                }
            }
        }

        // Remove trailing comma if last non-whitespace char
        result = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix(",") {
            result = String(result.dropLast())
        }

        // Ensure ends with period if no terminal punctuation
        if !result.isEmpty {
            let lastChar = result.last!
            if lastChar != "." && lastChar != "!" && lastChar != "?" {
                result += "."
            }
        }

        return result
    }

    /// Format spoken numbers to digits for common cases.
    public func formatNumbers(_ text: String) -> String {
        let numberWords: [String: String] = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
            "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
            "eighteen": "18", "nineteen": "19", "twenty": "20",
            "thirty": "30", "forty": "40", "fifty": "50",
            "sixty": "60", "seventy": "70", "eighty": "80", "ninety": "90",
            "hundred": "100", "thousand": "1000",
        ]

        var result = text
        // Only replace standalone number words (avoid replacing inside other words)
        for (word, digit) in numberWords {
            if let regex = try? NSRegularExpression(
                pattern: #"\b\#(word)\b"#, options: .caseInsensitive)
            {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: digit
                )
            }
        }

        return result
    }
}
