import Carbon
import Cocoa
import HotKey
import OSLog

/// Manages dictation trigger via fn key (default) or custom hotkey.
/// fn key: hold to talk, release to stop. Requires Accessibility permission for global monitoring.
final class HotKeyManager {
    enum Mode {
        case holdToTalk
        case toggle
    }

    enum TriggerMethod {
        case fnKey  // Hold fn to record (default)
        case customHotkey  // Traditional hotkey combo
    }

    var mode: Mode = .holdToTalk
    var triggerMethod: TriggerMethod = .fnKey
    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?

    private var hotKey: HotKey?
    private var isRecording = false
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?

    // Custom hotkey (used when triggerMethod == .customHotkey)
    private var currentKey: Key = .d
    private var currentModifiers: NSEvent.ModifierFlags = [.command, .option]

    // Persistence keys for the custom shortcut so it survives relaunch.
    private static let keyCodeDefault = "hotkeyKeyCode"
    private static let modifiersDefault = "hotkeyModifierFlags"

    // fn key code
    private static let fnKeyCode: UInt16 = 63

    // Debounce: require fn held for 250ms before starting recording
    private var fnPressTimer: DispatchWorkItem?
    private var fnPressedTime: Date?
    private static let fnDebounceInterval: TimeInterval = 0.25

    // Safety timeout: auto-stop after 120s
    private var safetyTimer: DispatchWorkItem?
    private static let maxRecordingDuration: TimeInterval = 120

    /// Register the dictation trigger based on current triggerMethod.
    func register() {
        unregister()
        switch triggerMethod {
        case .fnKey:
            registerFnKey()
        case .customHotkey:
            AppLog.hotkey.notice("Registering custom hotkey trigger")
            registerCustomHotkey()
        }
    }

