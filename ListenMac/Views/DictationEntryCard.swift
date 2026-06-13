import AppKit
import ListenCore
import SwiftData
import SwiftUI

/// Which layout a `DictationEntryCard` renders. `pinned` is the horizontal shelf card.
enum DictationCardMode {
    case comfortable
    case compact
    case gallery
    case pinned
}

/// Resolves and caches the real macOS app icon for a bundle id, so cards can show the
/// source app (Chrome, iTerm2, …) the way a clipboard manager does — color and identity.
@MainActor
enum AppIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = icon
        return icon
    }
}

/// A single dictation in the history. Renders one of four layouts, reveals an action
/// pill on hover, and exposes every action to VoiceOver via the context menu.
struct DictationEntryCard: View {
    let entry: DictationEntry
    let viewMode: DictationCardMode

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHovered = false
    @State private var isShowingQuickLook = false
    @State private var isRewriting = false

    private let radius: CGFloat = 13

    var body: some View {
        layout
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { isShowingQuickLook = true }
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { isHovered = hovering }
            }
            .sheet(isPresented: $isShowingQuickLook) {
                DictationQuickLookView(entry: entry, appState: appState)
            }
            // The context menu is the single source of actions for both mouse/keyboard and
            // VoiceOver (macOS surfaces it in the actions rotor) — so we take full control of
            // the element's a11y with `.ignore` + a hand-written label, no duplicate actions.
            .contextMenu { contextMenu }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Layouts

    @ViewBuilder private var layout: some View {
        switch viewMode {
        case .comfortable: comfortableLayout
        case .compact: compactLayout
        case .gallery: galleryLayout
        case .pinned: pinnedLayout
        }
    }

