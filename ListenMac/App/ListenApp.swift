import AVFoundation
import ListenCore
import SwiftData
import SwiftUI

@main
struct ListenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @State private var didSetup = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DictationEntry.self,
            Snippet.self,
            CustomWord.self,
            StylePreset.self,
            AppStyleProfile.self,
            ScratchpadNote.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Main app window
        WindowGroup("Listen") {
            MainAppView()
                .environmentObject(appState)
                .modelContainer(sharedModelContainer)
                .task {
                    guard !didSetup else { return }
                    didSetup = true
                    let context = ModelContext(sharedModelContainer)
                    appState.modelContext = context
                    appState.setup()
                    // Give AppDelegate the appState so the status bar menu can use it
                    appDelegate.appState = appState
                    appDelegate.setupStatusBarMenu()
                    print("[Listen] Setup complete, UI should be visible")
                }
        }
        .defaultSize(width: 900, height: 600)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .modelContainer(sharedModelContainer)
        }

        Window("Welcome", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
    }
}