    /// Unregister all triggers.
    func unregister() {
        // Remove fn key monitors
        if let monitor = globalFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            globalFlagsMonitor = nil
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsMonitor = nil
        }
        // Cancel timers
        cancelFnTimer()
        cancelSafetyTimer()
        fnPressedTime = nil
        // Remove Carbon hotkey
        hotKey = nil
        isRecording = false
    }

    /// Externally end the recording state (e.g. the user clicked ✓/✕ on the overlay pill instead
    /// of using the key). Without this, toggle mode would treat the next press as a "stop".
    func syncRecordingEnded() {
        cancelFnTimer()
        cancelSafetyTimer()
        fnPressedTime = nil
        isRecording = false
    }

    /// Change the custom shortcut key combination, persisting it across launches.
    func updateShortcut(key: Key, modifiers: NSEvent.ModifierFlags) {
        currentKey = key
        currentModifiers = modifiers
        // Persist so the choice survives relaunch (was previously in-memory only — the
        // shortcut reverted to the default ⌘⌥D every time the app restarted).
        UserDefaults.standard.set(Int(key.carbonKeyCode), forKey: Self.keyCodeDefault)
        UserDefaults.standard.set(Int(modifiers.rawValue), forKey: Self.modifiersDefault)
        if triggerMethod == .customHotkey {
            unregister()
            register()
        }
    }

    /// Restore a previously saved custom shortcut from UserDefaults. Call before `register()`.
    func loadPersistedShortcut() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.keyCodeDefault) != nil else { return }
        if let key = Key(carbonKeyCode: UInt32(defaults.integer(forKey: Self.keyCodeDefault))) {
            currentKey = key
        }
        currentModifiers = NSEvent.ModifierFlags(
            rawValue: UInt(defaults.integer(forKey: Self.modifiersDefault)))
    }

    // MARK: - fn Key Support

    private func registerFnKey() {
        // The global key monitor only receives events when the app is trusted for Accessibility.
        // Without it, the fn key silently does nothing in other apps — the #1 "I gave permissions
        // but it doesn't work" report. Log it loudly so it's diagnosable from `log show`.
        if !AXIsProcessTrusted() {
            AppLog.hotkey.error(
                "fn-key trigger active but Accessibility is NOT granted — global key monitor will receive nothing. Enable Listen in System Settings > Privacy & Security > Accessibility, and run it from /Applications."
            )
        } else {
            AppLog.hotkey.notice("fn-key trigger active, Accessibility granted")
        }
        // Global monitor: captures fn key events in other apps (needs Accessibility)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.handleFnFlagsChanged(event)
        }
        // Local monitor: captures fn key events when our app is active
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.handleFnFlagsChanged(event)
            return event
        }
        AppLog.hotkey.notice("fn-key monitors installed (global+local)")
    }

    private func handleFnFlagsChanged(_ event: NSEvent) {
        // Only respond to the fn key itself (keyCode 63)
        guard event.keyCode == Self.fnKeyCode else { return }

        let fnPressed = event.modifierFlags.contains(.function)
        // Ignore if other modifiers are held (cmd, opt, ctrl, shift)
        let otherModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let hasOtherModifiers = !event.modifierFlags.intersection(otherModifiers).isEmpty
        guard !hasOtherModifiers else {
            // Other modifiers held — cancel any pending fn timer and stop if recording
            cancelFnTimer()
            if isRecording {
                isRecording = false
                DispatchQueue.main.async { [weak self] in
                    self?.onRecordingStopped?()
                }
            }
            return
        }

        if fnPressed && !isRecording {
            // Start debounce timer — only begin recording if fn is held for 250ms
            fnPressedTime = Date()
            cancelFnTimer()
            let timer = DispatchWorkItem { [weak self] in
                guard let self, self.fnPressedTime != nil else { return }
                self.isRecording = true
                AppLog.hotkey.notice("fn held past debounce — starting recording")
                DispatchQueue.main.async {
                    self.onRecordingStarted?()
                }
                // Start safety timeout
                self.startSafetyTimer()
            }
            fnPressTimer = timer
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.fnDebounceInterval, execute: timer)
        } else if !fnPressed {
            // fn released — cancel pending timer or stop recording
            cancelFnTimer()
            cancelSafetyTimer()
            fnPressedTime = nil
            if isRecording {
                isRecording = false
                DispatchQueue.main.async { [weak self] in
                    self?.onRecordingStopped?()
                }
            }
        }
    }

    private func cancelFnTimer() {
        fnPressTimer?.cancel()
        fnPressTimer = nil
    }

    private func startSafetyTimer() {
        cancelSafetyTimer()
        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.isRecording else { return }
            AppLog.hotkey.info(
                "Safety timeout: auto-stopping recording after \(Self.maxRecordingDuration, privacy: .public)s"
            )
            self.isRecording = false
            // Gracefully stop and process what was recorded (same as a normal stop) — do NOT also
            // force-idle in the same hop, which would tear the dictation down mid-processing.
            DispatchQueue.main.async {
                self.onRecordingStopped?()
            }
        }
        safetyTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxRecordingDuration, execute: timer)
    }

    private func cancelSafetyTimer() {
        safetyTimer?.cancel()
        safetyTimer = nil
    }

    // MARK: - Custom Hotkey Support

    private func registerCustomHotkey() {
        hotKey = HotKey(key: currentKey, modifiers: currentModifiers)

        hotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            switch self.mode {
            case .holdToTalk:
                if !self.isRecording {
                    self.isRecording = true
                    self.onRecordingStarted?()
                }
            case .toggle:
                if self.isRecording {
                    self.isRecording = false
                    self.onRecordingStopped?()
                } else {
                    self.isRecording = true
                    self.onRecordingStarted?()
                }
            }
        }

        hotKey?.keyUpHandler = { [weak self] in
            guard let self else { return }
            if self.mode == .holdToTalk && self.isRecording {
                self.isRecording = false
                self.onRecordingStopped?()
            }
        }
    }
}