    private var comfortableLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.text)
                .font(.callout)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(DS.divider)
            cardFooter
        }
        .padding(14)
        .modifier(CardChrome(radius: radius, isPinned: entry.isPinned, isHovered: isHovered))
        .overlay(alignment: .topTrailing) { cornerOverlay }
        .overlay { rewriteOverlay }
    }

    private var galleryLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.text)
                .font(.callout)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 6)
            Divider().overlay(DS.divider)
            cardFooter
        }
        .padding(14)
        .frame(height: 150, alignment: .topLeading)
        .modifier(CardChrome(radius: radius, isPinned: entry.isPinned, isHovered: isHovered))
        .overlay(alignment: .topTrailing) { cornerOverlay }
        .overlay { rewriteOverlay }
    }

    private var compactLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(timeString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(DS.textTertiary)
                .frame(width: 70, alignment: .trailing)
            appIconView
            Text(entry.text)
                .font(.body)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if entry.isPinned, !isHovered {
                Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(DS.accent)
            }
            if entry.isFavorite, !isHovered {
                Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
            }
            if isHovered { actionPill }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 18)
        .background(isHovered ? Color(nsColor: .quaternaryLabelColor).opacity(0.35) : .clear)
        .overlay { rewriteOverlay }
    }

    private var pinnedLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.text)
                .font(.callout.weight(.medium))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                appIconView
                Text(entry.appName ?? "Dictation")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(DS.accent)
            }
        }
        .padding(12)
        .frame(width: 280, height: 92, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: radius).fill(
                LinearGradient(
                    colors: [DS.accent.opacity(0.16), DS.accent.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(DS.accent.opacity(0.3), lineWidth: 0.5))
        .overlay(alignment: .topTrailing) { if isHovered { actionPill.padding(6) } }
        .overlay { rewriteOverlay }
    }

    // MARK: - Footer (app icon + source + time)

    private var cardFooter: some View {
        HStack(spacing: 7) {
            appIconView
            Text(entry.appName ?? "Dictation")
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .lineLimit(1)
            if let style = entry.styleName {
                Text(style)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(DS.accent.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 6)
            Text("\(relativeTime) · \(durationLabel)")
                .font(.caption2)
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var appIconView: some View {
        if let icon = AppIconProvider.icon(for: entry.appBundleID) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.accent)
                .frame(width: 16, height: 16)
                .background(DS.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    /// Pin/favorite state badges when idle; the action pill when hovered.
    @ViewBuilder private var cornerOverlay: some View {
        if isHovered {
            actionPill.padding(8)
        } else if entry.isPinned || entry.isFavorite {
            HStack(spacing: 5) {
                if entry.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(DS.accent)
                }
                if entry.isFavorite {
                    Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                }
            }
            .padding(10)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Action pill (hover)

    @ViewBuilder private var actionPill: some View {
        if isHovered && !isRewriting {
            HStack(spacing: 2) {
                pillButton("arrow.up.left.and.arrow.down.right", "Expand") { isShowingQuickLook = true }
                pillButton("doc.on.doc", "Copy") { copy() }
                pillButton("arrow.uturn.left", "Re-insert into active app") { reinsert() }
                pillButton(
                    entry.isPinned ? "pin.slash" : "pin",
                    entry.isPinned ? "Unpin" : "Pin",
                    tint: entry.isPinned ? DS.accent : nil
                ) { togglePin() }
                pillButton(
                    entry.isFavorite ? "star.fill" : "star",
                    entry.isFavorite ? "Remove from favorites" : "Add to favorites",
                    tint: entry.isFavorite ? .yellow : nil
                ) { toggleFavorite() }
                overflowMenu
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DS.cardBorder, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.14), radius: 5, y: 1)
            .transition(reduceMotion ? .identity : .opacity)
            .accessibilityHidden(true)
        }
    }

    private func pillButton(
        _ icon: String, _ label: String, tint: Color? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? DS.textSecondary)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var overflowMenu: some View {
        Menu {
            if appState.isLLMAvailable {
                Menu("Rewrite with AI") {
                    ForEach(RewriteCommand.allCases, id: \.rawValue) { command in
                        Button(command.displayName) { rewrite(command) }
                    }
                }
                Divider()
            }
            Button("Copy raw transcript") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.rawText, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { delete() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.textSecondary)
                .frame(width: 24, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
    }

    @ViewBuilder private var rewriteOverlay: some View {
        if isRewriting {
            ZStack {
                RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial)
                ProgressView().controlSize(.small)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }

    // MARK: - Context menu

    @ViewBuilder private var contextMenu: some View {
        Button("Copy") { copy() }
        Button("Re-insert") { reinsert() }
        Button("Show Full Text") { isShowingQuickLook = true }
        Divider()
        Button(entry.isPinned ? "Unpin" : "Pin") { togglePin() }
        Button(entry.isFavorite ? "Remove from Favorites" : "Add to Favorites") { toggleFavorite() }
        if appState.isLLMAvailable {
            Menu("Rewrite with AI") {
                ForEach(RewriteCommand.allCases, id: \.rawValue) { command in
                    Button(command.displayName) { rewrite(command) }
                }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { delete() }
    }

    // MARK: - Actions

    /// Persist a model edit, surfacing any failure instead of silently dropping the user's change.
    private func save() {
        do { try modelContext.save() }
        catch { appState.errorMessage = "Couldn't save change: \(error.localizedDescription)" }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    private func reinsert() { appState.textInsertion.insertText(entry.text) }

    private func togglePin() {
        entry.isPinned.toggle()
        save()
    }

    private func toggleFavorite() {
        entry.isFavorite.toggle()
        save()
    }

    private func delete() {
        modelContext.delete(entry)
        save()
    }

    private func rewrite(_ command: RewriteCommand) {
        isRewriting = true
        Task {
            do {
                let rewritten = try await appState.llmService.rewrite(entry.text, command: command)
                await MainActor.run {
                    entry.text = rewritten
                    save()
                    isRewriting = false
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = "Rewrite failed: \(error.localizedDescription)"
                    isRewriting = false
                }
            }
        }
    }

    // MARK: - Formatting

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var timeString: String { Self.timeFormatter.string(from: entry.timestamp) }

    private var durationLabel: String {
        entry.duration < 1 ? "<1s" : "\(Int(entry.duration.rounded()))s"
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.timestamp, relativeTo: Date())
    }

    private var accessibilityLabel: String {
        var parts = [entry.text, "dictated at \(timeString)"]
        if let app = entry.appName { parts.append("in \(app)") }
        if let style = entry.styleName { parts.append("\(style) style") }
        if entry.isPinned { parts.append("pinned") }
        if entry.isFavorite { parts.append("favorite") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Card chrome

/// Shared card background: glass fill, a border that warms to the accent on hover, and a
/// lift on hover — the small touches that make a card feel tactile instead of flat.
private struct CardChrome: ViewModifier {
    let radius: CGFloat
    let isPinned: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial)
                if isPinned {
                    RoundedRectangle(cornerRadius: radius).fill(
                        LinearGradient(
                            colors: [DS.accent.opacity(0.10), DS.accent.opacity(0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: isHovered ? 1 : 0.5)
            )
            .shadow(
                color: isHovered ? DS.accent.opacity(0.18) : DS.glassShadow,
                radius: isHovered ? 10 : 5, y: isHovered ? 4 : 2)
    }

    private var borderColor: Color {
        if isHovered { return DS.accent.opacity(0.55) }
        if isPinned { return DS.accent.opacity(0.3) }
        return DS.cardBorder
    }
}

// MARK: - Quick look (detail modal)

/// Full dictation detail, presented as a centered modal — header, scrollable body,
/// structured metadata, and a Pin / Re-insert / Copy action bar.
struct DictationQuickLookView: View {
    let entry: DictationEntry
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showRaw = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentBody
            Divider()
            metadata
            Divider()
            actionBar
        }
        .frame(width: 620, height: 580)
        .background(DS.bg)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(DS.accent.opacity(0.16))
                if let icon = AppIconProvider.icon(for: entry.appBundleID) {
                    Image(nsImage: icon).resizable().interpolation(.high).frame(width: 26, height: 26)
                } else {
                    Image(systemName: "waveform").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.accent)
                }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Dictation")
                    .font(.title3.bold())
                    .foregroundStyle(DS.textPrimary)
                Text("\(relativeTime) · \(durationLabel)")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color(nsColor: .quaternaryLabelColor), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    // MARK: Body

    private var contentBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(showRaw ? entry.rawText : entry.text)
                    .font(.body)
                    .foregroundStyle(DS.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Metadata

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 11) {
            metaRow("SOURCE", entry.appName ?? "Unknown app", appIcon: AppIconProvider.icon(for: entry.appBundleID))
            metaRow("DICTATED", entry.timestamp.formatted(date: .abbreviated, time: .shortened))
            if let style = entry.styleName { metaRow("STYLE", style) }
            metaRow("DURATION", String(format: "%.1fs", entry.duration))
            metaRow("LANGUAGE", entry.language.uppercased())
        }
        .padding(20)
    }

    private func metaRow(_ label: String, _ value: String, appIcon: NSImage? = nil) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .tracking(0.5)
                .frame(width: 84, alignment: .leading)
            if let appIcon {
                Image(nsImage: appIcon).resizable().interpolation(.high).frame(width: 16, height: 16)
            }
            Text(value)
                .font(.callout)
                .foregroundStyle(DS.textSecondary)
            Spacer()
        }
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(showRaw ? "Show clean" : "Show raw") { showRaw.toggle() }
                .buttonStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(DS.accent)

            Spacer()

            Button { appState.textInsertion.insertText(entry.text) } label: {
                Label("Re-insert", systemImage: "arrow.uturn.left").font(.callout.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                entry.isPinned.toggle()
                try? entry.modelContext?.save()
            } label: {
                Label(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.text, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc").font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("c", modifiers: .command)
        }
        .padding(20)
    }

    // MARK: Formatting

    private var durationLabel: String {
        entry.duration < 1 ? "<1s" : "\(Int(entry.duration.rounded()))s"
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.timestamp, relativeTo: Date())
    }
}
