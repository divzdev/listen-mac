<!--
  MAINTENANCE CONTRACT — read before editing.
  • This is the single source of truth for WHAT this app is and WHY (business/domain).
    CLAUDE.md covers HOW we build (stack/commands/conventions). Keep them separate.
  • BUDGET: keep this file under ~200 lines / ~2–3 pages. It is a SUMMARY, not a log.
    If an edit pushes it over budget, COMPRESS — don't append.
  • BELONGS HERE: durable business truth — product purpose, users, domain model, business
    rules/invariants, critical flows, constraints, non-goals, glossary.
  • DOES NOT BELONG: anything already obvious from code/tests, implementation detail, task
    history, dated changelogs, how-to-build steps, transient TODOs.
  • CADENCE: refresh whenever business behavior changes. Run `/context` to regenerate &
    re-summarize from recent changes. The status line shows a stale marker when code has moved
    ahead of this file.
  • This is loaded into Claude's context every session, so every line costs tokens forever.
    Earn each one.
-->

# Application Context

> Status: **ACTIVE**
> Last meaningful update: 2026-06-12

## In one line

Listen helps macOS users dictate by voice — transcribed on-device — so they can type into any
app, hands-free and private.

## What it is

Listen is a **local-first voice dictation app for macOS**. Hold a global hotkey, speak, and the
spoken words are transcribed **on-device** with WhisperKit, cleaned up, optionally restyled, and
inserted into whatever app is focused. It is the **public, open-source, shipped v1.0** of the Mac
app — single-user desktop software, not a hosted service. The default path is fully local: no
accounts, no telemetry, no bundled cloud. Optional AI features (grammar fix, voice-command
rewrites, tone) run through a user-configured OpenAI-compatible API or a local Ollama instance.

## Who uses it

- **Dictating user** — the only user. Wants fast, accurate, private text entry by voice in any
  app; cares about latency, correctness, and that audio never leaves the Mac by default.
- **Privacy-conscious / offline user** — same person in a stricter mode: never enables a cloud
  LLM; everything (transcription + optional Ollama rewriting) stays on-device.
- **Contributor** — open-source developer; cares about a clean build-from-source path, local
  data handling, and tests for the pure logic.

## Domain model (the nouns)

- **DictationEntry** — one completed dictation; raw transcript + cleaned/inserted text, timestamp,
  duration, the focused app (bundle id + name), style used, language, and `favorite`/`pinned`
  flags. The history. Shown on Home with switchable view modes (comfortable / compact / gallery).
- **StylePreset** — a named formatting profile (remove fillers / formalize / make concise / email
  wrap). Three built-ins: **Casual**, **Work**, **Email**; users can add their own.
- **AppStyleProfile** — maps a focused app's bundle id → a StylePreset (e.g. Mail → Email), so
  output tone adapts to where you're dictating.
- **Snippet** — a trigger → expansion pair (e.g. `/sig` → a signature block). Expanded in output.
- **CustomWord** — a dictionary entry (word/phrase + optional pronunciation hint) to bias/correct
  transcription of names and jargon.
- **ScratchpadNote** — a free-form local note (title + content); a lightweight notepad, separate
  from dictation history.

## Business rules & invariants (the non-obvious logic)

- **Local by default; cloud only on explicit opt-in.** Transcription is always on-device. Text is
  sent to an external endpoint **only** when the user has enabled the OpenAI backend; Ollama keeps
  it on-device. No telemetry/analytics ever.
- **Secrets live in the Keychain, never in source/UserDefaults/logs.** LLM API keys are stored in
  the macOS Keychain only.
- **Per-app style overrides the global style.** If the focused app has an AppStyleProfile, its
  preset wins over the user's globally selected style for that dictation.
- **A recording ends three ways:** key release (hold-to-talk), silence (auto-stop after the
  configured timeout, default ~2s of sub-threshold RMS), or a 120s safety timeout — whichever
  first. Toggle mode ends on a second press.
