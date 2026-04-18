import ListenCore
import SwiftData
import SwiftUI

/// Manage snippet triggers and their expansions — Apple Design.
struct SnippetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]
    @State private var showingAddSheet = false
    @State private var selectedSnippet: Snippet?
    @State private var isSearching = false
    @State private var searchText = ""

    private let bg = Color(nsColor: .windowBackgroundColor)
    private let textPrimary = Color(nsColor: .labelColor)
    private let textSecondary = Color(nsColor: .secondaryLabelColor)
    private let textTertiary = Color(nsColor: .tertiaryLabelColor)
    private let divider = Color(nsColor: .separatorColor).opacity(0.5)
    private let accent = Color.accentColor
    private let cardBg = Color(nsColor: .controlBackgroundColor).opacity(0.5)
    private let cardBorder = Color(nsColor: .separatorColor).opacity(0.4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Snippets")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.5)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add new", systemImage: "plus")
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

            // Search bar
            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(textTertiary)
                    TextField("Search snippets...", text: $searchText)
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
                            .foregroundStyle(textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 0.5))
                .padding(.horizontal, 36)
                .padding(.bottom, 14)
            }

            // Toolbar
            HStack {
                Text("ALL SNIPPETS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(textTertiary)
                    .tracking(1.0)

                Spacer()

                HStack(spacing: 16) {
                    toolbarIcon("magnifyingglass") {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isSearching.toggle()
                            if !isSearching { searchText = "" }
                        }
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 14)

            Rectangle().fill(divider).frame(height: 1)
                .padding(.horizontal, 36)

            if filteredSnippets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 42))
                        .foregroundStyle(divider)
                    Text(snippets.isEmpty ? "No snippets yet" : "No matching snippets")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(textSecondary)
                    Text(
                        snippets.isEmpty
                            ? "Create snippets to quickly expand text shortcuts"
                            : "Try a different search term"
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(textTertiary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredSnippets) { snippet in
                            snippetRow(snippet)
                            if snippet.id != filteredSnippets.last?.id {
                                Rectangle().fill(divider).frame(height: 1)
                                    .padding(.horizontal, 36)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
        .sheet(isPresented: $showingAddSheet) {
            AddSnippetView { trigger, expansion, category in
                let snippet = Snippet(trigger: trigger, expansion: expansion, category: category)
                modelContext.insert(snippet)
            }
        }
        .sheet(item: $selectedSnippet) { snippet in
            EditSnippetView(snippet: snippet)
        }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        Button {
            selectedSnippet = snippet
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Text(snippet.trigger)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                    .frame(width: 100, alignment: .leading)

                Text(snippet.expansion)
                    .font(.system(size: 14))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(snippet.category)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .quaternaryLabelColor), in: Capsule())
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") { selectedSnippet = snippet }
            Button("Copy expansion") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snippet.expansion, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { modelContext.delete(snippet) }
        }
    }

    private func toolbarIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var filteredSnippets: [Snippet] {
        if searchText.isEmpty { return snippets }
        return snippets.filter {
            $0.trigger.localizedCaseInsensitiveContains(searchText)
                || $0.expansion.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Edit Snippet Sheet

struct EditSnippetView: View {
    @Bindable var snippet: Snippet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Snippet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(ListenPillButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            Form {
                TextField("Trigger (e.g. /sig)", text: $snippet.trigger)
                    .font(.system(.body, design: .monospaced))
                TextField("Category", text: $snippet.category)
                Section("Expansion") {
                    TextEditor(text: $snippet.expansion)
                        .frame(minHeight: 100)
                        .font(.body)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Add Snippet Sheet

struct AddSnippetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trigger = ""
    @State private var expansion = ""
    @State private var category = "General"

    let onSave: (String, String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Snippet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(nsColor: .labelColor))
                Spacer()
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 13))
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                    Button("Save") {
                        onSave(trigger, expansion, category)
                        dismiss()
                    }
                    .buttonStyle(ListenPillButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(trigger.isEmpty || expansion.isEmpty)
                }
            }
            .padding(24)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            Form {
                TextField("Trigger (e.g. /sig)", text: $trigger)
                    .font(.system(.body, design: .monospaced))
                TextField("Category", text: $category)
                Section("Expansion") {
                    TextEditor(text: $expansion)
                        .frame(minHeight: 100)
                        .font(.body)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
