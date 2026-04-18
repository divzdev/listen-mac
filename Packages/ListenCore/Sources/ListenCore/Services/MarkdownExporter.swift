import Foundation

/// Exports dictation history as Markdown documents.
public struct MarkdownExporter {
    public init() {}

    /// Export a single dictation entry as Markdown.
    public func exportEntry(_ entry: DictationEntryDTO) -> String {
        var md = "## Dictation — \(formatDate(entry.timestamp))\n\n"
        md += "| Field | Value |\n|---|---|\n"
        md += "| Duration | \(String(format: "%.1f", entry.duration))s |\n"
        if let app = entry.appName { md += "| Application | \(app) |\n" }
        if let style = entry.styleName { md += "| Style | \(style) |\n" }
        md += "| Language | \(entry.language) |\n\n"
        md += "### Formatted Text\n\n\(entry.text)\n\n"
        md += "### Raw Transcript\n\n\(entry.rawText)\n\n---\n\n"
        return md
    }

    /// Export multiple entries as a single Markdown document.
    public func exportAll(_ entries: [DictationEntryDTO]) -> String {
        var md = "# Listen — Dictation History\n\n"
        md += "Exported on \(formatDate(Date()))\n\n"
        md += "Total entries: \(entries.count)\n\n---\n\n"

        for entry in entries.sorted(by: { $0.timestamp > $1.timestamp }) {
            md += exportEntry(entry)
        }

        return md
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
