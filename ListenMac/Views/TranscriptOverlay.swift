import Cocoa
import SwiftUI

/// A small floating pill that shows a premium recording indicator, centered near the bottom of
/// the active screen. The transcript itself streams into the focused app, so this stays a compact
/// status/waveform indicator rather than a wide text bar.
final class TranscriptOverlayController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<TranscriptOverlayContent>?
    private var autoDismissWork: DispatchWorkItem?

    /// Invoked when the user clicks ✕ on the pill — discard the dictation.
    var onCancel: (() -> Void)?
    /// Invoked when the user clicks ✓ on the pill — stop and process.
    var onDone: (() -> Void)?

    /// Show the overlay in listening state.
    @MainActor
    func show(text: String) {
        autoDismissWork?.cancel()  // a real recording start supersedes any pending info message
        autoDismissWork = nil
        present(makeContent(text: text, status: .listening, audioLevel: 0))
    }

    /// Show a transient informational message (no recording indicator) that dismisses itself.
    /// Used to give feedback when a hotkey press can't start recording yet — e.g. the Whisper
    /// model is still downloading — instead of the app appearing to do nothing.
    @MainActor
    func showMessage(_ text: String, dismissAfter seconds: TimeInterval = 2.8) {
        present(makeContent(text: text, status: .info, audioLevel: 0))
        autoDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        autoDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Update the displayed status and audio level. During listening the pill shows only the
    /// live waveform — the words go into the focused app, not the overlay.
    @MainActor
    func update(text: String, audioLevel: Float = 0) {
        let status: TranscriptOverlayContent.Status =
            text.hasPrefix("Processing")
            ? .processing
            : text == "Rewriting with AI…" ? .rewriting : .listening
        hostingView?.rootView = makeContent(text: text, status: status, audioLevel: audioLevel)
        // Width is fixed while listening; reposition only when the content actually resizes.
        repositionIfSizeChanged()
    }

    @MainActor
    private func makeContent(
        text: String, status: TranscriptOverlayContent.Status, audioLevel: Float
    ) -> TranscriptOverlayContent {
        TranscriptOverlayContent(
            text: text, status: status, audioLevel: audioLevel,
            onCancel: { [weak self] in self?.onCancel?() },
            onDone: { [weak self] in self?.onDone?() })
    }

    /// Hide and dismiss the overlay.
    @MainActor
    func dismiss() {
        autoDismissWork?.cancel()
        autoDismissWork = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel?.alphaValue = 1
        }
    }

    // MARK: - Private

    @MainActor
    private func present(_ content: TranscriptOverlayContent) {
        if panel == nil {
            createPanel()
        }
        hostingView?.rootView = content
        repositionIfSizeChanged(force: true)
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel?.animator().alphaValue = 1
        }
    }

    @MainActor
    private func createPanel() {
        let hosting = NSHostingView(
            rootView: makeContent(text: "", status: .listening, audioLevel: 0))
        hosting.layer?.backgroundColor = .clear
        hostingView = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 132, height: 40),
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
        // Interactive: the ✕/✓ buttons need clicks. The .nonactivatingPanel style means clicking
        // them does NOT steal focus from the app being dictated into.
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting
        self.panel = panel
    }

    /// Size the panel to fit its content and center it horizontally near the bottom of the active
    /// screen. Recomputed on each show so multi-monitor setups and screen changes stay centered —
    /// and so the pill (not a fixed-width bar) is what's actually centered on screen. Skips the
    /// resize when the size is unchanged to avoid per-frame churn while the waveform animates.
    @MainActor
    private func repositionIfSizeChanged(force: Bool = false) {
        guard let panel, let hosting = hostingView else { return }
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        size.width = min(max(size.width.rounded(.up), 60), 460)
        size.height = max(size.height.rounded(.up), 30)

        let current = panel.frame
        if !force && abs(current.width - size.width) < 1 && abs(current.height - size.height) < 1 {
            return
        }

        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.frame ?? .zero
        let origin = NSPoint(
            x: (screenFrame.midX - size.width / 2).rounded(),
            y: screenFrame.minY + 96
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

/// SwiftUI content for the floating overlay — a compact, premium pill.
struct TranscriptOverlayContent: View {
    let text: String
    let status: Status
    let audioLevel: Float
    var onCancel: (() -> Void)?
    var onDone: (() -> Void)?

    enum Status {
        case listening, processing, rewriting, info
    }

    var body: some View {
        content
            .padding(.horizontal, status == .info ? 14 : 13)
            .padding(.vertical, status == .info ? 10 : 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).fill(.black.opacity(0.28)))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
            .environment(\.colorScheme, .dark)
            .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .listening:
            // ✕ cancel · live waveform · ✓ done — like a call bar. Clicks don't steal focus.
            HStack(spacing: 9) {
                PillButton(systemName: "xmark", prominent: false) { onCancel?() }
                WaveformLine(level: audioLevel)
                    .frame(width: 58, height: 20)
                PillButton(systemName: "checkmark", prominent: true) { onDone?() }
            }
        case .processing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(.white)
                // Carries the ETA, e.g. "Processing… ~2s".
                Text(text.isEmpty ? "Processing…" : text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        case .rewriting:
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.purple)
                Text("Rewriting…")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        case .info:
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(text)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A small circular pill button (✕ / ✓). `prominent` renders a filled white circle with dark
/// glyph (the affirmative action); otherwise a subtle translucent circle with a light glyph.
private struct PillButton: View {
    let systemName: String
    let prominent: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(prominent ? Color.black.opacity(0.85) : .white.opacity(0.85))
                .frame(width: 20, height: 20)
                .background {
                    Circle().fill(
                        prominent
                            ? Color.white.opacity(isHovering ? 1.0 : 0.88)
                            : Color.white.opacity(isHovering ? 0.28 : 0.16))
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .onHover { isHovering = $0 }
    }
}

/// A Siri-style multi-wave voice indicator: a flat line when the user is silent, and several
/// layered sine waves that swell and travel while they speak. Amplitude is driven entirely by the
/// live mic level, so "speaking vs not speaking" is unmistakable at a glance.
struct WaveformLine: View {
    let level: Float

    @State private var amplitude: CGFloat = 0  // smoothed 0…1 speaking energy

    /// Each layer: frequency (cycles across width), phase speed, amplitude share, opacity.
    private static let layers: [(freq: CGFloat, speed: Double, amp: CGFloat, opacity: CGFloat)] = [
        (2.0, 5.0, 1.0, 0.95),
        (3.1, -3.6, 0.65, 0.45),
        (4.3, 7.8, 0.4, 0.25),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let midY = size.height / 2
                let peak = (midY - 1) * amplitude  // silence ⇒ 0 ⇒ flat line

                for layer in Self.layers {
                    var path = Path()
                    let step: CGFloat = 1.5
                    var x: CGFloat = 0
                    while x <= size.width {
                        let rel = Double(x / size.width)
                        // Fade toward the ends so the waves stay contained in the pill.
                        let envelope = pow(sin(rel * .pi), 1.4)
                        let wave = sin(rel * .pi * 2 * Double(layer.freq) + now * layer.speed)
                        let y = midY + CGFloat(wave * envelope) * peak * layer.amp
                        if x == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        x += step
                    }
                    context.stroke(
                        path,
                        with: .color(.white.opacity(layer.opacity)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .onChange(of: level) { _, newLevel in
            // Speech RMS is ~0.01–0.15; amplify hard so normal speech fills the pill and the
            // listening state is unmistakable. Snap up fast, decay smoothly to a flat line.
            let target = min(CGFloat(newLevel) * 38.0, 1.0)
            amplitude = target > amplitude ? target : amplitude * 0.85 + target * 0.15
        }
    }
}
