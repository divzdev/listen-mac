# Listen

Listen is a local-first voice dictation app for macOS. It records speech from your microphone, transcribes it on-device with WhisperKit, cleans up the text, and inserts it into the app you are already using.

This repository is the public, open-source macOS version of Listen.

## Features

- On-device transcription with WhisperKit
- Global hotkey dictation with hold-to-talk and toggle modes
- Text insertion into the focused macOS app through Accessibility, with clipboard fallback
- Voice commands for punctuation, new lines, and paragraphs
- Style presets for Casual, Work, and Email output
- Per-app style profiles
- Custom dictionary and snippet expansion
- Dictation history with comfortable, compact, and gallery views — pin, favorite, copy, re-insert, and a full-text detail view, plus search and Markdown/JSON export
- Optional grammar correction and rewriting with OpenAI-compatible APIs or local Ollama
- No telemetry, analytics, accounts, or bundled cloud service

## Privacy

Listen is designed to keep the default dictation path local:

- Microphone audio is processed on your Mac.
- Whisper models are downloaded by WhisperKit and run locally.
- Dictation history, snippets, dictionary entries, and settings are stored locally.
- OpenAI API keys are stored in the macOS Keychain, not in plain text files.
- If you enable the OpenAI backend, the transcribed text you ask Listen to improve is sent to your configured API endpoint.
- If you use Ollama on localhost, LLM rewriting stays on your Mac.

## Download

Download the latest DMG from the [GitHub Releases page](https://github.com/divzdev/listen-mac/releases/latest).

**Requirements:** an Apple Silicon Mac (M1 or newer) running macOS 14 Sonoma or later. The current build is Apple Silicon only.

First launch checklist:

1. Move Listen to Applications.
2. Open Listen.
3. Grant Microphone access when prompted.
4. Grant Accessibility access in System Settings > Privacy & Security > Accessibility so Listen can insert text into other apps.
5. Wait for the model to finish preparing on first launch (it is downloaded and optimized for your Mac once).
6. Focus a text field and hold the configured hotkey to dictate. The default trigger is the **fn** key.

**Using an external keyboard?** Many external keyboards have no `fn` key, so the default trigger will not fire. Open **Listen > Settings > Trigger**, choose **Custom keyboard shortcut**, and record a combo such as `⌘⌥D`. It is saved and works on any keyboard.

If you build from source or run an unsigned development build, macOS may require you to open the app from Finder with Control-click > Open.
The current public DMG is not Apple-notarized yet, so macOS may also ask you to approve it in System Settings > Privacy & Security.

## Build From Source

Prerequisites:

- macOS 14 Sonoma or newer
- Xcode 16 or newer
- Xcode command line tools
- XcodeGen (`brew install xcodegen`)

Build steps:

```bash
git clone https://github.com/divzdev/listen-mac.git
cd listen-mac
xcodegen generate
open Listen.xcodeproj
```

In Xcode, select the `ListenMac` scheme and run the app.

You can also build from Terminal:

```bash
xcodebuild \
  -project Listen.xcodeproj \
  -scheme ListenMac \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## Optional AI Setup

Listen works without an LLM. Optional AI features can improve grammar, tone, and formatting.

OpenAI-compatible API:

1. Open Listen > Settings > AI.
2. Choose OpenAI.
3. Paste your API key.
4. Keep the default base URL or enter another OpenAI-compatible endpoint.
5. Click Test Connection.

Ollama:

```bash
brew install ollama
ollama pull llama3.1:8b
ollama serve
```

Then open Listen > Settings > AI, choose Ollama, and use `http://localhost:11434` as the host.

## Tests

Run the core unit tests:

```bash
cd Packages/ListenCore
swift test
```

The test suite covers text cleanup, command parsing, style formatting, snippets, export/import, grammar correction, markdown export, and LLM response cleaning.

## Project Structure

```text
listen-mac/
+-- ListenMac/                  # macOS app target
|   +-- App/                    # App entry point and shared app state
|   +-- Services/               # Audio capture, hotkeys, text insertion, silence detection
|   +-- Views/                  # SwiftUI windows and controls
|   +-- Resources/              # Info.plist and assets
+-- Packages/ListenCore/        # Swift package with reusable app logic and tests
+-- Listen.xcodeproj/           # Generated Xcode project checked in for convenience
+-- project.yml                 # XcodeGen project definition
+-- SETUP.md                    # End-user setup guide
+-- CONTRIBUTING.md             # Contributor guide
+-- SECURITY.md                 # Security reporting and privacy notes
+-- LICENSE                     # MIT License
```

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), open an issue for larger changes, and include tests for behavior changes when practical.

Good first areas:

- Dictation reliability
- Whisper model handling
- Accessibility text insertion edge cases
- UI polish and accessibility
- Documentation and onboarding
- Test coverage for cleanup and LLM response handling

## Security

Please do not open public issues for vulnerabilities or leaked credentials. See [SECURITY.md](SECURITY.md) for reporting guidance.

## License

Listen is released under the [MIT License](LICENSE).

Third-party dependencies are resolved through Swift Package Manager and remain under their own licenses. The repository does not include API keys, private certificates, provisioning profiles, or bundled Whisper model weights.
