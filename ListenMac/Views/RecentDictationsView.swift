import ListenCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - View mode

/// How the Recent Dictations history is laid out. Persisted across launches.
enum DictationListViewMode: String, CaseIterable, Identifiable {
    case comfortable
    case compact
    case gallery

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .comfortable: return "rectangle.grid.1x2"
        case .compact: return "list.bullet"
        case .gallery: return "square.grid.2x2"
        }
    }

    var label: String {
        switch self {
        case .comfortable: return "Comfortable view"
        case .compact: return "Compact view"
        case .gallery: return "Gallery view"
        }
    }
}

// MARK: - Recent Dictations section

/// The redesigned dictation history shown on Home: a pinned shelf above a
/// date-grouped, view-mode-aware list with per-entry actions and search.
struct RecentDictationsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DictationEntry.timestamp, order: .reverse) private var entries: [DictationEntry]

    @AppStorage("dictationListViewMode")
    private var viewModeRaw = DictationListViewMode.comfortable.rawValue
    @State private var search = ""
    @State private var isSearching = false
    @State private var page = 0
    @State private var filter: DictationFilter = .all
    @State private var showDeleteConfirm = false
    @State private var bulkDelete: BulkDeleteAction = .all

    private let pageSize = 20

    enum BulkDeleteAction { case sevenDays, thirtyDays, all }

    enum DictationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case pinned = "Pinned"
        case favorites = "Favorites"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .pinned: return "pin.fill"
            case .favorites: return "star.fill"
            }
        }
        var tint: Color {
            switch self {
            case .all: return DS.accent
            case .pinned: return .orange
            case .favorites: return .yellow
            }
        }
    }

    private var viewMode: DictationListViewMode {
        DictationListViewMode(rawValue: viewModeRaw) ?? .comfortable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isSearching { searchBar }

            filterBar

            if showPinnedShelf {
                pinnedSection
            }

            if listEntries.isEmpty {
                emptyState
            } else {
                groupedList
                if totalPages > 1 { pagination }
            }
        }
        // Deleting the last entry on a page (via a card action) shrinks the list; keep the
        // page index in range so we never strand the user on an empty page.
        .onChange(of: listEntries.count) { _, _ in
            if page >= totalPages { page = max(0, totalPages - 1) }
        }
        .alert("Delete Dictations", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performBulkDelete() }
        } message: {
            switch bulkDelete {
            case .sevenDays: Text("Delete dictations older than 7 days? Pinned items are kept. This cannot be undone.")
            case .thirtyDays: Text("Delete dictations older than 30 days? Pinned items are kept. This cannot be undone.")
            case .all: Text("Delete ALL unpinned dictations? Pinned items are kept. This cannot be undone.")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Recent Dictations")
                .font(.title2.bold())
                .foregroundStyle(DS.textPrimary)

            Spacer()

            viewModePicker

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    isSearching.toggle()
                    if !isSearching { search = ""; page = 0 }
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(isSearching ? DS.accent : DS.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSearching ? "Hide search" : "Search dictations")

            manageMenu
        }
    }

    private var viewModePicker: some View {
        Picker("View mode", selection: $viewModeRaw) {
            ForEach(DictationListViewMode.allCases) { mode in
                Image(systemName: mode.icon)
                    .accessibilityLabel(mode.label)
                    .tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Choose how dictations are displayed")
    }

    private var manageMenu: some View {
        Menu {
            Button { exportMarkdown() } label: { Label("Export as Markdown…", systemImage: "doc.richtext") }
            Button { exportJSON() } label: { Label("Export as JSON…", systemImage: "curlybraces") }
            if !entries.isEmpty {
                Divider()
                Button { bulkDelete = .sevenDays; showDeleteConfirm = true } label: {
                    Label("Delete older than 7 days", systemImage: "calendar.badge.minus")
                }
                Button { bulkDelete = .thirtyDays; showDeleteConfirm = true } label: {
                    Label("Delete older than 30 days", systemImage: "calendar")
                }
                Divider()
                Button(role: .destructive) { bulkDelete = .all; showDeleteConfirm = true } label: {
                    Label("Clear all (keep pinned)", systemImage: "trash")
                }
            }
        } label: {
            Label("Manage", systemImage: "ellipsis.circle")
                .font(.callout.weight(.medium))
                .foregroundStyle(DS.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Manage dictations")
    }

    // MARK: Filter rail

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(DictationFilter.allCases) { option in
                filterChip(option)
            }
            Spacer()
        }
    }

    private func filterChip(_ option: DictationFilter) -> some View {
        let isSelected = filter == option
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { filter = option; page = 0 }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : option.tint)
                Text(option.rawValue)
                    .font(.callout.weight(.medium))
                Text("\(count(for: option))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : DS.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        (isSelected ? Color.white.opacity(0.22) : Color(nsColor: .quaternaryLabelColor)),
                        in: Capsule())
            }
            .foregroundStyle(isSelected ? .white : DS.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                isSelected ? AnyShapeStyle(DS.accent) : AnyShapeStyle(Color(nsColor: .quaternaryLabelColor).opacity(0.5)),
                in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.rawValue), \(count(for: option)) dictations")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func count(for option: DictationFilter) -> Int {
        switch option {
        case .all: return entries.count
        case .pinned: return entries.lazy.filter(\.isPinned).count
        case .favorites: return entries.lazy.filter(\.isFavorite).count
        }
    }

    private var showPinnedShelf: Bool {
        filter == .all && search.isEmpty && !pinnedEntries.isEmpty
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.callout)
                .foregroundStyle(DS.textTertiary)
            TextField("Search dictations…", text: $search)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(DS.textPrimary)
                .onChange(of: search) { _, _ in page = 0 }
            if !search.isEmpty {
                Button { search = ""; page = 0 } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(DS.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.cardBorder, lineWidth: 0.5))
    }

    // MARK: Pinned shelf

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.accent)
                Text("Pinned")
                    .font(.caption.bold())
                    .foregroundStyle(DS.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text("\(pinnedEntries.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(DS.accent.opacity(0.12), in: Capsule())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pinnedEntries) { entry in
                        DictationEntryCard(entry: entry, viewMode: .pinned)
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: Grouped list

    @ViewBuilder private var groupedList: some View {
        switch viewMode {
        case .compact:
            VStack(spacing: 0) {
                ForEach(dateGroups, id: \.header) { group in
                    groupHeader(group.header)
                    ForEach(group.entries) { entry in
                        DictationEntryCard(entry: entry, viewMode: .compact)
                        if entry.id != group.entries.last?.id {
                            Rectangle().fill(DS.divider).frame(height: 0.5).padding(.leading, 20)
                        }
                    }
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.glassRadius))
            .overlay(RoundedRectangle(cornerRadius: DS.glassRadius).stroke(DS.cardBorder, lineWidth: 0.5))
            .shadow(color: DS.glassShadow, radius: 8, y: 2)

        case .comfortable:
            VStack(alignment: .leading, spacing: 18) {
                ForEach(dateGroups, id: \.header) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        groupHeader(group.header)
                        ForEach(group.entries) { entry in
                            DictationEntryCard(entry: entry, viewMode: .comfortable)
                        }
                    }
                }
            }

        case .gallery:
            VStack(alignment: .leading, spacing: 18) {
                ForEach(dateGroups, id: \.header) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        groupHeader(group.header)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 320), spacing: 14)],
                            spacing: 14
                        ) {
                            ForEach(group.entries) { entry in
                                DictationEntryCard(entry: entry, viewMode: .gallery)
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(DS.textTertiary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.top, viewMode == .compact ? 14 : 0)
            .padding(.horizontal, viewMode == .compact ? 20 : 2)
            .padding(.bottom, viewMode == .compact ? 8 : 0)
    }

    private var pagination: some View {
        HStack {
            Text("\(listEntries.count) \(search.isEmpty ? "dictations" : "results")")
                .font(.caption)
                .foregroundStyle(DS.textTertiary)
            Spacer()
            Button { withAnimation { page = max(0, page - 1) } } label: {
                Image(systemName: "chevron.left").font(.caption.weight(.medium))
                    .foregroundStyle(page > 0 ? DS.accent : DS.textTertiary)
            }
            .buttonStyle(.plain).disabled(page == 0)
            .accessibilityLabel("Previous page")

            Text("Page \(page + 1) of \(totalPages)")
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.textSecondary)

            Button { withAnimation { page = min(totalPages - 1, page + 1) } } label: {
                Image(systemName: "chevron.right").font(.caption.weight(.medium))
                    .foregroundStyle(page < totalPages - 1 ? DS.accent : DS.textTertiary)
            }
            .buttonStyle(.plain).disabled(page >= totalPages - 1)
            .accessibilityLabel("Next page")
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(DS.divider)
            Text(search.isEmpty ? "No dictations yet" : "No results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
            Text(
                search.isEmpty
                    ? "Hold fn and start speaking to create your first dictation"
                    : "Try a different search term"
            )
            .font(.body)
            .foregroundStyle(DS.textTertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.glassRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.glassRadius).stroke(DS.cardBorder, lineWidth: 0.5))
    }

    // MARK: Data

    private var pinnedEntries: [DictationEntry] { entries.filter(\.isPinned) }

    /// Entries for the paged, date-grouped list. The active filter is applied first; in the
    /// default "All" filter, pinned entries live in the shelf so we drop them from the list
    /// (unless the user is searching, where searching everything is what you'd expect).
    private var listEntries: [DictationEntry] {
        var result: [DictationEntry]
        switch filter {
        case .all: result = (search.isEmpty ? entries.filter { !$0.isPinned } : entries)
        case .pinned: result = entries.filter(\.isPinned)
        case .favorites: result = entries.filter(\.isFavorite)
        }
        if !search.isEmpty {
            result = result.filter {
                $0.text.localizedCaseInsensitiveContains(search)
                    || (($0.appName?.localizedCaseInsensitiveContains(search)) ?? false)
            }
        }
        return result
    }

    private var totalPages: Int { max(1, Int(ceil(Double(listEntries.count) / Double(pageSize)))) }

    private var pagedEntries: [DictationEntry] {
        let start = page * pageSize
        guard start < listEntries.count else { return [] }
        return Array(listEntries[start..<min(start + pageSize, listEntries.count)])
    }

    private static let groupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private var dateGroups: [DateGroup] {
        let calendar = Calendar.current
        var buckets: [String: [DictationEntry]] = [:]
        var order: [String] = []
        for entry in pagedEntries {
            let header: String
            if calendar.isDateInToday(entry.timestamp) {
                header = "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                header = "Yesterday"
            } else {
                header = Self.groupDateFormatter.string(from: entry.timestamp)
            }
            if buckets[header] == nil { buckets[header] = []; order.append(header) }
            buckets[header]?.append(entry)
        }
        return order.map { DateGroup(header: $0, entries: buckets[$0] ?? []) }
    }

    private func performBulkDelete() {
        let cutoff: Date?
        switch bulkDelete {
        case .sevenDays: cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .thirtyDays: cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .all: cutoff = nil
        }
        for entry in entries where !entry.isPinned {
            if let cutoff {
                if entry.timestamp < cutoff { modelContext.delete(entry) }
            } else {
                modelContext.delete(entry)
            }
        }
        do { try modelContext.save() }
        catch { appState.errorMessage = "Couldn't delete dictations: \(error.localizedDescription)" }
        page = 0
    }

    // MARK: Export (folded in from the retired History screen)

    private func dtos(_ source: [DictationEntry]) -> [DictationEntryDTO] {
        source.map {
            DictationEntryDTO(
                text: $0.text, rawText: $0.rawText, timestamp: $0.timestamp,
                duration: $0.duration, appName: $0.appName, styleName: $0.styleName,
                language: $0.language)
        }
    }

    private func exportMarkdown() {
        let markdown = MarkdownExporter().exportAll(dtos(entries))
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
        let data = ExportData(snippets: [], customWords: [], dictationHistory: dtos(entries))
        guard let jsonData = try? ExportImportService().exportToJSON(data) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "listen-history.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url { try? jsonData.write(to: url) }
        }
    }
}

struct DateGroup {
    let header: String
    let entries: [DictationEntry]
}
