# Swift / SwiftUI (macOS)

Extends `@.claude/rules/code-style.md`. Applies when editing `*.swift`.

## Tooling

- **Swift 5.9+** toolchain, **macOS 14 (Sonoma)+** target, Apple Silicon. Xcode 16+.
- **XcodeGen** owns the project: edit `project.yml`, then `xcodegen generate` — never hand-edit
  `Listen.xcodeproj` (it's regenerated). New files/targets/deps go in `project.yml`.
- **SPM** for shared logic: pure, testable code lives in `Packages/ListenCore` (no AppKit/UI
  imports there). The app target depends on it. Add packages in `project.yml` / `Package.swift`,
  pinned via `Package.resolved`.
- No SwiftLint/swift-format configured yet — match surrounding style by hand. If you add one,
  wire it into `.claude/verify.sh`.

## Style

- lowerCamelCase for vars/functions, UpperCamelCase for types/protocols, no Hungarian/`m_`
  prefixes. Protocols read as capabilities (`-able`) or nouns. One primary type per file.
- Prefer `struct`/`enum` value types; reach for `class` only for reference semantics or
  framework requirements (`ObservableObject`, AppKit delegates). `final class` by default.
- `let` over `var`; immutability by default. Use `guard` for early exits, keep the happy path
  un-nested. Trailing closures and `map`/`compactMap`/`filter` over manual loops where clearer.
- Access control is real: `private`/`fileprivate` by default, widen only when needed. Mark
  `ListenCore` API `public` deliberately — it's the package boundary.

## Optionals & errors

- Optionals model real absence — don't use sentinels. Unwrap with `guard let` / `if let` /
  `??`. **Never force-unwrap (`!`)** except true programmer-invariant cases, and never `try!`
  / `as!` on data that can fail.
- Throw typed `Error` enums for recoverable failures (transcription, LLM, audio, Keychain);
  handle at the boundary (a Service or the View layer), not deep in pure logic. Don't swallow
  `catch {}` — log and surface. Errors name the offending value.

## Concurrency

- **Swift Concurrency (async/await + actors)**; avoid raw `DispatchQueue`/locks unless bridging
  AppKit callbacks. Mark UI-touching types `@MainActor` (AppState, view models) — audio/whisper
  work runs off-main, hop back to main only to publish.
- No data races: isolate mutable shared state in an `actor` or behind `@MainActor`. Cancel tasks
  on stop (recording/transcription must be cancellable); never block the main thread on I/O.

## SwiftUI / AppKit

- **SwiftUI-first** views; drop to AppKit/`NSViewRepresentable` only for what SwiftUI can't do
  (global hotkeys, overlay panels, clipboard/Accessibility insertion). Keep views thin —
  business logic lives in Services / `ListenCore`, not in `body`.
- State flows one way: `@StateObject`/`@ObservedObject` on `ObservableObject` orchestrators
  (e.g. `AppState`), `@State` for local UI only. Derive, don't duplicate state.
- Permission- and entitlement-sensitive paths (mic, Accessibility, hotkeys) must degrade
  gracefully — e.g. clipboard fallback when Accessibility is denied; never crash on denial.

## Data & secrets

- **SwiftData** (`@Model`) for persisted entities (history, snippets, dictionary, style
  profiles, notes). **UserDefaults** only for small scalar settings. Don't put model logic in
  Views — query/mutate through the model context.
- **Secrets never touch source or UserDefaults.** LLM API keys live in the macOS **Keychain**
  only. Don't log keys, audio, or raw transcripts. The default dictation path stays on-device —
  only send text to an external endpoint when the user has explicitly enabled a cloud backend.

## Tests

- **XCTest** in `Packages/ListenCore/Tests`; run with `swift test`. Test the **pure logic** —
  cleanup pipeline, command parsing, style formatting, snippet expansion, export/import, LLM
  response cleaning — with table-driven cases (empty / one / many / unicode / long).
- Keep WhisperKit, network, audio, and AppKit out of unit tests — they're boundaries; test the
  deterministic transformations around them. No sleeps; seed any randomness.
