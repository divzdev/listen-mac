# Contributing to Listen

Thanks for helping improve Listen. This project is a macOS app, so contributions should keep the Mac experience reliable, private, and easy to build from source.

## Before You Start

1. Search existing issues and pull requests.
2. Open an issue for larger changes before writing a big patch.
3. Keep changes focused. Separate bug fixes, refactors, and UI changes into different pull requests when possible.

## Local Setup

Prerequisites:

- macOS 14 Sonoma or newer
- Xcode 16 or newer
- XcodeGen (`brew install xcodegen`)

Setup:

```bash
git clone https://github.com/divzdev/listen-mac.git
cd listen-mac
xcodegen generate
open Listen.xcodeproj
```

Run the `ListenMac` scheme from Xcode.

## Tests

Run unit tests before opening a pull request:

```bash
cd Packages/ListenCore
swift test
```

For app-level changes, also test manually:

- First launch onboarding
- Microphone permission flow
- Accessibility permission flow
- Start/stop dictation with the default hotkey
- Text insertion into Notes or TextEdit
- Clipboard fallback when Accessibility is not granted
- Optional LLM settings with no API key configured

## Pull Request Checklist

- The app builds with the `ListenMac` scheme.
- Unit tests pass, or the PR clearly explains why they were not run.
- No API keys, certificates, provisioning profiles, build artifacts, or personal data are committed.
- User-facing behavior changes are documented in README.md or SETUP.md.
- Privacy-sensitive changes explain what data is stored locally or sent to a configured endpoint.

## Coding Guidelines

- Prefer small, focused changes.
- Keep SwiftUI views readable and avoid unrelated style churn.
- Keep user data local by default.
- Store secrets only in Keychain or user-managed configuration, never in source files.
- Add tests for text cleanup, command parsing, LLM response cleaning, and other pure logic.

## Reporting Bugs

Please include:

- macOS version
- Mac model/chip
- Xcode version if building from source
- Steps to reproduce
- Expected behavior
- Actual behavior
- Relevant logs, with secrets removed
