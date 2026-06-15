import Carbon
import HotKey
import ListenCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// App preferences / settings window.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @AppStorage("whisperModel") private var selectedModel = "base"
    @AppStorage("defaultStyle") private var defaultStyle = "Casual"
    @AppStorage("silenceTimeout") private var silenceTimeout = 2.0
    @AppStorage("dictationMode") private var dictationMode = "holdToTalk"
    @AppStorage("language") private var language = "en"
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoStopOnSilence") private var autoStopOnSilence = true
    @AppStorage("triggerMethod") private var triggerMethod = "fnKey"
    @AppStorage("showOverlay") private var showOverlay = true
    @AppStorage("grammarCorrection") private var grammarCorrection = true
    @AppStorage("showNotification") private var showNotification = false
    @AppStorage("llmBackend") private var llmBackend = "none"
    @AppStorage("ollamaHost") private var ollamaHost = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.1:8b"
    @AppStorage("openAIModel") private var openAIModel = "gpt-4o-mini"
    @AppStorage("openAIBaseURL") private var openAIBaseURL = "https://api.openai.com/v1"

    @State private var showExportSuccess = false
    @State private var showImportSuccess = false
    @State private var importError: String?
    @State private var hotkeyKey: Key = .d
    @State private var hotkeyModifiers: NSEvent.ModifierFlags = [.command, .option]
    @State private var availableLLMModels: [String] = []
    @State private var isTestingLLM = false
    @State private var llmTestResult: String?
    @State private var openAIKey = ""
    @State private var isAPIKeyVisible = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            dictationTab
                .tabItem {
                    Label("Dictation", systemImage: "mic")
                }

            modelTab
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }

            aiTab
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 420)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        (NSApp.delegate as? AppDelegate)?.setLaunchAtLogin(newValue)
                    }
            }

            Section("Default Style") {
                Picker("Style preset", selection: $defaultStyle) {
                    Text("Casual").tag("Casual")
                    Text("Work").tag("Work")
                    Text("Email").tag("Email")
                }
                .onChange(of: defaultStyle) { _, newValue in
                    appState.selectedStyle = newValue
                }
            }

            Section("Display") {
                Toggle("Show transcript overlay while dictating", isOn: $showOverlay)
                Toggle("Show notification on dictation complete", isOn: $showNotification)
            }

            Section("Text Processing") {
                Toggle("Auto-correct grammar", isOn: $grammarCorrection)
                Text("Applies rule-based grammar fixes to transcriptions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                HStack {
                    Button("Export Data…") { exportData() }
                    Button("Import Data…") { importData() }
                }
                if showExportSuccess {
                    Label("Exported successfully", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                if showImportSuccess {
                    Label("Imported successfully", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                if let importError {
                    Label(importError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var dictationTab: some View {
        Form {
            Section("Trigger") {
                Picker("Activation method", selection: $triggerMethod) {
                    Text("Hold fn key (recommended)").tag("fnKey")
                    Text("Custom keyboard shortcut").tag("customHotkey")
                }
                .onChange(of: triggerMethod) { _, _ in
                    appState.applyTriggerMethod()
                    appState.hotKeyManager.register()
                }

                if triggerMethod == "fnKey" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hold the fn key to start dictating, release to stop.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            "Tip: Set fn key to \"Do Nothing\" in System Settings → Keyboard to avoid conflicts."
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                } else {
                    HStack {
                        Text("Dictation shortcut")
                        Spacer()
                        KeyRecorderView(
                            key: $hotkeyKey,
                            modifiers: $hotkeyModifiers
                        ) { newKey, newMods in
                            appState.hotKeyManager.updateShortcut(key: newKey, modifiers: newMods)
                            let display = hotkeyDisplayString(key: newKey, modifiers: newMods)
                            UserDefaults.standard.set(display, forKey: "hotkeyDisplay")
                        }
                    }
                    Text("Click the field, then press your desired key combination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Mode") {
                Picker("Dictation mode", selection: $dictationMode) {
                    Text("Hold to talk").tag("holdToTalk")
                    Text("Toggle (press to start/stop)").tag("toggle")
                }
                .onChange(of: dictationMode) { _, _ in
                    appState.applyDictationMode()
                }
            }

            Section("Silence Detection") {
                Toggle("Auto-stop on silence", isOn: $autoStopOnSilence)
                if autoStopOnSilence {
                    HStack {
                        Text("Silence timeout")
                        Slider(value: $silenceTimeout, in: 1...5, step: 0.5)
                        Text(String(format: "%.1fs", silenceTimeout))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 30)
                    }
                    .onChange(of: silenceTimeout) { _, newValue in
                        appState.audioCapture.updateSilenceSettings(
                            threshold: 0.01, duration: newValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear(perform: loadPersistedHotkey)
    }

    /// Reflect the saved custom shortcut in the recorder field (it's plain @State that would
    /// otherwise reset to the default ⌘⌥D every time Settings is opened).
    private func loadPersistedHotkey() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "hotkeyKeyCode") != nil else { return }
        if let key = Key(carbonKeyCode: UInt32(defaults.integer(forKey: "hotkeyKeyCode"))) {
            hotkeyKey = key
        }
        hotkeyModifiers = NSEvent.ModifierFlags(
            rawValue: UInt(defaults.integer(forKey: "hotkeyModifierFlags")))
    }

    private var modelTab: some View {
        Form {
            Section("Whisper Model") {
                Picker("Model", selection: $selectedModel) {
                    Text("Tiny (~75MB, fastest)").tag("tiny")
                    Text("Base (~150MB, balanced)").tag("base")
                    Text("Small (~470MB, better)").tag("small")
                    Text("Large V3 (~800MB, best)").tag("large-v3")
                }
                .onChange(of: selectedModel) { _, _ in
                    appState.reloadModel()
                }

                Text(
                    "Larger models are more accurate but use more memory and take longer to transcribe."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if appState.isModelLoaded {
                    Label("Model loaded", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading model…")
                            .font(.caption)
                    }
                }
            }

            Section("Language") {
                Picker("Primary language", selection: $language) {
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Italian").tag("it")
                    Text("Portuguese").tag("pt")
                    Text("Japanese").tag("ja")
                    Text("Chinese").tag("zh")
                    Text("Korean").tag("ko")
                    Text("Hindi").tag("hi")
                    Text("Auto-detect").tag("auto")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Listen")
                .font(.title)
                .fontWeight(.bold)

            Text("Local-first voice dictation")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Text(
                "All transcription happens on-device.\nNo cloud. No subscription. No data leaves your Mac."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - AI / LLM Tab

    private var aiTab: some View {
        Form {
            Section("AI Provider") {
                Picker("Backend", selection: $llmBackend) {
                    Text("OpenAI").tag("openai")
                    Text("Ollama (Local)").tag("ollama")
                    Text("Disabled").tag("none")
                }
                .onChange(of: llmBackend) { _, _ in
                    llmTestResult = nil
                    appState.updateLLMConfig()
                    Task { availableLLMModels = await appState.llmService.availableModels() }
                }
            }

            if llmBackend == "openai" {
                Section("OpenAI Configuration") {
                    HStack {
                        if isAPIKeyVisible {
                            TextField("API Key", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("API Key", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button {
                            isAPIKeyVisible.toggle()
                        } label: {
                            Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        Button("Save") {
                            LLMService.saveAPIKey(openAIKey, forBackend: .openai)
                            appState.updateLLMConfig()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Text("Your API key is stored securely in the macOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Model", text: $openAIModel)
                            .textFieldStyle(.roundedBorder)
                        Button("Refresh") {
                            Task {
                                availableLLMModels = await appState.llmService.availableModels()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .onChange(of: openAIModel) { _, _ in appState.updateLLMConfig() }

                    if !availableLLMModels.isEmpty {
                        Picker("Available Models", selection: $openAIModel) {
                            ForEach(availableLLMModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }

                    TextField("Base URL", text: $openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: openAIBaseURL) { _, _ in appState.updateLLMConfig() }
                    Text("Change this to use OpenAI-compatible APIs (e.g. Azure, Together, Groq).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if llmBackend == "ollama" {
                Section("Ollama Configuration") {
                    TextField("Host URL", text: $ollamaHost)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: ollamaHost) { _, _ in appState.updateLLMConfig() }

                    HStack {
                        TextField("Model", text: $ollamaModel)
                            .textFieldStyle(.roundedBorder)
                        Button("Refresh") {
                            Task {
                                availableLLMModels = await appState.llmService.availableModels()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .onChange(of: ollamaModel) { _, _ in appState.updateLLMConfig() }

                    if !availableLLMModels.isEmpty {
                        Picker("Available Models", selection: $ollamaModel) {
                            ForEach(availableLLMModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                }
            }

            Section("Status") {
                HStack {
                    Circle()
                        .fill(appState.isLLMAvailable ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(appState.isLLMAvailable ? "Connected" : "Not available")
                        .font(.callout)
                    Spacer()
                    Button("Test Connection") { testLLMConnection() }
                        .disabled(isTestingLLM || llmBackend == "none")
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                if isTestingLLM {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Testing…").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let result = llmTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("✓") ? .green : .red)
                }
            }

            Section("What AI Enhance Does") {
                VStack(alignment: .leading, spacing: 8) {
                    featureRow(
                        icon: "sparkles",
                        text: "Voice commands: \"make this shorter\", \"make it professional\"")
                    featureRow(
                        icon: "text.badge.checkmark", text: "Auto grammar & spelling correction")
                    featureRow(icon: "paintbrush", text: "Context-aware formatting per app")
                    featureRow(icon: "arrow.triangle.branch", text: "Rewrite in different tones")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            openAIKey = LLMService.loadAPIKey(forBackend: .openai) ?? ""
            appState.refreshLLMStatus()
            Task { availableLLMModels = await appState.llmService.availableModels() }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func testLLMConnection() {
        isTestingLLM = true
        llmTestResult = nil
        Task {
            let available = await appState.llmService.isAvailable()
            if available {
                do {
                    let response = try await appState.llmService.generate(
                        prompt: "Say hello in exactly 3 words.",
                        system: "You are a helpful assistant. Be very brief."
                    )
                    llmTestResult = "✓ Connected — Response: \(String(response.prefix(50)))"
                } catch {
                    llmTestResult =
                        "✗ Connected but generation failed: \(error.localizedDescription)"
                }
            } else {
                let backendName = llmBackend == "openai" ? "OpenAI API" : "Ollama at \(ollamaHost)"
                llmTestResult = "✗ Cannot reach \(backendName)"
            }
            isTestingLLM = false
        }
    }

    // MARK: - Export / Import

    private func exportData() {
        showExportSuccess = false
        importError = nil
        let snippets = (try? modelContext.fetch(FetchDescriptor<Snippet>())) ?? []
        let words = (try? modelContext.fetch(FetchDescriptor<CustomWord>())) ?? []
        let entries = (try? modelContext.fetch(FetchDescriptor<DictationEntry>())) ?? []

        let data = ExportData(
            snippets: snippets.map {
                SnippetDTO(trigger: $0.trigger, expansion: $0.expansion, category: $0.category)
            },
            customWords: words.map {
                CustomWordDTO(
                    word: $0.word, pronunciationHint: $0.pronunciationHint, category: $0.category)
            },
            dictationHistory: entries.map {
                DictationEntryDTO(
                    text: $0.text, rawText: $0.rawText, timestamp: $0.timestamp,
                    duration: $0.duration, appName: $0.appName, styleName: $0.styleName,
                    language: $0.language)
            }
        )

        let service = ExportImportService()
        guard let jsonData = try? service.exportToJSON(data) else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "listen-data.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? jsonData.write(to: url)
                showExportSuccess = true
            }
        }
    }

    private func importData() {
        showImportSuccess = false
        importError = nil

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let jsonData = try Data(contentsOf: url)
                let service = ExportImportService()
                let exported = try service.importFromJSON(jsonData)

                for dto in exported.snippets {
                    let snippet = Snippet(
                        trigger: dto.trigger, expansion: dto.expansion, category: dto.category)
                    modelContext.insert(snippet)
                }
                for dto in exported.customWords {
                    let word = CustomWord(
                        word: dto.word, pronunciationHint: dto.pronunciationHint,
                        category: dto.category)
                    modelContext.insert(word)
                }
                for dto in exported.dictationHistory {
                    let entry = DictationEntry(
                        text: dto.text, rawText: dto.rawText, duration: dto.duration,
                        appName: dto.appName, styleName: dto.styleName, language: dto.language)
                    modelContext.insert(entry)
                }
                try? modelContext.save()
                showImportSuccess = true
            } catch {
                importError = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}
