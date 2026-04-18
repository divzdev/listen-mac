# Security Policy

Listen handles microphone input, local transcripts, Accessibility permissions, and optional LLM API credentials. Please report security issues carefully.

## Reporting a Vulnerability

Do not open a public GitHub issue for security vulnerabilities or leaked credentials.

Report privately to the maintainer through GitHub Security Advisories once the repository is public. If advisories are not enabled yet, contact the repository owner directly through their GitHub profile.

Please include:

- Affected version or commit
- Impact
- Steps to reproduce
- Any proof of concept, with personal data and secrets removed
- Suggested fix if you have one

## Scope

Security-sensitive areas include:

- Keychain storage for LLM API keys
- Microphone permission flow
- Accessibility text insertion
- Clipboard fallback behavior
- Local transcript/history persistence
- Network calls to configured LLM endpoints
- Build and release signing material

## Secret Handling

The repository should never contain:

- API keys or access tokens
- Apple signing certificates
- Provisioning profiles
- ExportOptions.plist files with signing metadata
- Private keys
- User transcripts or imported/exported personal data
- Build outputs, DMGs, archives, or derived data

## Privacy Notes

- Transcription runs on device through WhisperKit.
- Optional OpenAI-compatible LLM features send selected text to the configured endpoint.
- Optional Ollama features can run locally at `http://localhost:11434`.
- API keys are stored in macOS Keychain by the app.