- **Junk audio is discarded, not inserted.** Sub-threshold/too-short buffers (~<0.1s) and known
  Whisper silence-hallucinations (e.g. "thank you", "[silence]") are dropped — no text is pasted.
- **Insertion degrades gracefully.** Text is inserted via clipboard paste (⌘V) into the focused
  app and the prior clipboard is restored; if Accessibility/insertion is unavailable the user is
  not blocked. Permission denial never crashes the app.
- **Cleanup pipeline is deterministic and ordered.** Voice-command parsing → text cleanup →
  snippet expansion → style formatting → grammar correction. Order matters; it's the contract the
  unit tests pin.
- **Grammar correction has a local fallback.** If an LLM is configured it fixes grammar; if not, a
  rule-based GrammarService runs. The app is fully functional with **no** LLM configured —
  AI features are additive, never required.
- **Longest snippet trigger wins** when triggers overlap, to avoid partial-match corruption.
- **Pinned dictations are sticky.** They surface in a shelf above the date-grouped history and are
  kept when the user bulk-clears history (only unpinned entries are removed).

## Critical flows

**Dictation (core loop):** hotkey press → `AudioCaptureService` records 16kHz mono samples while
`SilenceDetector` watches RMS → stop (release / silence / 120s) → `TranscriptionService`
(WhisperKit) → discard junk/hallucinations → `CommandParser` → `TextCleanupPipeline` →
`SnippetExpander` → resolve style (per-app profile ?? global) → `StyleFormatter` → grammar
(LLM or rule-based) → `TextInsertionService` pastes into focused app → save `DictationEntry`.

**Voice-command rewrite:** a follow-up dictation matching a rewrite command ("make this shorter",
"more professional", "as bullet points", "summarize") routes the previous output through the LLM
and replaces it. Only works when an LLM backend is enabled.

**First-run onboarding:** wizard requests Microphone permission, guides Accessibility access (for
insertion), and lets the user pick a hotkey/mode and Whisper model before first dictation.

**Optional AI setup:** Settings → AI → choose OpenAI (paste key → Keychain) or Ollama (host) →
Test Connection. Toggling backend changes the grammar/rewrite path; default is off (local-only).

## Constraints & non-goals

- **Platform:** macOS 14+ on Apple Silicon; SwiftUI/AppKit; Xcode 16+, XcodeGen-generated project.
- **Privacy contract:** default path 100% on-device; no accounts/telemetry; keys in Keychain;
  audio and raw transcripts are never logged or transmitted on the default path.
- **Distribution:** open-source (MIT); shipped as a DMG via GitHub Releases. **Not yet
  Apple-notarized** — users may need to approve it in System Settings.
- **Non-goals:** no backend/multi-tenant service; no cloud sync or accounts; **iOS / keyboard
  extension are out of scope for this build** (`ListeniOS/`, `ListenKeyboard/` exist in the tree
  but are excluded from `project.yml`); no bundled Whisper weights (WhisperKit downloads them).

## Glossary

- **WhisperKit** — on-device speech-to-text engine (CoreML); downloads model weights locally.
- **Hold-to-talk vs toggle** — record while the hotkey is held vs. press-to-start / press-to-stop.
- **Silence auto-stop** — ending a recording when audio RMS stays below threshold for the
  configured duration (default ~2s).
- **Clipboard fallback** — inserting text by setting the clipboard and sending ⌘V, then restoring
  the old clipboard — used so insertion works without full Accessibility-API control.
- **Rewrite command** — a spoken instruction that transforms the previous dictation via the LLM,
  rather than producing new literal text.
- **AI Enhance** — the umbrella for optional LLM features (grammar fix, rewrites, tone); off by
  default.

## Open questions / decisions pending

- Apple notarization & signing for the public DMG — planned but not done.
- Whether `ListeniOS/` / `ListenKeyboard/` ever rejoin this repo's build, or stay separate.
