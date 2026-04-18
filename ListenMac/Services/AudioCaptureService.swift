import AVFoundation
import Combine
import CoreAudio

/// Captures microphone audio via AVAudioEngine and accumulates Float samples
/// at 16kHz mono (WhisperKit's expected format).
final class AudioCaptureService: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var audioLevel: Float = 0.0

    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let silenceDetector = SilenceDetector()
    private var hasMicPermission: Bool = false

    /// Callback fired when silence is detected during recording.
    var onSilenceDetected: (() -> Void)?

    private var configChangeObserver: NSObjectProtocol?

    init() {
        // After sleep/wake or audio device changes, AVAudioEngine stops and may
        // invalidate taps without our knowledge. Register for the notification so
        // we can reset state and prevent a "tap already installed" crash the next
        // time beginCapture() calls installTap(onBus:).
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            print("[Listen] Audio engine reconfigured (sleep/wake or device change) — resetting state")
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }

    deinit {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Permission

    /// Pre-request mic permission at app launch so it's ready when user presses fn.
    func requestPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("[Listen] Mic permission status: \(status.rawValue)")
        switch status {
        case .authorized:
            hasMicPermission = true
            print("[Listen] Mic already authorized")
        case .notDetermined:
            print("[Listen] Requesting mic permission...")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                print("[Listen] Mic permission granted: \(granted)")
                DispatchQueue.main.async {
                    self?.hasMicPermission = granted
                }
            }
        case .denied, .restricted:
            print("[Listen] Mic permission denied/restricted")
            hasMicPermission = false
        @unknown default:
            break
        }
    }

    // MARK: - Recording

    /// Start capturing audio immediately. Mic permission should be pre-requested.
    func startRecording() {
        print("[Listen] startRecording called, hasMicPermission=\(hasMicPermission)")
        if hasMicPermission {
            beginCapture()
        } else {
            // Try requesting on-the-fly as fallback
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                print("[Listen] Late mic permission: \(granted)")
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
            print("[Listen] stopRecording called but not recording")
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

        print(
            "[Listen] stopRecording: captured \(result.count) samples (\(String(format: "%.1f", Double(result.count) / 16000.0))s)"
        )
        return result
    }

    /// Force-stop the audio engine unconditionally. Call this as a safety net.
    func forceStopEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            print("[Listen] forceStopEngine: engine stopped")
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
        let inputNode = audioEngine.inputNode

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Query format BEFORE removing the tap — on macOS, calling outputFormat(forBus:)
        // on a stopped or freshly-reset engine can trigger an internal reconfiguration
        // that reinstalls an internal tap. Removing AFTER the query ensures we catch it.
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Remove tap as close to installTap as possible to prevent any intermediate
        // reconfiguration from sneaking in a tap between remove and install.
        inputNode.removeTap(onBus: 0)

        // WhisperKit expects 16kHz mono Float32
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            )
        else {
            print("[Listen] Failed to create target audio format")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("[Listen] Failed to create audio converter")
            return
        }

        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
        silenceDetector.reset()

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
                print("[Listen] Audio conversion error: \(error)")
                return
            }

            guard let channelData = convertedBuffer.floatChannelData?[0] else { return }
            let samples = Array(
                UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))

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

        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("[Listen] Failed to start audio engine: \(error)")
        }
    }

    /// Update silence detector parameters at runtime.
    func updateSilenceSettings(threshold: Float, duration: TimeInterval) {
        silenceDetector.silenceThreshold = threshold
        silenceDetector.silenceDuration = duration
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
            print("[Listen] Could not find audio device with ID: \(uniqueID)")
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
            print("[Listen] Set preferred input device: \(uniqueID)")
        } else {
            print("[Listen] Failed to set input device: \(status)")
        }
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}
