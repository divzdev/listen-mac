import AVFoundation
import Combine
import CoreAudio
import OSLog

/// Captures microphone audio via AVAudioEngine and accumulates Float samples
/// at 16kHz mono (WhisperKit's expected format).
final class AudioCaptureService: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0

    private var audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let silenceDetector = SilenceDetector()
    private var hasMicPermission: Bool = false

    /// Callback fired when silence is detected during recording.
    var onSilenceDetected: (() -> Void)?

    /// Callback fired (on the main queue) when capture can't start — e.g. no microphone or an
    /// audio-engine failure. Lets the app show a message instead of failing silently.
    var onCaptureError: ((String) -> Void)?

    private var configChangeObserver: NSObjectProtocol?

    init() {
        registerConfigChangeObserver()
    }

    deinit {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Observe configuration changes (sleep/wake, audio device connect/disconnect). When one
    /// fires mid-recording, AVAudioEngine stops and may invalidate taps without our knowledge —
    /// reset state so the next beginCapture() starts clean. The observer is bound to a specific
    /// engine instance, so it must be re-registered whenever `audioEngine` is rebuilt.
    private func registerConfigChangeObserver() {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            AppLog.audio.info("Audio engine reconfigured (sleep/wake or device change) — resetting state")
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }

    /// Tear down the current engine and build a fresh one so the input node reflects the
    /// CURRENT audio hardware. AVAudioEngine caches the input device's format; when an
    /// accessory (AirPods, headset) is connected or removed while the engine sits idle between
    /// dictations, that cached format goes stale and the next installTap/start raises a
    /// format-mismatch exception — capture fails until the app is restarted. Rebuilding gives a
    /// fresh engine that reads the live hardware, the same clean state as a restart.
    private func rebuildEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine = AVAudioEngine()
        registerConfigChangeObserver()
    }

    // MARK: - Permission

    /// Pre-request mic permission at app launch so it's ready when user presses fn.
    func requestPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        AppLog.audio.info("Mic permission status: \(status.rawValue, privacy: .public)")
        switch status {
        case .authorized:
            hasMicPermission = true
            AppLog.audio.info("Mic already authorized")
        case .notDetermined:
            AppLog.audio.info("Requesting mic permission...")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                AppLog.audio.info("Mic permission granted: \(granted, privacy: .public)")
                DispatchQueue.main.async {
                    self?.hasMicPermission = granted
                }
            }
        case .denied, .restricted:
            AppLog.audio.error("Mic permission denied/restricted")
            hasMicPermission = false
        @unknown default:
            break
        }
    }

    // MARK: - Recording

    /// Start capturing audio immediately. Mic permission should be pre-requested.
    func startRecording() {
        AppLog.audio.info("startRecording called, hasMicPermission=\(self.hasMicPermission, privacy: .public)")
        if hasMicPermission {
            beginCapture()
        } else {
            // Try requesting on-the-fly as fallback
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                AppLog.audio.info("Late mic permission: \(granted, privacy: .public)")
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.hasMicPermission = true
                    self?.beginCapture()
                }
            }
        }
    }

    /// Stop recording and return the accumulated audio buffer.
    @discardableResult
    func stopRecording() -> [Float] {
        guard isRecording else {
            AppLog.audio.info("stopRecording called but not recording")
            // Safety: force stop engine if it's somehow still running
            forceStopEngine()
            return []
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = 0.0
        }

        bufferLock.lock()
        let result = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        AppLog.audio.info(
            "stopRecording: captured \(result.count, privacy: .public) samples (\(String(format: "%.1f", Double(result.count) / 16000.0), privacy: .public)s)"
        )
        return result
    }

    /// Total samples captured so far in this recording (without stopping or clearing).
    func sampleCount() -> Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return audioBuffer.count
    }

    /// Copy the sample range [start, end) — used by streaming insertion to transcribe one
    /// phrase-segment while recording continues. Bounds are clamped; returns a fresh array so the
    /// tap thread's appends can't COW-copy the whole buffer under the lock.
    func samples(from start: Int, to end: Int) -> [Float] {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        let upper = min(end, audioBuffer.count)
        guard start >= 0, start < upper else { return [] }
        return Array(audioBuffer[start..<upper])
    }

    /// Force-stop the audio engine unconditionally. Call this as a safety net.
    func forceStopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            AppLog.audio.info("forceStopEngine: engine stopped")
        }
        // Always remove tap regardless of engine state to prevent "tap already installed" crash
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = 0.0
        }
    }

    // MARK: - Private

    private func beginCapture() {
        guard !isRecording else {
            AppLog.audio.info("beginCapture ignored — already recording")
            return
        }

        // Rebuild the engine so the input node reflects the device that's connected RIGHT NOW.
        // Without this, an accessory swap (AirPods on/off) while idle leaves a stale cached
        // hardware format and capture fails until restart.
        rebuildEngine()
        let inputNode = audioEngine.inputNode

        let inputFormat = inputNode.outputFormat(forBus: 0)
        // An unavailable / not-ready input device reports a 0 Hz, 0-channel format, which makes
        // installTap raise a fatal exception. Bail gracefully with a message instead.
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            AppLog.audio.error("Invalid input format: \(inputFormat, privacy: .public)")
            notifyCaptureError(
                "No microphone is available. Check your input device and microphone permission "
                    + "in System Settings → Privacy & Security → Microphone.")
            return
        }

        // WhisperKit expects 16kHz mono Float32
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            )
        else {
            AppLog.audio.error("Failed to create target audio format")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            AppLog.audio.error("Failed to create audio converter")
            return
        }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
        silenceDetector.reset()

        // installTap can raise an uncatchable Obj-C exception (format mismatch, a lingering
        // tap). Route it through the Obj-C catcher so a bad audio state can never abort the app.
        do {
            try ObjCExceptionCatcher.perform {
                inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
                    [weak self] buffer, _ in
                    guard let self else { return }

                    // Convert to 16kHz mono
                    let frameCount = AVAudioFrameCount(
                        Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate
                    )
                    guard
                        let convertedBuffer = AVAudioPCMBuffer(
                            pcmFormat: targetFormat, frameCapacity: frameCount)
                    else { return }

                    var error: NSError?
                    converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }

                    if let error {
                        AppLog.audio.error("Audio conversion error: \(error, privacy: .public)")
                        return
                    }

                    guard let channelData = convertedBuffer.floatChannelData?[0] else { return }
                    let samples = Array(
                        UnsafeBufferPointer(
                            start: channelData, count: Int(convertedBuffer.frameLength)))

                    // Accumulate samples
                    self.bufferLock.lock()
                    self.audioBuffer.append(contentsOf: samples)
                    self.bufferLock.unlock()

                    // Update audio level for UI metering
                    let rms = self.calculateRMS(samples)
                    DispatchQueue.main.async {
                        self.audioLevel = rms
                    }

                    // Check for silence
                    if self.silenceDetector.isSilence(rms: rms) {
                        DispatchQueue.main.async {
                            self.onSilenceDetected?()
                        }
                    }
                }
            }
        } catch {
            AppLog.audio.error("installTap failed: \(error.localizedDescription, privacy: .public)")
            inputNode.removeTap(onBus: 0)
            notifyCaptureError("Couldn't start the microphone: \(error.localizedDescription)")
            return
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            AppLog.audio.error("Failed to start audio engine: \(error, privacy: .public)")
            inputNode.removeTap(onBus: 0)
            notifyCaptureError("Couldn't start audio: \(error.localizedDescription)")
        }
    }

    private func notifyCaptureError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.audioLevel = 0.0
            self?.onCaptureError?(message)
        }
    }

    /// Update silence detector parameters at runtime.
    func updateSilenceSettings(threshold: Float, duration: TimeInterval) {
        silenceDetector.silenceThreshold = threshold
        silenceDetector.silenceDuration = duration
    }

    /// The RMS level above which audio counts as speech — the SAME threshold the silence
    /// auto-stop uses, so streaming's pause detection can never disagree with it.
    var speechThreshold: Float {
        silenceDetector.silenceThreshold
    }

    /// Set the preferred audio input device by its unique ID.
    func setPreferredDevice(uniqueID: String) {
        // Use CoreAudio to set the default input device
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        // Find the device matching the uniqueID
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceCount: UInt32 = 0
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &deviceCount)
        let numDevices = Int(deviceCount) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: numDevices)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &deviceCount,
            &devices)

        for device in devices {
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, &uid)
            if uid as String == uniqueID {
                deviceID = device
                break
            }
        }

        guard deviceID != 0 else {
            AppLog.audio.info("Could not find audio device with ID: \(uniqueID, privacy: .public)")
            return
        }

        // Set as default input device
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, propertySize,
            &deviceID)
        if status == noErr {
            AppLog.audio.info("Set preferred input device: \(uniqueID, privacy: .public)")
        } else {
            AppLog.audio.error("Failed to set input device: \(status, privacy: .public)")
        }
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}
