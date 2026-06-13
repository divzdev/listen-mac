# Listen — Delivery Plan (Sprints)

> The sprint-by-sprint build plan and source of truth for **what's built vs. pending**. Build one
> sprint at a time; check off each `- [ ]` as it ships; mark a sprint ✅ only when its **Definition
> of Done** holds (all boxes + `verify.sh` green + demoable); then advance.
>
> **Reality:** Listen **v1.0 is shipped** (public DMG). Sprints 0–5 below are the foundation and
> are **done** — recorded here so the plan is complete and the architecture is legible. Forward
> work starts at **Sprint 6**. Test backfill for shipped code is owned by **Sprint 8**.

## Status overview

| Sprint | Goal | Status |
|--------|------|--------|
| 0 | Project foundation & on-device transcription | ✅ Done |
| 1 | Core dictation loop & text insertion | ✅ Done |
| 2 | Cleanup, styles, snippets, dictionary, per-app profiles | ✅ Done |
| 3 | History & local persistence | ✅ Done |
| 4 | Optional AI (LLM grammar / rewrites) | ✅ Done |
| 5 | Onboarding, settings & live overlay | ✅ Done |
| — | **MVP / v1.0 cut-line** (shipped publicly) | ✅ |
| 6 | UX/polish & accessibility | 🔶 In progress |
| 7 | New user-facing features | ⬜ Planned |
| 8 | Reliability & test coverage | ⬜ Planned |
| 9 | Distribution hardening (notarization) | ⬜ Planned |

---

## Sprint 0 — Project foundation & on-device transcription ✅

**Goal:** A buildable macOS app that captures mic audio and transcribes it on-device.
**Depends on:** —

### Features
- [x] XcodeGen project (`project.yml`) + checked-in `Listen.xcodeproj`; `ListenMac` scheme builds
- [x] `ListenCore` SPM package (pure logic, no UI) wired into the app target
- [x] WhisperKit integration + `TranscriptionService` (model selection, partial/final results)
- [x] `AudioCaptureService` — AVAudioEngine 16kHz mono capture + audio-level metering

### Testing
- [x] `ListenCore` compiles via `swift build` (verify gate)
- [ ] Manual: model downloads and transcribes a short sample _(carried to Sprint 8)_

### Definition of Done
App builds with the `ListenMac` scheme; speaking produces a transcript on-device.

---

## Sprint 1 — Core dictation loop & text insertion ✅

**Goal:** Press a hotkey, speak, and have cleaned text appear in the focused app.
**Depends on:** Sprint 0

### Features
- [x] `HotKeyManager` — fn-key default + custom hotkey; hold-to-talk and toggle modes; 250ms debounce
- [x] `SilenceDetector` — RMS voice-activity auto-stop; 120s safety timeout
- [x] Junk-audio guard — discard too-short buffers and Whisper silence-hallucinations
- [x] `CommandParser` — inline voice commands ("new paragraph", "period", …)
- [x] `TextInsertionService` — clipboard-paste insertion with prior-clipboard restore; graceful when Accessibility denied

### Testing
- [x] Unit: `CommandParser` inline commands
- [ ] Integration: end-to-end paste into Notes/TextEdit _(carried to Sprint 8)_

### Definition of Done
Hotkey → speech → cleaned text inserted into the focused app; no crash when Accessibility is denied.

---

## Sprint 2 — Cleanup, styles, snippets, dictionary, per-app profiles ✅

**Goal:** Transform raw transcript into polished, context-appropriate text.
**Depends on:** Sprint 1

### Features
- [x] `TextCleanupPipeline` — whitespace, fillers, capitalization, punctuation, numbers
- [x] `StylePreset` + `StyleFormatter` — Casual / Work / Email built-ins (formalize, concise, email wrap)
- [x] `Snippet` + `SnippetExpander` — trigger→expansion, longest-trigger-first
- [x] `CustomWord` dictionary for transcription hints
- [x] `AppStyleProfile` — per-app style override beats the global selected style

### Testing
- [x] Unit: cleanup pipeline, style formatter, snippet expander
- [ ] Unit: dictionary/custom-word application _(carried to Sprint 8)_

