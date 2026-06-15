import ApplicationServices
import Cocoa

/// Inserts text into the currently focused text field.
/// Uses AppleScript to send ⌘V keystroke — works without Accessibility permission.
final class TextInsertionService {

    /// Insert text into the frontmost app's focused text field via clipboard paste.
    /// Returns `false` if the ⌘V couldn't be delivered (e.g. Accessibility/Automation not
    /// granted) so the caller can tell the user instead of failing silently.
    @discardableResult
    func insertText(_ text: String) -> Bool {
        print("[Listen] Inserting text via clipboard paste (\(text.count) chars)")
        return insertViaClipboard(text)
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
        print("[Listen] Paste \(pasted ? "succeeded" : "FAILED")")

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
            return true
        }

        // Strategy 2: osascript subprocess (needs Automation permission for System Events)
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
                return true
            }
            let errData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            print("[Listen] osascript failed (status \(status)): \(errStr)")
            return false
        } catch {
            print("[Listen] osascript launch failed: \(error)")
            return false
        }
    }
}
