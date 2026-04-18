import ListenCore
import SwiftUI

/// First-run onboarding flow guiding users through permissions and model setup.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0

    private let steps = ["Welcome", "Microphone", "Accessibility", "Model", "Ready"]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Content area
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: microphoneStep
                case 2: accessibilityStep
                case 3: modelStep
                default: readyStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)

            Divider()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                }
                Spacer()
                if currentStep < steps.count - 1 {
                    Button("Continue") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        appState.hasCompletedOnboarding = true
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Listen")
                .font(.title)
                .fontWeight(.bold)

            Text(
                "Local-first voice dictation for your Mac.\nAll transcription happens on-device — no cloud, no subscription."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Text("Hold fn and start speaking to dictate.")
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                "Listen needs microphone access to hear your voice.\nThe first time you dictate, macOS will ask for permission."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Button("Open System Settings") {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Accessibility Permission")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                "Listen uses Accessibility to insert text directly into the focused app. Without it, text is copied to clipboard instead."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Circle()
                    .fill(appState.isAccessibilityGranted ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(appState.isAccessibilityGranted ? "Permission granted" : "Not yet granted")
                    .font(.callout)
            }

            HStack(spacing: 12) {
                Button("Open System Settings") {
                    if let url = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                Button("Check Again") {
                    appState.refreshAccessibilityStatus()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var modelStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("Speech Model")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                "Listen is downloading the Whisper model for on-device transcription. This happens once (~150MB for the Base model)."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            if appState.isModelLoaded {
                Label("Model ready!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else if !appState.modelLoadProgress.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.modelLoadProgress)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if let error = appState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "command", text: "Hold fn to start/stop dictation")
                tipRow(icon: "text.quote", text: "Create snippets for frequently used phrases")
                tipRow(icon: "paintbrush", text: "Switch style (Casual/Work/Email) from the menu")
                tipRow(icon: "clock", text: "View past dictations in History")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
        }
    }
}
