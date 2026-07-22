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
        modelLoadProgress = "Preparing \(model) model…"

        // prewarm forces Core ML's device-specific model specialization to happen NOW, during
        // this visible "preparing" phase, instead of lazily on the user's first dictation.
        // Without it the first transcription on a fresh install (or after an OS update evicts
        // Core ML's cache) pays the full compile cost and appears to hang in "processing".
        let config = WhisperKitConfig(model: model, verbose: false, prewarm: true, load: true)
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

    // Serialize all transcription: WhisperKit must not run two transcriptions on one instance at
    // once. This is enforced HERE, not in callers — a caller that times out or is cancelled can't
    // actually stop an in-flight WhisperKit call (there's no cancellation check), so the next call
    // must wait for it here rather than overlapping. Safe because this type is @MainActor: the
    // busy-flag reads/writes never interleave except across the explicit awaits below.
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquire() async throws {
        while isBusy {
            await withCheckedContinuation { waiters.append($0) }
            if Task.isCancelled {
                // Hand the baton to the next waiter before bailing so nobody is stranded.
                if !isBusy, !waiters.isEmpty {
                    waiters.removeFirst().resume()
                }
                throw CancellationError()
            }
        }
        isBusy = true
    }

    private func release() {
        isBusy = false
        if !waiters.isEmpty {
            waiters.removeFirst().resume()
        }
    }

    /// Transcribe an audio buffer (Float array at 16kHz).
    /// Calls back with partial results during transcription. Serialized: concurrent callers run
    /// strictly one at a time.
    public func transcribe(audioArray: [Float], language: String? = nil) async throws -> String {
        try await acquire()
        defer { release() }

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

        // Bridge Swift cancellation into WhisperKit's callback protocol (returning false stops
        // inference) — without this, a caller's timeout/cancel can't actually end the work, and
        // "recovery" would silently wait for the full transcription anyway.
        let cancelled = CancelFlag()
        let results: [TranscriptionResult] = try await withTaskCancellationHandler {
            try await whisperKit.transcribe(
                audioArray: audioArray,
                decodeOptions: options
            ) { progress in
                // Update partial text on each callback
                Task { @MainActor in
                    self.partialText = progress.text
                }
                return !cancelled.isSet  // false stops transcription early
            }
        } onCancel: {
            cancelled.set()
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

/// Thread-safe cancellation flag readable from WhisperKit's non-isolated progress callback.
private final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }

    func set() {
        lock.lock()
        flag = true
        lock.unlock()
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
