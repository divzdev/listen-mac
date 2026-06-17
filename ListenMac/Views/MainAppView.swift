import ListenCore
import SwiftData
import SwiftUI

// MARK: - Apple Design System (Light + Dark)

enum DS {
    // Adaptive colors that follow system appearance
    static let bg = Color(nsColor: .windowBackgroundColor)
    static let sidebarBg = Color.clear  // Use material instead
    static let sidebarHover = Color(nsColor: .quaternaryLabelColor)
    static let sidebarSelected = Color.accentColor.opacity(0.12)
    static let accent = Color.accentColor
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let divider = Color(nsColor: .separatorColor).opacity(0.5)
    static let cardBg = Color(nsColor: .controlBackgroundColor).opacity(0.5)
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.4)

    // Modern gradient palette
    static let gradientStart = Color(red: 0.25, green: 0.10, blue: 0.55)
    static let gradientMid = Color(red: 0.15, green: 0.30, blue: 0.65)
    static let gradientEnd = Color(red: 0.10, green: 0.50, blue: 0.60)

    // Category accent palette — gives each section a distinct identity.
    static let tintHome = Color(red: 0.40, green: 0.55, blue: 1.00)
    static let tintDictionary = Color(red: 0.27, green: 0.83, blue: 0.64)
    static let tintSnippets = Color(red: 1.00, green: 0.68, blue: 0.30)
    static let tintStyle = Color(red: 0.82, green: 0.42, blue: 1.00)
    static let tintScratchpad = Color(red: 0.35, green: 0.74, blue: 1.00)

    // Glass card styling helper
    static let glassRadius: CGFloat = 16
    static let glassShadow = Color.black.opacity(0.08)
}

