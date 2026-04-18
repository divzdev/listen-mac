import Foundation
import WhisperKit

/// Wraps WhisperKit to provide on-device speech-to-text transcription.
/// Supports real-time partial results via callback and final transcript.
@MainActor
public final class TranscriptionService: ObservableObject {
    @Published public var partialText: String = ""
    @Published public var finalText: String = ""
    @Published public var isModelLoaded: Bool = false
    @Published public var modelLoadProgress: String = ""
    @Published public var isTranscribing: Bool = false

    private var whisperKit: WhisperKit?
    private var currentModelName: String

    public init(modelName: String = "base") {
        self.currentModelName = modelName
    }

    // MARK: - Model Management

    /// Load the WhisperKit model. Downloads on first use (~150-800MB depending on model).
    public func loadModel(name: String? = nil) async throws {
        let model = name ?? currentModelName
        currentModelName = model
        modelLoadProgress = "Loading \(model) model…"

        let config = WhisperKitConfig(model: model, verbose: false)
        whisperKit = try await WhisperKit(config)

        isModelLoaded = true
        modelLoadProgress = ""
    }

    /// List available model names from the HuggingFace repo.
    public func availableModels() -> [String] {
        let models = WhisperKit.recommendedModels()
        return models.supported.isEmpty ? ["tiny", "base", "small", "medium", "large-v3"] : models.supported
    }

    // MARK: - Transcription

    /// Transcribe an audio buffer (Float array at 16kHz).
    /// Calls back with partial results during transcription.
    public func transcribe(audioArray: [Float], language: String? = nil) async throws -> String {
        guard let whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        isTranscribing = true
        partialText = ""
        finalText = ""

        var options = DecodingOptions()
        if let language {
            options.language = language
        }
        options.chunkingStrategy = .vad

        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: audioArray,
            decodeOptions: options
        ) { progress in
            // Update partial text on each callback
            Task { @MainActor in
                self.partialText = progress.text
            }
            return true // continue transcription
        }

        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        finalText = text
        isTranscribing = false
        return text
    }

    /// Reset state between dictation sessions.
    public func reset() {
        partialText = ""
        finalText = ""
        isTranscribing = false
    }
}

// MARK: - Errors

public enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model not loaded. Please wait for model download to complete."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}
