import ListenCore
import SwiftData
import SwiftUI

// MARK: - Dictionary View (Apple Design)

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomWord.word) private var words: [CustomWord]
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var selectedFilter: DictFilter = .all
    @State private var showBanner = true
    @State private var isSearching = false
    @State private var sortAscending = true

    private let bg = Color(nsColor: .windowBackgroundColor)
    private let textPrimary = Color(nsColor: .labelColor)
    private let textSecondary = Color(nsColor: .secondaryLabelColor)
    private let textTertiary = Color(nsColor: .tertiaryLabelColor)
    private let divider = Color(nsColor: .separatorColor).opacity(0.5)
    private let accent = Color.accentColor
    private let cardBg = Color(nsColor: .controlBackgroundColor).opacity(0.5)
    private let cardBorder = Color(nsColor: .separatorColor).opacity(0.4)

    enum DictFilter: String, CaseIterable {
        case all = "All"
        case personal = "Personal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Dictionary")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.5)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add word", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 36)
            .padding(.top, 32)
            .padding(.bottom, 20)

            // Filter tabs
            HStack(spacing: 24) {
                ForEach(DictFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedFilter = filter }
                    } label: {
                        VStack(spacing: 8) {
                            Text(filter.rawValue)
                                .font(
                                    .system(
                                        size: 14,
                                        weight: selectedFilter == filter ? .semibold : .regular)
                                )
                                .foregroundStyle(
                                    selectedFilter == filter ? textPrimary : textSecondary)
                            Rectangle()
                                .fill(selectedFilter == filter ? accent : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                HStack(spacing: 16) {
                    iconButton("magnifyingglass") {
                        withAnimation(.easeInOut(duration: 0.15)) { isSearching.toggle() }
                        if !isSearching { searchText = "" }
                    }
                    iconButton("arrow.up.arrow.down") {
                        withAnimation(.easeInOut(duration: 0.15)) { sortAscending.toggle() }
                    }
                }
            }
            .padding(.horizontal, 36)

            Rectangle().fill(divider).frame(height: 1)
                .padding(.horizontal, 36)
                .padding(.bottom, isSearching ? 0 : 20)

            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(textTertiary)
                    TextField("Search words...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 0.5))
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if showBanner {
                        heroBanner
                            .padding(.horizontal, 36)
                    }

                    wordChips
                        .padding(.horizontal, 36)

                    wordList
                        .padding(.horizontal, 36)
                }
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
        .sheet(isPresented: $showingAddSheet) {
            AddWordView { word, hint, category in
                let entry = CustomWord(word: word, pronunciationHint: hint, category: category)
                modelContext.insert(entry)
            }
        }
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13))
                .foregroundStyle(textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.25, green: 0.10, blue: 0.55),
                                Color(red: 0.15, green: 0.30, blue: 0.65),
                                Color(red: 0.10, green: 0.50, blue: 0.60),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)
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
                                .frame(width: 100, height: 100)
                                .blur(radius: 20)
                                .offset(x: -20, y: -5)
                            Circle()
                                .fill(accent.opacity(0.15))
                                .frame(width: 70, height: 70)
                                .blur(radius: 15)
                                .offset(x: 10, y: 15)
                        }
                        .padding(.trailing, 30)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Listen speaks the way you speak.")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Text(
                        "Add personal terms, company jargon, or industry-specific lingo to improve transcription accuracy."
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .padding(.trailing, 60)
            }

            Button {
                withAnimation(.easeOut(duration: 0.2)) { showBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(10)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color(red: 0.25, green: 0.10, blue: 0.55).opacity(0.25), radius: 20, y: 8)
    }

    // MARK: - Word Chips

    private var wordChips: some View {
        FlowLayout(spacing: 8) {
            Button {
                showingAddSheet = true
            } label: {
                Label("Add new word", systemImage: "plus")
                    .font(.system(size: 13))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().stroke(cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            ForEach(filteredWords.prefix(8)) { word in
                Text(word.word)
                    .font(.system(size: 13))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(cardBorder, lineWidth: 0.5))
            }
        }
    }

    // MARK: - Word List

    private var wordList: some View {
        VStack(spacing: 0) {
            ForEach(filteredWords) { word in
                HStack {
                    Text(word.word)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textPrimary)

                    if let hint = word.pronunciationHint, !hint.isEmpty {
                        Text("→ \(hint)")
                            .font(.system(size: 14))
                            .foregroundStyle(textSecondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(word)
                    }
                }

                if word.id != filteredWords.last?.id {
                    Rectangle().fill(divider).frame(height: 1)
                }
            }
        }
    }

    private var filteredWords: [CustomWord] {
        var base = Array(words)
        if selectedFilter == .personal {
            base = base.filter { $0.category == "Personal" || $0.category == "Names" }
        }
        if !searchText.isEmpty {
            base = base.filter { $0.word.localizedCaseInsensitiveContains(searchText) }
        }
        return sortAscending ? base : base.reversed()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (
        size: CGSize, positions: [CGPoint]
    ) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Add Word Sheet

struct AddWordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var word = ""
    @State private var pronunciationHint = ""
    @State private var category = "General"

    let onSave: (String, String?, String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Word")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(nsColor: .labelColor))

            Form {
                TextField("Word or phrase", text: $word)
                TextField("Pronunciation hint (optional)", text: $pronunciationHint)
                Picker("Category", selection: $category) {
                    Text("General").tag("General")
                    Text("Names").tag("Names")
                    Text("Technical").tag("Technical")
                    Text("Medical").tag("Medical")
                    Text("Legal").tag("Legal")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave(word, pronunciationHint.isEmpty ? nil : pronunciationHint, category)
                    dismiss()
                }
                .buttonStyle(ListenPillButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(word.isEmpty)
            }
        }
        .padding()
        .frame(width: 380, height: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
