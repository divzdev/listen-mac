import ApplicationServices
import Cocoa

/// Inserts text into the currently focused text field.
/// Uses AppleScript to send ⌘V keystroke — works without Accessibility permission.
final class TextInsertionService {

    /// Insert text into the frontmost app's focused text field via clipboard paste.
    func insertText(_ text: String) {
        print("[Listen] Inserting text via clipboard paste (\(text.count) chars)")
        insertViaClipboard(text)
    }

    // MARK: - Clipboard Paste

    /// Insert text by putting it on the clipboard and simulating ⌘V via AppleScript.
    private func insertViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents to restore later
        let savedType = pasteboard.pasteboardItems?.first?.types.first
        let savedData = savedType.flatMap { pasteboard.pasteboardItems?.first?.data(forType: $0) }

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to let pasteboard update propagate
        usleep(50_000)  // 50ms

        // Simulate ⌘V via AppleScript
        simulatePaste()
        print("[Listen] Paste simulated")

        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let savedType, let savedData {
                pasteboard.clearContents()
                pasteboard.setData(savedData, forType: savedType)
            }
        }
    }

    /// Simulate pressing ⌘V via multiple strategies.
    private func simulatePaste() {
        let trusted = AXIsProcessTrusted()
        print("[Listen] AXIsProcessTrusted: \(trusted)")

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            print(
                "[Listen] Frontmost app: \(frontApp.localizedName ?? "unknown") (\(frontApp.bundleIdentifier ?? "no-bundle"))"
            )
        }

        // Strategy 1: CGEvent (needs Accessibility)
        if trusted {
            print("[Listen] Using CGEvent paste (accessibility granted)")
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(20_000)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
            return
        }

        // Strategy 2: osascript subprocess (inherits broader permissions)
        print("[Listen] Using osascript subprocess paste")
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
                print("[Listen] osascript paste succeeded")
            } else {
                let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                print("[Listen] osascript failed (status \(status)): \(errStr)")
            }
        } catch {
            print("[Listen] osascript launch failed: \(error)")
        }
    }
}
