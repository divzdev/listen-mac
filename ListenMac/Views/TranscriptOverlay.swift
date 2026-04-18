import Cocoa
import SwiftUI

/// A floating transparent panel that shows a compact recording indicator
/// at the bottom center of the screen.
final class TranscriptOverlayController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<TranscriptOverlayContent>?

    /// Show the overlay with the given text.
    @MainActor
    func show(text: String) {
        if panel == nil {
            createPanel()
        }
        hostingView?.rootView = TranscriptOverlayContent(
            text: text, status: .listening, audioLevel: 0)
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel?.animator().alphaValue = 1
        }
    }

    /// Update the displayed text and audio level.
    @MainActor
    func update(text: String, audioLevel: Float = 0) {
        let status: TranscriptOverlayContent.Status =
            text == "Processing…"
            ? .processing
            : text == "Rewriting with AI…"
                ? .rewriting : .listening
        hostingView?.rootView = TranscriptOverlayContent(
            text: text, status: status, audioLevel: audioLevel)
    }

    /// Hide and dismiss the overlay.
    @MainActor
    func dismiss() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel?.alphaValue = 1
        }
    }

    // MARK: - Private

    @MainActor
    private func createPanel() {
        let content = TranscriptOverlayContent(text: "", status: .listening, audioLevel: 0)
        let hosting = NSHostingView(rootView: content)
        hosting.layer?.backgroundColor = .clear
        hostingView = hosting

        let panelWidth: CGFloat = 480
        let panelHeight: CGFloat = 64

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY + 80

        let frame = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = hosting

        self.panel = panel
    }
}

/// SwiftUI content for the floating transcript overlay — compact pill design.
struct TranscriptOverlayContent: View {
    let text: String
    let status: Status
    let audioLevel: Float

    enum Status {
        case listening, processing, rewriting
    }

    var body: some View {
        HStack(spacing: 8) {
            statusIndicator

            if status == .processing {
                Text("Processing…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            } else if status == .rewriting {
                Text("Rewriting…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            } else if !text.isEmpty && text != "Listening…" {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.head)
            } else {
                AudioLevelBars(level: audioLevel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .listening:
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(.red.opacity(0.4))
                        .frame(width: 18, height: 18)
                )
        case .processing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .rewriting:
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .font(.system(size: 14))
        }
    }
}

/// Audio level bars that respond to real microphone input
struct AudioLevelBars: View {
    let level: Float

    @State private var displayLevel: Float = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white.opacity(0.85))
                    .frame(width: 3, height: barHeight(for: i))
            }
        }
        .frame(height: 26)
        .animation(.easeOut(duration: 0.08), value: displayLevel)
        .onChange(of: level) { _, newLevel in
            // Smooth but snappy: jump up fast, decay slower
            if newLevel > displayLevel {
                displayLevel = newLevel
            } else {
                displayLevel = displayLevel * 0.6 + newLevel * 0.4
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Aggressively amplify — speech RMS is typically 0.01-0.15
        let amplified = min(CGFloat(displayLevel) * 25.0, 1.0)
        let offsets: [CGFloat] = [0.5, 0.7, 0.85, 1.0, 0.85, 0.65, 0.45]
        let barLevel = min(amplified * offsets[index] * 1.5 + 0.08, 1.0)
        return max(3, barLevel * 24)
    }
}
