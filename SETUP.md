# Listen — AI-Enhanced Voice Dictation for macOS

Listen is a local-first voice dictation app that transcribes speech on-device using WhisperKit. Optionally, connect an LLM to unlock enhanced features like voice commands, tone rewriting, and smart formatting.

---

## Quick Start

1. **Open Listen** from Applications or the menu bar
2. Complete the onboarding wizard (microphone permission, accessibility access)
3. **Hold fn** and speak — release to transcribe and paste

---

## AI Enhance Setup

Listen supports two LLM backends for enhanced features. Choose one:

### Option A: OpenAI API (Recommended for most users)

1. Get an API key from [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Open **Listen → Settings → AI**
3. Set **Backend** to **OpenAI**
4. Paste your API key and click **Save**
5. Click **Test Connection** to verify

**Recommended model:** `gpt-4o-mini` (fast, cheap, great quality)

**OpenAI-compatible APIs:** You can use any OpenAI-compatible provider by changing the Base URL:
| Provider | Base URL |
|----------|----------|
| OpenAI | `https://api.openai.com/v1` (default) |
| Azure OpenAI | `https://{resource}.openai.azure.com/openai/deployments/{deployment}` |
| Together AI | `https://api.together.xyz/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Ollama (remote) | `http://your-server:11434/v1` |

> **Security:** Your API key is stored in the macOS Keychain — never in plain text, never sent anywhere except the configured API endpoint.

### Option B: Ollama (Fully Local, No Internet)

1. Install Ollama: [ollama.com/download](https://ollama.com/download)
2. Pull a model:
   ```bash
   ollama pull llama3.1:8b
   ```
3. Make sure Ollama is running (it auto-starts after install)
4. Open **Listen → Settings → AI**
5. Set **Backend** to **Ollama (Local)**
6. Host should be `http://localhost:11434` (default)
7. Click **Test Connection** to verify

**Recommended models:**
| Model | Size | Quality | Speed |
|-------|------|---------|-------|
| `llama3.1:8b` | ~4.7GB | Good | Fast |
| `mistral:7b` | ~4.1GB | Good | Fast |
| `llama3.1:70b` | ~40GB | Excellent | Slow |

> Ollama keeps everything on your Mac. No data leaves your machine.

---

## What AI Enhance Does

When an LLM is connected, you unlock these features:

- **Voice commands** — After dictating, say things like:
  - *"Make this shorter"*
  - *"Make it more professional"*
  - *"Rewrite as bullet points"*
  - *"Summarize this"*

- **Auto grammar correction** — Fixes spelling, punctuation, and grammar in real-time

- **Context-aware formatting** — Automatically adjusts tone based on which app you're dictating into (e.g., casual in Messages, formal in Mail)

- **Style rewriting** — Transform any text between Casual, Work, and Email tones

---

## Troubleshooting

### "Not available" status
- **OpenAI:** Check your API key is valid and has credits
- **Ollama:** Make sure Ollama is running (`ollama serve` in Terminal)

### Slow responses
- **OpenAI:** Try `gpt-4o-mini` instead of `gpt-4o`
- **Ollama:** Use a smaller model like `llama3.1:8b`

### fn key doesn't work
- Go to **System Settings → Keyboard**
- Set "Press fn key to" → **Do Nothing**
- This frees the fn key for Listen

---

## Privacy

- **Transcription** is always on-device via WhisperKit (no cloud)
- **AI Enhance** sends only the transcribed text to your chosen LLM:
  - OpenAI: sent to OpenAI's API (or your configured endpoint)
  - Ollama: stays entirely on your Mac
- **No telemetry, no analytics, no accounts required**
