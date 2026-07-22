import ApplicationServices
import Cocoa
import OSLog

/// Inserts text into the currently focused text field.
/// Uses AppleScript to send ⌘V keystroke — works without Accessibility permission.
final class TextInsertionService {

    /// Insert text into the frontmost app's focused text field via clipboard paste.
    /// Returns `false` if the ⌘V couldn't be delivered (e.g. Accessibility/Automation not
    /// granted) so the caller can tell the user instead of failing silently.
    @discardableResult
    func insertText(_ text: String) -> Bool {
        AppLog.app.info("Inserting text via clipboard paste (\(text.count, privacy: .public) chars)")
        return insertViaClipboard(text)
    }

    // MARK: - Streaming Session

    // Streaming pastes many chunks in quick succession; per-chunk clipboard save/restore would
    // race its own 0.5s-delayed restores and clobber later chunks. Instead the session saves the
    // user's clipboard ONCE at dictation start and restores it once at the end.
    private var sessionSavedType: NSPasteboard.PasteboardType?
    private var sessionSavedData: Data?
    private var sessionActive = false

    /// Begin a streaming-insertion session: remember the user's clipboard so it can be restored
    /// when the session ends.
    func beginStreamingSession() {
        let pasteboard = NSPasteboard.general
        sessionSavedType = pasteboard.pasteboardItems?.first?.types.first
        sessionSavedData = sessionSavedType.flatMap {
            pasteboard.pasteboardItems?.first?.data(forType: $0)
        }
        sessionActive = true
    }

    /// Paste one streamed chunk without touching the saved clipboard state.
    @discardableResult
    func insertStreamingChunk(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        usleep(50_000)  // let the pasteboard update propagate
        return simulatePaste()
    }

    /// End the session. `restore: true` puts the pre-dictation clipboard back (used when chunks
    /// were streamed); `restore: false` just drops the session state (used when the classic
    /// insert-at-end path runs, which manages its own clipboard save/restore — a delayed session
    /// restore could otherwise race that paste).
    func endStreamingSession(restore: Bool) {
        guard sessionActive else { return }
        sessionActive = false
        let savedType = sessionSavedType
        let savedData = sessionSavedData
        sessionSavedType = nil
        sessionSavedData = nil
        guard restore, let savedType, let savedData else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(savedData, forType: savedType)
        }
    }

    // MARK: - Clipboard Paste

    /// Insert text by putting it on the clipboard and simulating ⌘V.
    private func insertViaClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents to restore later
        let savedType = pasteboard.pasteboardItems?.first?.types.first
        let savedData = savedType.flatMap { pasteboard.pasteboardItems?.first?.data(forType: $0) }

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to let pasteboard update propagate
        usleep(50_000)  // 50ms

        let pasted = simulatePaste()
        if pasted {
            AppLog.app.info("Paste succeeded")
        } else {
            AppLog.app.error("Paste FAILED — Accessibility/Automation not granted")
        }

        // Only restore the previous clipboard if we actually pasted. If we couldn't, leave our
        // text on the clipboard so the user can press ⌘V manually.
        if pasted, let savedType, let savedData {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setData(savedData, forType: savedType)
            }
        }
        return pasted
    }

    /// Simulate pressing ⌘V. Returns whether the keystroke was delivered.
    private func simulatePaste() -> Bool {
        let trusted = AXIsProcessTrusted()
        AppLog.app.info("AXIsProcessTrusted: \(trusted, privacy: .public)")

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            AppLog.app.info(
                "Frontmost app: \(frontApp.localizedName ?? "unknown", privacy: .public) (\(frontApp.bundleIdentifier ?? "no-bundle", privacy: .public))"
            )
        }

        // Strategy 1: CGEvent (needs Accessibility)
        if trusted {
            AppLog.app.info("Using CGEvent paste (accessibility granted)")
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(20_000)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
            return true
        }

        // Strategy 2: osascript subprocess (needs Automation permission for System Events)
        AppLog.app.info("Using osascript subprocess paste")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "tell application \"System Events\" to keystroke \"v\" using command down",
        ]
        let pipe = Pipe()
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let status = process.terminationStatus
            if status == 0 {
                AppLog.app.info("osascript paste succeeded")
                return true
            }
            let errData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            AppLog.app.error("osascript failed (status \(status, privacy: .public)): \(errStr, privacy: .public)")
            return false
        } catch {
            AppLog.app.error("osascript launch failed: \(error, privacy: .public)")
            return false
        }
    }
}
