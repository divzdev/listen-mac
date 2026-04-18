import Foundation

/// Energy-based Voice Activity Detector that tracks silence duration.
/// Fires when silence exceeds a configurable threshold.
final class SilenceDetector {
    /// RMS level below which audio is considered silence.
    var silenceThreshold: Float = 0.01
    /// How many seconds of continuous silence before triggering.
    var silenceDuration: TimeInterval = 2.0

    private var silenceStartTime: Date?

    /// Reset the detector state.
    func reset() {
        silenceStartTime = nil
    }

    /// Check if the current RMS indicates sustained silence.
    /// Returns true once silence has exceeded `silenceDuration`.
    func isSilence(rms: Float) -> Bool {
        if rms < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            }
            if let start = silenceStartTime, Date().timeIntervalSince(start) >= silenceDuration {
                return true
            }
        } else {
            // Sound detected, reset silence timer
            silenceStartTime = nil
        }
        return false
    }
}
