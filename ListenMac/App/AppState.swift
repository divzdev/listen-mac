import Combine
import ListenCore
import OSLog
import SwiftData
import SwiftUI
import UserNotifications

/// Thrown when transcription exceeds its hard time budget so the UI can recover
/// instead of hanging in `.processing` forever (e.g. a stuck WhisperKit on first use).
struct TranscriptionTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Transcription timed out. The Whisper model may still be loading or failed to start — "
            + "try again, or pick a smaller model in Settings → Model."
    }
}

/// Run an async operation with a hard timeout. Throws `TranscriptionTimeoutError` if it
/// doesn't finish in `seconds`.
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TranscriptionTimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw TranscriptionTimeoutError() }
        return result
    }
}

/// Central app state shared across all views via EnvironmentObject.
@MainActor
final class AppState: ObservableObject {
    // MARK: - Dictation State

    enum DictationStatus: String {
        case idle
        case listening
        case processing
        case rewriting
    }

    @Published var status: DictationStatus = .idle
    @Published var partialTranscript: String = ""
    @Published var selectedStyle: String =
        UserDefaults.standard.string(forKey: "defaultStyle") ?? "Casual"
    {
        didSet {
            UserDefaults.standard.set(selectedStyle, forKey: "defaultStyle")
            AppLog.app.info("Style changed to: \(self.selectedStyle, privacy: .public)")
        }
    }
    @Published var isModelLoaded: Bool = false
    @Published var modelLoadProgress: String = ""
    /// True when the Whisper model download/load failed — surfaced so a hotkey press gives a
    /// "retry" hint instead of a silent no-op (the model gate in `startDictation`).
    @Published var modelLoadFailed: Bool = false
    /// Non-nil when the app is running from a location where macOS won't persist permissions
    /// (App Translocation / disk image), which silently breaks the global fn hotkey.
    @Published var installWarning: String? = AppLocation.installWarning
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0.0
    @Published var totalDictations: Int = 0
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(
        forKey: "hasCompletedOnboarding")
    @Published var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published var isLLMAvailable: Bool = false
    @Published var llmStatus: String = ""
    @Published var lastDictationText: String = ""
    @Published var lastDictationRaw: String = ""
    @Published var selectedMicrophoneID: String? = UserDefaults.standard.string(
        forKey: "selectedMicrophoneID")

    // MARK: - Services

    let transcriptionService: TranscriptionService
    let textCleanup = TextCleanupPipeline()
    let styleFormatter = StyleFormatter()
    let snippetExpander = SnippetExpander()
    let commandParser = CommandParser()
    let grammarService = GrammarService()
    let dictationFormatter = DictationFormatter()
    let audioCapture = AudioCaptureService()
    let hotKeyManager = HotKeyManager()
    let textInsertion = TextInsertionService()
    let overlayController = TranscriptOverlayController()
    let soundFeedback = SoundFeedback()
    let llmService: LLMService

    /// ModelContext injected from the SwiftUI environment after app launches.
    var modelContext: ModelContext?

    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    /// Streaming insertion: background loop that commits phrase-segments into the focused app at
    /// natural pauses while the user is still speaking.
    private var streamingTask: Task<Void, Never>?
    /// Sample index up to which audio has already been transcribed AND pasted. The final pass on
    /// stop only handles audio after this offset.
    private var committedSampleOffset = 0
    /// Text already streamed into the focused app this dictation.
    private var committedText = ""
    /// Raw (pre-cleanup) transcript of the streamed segments, kept for history.
    private var committedRawText = ""
    /// Last moment the mic level was above the speech threshold — drives phrase-pause detection.
    private var lastVoiceTime = Date()
    /// When the last segment commit finished — a new commit requires voice AFTER this, so pure
    /// silence (or a mic quieter than the threshold) can never trigger repeated commits.
    private var lastCommitTime = Date.distantPast
    private var isCommittingSegment = false

    var statusIcon: String {
        switch status {
        case .idle: return "mic"
        case .listening: return "mic.fill"
        case .processing: return "ellipsis.circle"
        case .rewriting: return "sparkles"
        }
    }

    init() {
        let modelName = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
        self.transcriptionService = TranscriptionService(modelName: modelName)

        let llmBackendRaw = UserDefaults.standard.string(forKey: "llmBackend") ?? "none"
        let llmBackend = LLMService.Backend(rawValue: llmBackendRaw) ?? .none
        let llmHost = UserDefaults.standard.string(forKey: "ollamaHost") ?? "http://localhost:11434"
        let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.1:8b"
        let openAIModel = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4o-mini"
        let openAIBase =
            UserDefaults.standard.string(forKey: "openAIBaseURL") ?? "https://api.openai.com/v1"
        self.llmService = LLMService(
            backend: llmBackend,
            ollamaHost: llmHost,
            ollamaModel: ollamaModel,
            openAIModel: openAIModel,
            openAIBaseURL: openAIBase
        )
    }

