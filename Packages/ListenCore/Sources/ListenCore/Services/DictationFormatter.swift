import Foundation

/// Rule-based "smart formatting" for the local (no-LLM) path. It can't match an LLM, but it
/// handles the most common structural case — spoken enumerations ("first… second… third",
/// "number one… two…") become a numbered list — plus light grammar and sentence tidying. Used
/// when smart formatting is on but no LLM backend is configured.
public struct DictationFormatter {
    private let grammar = GrammarService()

    public init() {}

    public func format(_ text: String) -> String {
        let corrected = grammar.correct(text)
        if let list = enumerationToList(corrected) {
            return list
        }
        return tidy(corrected)
    }

    // MARK: - Enumeration → numbered list

    /// Ordinal cue words, indexed so cue → expected position (firstOrdinals[0] == "first" → 1).
    private static let ordinals = [
        "first", "second", "third", "fourth", "fifth",
        "sixth", "seventh", "eighth", "ninth", "tenth",
    ]
    private static let numberWords = [
        "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten",
    ]

    /// If the text is a spoken enumeration, return it as a lead-in line plus a numbered list.
    /// Returns nil when there's no clear ≥2-item ordinal sequence starting at the first item.
    private func enumerationToList(_ text: String) -> String? {
        // Build a matcher for "first"/"firstly" and "number one" style cues, capturing rank.
        var cues: [(range: Range<String.Index>, rank: Int)] = []

        for (idx, word) in Self.ordinals.enumerated() {
            collectMatches(of: #"\b\#(word)(?:ly)?\b"#, in: text, rank: idx + 1, into: &cues)
        }
        for (idx, word) in Self.numberWords.enumerated() {
            collectMatches(of: #"\bnumber\s+\#(word)\b"#, in: text, rank: idx + 1, into: &cues)
        }

        guard !cues.isEmpty else { return nil }
        cues.sort { $0.range.lowerBound < $1.range.lowerBound }

        // Require the sequence to start at item 1 and count up 1,2,3… (allow duplicates/gaps to
        // bail rather than mangle normal prose that merely contains "first" once).
        var ordered: [(range: Range<String.Index>, rank: Int)] = []
        var expected = 1
        for cue in cues where cue.rank == expected {
            ordered.append(cue)
            expected += 1
        }
        guard ordered.count >= 2 else { return nil }

        let leadIn = String(text[text.startIndex..<ordered[0].range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:\n\t"))

        var items: [String] = []
        for (i, cue) in ordered.enumerated() {
            let itemStart = cue.range.upperBound
            let itemEnd = i + 1 < ordered.count ? ordered[i + 1].range.lowerBound : text.endIndex
            let item = cleanItem(String(text[itemStart..<itemEnd]))
            if !item.isEmpty { items.append(item) }
        }
        guard items.count >= 2 else { return nil }

        var out = ""
        if !leadIn.isEmpty {
            out += leadIn.hasSuffix(":") ? leadIn : leadIn + ":"
            out += "\n"
        }
        out += items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return out
    }

    private func collectMatches(
        of pattern: String, in text: String, rank: Int,
        into cues: inout [(range: Range<String.Index>, rank: Int)]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return }
        let full = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: full) {
            if let r = Range(match.range, in: text) {
                cues.append((r, rank))
            }
        }
    }

    /// Trim connective punctuation/words a speaker drops between list items and capitalize.
    private func cleanItem(_ raw: String) -> String {
        let punct = CharacterSet(charactersIn: " ,;:.\n\t")
        var s = raw.trimmingCharacters(in: punct)
        for lead in ["and ", "then ", "also "] where s.lowercased().hasPrefix(lead) {
            s = String(s.dropFirst(lead.count))
        }
        // A speaker often trails the previous item with "and" before the next ordinal
        // ("second eggs and third bread") — strip that trailing connective.
        for tail in [" and", " then", " also"] where s.lowercased().hasSuffix(tail) {
            s = String(s.dropLast(tail.count))
        }
        s = s.trimmingCharacters(in: punct)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    // MARK: - Light tidying (non-list prose)

    private func tidy(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Collapse runs of spaces (not newlines).
        if let regex = try? NSRegularExpression(pattern: #"[ \t]{2,}"#) {
            s = regex.stringByReplacingMatches(
                in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        // Capitalize the first alphabetical character.
        if let first = s.firstIndex(where: { $0.isLetter }) {
            s.replaceSubrange(first...first, with: s[first].uppercased())
        }
        return s
    }
}
