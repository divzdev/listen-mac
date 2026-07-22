import Foundation
import OSLog

/// Centralized logging via `os.Logger` so diagnostics are actually retrievable in the field.
///
/// Plain `print(...)` is invisible for a Finder-launched app — it isn't captured by the unified
/// log (Console.app shows nothing) and, when stdout is redirected, it's block-buffered — which
/// made "have the user send logs" impossible for a shipped, un-notarized build. Logging through a
/// subsystem fixes that: the affected user (or a support script) can reproduce the problem, then run
///
///     log show --last 30m --predicate 'subsystem == "com.divyam.listen"'
///
/// to see exactly where dictation is failing. The diagnostic spine (launch, model load, hotkey
/// registration, the startDictation gate) is logged at `.notice`/`.error`/`.fault` so it PERSISTS
/// and is retrievable after the fact — `.info`/`.debug` are memory-only and need `--info`/`--debug`
/// with live `log stream`, so they're used only for chatty, non-essential detail.
///
/// PRIVACY CONTRACT: raw audio, transcripts, and inserted text are NEVER logged. `os.Logger`
/// redacts interpolated values by default (renders `<private>`), so numbers/enums must be marked
/// `\(x, privacy: .public)` to appear — but transcript *content* must never be marked public, and
/// is not logged at all here. Log lengths/counts/state, never words the user spoke.
enum AppLog {
    private static let subsystem = "com.divyam.listen"

    /// App lifecycle, dictation orchestration, text insertion.
    static let app = Logger(subsystem: subsystem, category: "app")
    /// Audio capture / engine state.
    static let audio = Logger(subsystem: subsystem, category: "audio")
    /// Global hotkey / fn-key trigger.
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    /// Whisper model download / load / transcription.
    static let model = Logger(subsystem: subsystem, category: "model")
}