    // MARK: - Lifecycle

    func setup() {
        // Surface an install-location problem loudly — this is the top cause of "I gave
        // permissions but the fn key does nothing" on downloaded, un-notarized builds.
        if let warning = installWarning {
            AppLog.app.error("Running from a permission-breaking location: \(warning, privacy: .public)")
        }

        // Pre-request microphone permission immediately
        audioCapture.requestPermission()

        // Load the Whisper model
        Task {
            do {
                AppLog.model.notice("Loading Whisper model…")
                modelLoadFailed = false
                modelLoadProgress = "Downloading & loading model…"
                try await transcriptionService.loadModel()
                isModelLoaded = true
                modelLoadProgress = ""
                AppLog.model.notice("Model loaded successfully")
            } catch {
                AppLog.model.error("Model load FAILED: \(error.localizedDescription, privacy: .public)")
                modelLoadFailed = true
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                modelLoadProgress = ""
            }
        }

        // Check LLM availability
        Task {
            isLLMAvailable = await llmService.isAvailable()
        }

        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
        }

        // Wire up hotkey
        applyTriggerMethod()
        applyDictationMode()
        hotKeyManager.onRecordingStarted = { [weak self] in
            self?.startDictation()
        }
        hotKeyManager.onRecordingStopped = { [weak self] in
            self?.stopDictation()
        }
        // Overlay pill buttons: ✓ finishes (same as releasing the key), ✕ discards. Both must
        // also reset the hotkey's recording state so the next press starts fresh.
        overlayController.onDone = { [weak self] in
            self?.hotKeyManager.syncRecordingEnded()
            self?.stopDictation()
        }
        overlayController.onCancel = { [weak self] in
            self?.hotKeyManager.syncRecordingEnded()
            self?.cancelDictation()
        }
        hotKeyManager.loadPersistedShortcut()  // restore the user's saved custom shortcut
        hotKeyManager.register()

        // Wire up silence detection → auto-stop
        audioCapture.onSilenceDetected = { [weak self] in
            guard let self, self.status == .listening else { return }
            let autoStop = UserDefaults.standard.bool(forKey: "autoStopOnSilence")
            if autoStop {
                self.stopDictation()
            }
        }

        audioCapture.onCaptureError = { [weak self] message in
            self?.errorMessage = message
            self?.forceIdle()
        }

