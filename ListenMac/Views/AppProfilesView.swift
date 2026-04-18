import ListenCore
import SwiftData
import SwiftUI

/// Manage per-app style profiles — automatically use a specific style
/// when dictating into a particular application.
struct AppProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppStyleProfile.appName) private var profiles: [AppStyleProfile]
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Profiles")
                        .font(.headline)
                    Text("Auto-switch style when dictating into specific apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if profiles.isEmpty {
                ContentUnavailableView(
                    "No App Profiles",
                    systemImage: "app.badge.checkmark",
                    description: Text(
                        "Add a profile to automatically switch style when dictating in specific apps."
                    )
                )
            } else {
                List {
                    ForEach(profiles) { profile in
                        AppProfileRow(profile: profile)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(profile)
                                }
                            }
                    }
                    .onDelete(perform: deleteProfiles)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddAppProfileView { bundleID, appName, style in
                let profile = AppStyleProfile(
                    appBundleID: bundleID, appName: appName, styleName: style)
                modelContext.insert(profile)
            }
        }
        .frame(minWidth: 450, minHeight: 350)
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(profiles[index])
        }
    }
}

struct AppProfileRow: View {
    @Bindable var profile: AppStyleProfile

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: appPath(for: profile.appBundleID)))
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.appName)
                    .font(.body)
                Text(profile.appBundleID)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Picker("", selection: $profile.styleName) {
                Text("Casual").tag("Casual")
                Text("Work").tag("Work")
                Text("Email").tag("Email")
            }
            .pickerStyle(.menu)
            .frame(width: 120)
        }
        .padding(.vertical, 4)
    }

    private func appPath(for bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path ?? ""
    }
}

struct AddAppProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedApp: RunningApp?
    @State private var selectedStyle = "Work"
    @State private var installedApps: [RunningApp] = []
    @State private var searchText = ""

    let onSave: (String, String, String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add App Profile")
                .font(.headline)

            TextField("Search apps…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List(filteredApps, selection: $selectedApp) { app in
                HStack(spacing: 10) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    VStack(alignment: .leading) {
                        Text(app.name)
                            .font(.body)
                        Text(app.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tag(app)
            }
            .frame(height: 200)

            HStack {
                Text("Style:")
                Picker("", selection: $selectedStyle) {
                    Text("Casual").tag("Casual")
                    Text("Work").tag("Work")
                    Text("Email").tag("Email")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    if let app = selectedApp {
                        onSave(app.bundleID, app.name, selectedStyle)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedApp == nil)
            }
        }
        .padding()
        .frame(width: 400, height: 420)
        .onAppear { loadInstalledApps() }
    }

    private var filteredApps: [RunningApp] {
        if searchText.isEmpty { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadInstalledApps() {
        // Get all installed apps from /Applications + running apps
        var apps: [RunningApp] = []
        let workspace = NSWorkspace.shared

        // Currently running apps
        for runningApp in workspace.runningApplications {
            if let bundleID = runningApp.bundleIdentifier,
                let name = runningApp.localizedName,
                runningApp.activationPolicy == .regular
            {
                let icon = runningApp.icon
                apps.append(RunningApp(bundleID: bundleID, name: name, icon: icon))
            }
        }

        // Also scan /Applications
        let fm = FileManager.default
        if let appURLs = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Applications"),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in appURLs where url.pathExtension == "app" {
                if let bundle = Bundle(url: url),
                    let bundleID = bundle.bundleIdentifier
                {
                    let name =
                        (bundle.infoDictionary?["CFBundleName"] as? String)
                        ?? url.deletingPathExtension().lastPathComponent
                    // Avoid duplicates
                    if !apps.contains(where: { $0.bundleID == bundleID }) {
                        let icon = workspace.icon(forFile: url.path)
                        apps.append(RunningApp(bundleID: bundleID, name: name, icon: icon))
                    }
                }
            }
        }

        installedApps = apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

struct RunningApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let icon: NSImage?

    var id: String { bundleID }

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}
