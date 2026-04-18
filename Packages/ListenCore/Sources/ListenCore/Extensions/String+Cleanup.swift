import Foundation

extension String {
    /// Trim leading/trailing whitespace and normalize internal whitespace.
    public var cleaned: String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Check if the string is effectively empty (whitespace only).
    public var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