        // Observe audio level for UI metering and overlay
        audioCapture.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self else { return }
                self.audioLevel = level
                // Safety: if we're getting real audio levels while idle, something is wrong — force stop
                if level > 0.001 && self.status == .idle && self.audioCapture.isRecording {
                    AppLog.audio.error("Audio active while idle, forcing stop")
                    self.audioCapture.forceStopEngine()
                    self.audioLevel = 0.0
                    return
                }
                // Update overlay with real audio level while listening
                if self.status == .listening {
                    let text =
                        self.partialTranscript.isEmpty ? "Listening…" : self.partialTranscript
                    self.overlayController.update(text: text, audioLevel: level)
                }
            }
            .store(in: &cancellables)

        // Stream partial transcript updates from the service
        transcriptionService.$partialText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self, self.status == .listening else {
                    return
                }
                if !text.isEmpty {
                    self.partialTranscript = text
                    self.overlayController.update(text: text)
                }
            }
            .store(in: &cancellables)

        // Apply silence detector settings
        let timeout = UserDefaults.standard.double(forKey: "silenceTimeout")
        if timeout > 0 {
            audioCapture.updateSilenceSettings(threshold: 0.01, duration: timeout)
        }

        // Seed built-in style presets on first launch
        seedBuiltInPresetsIfNeeded()
    }

    /// Read the dictation mode setting and apply it.
    func applyDictationMode() {
        let mode = UserDefaults.standard.string(forKey: "dictationMode") ?? "holdToTalk"
        hotKeyManager.mode = mode == "toggle" ? .toggle : .holdToTalk
    }

    /// Read the trigger method setting and apply it.
    func applyTriggerMethod() {
        let method = UserDefaults.standard.string(forKey: "triggerMethod") ?? "fnKey"
        hotKeyManager.triggerMethod = method == "customHotkey" ? .customHotkey : .fnKey
    }

    // MARK: - Dictation Flow

    func startDictation() {
        AppLog.app.notice(
            "startDictation: status=\(self.status.rawValue, privacy: .public), modelLoaded=\(self.isModelLoaded, privacy: .public)"
        )
        guard status == .idle else {
            AppLog.app.info("Cannot start: not idle")
            return
        }
        let showOverlay = UserDefaults.standard.object(forKey: "showOverlay") as? Bool ?? true
        guard isModelLoaded else {
            // Don't no-op silently — that's the "I press fn and nothing happens" bug. Give the
            // user visible feedback that the keypress registered but the model isn't ready yet.
            AppLog.model.notice("Hotkey fired but model not ready (failed=\(self.modelLoadFailed, privacy: .public))")
            if showOverlay {
                overlayController.showMessage(
                    modelLoadFailed
                        ? "Speech model failed to download — open Listen to retry"
                        : "Preparing speech model, one moment…")
            }
            errorMessage =
                modelLoadFailed
                ? "The speech model failed to download. Open Listen and retry from the Model card, "
                    + "and check your internet connection."
                : "The speech model is still downloading (this happens once). Try again in a moment."
            return
        }
        status = .listening
        partialTranscript = ""
        errorMessage = nil
        recordingStartTime = Date()
        // Always reset streaming bookkeeping — stale offsets from a previous streamed dictation
        // must never leak into this one (e.g. if the user toggled streaming off in between).
        committedSampleOffset = 0
        committedText = ""
        committedRawText = ""
        lastCommitTime = Date.distantPast

        audioCapture.startRecording()
        // Play AFTER the engine is up: starting the mic engine triggers an audio-route
        // transition that swallows any sound already in flight (why the start cue used to be
        // silent while the stop cue played fine).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.status == .listening else { return }
            self.soundFeedback.playStart()
        }

        // Show overlay if enabled — a clean waveform indicator; text is inserted once, fully
        // formatted, on stop.
        if showOverlay {
            overlayController.show(text: "Listening…")
        }

        // Warm the local LLM while the user is speaking (Ollama unloads after ~5 idle minutes;
        // a cold formatting call costs 10s+ of model loading). Fire-and-forget — by the time the
        // user stops, the model is resident and formatting is fast.
        if isLLMAvailable {
            Task { await llmService.warmUp() }
        }

        // Streaming insertion: type text into the focused app at natural pauses while the user
        // speaks (like OS dictation). On by default; committed text is final, so end-of-dictation
        // LLM restructuring only applies when this is off.
        let streamInsert = UserDefaults.standard.object(forKey: "streamInsertion") as? Bool ?? true
        if streamInsert {
            startStreamingInsertion()
        }
        AppLog.app.notice("Now listening (streaming=\(streamInsert, privacy: .public))")
    }

    // MARK: - Streaming Insertion

    private func startStreamingInsertion() {
        streamingTask?.cancel()
        committedSampleOffset = 0
        committedText = ""
        lastVoiceTime = Date()
        textInsertion.beginStreamingSession()
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        // Commit on sentence-sized pauses, not word-sized ones. A short thinking-pause mid-sentence
        // must NOT chop the phrase — Whisper treats every slice as a complete utterance and stamps
        // it with a capital and a trailing period, turning fragments into fake "sentences."
        let phrasePause: TimeInterval = 1.3  // silence gap that ends a sentence-ish phrase
        let minSegmentSamples = 40000  // ≥2.5s of audio before a commit is worthwhile

        streamingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.status == .listening {
                try? await Task.sleep(nanoseconds: 150_000_000)
                // Same threshold as silence auto-stop — a second, disagreeing constant here once
                // meant a quiet talker could be chopped mid-word every tick.
                if self.audioLevel > self.audioCapture.speechThreshold {
                    self.lastVoiceTime = Date()
                }
                let paused = Date().timeIntervalSince(self.lastVoiceTime) >= phrasePause
                let hadVoiceSinceLastCommit = self.lastVoiceTime > self.lastCommitTime
                let uncommitted = self.audioCapture.sampleCount() - self.committedSampleOffset
                guard paused, hadVoiceSinceLastCommit, uncommitted >= minSegmentSamples,
                    !self.isCommittingSegment, self.status == .listening
                else { continue }
                await self.commitSegment(lang: lang)
            }
        }
    }

    /// Transcribe the audio since the last commit and paste it into the focused app. Committed
    /// text is final — the phrase boundary (a real pause) is what makes that safe, because
    /// Whisper only revises words within a continuing utterance, not across a completed one.
    private func commitSegment(lang: String) async {
        isCommittingSegment = true
        defer {
            isCommittingSegment = false
            lastCommitTime = Date()
        }

        let end = audioCapture.sampleCount()
        let slice = audioCapture.samples(from: committedSampleOffset, to: end)
        guard slice.count > 8000 else { return }

        // Bounded: a wedged transcription must not stall the stop path (which awaits this
        // commit). On timeout the offset doesn't advance, so the tail pass covers this audio.
        guard
            let raw = try? await withTimeout(seconds: 15, operation: {
                try await self.transcriptionService.transcribe(
                    audioArray: slice, language: lang == "auto" ? nil : lang)
            })
        else {
            AppLog.model.error("Segment transcription failed/timed out — deferring to final pass")
            return
        }

        // The user may have cancelled while we were transcribing — never paste after that.
        // (.processing is fine: that's the intended final flush during stop.)
        guard status != .idle else { return }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isWhisperNoise(trimmed) else {
            // Junk audio (breath, noise) — mark it consumed so it isn't retried or re-transcribed.
            committedSampleOffset = end
            return
        }

        var chunk = processStreamingChunk(trimmed)
        if !committedText.isEmpty {
            chunk = " " + chunk
        }
        if textInsertion.insertStreamingChunk(chunk) {
            committedText += chunk
            committedRawText += committedRawText.isEmpty ? trimmed : " " + trimmed
            committedSampleOffset = end
            AppLog.app.info("Streamed segment: \(chunk.count, privacy: .public) chars")
        } else {
            // Paste isn't possible (permissions) — stop streaming; the normal end-of-dictation
            // flow will handle ALL the audio in one shot and surface the permission error.
            AppLog.app.error("Streaming paste failed — falling back to insert-at-end")
            streamingTask?.cancel()
        }
    }

    /// Fast, deterministic per-segment cleanup: spoken commands, text cleanup, snippets. No LLM —
    /// a streamed segment must land the instant the pause is detected.
    private func processStreamingChunk(_ raw: String) -> String {
        var text = commandParser.process(raw)
        text = textCleanup.clean(text)
        let snippets: [Snippet] = {
            guard let ctx = modelContext else { return [] }
            return (try? ctx.fetch(FetchDescriptor<Snippet>())) ?? []
        }()
        text = snippetExpander.expand(text, using: snippets)
        // Rule-based grammar is deterministic and instant — safe per-chunk. (Style formatting is
        // NOT applied here: presets like Email wrap the whole text in a greeting/sign-off, which
        // must never happen per-sentence. Streamed dictations trade styling for immediacy.)
        let grammarEnabled =
            UserDefaults.standard.object(forKey: "grammarCorrection") as? Bool ?? true
        if grammarEnabled {
            text = grammarService.correct(text)
        }
        // Glue: a slice must never START with stray punctuation ("… . Getting"). Whisper
        // sometimes leads a slice with the previous phrase's terminal punctuation.
        while let first = text.first, first.isPunctuation || first.isWhitespace {
            text.removeFirst()
        }
        return text
    }

    func stopDictation() {
        guard status == .listening else {
            AppLog.app.info("stopDictation: not listening, status=\(self.status.rawValue, privacy: .public)")
            return
        }
        AppLog.app.info("stopDictation: stopping recording")
        soundFeedback.playStop()
        status = .processing
        partialTranscript = ""
        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        let audioBuffer = audioCapture.stopRecording()
        AppLog.app.info(
            "Captured \(audioBuffer.count, privacy: .public) samples (\(String(format: "%.1f", Double(audioBuffer.count) / 16000.0), privacy: .public)s of audio)"
        )

        guard audioBuffer.count > 1600 else {
            // Less than 0.1s of audio — too short (nothing can have streamed either)
            AppLog.app.info("Audio too short, discarding")
            streamingTask?.cancel()
            streamingTask = nil
            textInsertion.endStreamingSession(restore: true)
            overlayController.dismiss()
            status = .idle
            return
        }

        // Update overlay with a processing ETA learned from previous runs (transcription rate ×
        // audio length + typical formatting time), so the wait is never a black box. When
        // segments were already streamed, only the tail remains — much smaller estimate.
        let pendingSamples = audioBuffer.count - min(committedSampleOffset, audioBuffer.count)
        let estimate = estimatedProcessingSeconds(
            audioSeconds: Double(pendingSamples) / 16000.0,
            usesLLM: committedSampleOffset == 0)
        overlayController.update(text: String(format: "Processing… ~%.0fs", max(estimate.rounded(), 1)))

        // Detect focused app before transcription
        let focusedApp = NSWorkspace.shared.frontmostApplication
        let appName = focusedApp?.localizedName
        let appBundleID = focusedApp?.bundleIdentifier

        // Resolve style: per-app profile overrides global
        let effectiveStyle = resolveStyle(forBundleID: appBundleID)

        // Fetch snippets from storage
        let snippets: [Snippet] = {
            guard let ctx = modelContext else { return [] }
            return (try? ctx.fetch(FetchDescriptor<Snippet>())) ?? []
        }()

        Task {
            // Let any in-flight streamed segment finish before deciding how to close out — the
            // serialized TranscriptionService plus this await guarantee no overlap and no
            // out-of-order pastes.
            streamingTask?.cancel()
            await streamingTask?.value
            streamingTask = nil
            let streamedOffset = committedSampleOffset
            let streamedText = committedText

            if streamedOffset > 0 {
                // Segments were already streamed into the app — just finish the tail.
                await finishStreamedDictation(
                    audioBuffer: audioBuffer, streamedOffset: streamedOffset,
                    streamedText: streamedText, duration: duration,
                    appBundleID: appBundleID, appName: appName, styleName: effectiveStyle)
                return
            }
            // Nothing was streamed — drop the session without a clipboard restore (insertText
            // below manages its own save/restore; a delayed session restore could race the paste).
            textInsertion.endStreamingSession(restore: false)

            do {
                let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
                AppLog.model.info("Transcribing \(audioBuffer.count, privacy: .public) samples, lang=\(lang, privacy: .public)")
                let transcribeStart = Date()
                // Hard timeout so a stuck WhisperKit can't strand us in `.processing` forever.
                let rawText = try await withTimeout(seconds: 60) {
                    try await self.transcriptionService.transcribe(
                        audioArray: audioBuffer,
                        language: lang == "auto" ? nil : lang
                    )
                }
                // Privacy: log only length, never the spoken words (transcripts are never persisted).
                // .notice so the latency breakdown survives in `log show` for field diagnosis.
                let transcribeSeconds = Date().timeIntervalSince(transcribeStart)
                let audioSeconds = Double(audioBuffer.count) / 16000.0
                AppLog.model.notice(
                    "Transcription: \(String(format: "%.2f", transcribeSeconds), privacy: .public)s for \(String(format: "%.1f", audioSeconds), privacy: .public)s audio → \(rawText.count, privacy: .public) chars"
                )
                // Learn the transcription rate for the overlay's processing-time estimate.
                if audioSeconds > 1 {
                    let old =
                        UserDefaults.standard.object(forKey: "emaTranscribeRate") as? Double ?? 0.03
                    UserDefaults.standard.set(
                        old * 0.7 + (transcribeSeconds / audioSeconds) * 0.3,
                        forKey: "emaTranscribeRate")
                }

                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    AppLog.model.info("Empty transcription, discarding")
                    overlayController.dismiss()
                    status = .idle
                    return
                }

                // Discard Whisper noise artifacts (hallucinations from silence/noise)
                if Self.isWhisperNoise(rawText) {
                    AppLog.model.info("Discarded Whisper noise artifact (\(rawText.count, privacy: .public) chars)")
                    overlayController.dismiss()
                    status = .idle
                    return
                }

                // Check for rewrite commands first
                if let rewriteCommand = commandParser.detectRewriteCommand(rawText) {
                    await handleRewriteCommand(rewriteCommand, appName: appName)
                    return
                }

                var processed = processTranscript(
                    rawText, snippets: snippets, styleName: effectiveStyle)

                // Smart formatting (the differentiator): structure the whole utterance — lists,
                // paragraphs, punctuation — using the LLM when available, else the local
                // rule-based formatter. Falls back to plain grammar-only when the user opts out.
                let smartFormat =
                    UserDefaults.standard.object(forKey: "smartFormatting") as? Bool ?? true
                let grammarEnabled =
                    UserDefaults.standard.object(forKey: "grammarCorrection") as? Bool ?? true
                let formatStart = Date()
                // The LLM never gets to hold the paste hostage: any LLM pass races a hard timeout
                // and loses to the instant local fallback. (A cold/stuck local LLM once cost 15s
                // here — the paste must land promptly no matter what the LLM is doing.)
                let llmBudgetSeconds: TimeInterval = 4
                if smartFormat {
                    if self.isLLMAvailable {
                        do {
                            let input = processed
                            processed = try await withTimeout(seconds: llmBudgetSeconds) {
                                try await self.llmService.formatDictation(input)
                            }
                            AppLog.model.info("LLM smart formatting applied")
                        } catch {
                            AppLog.model.error(
                                "LLM formatting failed/timed out, using local formatter: \(error.localizedDescription, privacy: .public)"
                            )
                            processed = self.dictationFormatter.format(processed)
                        }
                    } else {
                        processed = self.dictationFormatter.format(processed)
                    }
                } else if grammarEnabled {
                    if self.isLLMAvailable {
                        do {
                            let input = processed
                            processed = try await withTimeout(seconds: llmBudgetSeconds) {
                                try await self.llmService.fixGrammar(input)
                            }
                            AppLog.model.info("LLM grammar correction applied")
                        } catch {
                            AppLog.model.error(
                                "LLM grammar failed/timed out, falling back to rule-based: \(error.localizedDescription, privacy: .public)"
                            )
                            processed = self.grammarService.correct(processed)
                        }
                    } else {
                        processed = self.grammarService.correct(processed)
                    }
                }

                let formatSeconds = Date().timeIntervalSince(formatStart)
                AppLog.model.notice(
                    "Formatting: \(String(format: "%.2f", formatSeconds), privacy: .public)s (llm=\(self.isLLMAvailable, privacy: .public), smart=\(smartFormat, privacy: .public))"
                )
                // Learn typical formatting time for the overlay's processing-time estimate.
                let oldFormat =
                    UserDefaults.standard.object(forKey: "emaFormatSeconds") as? Double ?? 1.5
                UserDefaults.standard.set(
                    oldFormat * 0.7 + formatSeconds * 0.3, forKey: "emaFormatSeconds")
                AppLog.app.info("Inserting \(processed.count, privacy: .public) chars")
                // Small delay to ensure the target app has focus back
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                let pasted = textInsertion.insertText(processed)
                if !pasted {
                    errorMessage =
                        "Couldn't paste automatically — enable Accessibility for Listen in "
                        + "System Settings → Privacy & Security → Accessibility. Your text is on "
                        + "the clipboard; press ⌘V to paste it."
                }

                // Store for re-dictate
                lastDictationText = processed
                lastDictationRaw = rawText

                // Save to history
                saveDictationEntry(
                    text: processed,
                    rawText: rawText,
                    duration: duration,
                    appBundleID: appBundleID,
                    appName: appName,
                    styleName: effectiveStyle
                )

                overlayController.dismiss()
                status = .idle
                partialTranscript = ""
                totalDictations += 1

                // Send notification
                sendCompletionNotification(text: processed)
            } catch {
                if error is TranscriptionTimeoutError {
                    errorMessage = error.localizedDescription
                } else {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                }
                AppLog.model.error("Transcription error: \(error.localizedDescription, privacy: .public)")
                overlayController.dismiss()
                status = .idle
            }
        }
    }

    /// Known Whisper hallucinations produced by silence/noise — never worth inserting.
    private static let whisperNoisePatterns: Set<String> = [
        "you", "thank you", "thanks", "bye", "okay",
        "thank you for watching", "thanks for watching",
        "subscribe", "like and subscribe",
        ".", "..", "...", "!", "?", "-",
        "(silence)", "[silence]", "(inaudible)", "[inaudible]",
        "(music)", "[music]", "(applause)", "[applause]",
        "(laughing)", "[laughing]", "(coughing)", "[coughing]",
        "(sighs)", "(breathing)", "(noise)",
        "blank_audio", "[blank_audio]", "(blank_audio)",
        "blank audio", "[blank audio]",
    ]

    static func isWhisperNoise(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return whisperNoisePatterns.contains(lowered)
            || trimmed.allSatisfy({ $0.isPunctuation || $0.isWhitespace })
            || lowered.contains("blank_audio")
            || lowered.contains("blank audio")
    }

    /// Predicted stop-to-text seconds for the overlay's "Processing… ~Ns" hint, learned from
    /// previous dictations (EMA of transcription rate and formatting time).
    private func estimatedProcessingSeconds(audioSeconds: Double, usesLLM: Bool = true) -> Double {
        let defaults = UserDefaults.standard
        let rate = defaults.object(forKey: "emaTranscribeRate") as? Double ?? 0.03
        let format = defaults.object(forKey: "emaFormatSeconds") as? Double ?? 1.5
        let smartFormat = defaults.object(forKey: "smartFormatting") as? Bool ?? true
        // The LLM race is capped at 4s, so the estimate never exceeds that for formatting.
        let formatPart = (usesLLM && (smartFormat || isLLMAvailable)) ? min(format, 4.0) : 0.1
        return audioSeconds * rate + formatPart + 0.4  // + paste/setup overhead
    }

    /// Close out a dictation whose earlier phrases were already streamed into the focused app:
    /// transcribe and paste only the remaining tail, then record the whole utterance in history.
    /// Streamed text is final by design, so the whole-utterance LLM restructuring pass is skipped.
    private func finishStreamedDictation(
        audioBuffer: [Float], streamedOffset: Int, streamedText: String, duration: Double,
        appBundleID: String?, appName: String?, styleName: String
    ) async {
        var fullText = streamedText
        var fullRaw = committedRawText
        var restoreClipboard = true
        let tail = streamedOffset < audioBuffer.count ? Array(audioBuffer[streamedOffset...]) : []
        // Same floor as the classic path (0.1s) — a short closing word ("yes", "thanks") after
        // the last committed segment must not be silently dropped.
        if tail.count > 1600 {
            let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
            let raw = try? await withTimeout(seconds: 60) {
                try await self.transcriptionService.transcribe(
                    audioArray: tail, language: lang == "auto" ? nil : lang)
            }
            if let raw {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !Self.isWhisperNoise(trimmed) {
                    var chunk = processStreamingChunk(trimmed)
                    if !fullText.isEmpty { chunk = " " + chunk }
                    fullText += chunk  // history keeps the words even if the paste fails
                    fullRaw += fullRaw.isEmpty ? trimmed : " " + trimmed
                    if !textInsertion.insertStreamingChunk(chunk) {
                        // Leave the chunk on the clipboard for a manual ⌘V and say so.
                        restoreClipboard = false
                        errorMessage =
                            "Couldn't paste the last part — it's on the clipboard, press ⌘V "
                            + "to insert it."
                        AppLog.app.error("Tail paste failed — left on clipboard")
                    }
                }
            }
        }
        textInsertion.endStreamingSession(restore: restoreClipboard)

        if !fullText.isEmpty {
            lastDictationText = fullText
            lastDictationRaw = fullRaw
            // Style presets are intentionally not applied to streamed text — record that
            // honestly instead of claiming a style that never ran.
            saveDictationEntry(
                text: fullText, rawText: fullRaw, duration: duration,
                appBundleID: appBundleID, appName: appName, styleName: "Streamed")
            totalDictations += 1
            sendCompletionNotification(text: fullText)
        }
        overlayController.dismiss()
        status = .idle
        partialTranscript = ""
        AppLog.app.notice(
            "Streamed dictation complete: \(fullText.count, privacy: .public) chars total")
    }

    /// Cancel an ongoing dictation without inserting text.
    func cancelDictation() {
        guard status == .listening else { return }
        streamingTask?.cancel()
        streamingTask = nil
        textInsertion.endStreamingSession(restore: true)
        _ = audioCapture.stopRecording()
        overlayController.dismiss()
        status = .idle
        partialTranscript = ""
    }

    /// Force everything to idle state — safety net for stuck states.
    func forceIdle() {
        AppLog.app.info("forceIdle: ensuring clean state")
        streamingTask?.cancel()
        streamingTask = nil
        textInsertion.endStreamingSession(restore: true)
        audioCapture.stopRecording()
        audioCapture.forceStopEngine()
        overlayController.dismiss()
        status = .idle
        partialTranscript = ""
        audioLevel = 0.0
    }

    /// Re-insert the last dictation text into the focused app.
    func reDictate() {
        guard !lastDictationText.isEmpty, status == .idle else { return }
        textInsertion.insertText(lastDictationText)
    }

    // MARK: - Rewrite Commands (Phase 2 LLM)

    private func handleRewriteCommand(_ command: RewriteCommand, appName: String?) async {
        guard isLLMAvailable else {
            errorMessage = "LLM not available. Start Ollama to use rewrite commands."
            overlayController.dismiss()
            status = .idle
            return
        }

        guard !lastDictationText.isEmpty else {
            errorMessage = "Nothing to rewrite. Dictate some text first."
            overlayController.dismiss()
            status = .idle
            return
        }

        status = .rewriting
        overlayController.update(text: "Rewriting with AI…")

        do {
            let rewritten = try await llmService.rewrite(lastDictationText, command: command)
            textInsertion.insertText(rewritten)
            lastDictationText = rewritten
            overlayController.dismiss()
            status = .idle
            sendCompletionNotification(text: "Rewrote: \(command.displayName)")
        } catch {
            errorMessage = "Rewrite failed: \(error.localizedDescription)"
            overlayController.dismiss()
            status = .idle
        }
    }

    /// Rewrite the last dictation with a specific command (called from UI).
    func rewriteLastDictation(command: RewriteCommand) {
        Task {
            await handleRewriteCommand(command, appName: nil)
        }
    }

    // MARK: - Per-App Style Profiles (Phase 1)

    /// Look up per-app style profile, fall back to selected global style.
    func resolveStyle(forBundleID: String?) -> String {
        guard let bundleID = forBundleID, let ctx = modelContext else {
            return selectedStyle
        }
        let descriptor = FetchDescriptor<AppStyleProfile>(
            predicate: #Predicate { $0.appBundleID == bundleID }
        )
        if let profile = try? ctx.fetch(descriptor).first {
            return profile.styleName
        }
        return selectedStyle
    }

    // MARK: - Text Processing

    /// Apply cleanup, commands, snippets, and style formatting.
    func processTranscript(_ raw: String, snippets: [Snippet] = [], styleName: String? = nil)
        -> String
    {
        var text = raw

        // 1. Parse inline commands (new paragraph, period, etc.)
        text = commandParser.process(text)

        // 2. Basic cleanup
        text = textCleanup.clean(text)

        // 3. Expand snippets
        text = snippetExpander.expand(text, using: snippets)

        // 4. Apply style
        let style = styleName ?? selectedStyle
        text = styleFormatter.formatWithBuiltInStyle(text, styleName: style)

        return text
    }

    // MARK: - Notifications

    private func sendCompletionNotification(text: String) {
        let showNotification =
            UserDefaults.standard.object(forKey: "showNotification") as? Bool ?? false
        guard showNotification else { return }

        let content = UNMutableNotificationContent()
        content.title = "Dictation Complete"
        content.body = String(text.prefix(100))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private func saveDictationEntry(
        text: String,
        rawText: String,
        duration: Double,
        appBundleID: String?,
        appName: String?,
        styleName: String? = nil
    ) {
        guard let ctx = modelContext else { return }
        let lang = UserDefaults.standard.string(forKey: "language") ?? "en"
        let entry = DictationEntry(
            text: text,
            rawText: rawText,
            duration: duration,
            appBundleID: appBundleID,
            appName: appName,
            styleName: styleName ?? selectedStyle,
            language: lang
        )
        ctx.insert(entry)
        try? ctx.save()
    }

    private func seedBuiltInPresetsIfNeeded() {
        guard let ctx = modelContext else { return }
        let existing = (try? ctx.fetchCount(FetchDescriptor<StylePreset>())) ?? 0
        if existing == 0 {
            for preset in StylePreset.builtInPresets() {
                ctx.insert(preset)
            }
            try? ctx.save()
        }
    }

    /// Reload the transcription model (e.g. after user changes model in settings).
    func reloadModel() {
        isModelLoaded = false
        modelLoadFailed = false
        errorMessage = nil
        Task {
            do {
                let name = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
                modelLoadProgress = "Switching to \(name) model…"
                try await transcriptionService.loadModel(name: name)
                isModelLoaded = true
                modelLoadProgress = ""
                AppLog.model.info("Model reloaded successfully")
            } catch {
                AppLog.model.error("Model reload FAILED: \(error.localizedDescription, privacy: .public)")
                modelLoadFailed = true
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                modelLoadProgress = ""
            }
        }
    }

    /// Check and update accessibility permission status.
    func refreshAccessibilityStatus() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// Select a specific microphone input device.
    func selectMicrophone(deviceID: String) {
        selectedMicrophoneID = deviceID
        UserDefaults.standard.set(deviceID, forKey: "selectedMicrophoneID")
        audioCapture.setPreferredDevice(uniqueID: deviceID)
    }

    /// Get the user's first name for personalized greeting.
    var userFirstName: String {
        let fullName = NSFullUserName()
        return fullName.components(separatedBy: " ").first ?? fullName
    }

    /// Refresh LLM availability status.
    func refreshLLMStatus() {
        Task {
            isLLMAvailable = await llmService.isAvailable()
            llmStatus = isLLMAvailable ? "Connected" : "Not available"
        }
    }

    /// Update LLM configuration.
    func updateLLMConfig() {
        let backendRaw = UserDefaults.standard.string(forKey: "llmBackend") ?? "none"
        let backend = LLMService.Backend(rawValue: backendRaw) ?? .none
        let host = UserDefaults.standard.string(forKey: "ollamaHost") ?? "http://localhost:11434"
        let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.1:8b"
        let openAIModel = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4o-mini"
        let openAIBase =
            UserDefaults.standard.string(forKey: "openAIBaseURL") ?? "https://api.openai.com/v1"
        Task {
            await llmService.updateConfig(
                backend: backend,
                ollamaHost: host,
                ollamaModel: ollamaModel,
                openAIModel: openAIModel,
                openAIBaseURL: openAIBase
            )
            refreshLLMStatus()
        }
    }
}