### Definition of Done
Pipeline order (commands → cleanup → snippets → style → grammar) is deterministic and test-pinned.

---

## Sprint 3 — History & local persistence ✅

**Goal:** Every dictation is saved locally, searchable, and exportable.
**Depends on:** Sprint 2

### Features
- [x] SwiftData models persisted (`DictationEntry`, snippets, dictionary, profiles, `ScratchpadNote`)
- [x] `HistoryView` — searchable list, favorite flag, re-insert
- [x] `ExportImportService` (JSON) + `MarkdownExporter`
- [x] Settings persisted via UserDefaults

### Testing
- [x] Unit: export/import round-trip, markdown export
- [ ] Edge: corrupt/partial import handling _(carried to Sprint 8)_

### Definition of Done
History survives relaunch; export then import reproduces snippets/dictionary/history.

---

## Sprint 4 — Optional AI (LLM grammar / rewrites) ✅

**Goal:** Optional, off-by-default AI that improves grammar and rewrites on voice command.
**Depends on:** Sprint 2

### Features
- [x] `LLMService` — OpenAI-compatible + Ollama backends; disabled default
- [x] API keys stored in macOS **Keychain** only
- [x] `GrammarService` rule-based fallback when no LLM configured
- [x] Rewrite commands ("make shorter", "more professional", "bullet points", "summarize") replace prior output

### Testing
- [x] Unit: rewrite-command detection, LLM response cleaning, grammar fallback
- [ ] Integration: live OpenAI/Ollama Test-Connection paths _(carried to Sprint 8)_

### Definition of Done
App is fully usable with **no** LLM; enabling a backend adds grammar/rewrite without leaking keys.

---

## Sprint 5 — Onboarding, settings & live overlay ✅

**Goal:** First-run permissions flow, full settings, and a live dictation HUD.
**Depends on:** Sprints 1–4

### Features
- [x] `OnboardingView` — mic + Accessibility permission flow, hotkey/model pick
- [x] `SettingsView` — model, LLM backend, hotkey/mode, silence timeout, styles, app profiles, dictionary
- [x] `TranscriptOverlay` — floating partial-transcript + audio-level HUD
- [x] `MainAppView`, `SnippetsView`, `AppProfilesView`, `DictionaryView`, `KeyRecorderView`

### Testing
- [ ] Manual: full first-run on a clean machine _(carried to Sprint 8)_

### Definition of Done
A new user can onboard, grant permissions, configure, and dictate — the shipped v1.0 experience.

---

## 🎯 MVP / v1.0 cut-line — **shipped** (public DMG on GitHub Releases)

Everything above is live. Everything below is forward work, in priority order.

---

## Sprint 6 — UX/polish & accessibility ⬜ (next, detailed)

**Goal:** Make the shipped experience feel finished and usable to everyone — clearer onboarding,
a polished overlay, and full VoiceOver/keyboard accessibility.
**Depends on:** Sprint 5

### Features
- [x] **Recent Dictations redesign** — Clipnest-inspired: 3 switchable view modes (comfortable / compact / gallery), a **pinned** shelf, visible hover actions (copy · re-insert · pin · favorite · quick-look · AI-rewrite · delete), quick-look popover, in-list search/manage/export. Retired the orphaned duplicate `HistoryView`.
- [~] Accessibility pass — **done for Home + Recent Dictations** (Dynamic Type, VoiceOver labels/actions, reduced-motion, combined card labels); **pending** for Settings / Style / Scratchpad / Onboarding (still hardcoded `.system(size:)` fonts)
- [~] Error & status messaging — model save/rewrite failures now surface via `errorMessage` (was silently swallowed); broader coverage ("no mic", "Accessibility off", "model downloading") still pending
- [ ] Onboarding refinement — clearer permission rationale, recover gracefully if mic/Accessibility denied or revoked later, "test your hotkey" step
- [ ] Overlay/HUD polish — consistent states (listening / transcribing / inserting / error), respects reduced-motion, non-intrusive placement
- [ ] Settings clarity — group/label settings, explain on-device vs cloud, surface current model & permission status at a glance