// MARK: - Main App View

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var selectedTab: SidebarTab = .home

    enum SidebarTab: String, CaseIterable, Identifiable {
        case home = "Home"
        case dictionary = "Dictionary"
        case snippets = "Snippets"
        case style = "Style"
        case scratchpad = "Scratchpad"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .dictionary: return "character.book.closed.fill"
            case .snippets: return "text.quote"
            case .style: return "paintbrush.fill"
            case .scratchpad: return "note.text"
            }
        }

        var tint: Color {
            switch self {
            case .home: return DS.tintHome
            case .dictionary: return DS.tintDictionary
            case .snippets: return DS.tintSnippets
            case .style: return DS.tintStyle
            case .scratchpad: return DS.tintScratchpad
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(DS.divider)
                .frame(width: 0.5)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.bg)
        .frame(minWidth: 880, minHeight: 580)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [DS.accent, DS.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: DS.accent.opacity(0.3), radius: 6, y: 2)
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Listen")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
            }
            .padding(.leading, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)

            // Nav
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            // Bottom
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(DS.divider)
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)

                sidebarBottomItem(icon: "gear", label: "Settings") {
                    openSettings()
                }
            }
            .padding(.bottom, 14)
        }
        .frame(width: 210)
        .background(.ultraThinMaterial)
    }

    private func sidebarButton(_ tab: SidebarTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedTab = tab }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? tab.tint : tab.tint.opacity(0.6))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DS.textPrimary : DS.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [tab.tint.opacity(0.22), tab.tint.opacity(0.06)],
                                startPoint: .leading, endPoint: .trailing))
                }
            }
            // Accent bar on the leading edge, colored to the section.
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule().fill(tab.tint).frame(width: 3, height: 16)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()  // kill the macOS focus ring that drew the boxy border
    }

    private func sidebarBottomItem(icon: String, label: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(DS.textTertiary)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .home:
            HomeView(selectedTab: $selectedTab)
        case .dictionary:
            DictionaryView()
        case .snippets:
            SnippetsView()
        case .style:
            StyleView(selectedTab: $selectedTab)
        case .scratchpad:
            ScratchpadView()
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Query(sort: \DictationEntry.timestamp, order: .reverse) private var entries: [DictationEntry]
    @Binding var selectedTab: MainAppView.SidebarTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Greeting
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome back, \(appState.userFirstName).")
                        .font(.largeTitle.bold())
                        .foregroundStyle(DS.textPrimary)
                        .tracking(-0.5)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("Start dictating by holding ")
                        .font(.title3)
                        .foregroundStyle(DS.textSecondary)
                        + Text("fn")
                        .font(.body.weight(.bold).monospaced())
                        .foregroundStyle(DS.accent)
                }
                .padding(.horizontal, 36)
                .padding(.top, 36)
                .padding(.bottom, 32)

                // Hero
                heroBanner
                    .padding(.horizontal, 36)
                    .padding(.bottom, 40)

                // Stat cards
                statsRow
                    .padding(.horizontal, 36)
                    .padding(.bottom, 36)

                // History
                RecentDictationsView()
                    .padding(.horizontal, 36)
                    .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            DS.bg.overlay(alignment: .top) {
                LinearGradient(
                    colors: [DS.accent.opacity(0.12), Color.clear],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: 320)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
    }

    private var heroBanner: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [DS.gradientStart, DS.gradientMid, DS.gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 170)
                .overlay {
                    // Glass highlight
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
                .overlay(alignment: .trailing) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                            .offset(x: -20, y: -15)
                        Circle()
                            .fill(DS.accent.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .blur(radius: 15)
                            .offset(x: 15, y: 25)
                    }
                    .padding(.trailing, 40)
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Your voice, your style.")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("Configure writing styles that match how you actually communicate.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = .style
                    }
                } label: {
                    Text("Set up styles")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: DS.gradientStart.opacity(0.25), radius: 20, y: 8)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Dictations",
                value: "\(entries.count)",
                detail: "\(dictationsThisWeek) this week",
                icon: "waveform",
                tint: DS.tintHome
            )
            statCard(
                title: "Model",
                value: appState.isModelLoaded ? "Ready" : "Loading",
                detail: modelDetail,
                icon: "cpu.fill",
                tint: appState.isModelLoaded ? DS.tintDictionary : .orange
            )
            statCard(
                title: "AI Enhance",
                value: appState.isLLMAvailable ? "Active" : "Off",
                detail: appState.isLLMAvailable ? "Connected" : "Not configured",
                icon: "sparkles",
                tint: appState.isLLMAvailable ? DS.tintStyle : DS.textTertiary
            )
        }
    }

    private var dictationsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.timestamp >= weekAgo }.count
    }

    private var modelDetail: String {
        let model = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
        return "\(model) · on-device"
    }

    private func statCard(title: String, value: String, detail: String, icon: String, tint: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.glassRadius))
        .overlay(alignment: .top) { tint.frame(height: 2) }  // colored top accent
        .clipShape(RoundedRectangle(cornerRadius: DS.glassRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.glassRadius).stroke(DS.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: DS.glassShadow, radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(detail)")
    }

}


// MARK: - Style View

