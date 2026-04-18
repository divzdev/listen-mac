import ListenCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Displays the history of past dictation entries.
struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictationEntry.timestamp, order: .reverse) private var entries: [DictationEntry]
    @State private var searchText = ""
    @State private var selectedEntry: DictationEntry?
    @State private var filterFavorites = false

    var body: some View {
        NavigationSplitView {
            List(filteredEntries, selection: $selectedEntry) { entry in
                HistoryRow(entry: entry)
                    .tag(entry)
                    .contextMenu {
                        Button("Copy Text") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.text, forType: .string)
                        }
                        Button("Copy Raw") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.rawText, forType: .string)
                        }
                        Divider()
                        Button("Re-insert") {
                            appState.textInsertion.insertText(entry.text)
                        }
                        Divider()
                        if appState.isLLMAvailable {
                            Menu("Rewrite with AI") {
                                Button("Make Shorter") {
                                    rewriteEntry(entry, command: .makeShorter)
                                }
                                Button("Make Professional") {
                                    rewriteEntry(entry, command: .makeProfessional)
                                }
                                Button("Make Casual") {
                                    rewriteEntry(entry, command: .makeCasual)
                                }
                                Button("Bullet Points") {
                                    rewriteEntry(entry, command: .bulletPoints)
                                }
                                Button("Summarize") {
                                    rewriteEntry(entry, command: .summarize)
                                }
                            }
                            Divider()
                        }
                        Button("Toggle Favorite") {
                            entry.isFavorite.toggle()
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            modelContext.delete(entry)
                        }
                    }
            }
            .searchable(text: $searchText, prompt: "Search transcripts")
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $filterFavorites) {
                        Label("Favorites", systemImage: filterFavorites ? "star.fill" : "star")
                    }
                    .help("Show only favorites")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Export as Markdown…") { exportMarkdown() }
                        Button("Export as JSON…") { exportJSON() }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        } detail: {
            if let entry = selectedEntry {
                HistoryDetailView(entry: entry, appState: appState)
            } else {
                ContentUnavailableView(
                    "Select a transcript", systemImage: "doc.text",
                    description: Text("Choose a dictation from the list"))
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var filteredEntries: [DictationEntry] {
        var result = entries
        if filterFavorites {
            result = result.filter { $0.isFavorite }
        }
        if !searchText.isEmpty {
            result = result.filter { entry in
                entry.text.localizedCaseInsensitiveContains(searchText)
                    || entry.rawText.localizedCaseInsensitiveContains(searchText)
                    || (entry.appName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return result
    }

    private func rewriteEntry(_ entry: DictationEntry, command: RewriteCommand) {
        Task {
            do {
                let rewritten = try await appState.llmService.rewrite(entry.text, command: command)
                entry.text = rewritten
                try? modelContext.save()
            } catch {
                appState.errorMessage = "Rewrite failed: \(error.localizedDescription)"
            }
        }
    }

    private func exportMarkdown() {
        let exporter = MarkdownExporter()
        let dtos = filteredEntries.map {
            DictationEntryDTO(
                text: $0.text, rawText: $0.rawText, timestamp: $0.timestamp,
                duration: $0.duration, appName: $0.appName, styleName: $0.styleName,
                language: $0.language)
        }
        let markdown = exporter.exportAll(dtos)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "listen-history.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func exportJSON() {
        let dtos = filteredEntries.map {
            DictationEntryDTO(
                text: $0.text, rawText: $0.rawText, timestamp: $0.timestamp,
                duration: $0.duration, appName: $0.appName, styleName: $0.styleName,
                language: $0.language)
        }
        let data = ExportData(snippets: [], customWords: [], dictationHistory: dtos)
        let service = ExportImportService()
        guard let jsonData = try? service.exportToJSON(data) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "listen-history.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? jsonData.write(to: url)
            }
        }
    }
}

struct HistoryRow: View {
    let entry: DictationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Text(entry.text)
                    .lineLimit(2)
                    .font(.body)
            }

            HStack(spacing: 8) {
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let appName = entry.appName {
                    Text("• \(appName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let style = entry.styleName {
                    Text("• \(style)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct HistoryDetailView: View {
    @Bindable var entry: DictationEntry
    let appState: AppState

    @State private var isRewriting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata
                HStack(spacing: 16) {
                    Label(
                        entry.timestamp.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock")
                    Label(String(format: "%.1fs", entry.duration), systemImage: "waveform")
                    if let app = entry.appName {
                        Label(app, systemImage: "app")
                    }
                    if let style = entry.styleName {
                        Label(style, systemImage: "paintbrush")
                    }
                    Label(entry.language, systemImage: "globe")
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                // Final text
                Text("Formatted Text")
                    .font(.headline)
                Text(entry.text)
                    .textSelection(.enabled)
                    .font(.body)

                Divider()

                // Raw text
                Text("Raw Transcript")
                    .font(.headline)
                Text(entry.rawText)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(.secondary)

                // Rewrite section
                if appState.isLLMAvailable {
                    Divider()
                    HStack(spacing: 8) {
                        Text("Rewrite with AI")
                            .font(.headline)
                        if isRewriting {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(RewriteCommand.allCases, id: \.rawValue) { command in
                            Button(command.displayName) {
                                rewrite(command: command)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isRewriting)
                        }
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    entry.isFavorite.toggle()
                } label: {
                    Label(
                        "Favorite",
                        systemImage: entry.isFavorite ? "star.fill" : "star")
                }
            }
            ToolbarItem {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func rewrite(command: RewriteCommand) {
        isRewriting = true
        Task {
            do {
                let rewritten = try await appState.llmService.rewrite(
                    entry.text, command: command)
                entry.text = rewritten
            } catch {
                appState.errorMessage = "Rewrite failed: \(error.localizedDescription)"
            }
            isRewriting = false
        }
    }
}