### Testing
- [ ] Manual: VoiceOver walkthrough of onboarding, dictation, settings (golden path)
- [ ] Manual: permission-revoked-mid-session recovery (mic and Accessibility)
- [ ] Manual: reduced-motion + increased-contrast system settings honored
- [ ] Edge: overlay behavior across multiple displays / spaces / full-screen apps

### Definition of Done
All boxes checked; `verify.sh` green; a VoiceOver user can complete onboarding and dictate; no
unexplained error states; demoable on a clean machine.

---

## Sprint 7 — New user-facing features ⬜ (detailed-light)

**Goal:** Add net-new dictation capability beyond v1.0. **Scope to be locked at sprint start**
(pick from below; don't build all at once).
**Depends on:** Sprint 6

### Candidate features (choose per sprint)
- [ ] Streaming / partial insertion — insert text live as you speak (vs. only on stop)
- [ ] Expanded voice-command vocabulary (formatting, capitalization, undo-last)
- [ ] User-defined / editable style presets beyond the three built-ins
- [ ] Multi-language transcription selection + per-language model handling
- [ ] Scratchpad upgrades — organize, search, export notes
- [ ] Per-app profile improvements (auto-suggest a style from app category)

### Testing
- [ ] Unit: every new pure transform in `ListenCore` (table-driven: empty/one/many/unicode/long)
- [ ] Integration: any new insertion/transcription path exercised end-to-end
- [ ] Edge cases per `@.claude/rules/testing.md`

### Definition of Done
Chosen feature(s) shipped + tested; existing pipeline tests still green; `verify.sh` green;
`docs/APP_CONTEXT.md` updated if a business rule/flow changed.

---

## Sprint 8 — Reliability & test coverage ⬜ (outline)

**Goal:** Harden the dictation pipeline and backfill the test pyramid for shipped code (the
"carried to Sprint 8" items above).
**Depends on:** Sprint 5 (can run alongside 6–7)

### Features / hardening
- [ ] Audio robustness — sleep/wake & device-change recovery, mic switch mid-app, empty/garbled input
- [ ] Whisper artifact handling — broaden hallucination filter, validate across models
- [ ] Insertion edge cases — secure fields, slow-focus apps, very long text, clipboard contention
- [ ] Backfill unit tests for dictionary application, import error handling, and any untested `ListenCore` logic

### Testing
- [ ] Raise `ListenCore` coverage on meaningful logic (target 70–85%, not vanity 100%)
- [ ] Integration: paste into Notes/TextEdit; OpenAI/Ollama Test-Connection paths (mock the network boundary)
- [ ] Deterministic suite — no sleeps, seeded randomness; `swift test` < a few minutes

### Definition of Done
No flaky tests; carried-forward items closed; pipeline survives sleep/wake and device changes; `verify.sh` green.

---

## Sprint 9 — Distribution hardening ⬜ (outline)

**Goal:** Ship a signed, Apple-notarized DMG so users skip the Gatekeeper workaround.
**Depends on:** Sprint 6 (stable UX before wider distribution)

### Features
- [ ] Developer ID code signing for the app + hardened runtime (already enabled in `project.yml`)
- [ ] Apple notarization + stapling of the DMG; verify Gatekeeper acceptance on a clean Mac
- [ ] Release pipeline — repeatable build → sign → notarize → DMG → GitHub Release (document or script it)
- [ ] (Optional) auto-update / update-check mechanism
- [ ] Update README/SETUP to drop the "not notarized" caveat once true

### Testing
- [ ] Manual: download DMG on a fresh Mac, open without Control-click workaround
- [ ] `spctl --assess` / notarization status checks pass
- [ ] Smoke: signed build still dictates + inserts (signing didn't break entitlements)

### Definition of Done
A notarized DMG opens cleanly via Gatekeeper; release steps are reproducible; docs reflect reality.

---

### Build discipline (carry into implementation)
- Build one sprint at a time; check off each box as it ships.
- Mark a sprint ✅ only when its DoD holds (all boxes + `verify.sh` green + demoable).
- Keep this file current — it's the source of truth for built vs. pending.
- Don't invent features not in the docs; lock Sprint 7 scope before building it.
