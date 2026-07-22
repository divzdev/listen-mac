import AVFoundation

/// Plays short synthesized UI sounds for dictation start/stop. The start sound is a soft
/// water-drop: a low, gently rising "bloop" (bubble resonance) followed by a faint, higher
/// echo-bubble — the two-event shape is what makes a real drop-into-water sound. The stop sound
/// is a quieter, low descending blip. Synthesized in-memory (no bundled asset), tuned soothing:
/// low register, pure tone, slow attack, long decay, low gain.
final class SoundFeedback {
    private struct Bubble {
        let startAt: Double  // seconds into the clip
        let fromHz: Double
        let toHz: Double
        let sweepSeconds: Double
        let decayTau: Double
        let gain: Double
    }

    private let startPlayer: AVAudioPlayer?
    private let stopPlayer: AVAudioPlayer?

    init() {
        // Drop + delayed echo-bubble = "drop of water falling in water".
        startPlayer = Self.makePlayer(
            bubbles: [
                Bubble(
                    startAt: 0, fromHz: 280, toHz: 560, sweepSeconds: 0.16, decayTau: 0.10,
                    gain: 0.26),
                Bubble(
                    startAt: 0.19, fromHz: 400, toHz: 720, sweepSeconds: 0.10, decayTau: 0.06,
                    gain: 0.10),
            ],
            totalSeconds: 0.7)
        // Low, quiet, descending — "done".
        stopPlayer = Self.makePlayer(
            bubbles: [
                Bubble(
                    startAt: 0, fromHz: 460, toHz: 300, sweepSeconds: 0.12, decayTau: 0.08,
                    gain: 0.16)
            ],
            totalSeconds: 0.45)
        startPlayer?.prepareToPlay()
        stopPlayer?.prepareToPlay()
    }

    private var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "playSounds") as? Bool ?? true
    }

    /// The water-drop cue: recording has started, speak now.
    func playStart() {
        guard soundsEnabled else { return }
        startPlayer?.currentTime = 0
        startPlayer?.play()
    }

    /// Soft descending cue: recording ended.
    func playStop() {
        guard soundsEnabled else { return }
        stopPlayer?.currentTime = 0
        stopPlayer?.play()
    }

    // MARK: - Synthesis

    private static func makePlayer(bubbles: [Bubble], totalSeconds: Double) -> AVAudioPlayer? {
        let player = try? AVAudioPlayer(
            data: render(bubbles: bubbles, totalSeconds: totalSeconds))
        player?.volume = 1.0
        return player
    }

    /// Render pitch-sweeping sine "bubbles" into one in-memory 16-bit mono WAV.
    private static func render(bubbles: [Bubble], totalSeconds: Double) -> Data {
        let sampleRate = 44_100.0
        let count = Int(sampleRate * totalSeconds)
        var mix = [Double](repeating: 0, count: count)

        for bubble in bubbles {
            var phase = 0.0
            let startSample = Int(bubble.startAt * sampleRate)
            for i in startSample..<count {
                let t = Double(i - startSample) / sampleRate
                // Exponential pitch sweep — reads as a bubble far better than a linear one.
                let sweepProgress = min(t / bubble.sweepSeconds, 1.0)
                let freq = bubble.fromHz * pow(bubble.toHz / bubble.fromHz, sweepProgress)
                phase += 2.0 * .pi * freq / sampleRate

                // Gentle attack (12ms) and a long exponential decay keep it soothing, not beepy.
                let attack = min(t / 0.012, 1.0)
                let decay = exp(-t / bubble.decayTau)
                mix[i] += sin(phase) * attack * decay * bubble.gain
            }
        }

        let samples = mix.map { Int16(max(-1.0, min(1.0, $0)) * 32_766.0) }
        return wavData(samples: samples, sampleRate: Int(sampleRate))
    }

    /// Wrap raw 16-bit mono PCM samples in a minimal WAV container.
    private static func wavData(samples: [Int16], sampleRate: Int) -> Data {
        let byteCount = samples.count * 2
        var data = Data(capacity: 44 + byteCount)

        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        append("RIFF")
        append32(UInt32(36 + byteCount))
        append("WAVE")
        append("fmt ")
        append32(16)  // PCM chunk size
        append16(1)  // PCM format
        append16(1)  // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))  // byte rate
        append16(2)  // block align
        append16(16)  // bits per sample
        append("data")
        append32(UInt32(byteCount))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
