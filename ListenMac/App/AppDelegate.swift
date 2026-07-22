import AVFoundation
import Cocoa
import Combine
import OSLog
import ServiceManagement

/// Handles app-level setup: Accessibility permissions, login item, menu bar status item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    private var statusItem: NSStatusItem?
    private var statusCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.notice("applicationDidFinishLaunching")

        // Always prompt for Accessibility if not currently trusted
        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            )
        }

        // Make sure we show as a regular app with a Dock icon
        NSApp.setActivationPolicy(.regular)

        // Explicitly activate and show window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Status Bar Menu (called after appState is available)

    func setupStatusBarMenu() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Listen")
        }

        rebuildMenu()

        // Observe recording status to update icon color
        if let appState = appState {
            statusCancellable = appState.$status
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newStatus in
                    self?.updateStatusIcon(newStatus)
                }
        }

        AppLog.app.info("Status bar menu created")
    }

    private func updateStatusIcon(_ status: AppState.DictationStatus) {
        guard let button = statusItem?.button else { return }
        switch status {
        case .listening:
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = NSImage(
                systemSymbolName: "mic.fill", accessibilityDescription: "Listening")?
                .withSymbolConfiguration(config)
        case .processing:
            button.image = NSImage(
                systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Processing")
        default:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Listen")
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Home
        let homeItem = NSMenuItem(title: "Home", action: #selector(showHome), keyEquivalent: "")
        homeItem.target = self
        menu.addItem(homeItem)

        menu.addItem(.separator())

        // Paste last transcript
        let pasteItem = NSMenuItem(
            title: "Paste last transcript", action: #selector(pasteLastTranscript),
            keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = [.command, .option]
        pasteItem.target = self
        if appState?.lastDictationText.isEmpty ?? true {
            pasteItem.isEnabled = false
        }
        menu.addItem(pasteItem)

        menu.addItem(.separator())

        // Shortcuts
        let shortcutsItem = NSMenuItem(
            title: "Shortcuts", action: #selector(showShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        // Microphone submenu
        let micMenu = NSMenu()
        let micItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        let currentMicID = appState?.selectedMicrophoneID

        for device in devices {
            let deviceItem = NSMenuItem(
                title: device.localizedName,
                action: #selector(selectMicrophone(_:)),
                keyEquivalent: ""
            )
            deviceItem.target = self
            deviceItem.representedObject = device.uniqueID
            if device.uniqueID == currentMicID {
                deviceItem.state = .on
            }
            micMenu.addItem(deviceItem)
        }
        micItem.submenu = micMenu
        menu.addItem(micItem)

        // Languages submenu
        let langMenu = NSMenu()
        let langItem = NSMenuItem(title: "Languages", action: nil, keyEquivalent: "")
        let languages: [(String, String)] = [
            ("English", "en"), ("Spanish", "es"), ("French", "fr"),
            ("German", "de"), ("Italian", "it"), ("Portuguese", "pt"),
            ("Chinese", "zh"), ("Japanese", "ja"), ("Korean", "ko"),
            ("Hindi", "hi"), ("Auto-detect", "auto"),
        ]
        let currentLang = UserDefaults.standard.string(forKey: "language") ?? "en"
        for (name, code) in languages {
            let li = NSMenuItem(
                title: name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            li.target = self
            li.representedObject = code
            if code == currentLang { li.state = .on }
            langMenu.addItem(li)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Listen", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func showHome() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func pasteLastTranscript() {
        appState?.reDictate()
    }

    @objc private func showShortcuts() {
        // Try macOS 14+ selector first, fall back to macOS 13 selector
        if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String else { return }
        appState?.selectMicrophone(deviceID: deviceID)
        rebuildMenu()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        UserDefaults.standard.set(code, forKey: "language")
        rebuildMenu()
    }

    // MARK: - Login Item

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.app.error("Failed to set launch at login: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
