import Foundation
import SwiftData

/// Scans text for snippet triggers and expands them inline.
public struct SnippetExpander {
    public init() {}

    /// Expand all snippet triggers found in the text.
    /// - Parameters:
    ///   - text: The transcript text to scan.
    ///   - snippets: Available snippets to match against.
    /// - Returns: Text with all matching triggers replaced by their expansions.
    public func expand(_ text: String, using snippets: [Snippet]) -> String {
        guard !snippets.isEmpty else { return text }

        var result = text
        // Sort by trigger length descending to match longer triggers first
        let sorted = snippets.sorted { $0.trigger.count > $1.trigger.count }

        for snippet in sorted {
            result = result.replacingOccurrences(of: snippet.trigger, with: snippet.expansion)
        }

        return result
    }
}
