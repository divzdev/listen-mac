import Carbon
import Cocoa
import HotKey
import SwiftUI

/// A view that captures a keyboard shortcut when focused.
/// Click to start recording, press a key combination, click again to cancel.
struct KeyRecorderView: View {
    @Binding var key: Key
    @Binding var modifiers: NSEvent.ModifierFlags
    @State private var isRecording = false
    @State private var displayString: String = ""

    var onChange: ((Key, NSEvent.ModifierFlags) -> Void)?

    var body: some View {
        Button(action: {
            isRecording.toggle()
        }) {
            HStack(spacing: 6) {
                if isRecording {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                    Text("Press shortcut…")
                        .foregroundStyle(.secondary)
                } else {
                    Text(KeyRecorderView.hotkeyDisplayString(key: key, modifiers: modifiers))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isRecording
                            ? AnyShapeStyle(Color.red.opacity(0.1)) : AnyShapeStyle(.quaternary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.red : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .background(
            KeyCaptureRepresentable(
                isRecording: $isRecording,
                onKeyRecorded: { newKey, newMods in
                    key = newKey
                    modifiers = newMods
                    isRecording = false
                    onChange?(newKey, newMods)
                }
            )
        )
    }

    /// Convert a key + modifiers to a display string like "⌥⌘D".
    static func hotkeyDisplayString(key: Key, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyToString(key))
        return parts.joined()
    }
}

func hotkeyDisplayString(key: Key, modifiers: NSEvent.ModifierFlags) -> String {
    KeyRecorderView.hotkeyDisplayString(key: key, modifiers: modifiers)
}

private func keyToString(_ key: Key) -> String {
    switch key {
    case .a: return "A"
    case .b: return "B"
    case .c: return "C"
    case .d: return "D"
    case .e: return "E"
    case .f: return "F"
    case .g: return "G"
    case .h: return "H"
    case .i: return "I"
    case .j: return "J"
    case .k: return "K"
    case .l: return "L"
    case .m: return "M"
    case .n: return "N"
    case .o: return "O"
    case .p: return "P"
    case .q: return "Q"
    case .r: return "R"
    case .s: return "S"
    case .t: return "T"
    case .u: return "U"
    case .v: return "V"
    case .w: return "W"
    case .x: return "X"
    case .y: return "Y"
    case .z: return "Z"
    case .zero: return "0"
    case .one: return "1"
    case .two: return "2"
    case .three: return "3"
    case .four: return "4"
    case .five: return "5"
    case .six: return "6"
    case .seven: return "7"
    case .eight: return "8"
    case .nine: return "9"
    case .f1: return "F1"
    case .f2: return "F2"
    case .f3: return "F3"
    case .f4: return "F4"
    case .f5: return "F5"
    case .f6: return "F6"
    case .f7: return "F7"
    case .f8: return "F8"
    case .f9: return "F9"
    case .f10: return "F10"
    case .f11: return "F11"
    case .f12: return "F12"
    case .space: return "Space"
    case .escape: return "Esc"
    case .return: return "↩"
    case .tab: return "⇥"
    case .delete: return "⌫"
    case .forwardDelete: return "⌦"
    case .upArrow: return "↑"
    case .downArrow: return "↓"
    case .leftArrow: return "←"
    case .rightArrow: return "→"
    default: return "?"
    }
}

/// NSView-backed key capture that monitors local key events.
private struct KeyCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyRecorded: (Key, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyRecorded = onKeyRecorded
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isCapturing = isRecording
        nsView.onKeyRecorded = onKeyRecorded
    }
}

private class KeyCaptureNSView: NSView {
    var isCapturing = false
    var onKeyRecorded: ((Key, NSEvent.ModifierFlags) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isCapturing else { return event }

            // Require at least one modifier
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }

            if let key = Key(carbonKeyCode: UInt32(event.keyCode)) {
                self.onKeyRecorded?(key, mods)
            }
            return nil  // consume the event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