struct StyleView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedStyleTab: StyleTab = .personal
    @State private var showBanner = true
    @Binding var selectedTab: MainAppView.SidebarTab

    enum StyleTab: String, CaseIterable {
        case personal = "Personal"
        case work = "Work"
        case email = "Email"
        case other = "Other"
        case autoCleanup = "Auto Cleanup"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Style")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(DS.textPrimary)
                    .tracking(-0.5)
                    .padding(.horizontal, 36)
                    .padding(.top, 32)
                    .padding(.bottom, 24)

                // Tab bar
                styleTabBar
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)

                if showBanner {
                    styleBanner
                        .padding(.horizontal, 36)
                        .padding(.bottom, 28)
                }

                styleContent
                    .padding(.horizontal, 36)
                    .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.bg)
    }

    private var styleTabBar: some View {
        HStack(spacing: 0) {
            ForEach(StyleTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedStyleTab = tab }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Text(tab.rawValue)
                                .font(
                                    .system(
                                        size: 14,
                                        weight: selectedStyleTab == tab ? .semibold : .regular)
                                )
                                .foregroundStyle(
                                    selectedStyleTab == tab ? DS.textPrimary : DS.textSecondary)
                            if tab == .autoCleanup {
                                Text("Beta")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DS.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(DS.accent.opacity(0.10), in: Capsule())
                            }
                        }
                        Rectangle()
                            .fill(selectedStyleTab == tab ? DS.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)
            }
            Spacer()
        }
    }

    private var styleBanner: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [DS.gradientStart, DS.gradientMid, DS.gradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 170)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay(alignment: .trailing) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.08))
                                .frame(width: 130, height: 130)
                                .blur(radius: 20)
                                .offset(x: -20, y: -10)
                            Circle()
                                .fill(DS.accent.opacity(0.15))
                                .frame(width: 90, height: 90)
                                .blur(radius: 15)
                                .offset(x: 15, y: 25)
                        }
                        .padding(.trailing, 40)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Make Listen sound like ")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        + Text("you.")
                        .font(.system(size: 22, weight: .bold).italic())
                        .foregroundStyle(.white)

                    Text("Set up different writing styles for different apps.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.75))

                    Button {
                        showBanner = false
                    } label: {
                        Text("Get started")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(.white.opacity(0.25), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(10)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: DS.gradientStart.opacity(0.25), radius: 20, y: 8)
    }

    @ViewBuilder
    private var styleContent: some View {
        switch selectedStyleTab {
        case .personal:
            styleDetailCard(
                title: "Personal",
                description:
                    "Relaxed, conversational tone — great for messages, notes, and casual writing.",
                sample:
                    "hey! just wanted to check in and see how things are going. let me know if you need anything 😊",
                styleName: "Casual"
            )
        case .work:
            styleDetailCard(
                title: "Work",
                description:
                    "Clear and professional — suitable for documents, reports, and team communication.",
                sample:
                    "Hi team, I wanted to follow up on the items we discussed in yesterday's meeting. Please see the updated timeline below.",
                styleName: "Work"
            )
        case .email:
            styleDetailCard(
                title: "Email",
                description:
                    "Structured and polite — formatted for email correspondence with proper greetings and sign-offs.",
                sample:
                    "Dear Alex,\n\nThank you for your message. I've reviewed the proposal and have a few suggestions I'd like to share.\n\nBest regards",
                styleName: "Email"
            )
        case .other:
            VStack(alignment: .leading, spacing: 24) {
                Text("Active Style")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)

                Picker("", selection: $appState.selectedStyle) {
                    Text("Casual").tag("Casual")
                    Text("Work").tag("Work")
                    Text("Email").tag("Email")
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Rectangle()
                    .fill(DS.divider)
                    .frame(height: 1)

                Text("Per-App Profiles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)

                AppProfilesView()
                    .frame(minHeight: 300)
            }
        case .autoCleanup:
            autoCleanupContent
        }
    }

    private func styleDetailCard(
        title: String, description: String, sample: String, styleName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textSecondary)
            }

            // Sample preview
            VStack(alignment: .leading, spacing: 12) {
                Text("SAMPLE OUTPUT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
                    .tracking(1.0)

                Text(sample)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textPrimary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(DS.cardBorder, lineWidth: 0.5))
            }

            Rectangle()
                .fill(DS.divider)
                .frame(height: 1)

            // Set active button
            HStack {
                if appState.selectedStyle == styleName {
                    Label("Active style", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    Button {
                        appState.selectedStyle = styleName
                    } label: {
                        Text("Set as active style")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(ListenPillButtonStyle())
                }
                Spacer()
            }
        }
    }

    @AppStorage("grammarCorrection") private var grammarCorrection = false

    private var autoCleanupContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Auto Cleanup")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text("Beta")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(DS.accent.opacity(0.10), in: Capsule())
                }
                Text(
                    "Automatically fix grammar, punctuation, and filler words after each dictation."
                )
                .font(.system(size: 14))
                .foregroundStyle(DS.textSecondary)
            }

            Toggle(isOn: $grammarCorrection) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grammar correction")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.textPrimary)
                    Text("Clean up transcribed text using AI before inserting")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textTertiary)
                }
            }
            .toggleStyle(.switch)
            .tint(DS.accent)

            Rectangle()
                .fill(DS.divider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("AI BACKEND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
                    .tracking(1.0)

                if appState.isLLMAvailable {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("No AI backend configured. Set one up in Settings → AI.")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Scratchpad View

struct ScratchpadView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScratchpadNote.updatedAt, order: .reverse) private var notes: [ScratchpadNote]
    @State private var searchText = ""
    @State private var selectedNote: ScratchpadNote?
    @State private var isSearching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Scratchpad")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DS.textPrimary)
                .tracking(-0.5)
                .padding(.horizontal, 36)
                .padding(.top, 32)
                .padding(.bottom, 24)

            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textTertiary)
                    TextField("Search notes...", text: $searchText)
                        .font(.system(size: 14))
                        .textFieldStyle(.plain)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isSearching = false
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(DS.cardBorder, lineWidth: 0.5))
                .padding(.horizontal, 36)
                .padding(.bottom, 14)
            }

            // Toolbar
            HStack {
                Text("RECENTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
                    .tracking(1.0)

                Spacer()

                HStack(spacing: 16) {
                    toolbarIcon("magnifyingglass") {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isSearching.toggle()
                            if !isSearching { searchText = "" }
                        }
                    }
                    toolbarIcon("plus") { addNote() }
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 14)

            Rectangle()
                .fill(DS.divider)
                .frame(height: 1)
                .padding(.horizontal, 36)

            if notes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 42))
                        .foregroundStyle(DS.divider)
                    Text("No notes yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.textSecondary)
                    Text("Create a note to get started")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredNotes) { note in
                            Button {
                                selectedNote = note
                            } label: {
                                ScratchpadNoteRow(note: note)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(note)
                                }
                            }
                            if note.id != filteredNotes.last?.id {
                                Rectangle()
                                    .fill(DS.divider)
                                    .frame(height: 1)
                                    .padding(.horizontal, 36)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.bg)
        .sheet(item: $selectedNote) { note in
            ScratchpadNoteEditor(note: note)
        }
    }

    private func toolbarIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(DS.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var filteredNotes: [ScratchpadNote] {
        if searchText.isEmpty { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func addNote() {
        let note = ScratchpadNote(title: "Untitled Note")
        modelContext.insert(note)
        try? modelContext.save()
        selectedNote = note
    }
}

struct ScratchpadNoteRow: View {
    let note: ScratchpadNote

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(note.updatedAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textTertiary)
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 36)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct ScratchpadNoteEditor: View {
    @Bindable var note: ScratchpadNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Title", text: $note.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DS.textPrimary)
                    .textFieldStyle(.plain)

                Spacer()

                Button("Done") {
                    note.updatedAt = Date()
                    dismiss()
                }
                .buttonStyle(ListenPillButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)

            Rectangle().fill(DS.divider).frame(height: 1)

            TextEditor(text: $note.content)
                .font(.system(size: 15))
                .foregroundStyle(DS.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(24)
                .onChange(of: note.content) { note.updatedAt = Date() }

            Rectangle().fill(DS.divider).frame(height: 1)

            HStack {
                let wordCount = note.content.split(separator: " ").count
                Text("\(wordCount) words")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textTertiary)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(note.content, forType: .string)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.accent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 540, height: 440)
        .background(DS.bg)
    }
}

// MARK: - Shared Button Styles

struct ListenHeroBtnStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ListenPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 6, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
