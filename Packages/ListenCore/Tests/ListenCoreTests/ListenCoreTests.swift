import Foundation
import Testing

@testable import ListenCore

// MARK: - TextCleanupPipeline Tests

@Suite("TextCleanupPipeline")
struct TextCleanupPipelineTests {
    let pipeline = TextCleanupPipeline()

    @Test func normalizeWhitespace_collapsesMultipleSpaces() {
        let result = pipeline.normalizeWhitespace("hello   world")
        #expect(result == "hello world")
    }

    @Test func normalizeWhitespace_collapsesTripleNewlines() {
        let result = pipeline.normalizeWhitespace("hello\n\n\nworld")
        #expect(result == "hello\n\nworld")
    }

    @Test func removeFillerWords_removesUm() {
        let result = pipeline.removeFillerWords("I um want to go")
        #expect(!result.contains("um"))
    }

    @Test func removeFillerWords_removesUh() {
        let result = pipeline.removeFillerWords("So uh I think so")
        #expect(!result.contains("uh"))
    }

    @Test func removeFillerWords_removesYouKnow() {
        let result = pipeline.removeFillerWords("It was you know really good")
        #expect(!result.contains("you know"))
    }

    @Test func capitalizeSentences_capitalizesFirstLetter() {
        let result = pipeline.capitalizeSentences("hello world")
        #expect(result == "Hello world")
    }

    @Test func capitalizeSentences_capitalizesAfterPeriod() {
        let result = pipeline.capitalizeSentences("hello. world")
        #expect(result == "Hello. World")
    }

    @Test func capitalizeSentences_capitalizesAfterQuestionMark() {
        let result = pipeline.capitalizeSentences("how? good")
        #expect(result == "How? Good")
    }

    @Test func capitalizeSentences_emptyString() {
        let result = pipeline.capitalizeSentences("")
        #expect(result == "")
    }

    @Test func fixPunctuation_removesSpaceBeforePeriod() {
        let result = pipeline.fixPunctuation("hello .")
        #expect(result == "hello.")
    }

    @Test func fixPunctuation_removesSpaceBeforeComma() {
        let result = pipeline.fixPunctuation("hello , world")
        #expect(result.contains("hello,"))
    }

    @Test func fixPunctuation_addsTerminalPeriod() {
        let result = pipeline.fixPunctuation("hello world")
        #expect(result.hasSuffix("."))
    }

    @Test func fixPunctuation_doesNotDoubleTerminalPeriod() {
        let result = pipeline.fixPunctuation("hello world.")
        #expect(result == "hello world.")
    }

    @Test func fixPunctuation_removesTrailingComma() {
        let result = pipeline.fixPunctuation("hello world,")
        #expect(!result.hasSuffix(","))
    }

    @Test func formatNumbers_replacesSpokenNumbers() {
        let result = pipeline.formatNumbers("I have three cats")
        #expect(result.contains("3"))
    }

    @Test func formatNumbers_replacesTen() {
        let result = pipeline.formatNumbers("Give me ten minutes")
        #expect(result.contains("10"))
    }

    @Test func cleanFullPipeline_endToEnd() {
        let result = pipeline.clean("  hello   um  world  ")
        #expect(!result.contains("  "))
        #expect(!result.lowercased().contains("um"))
        #expect(result.first?.isUppercase == true)
    }
}

// MARK: - CommandParser Tests

@Suite("CommandParser")
struct CommandParserTests {
    let parser = CommandParser()

    @Test func process_newParagraph() {
        let result = parser.process("hello new paragraph world")
        #expect(result.contains("\n\n"))
    }

    @Test func process_newLine() {
        let result = parser.process("hello new line world")
        #expect(result.contains("\n"))
    }

    @Test func process_period() {
        let result = parser.process("hello period")
        #expect(result.contains("."))
        #expect(!result.lowercased().contains("period"))
    }

    @Test func process_comma() {
        let result = parser.process("hello comma world")
        #expect(result.contains(","))
        #expect(!result.lowercased().contains("comma"))
    }

    @Test func process_questionMark() {
        let result = parser.process("how are you question mark")
        #expect(result.contains("?"))
    }

    @Test func process_exclamationMark() {
        let result = parser.process("wow exclamation mark")
        #expect(result.contains("!"))
    }

    @Test func process_openCloseQuote() {
        let result = parser.process("he said open quote hello close quote")
        #expect(result.contains("\""))
    }

    @Test func process_dash() {
        let result = parser.process("this dash and that")
        #expect(result.contains("—"))
    }

    @Test func detectRewriteCommand_makeShorter() {
        let result = parser.detectRewriteCommand("make this shorter")
        #expect(result == .makeShorter)
    }

    @Test func detectRewriteCommand_makeProfessional() {
        let result = parser.detectRewriteCommand("make this more professional")
        #expect(result == .makeProfessional)
    }

    @Test func detectRewriteCommand_bulletPoints() {
        let result = parser.detectRewriteCommand("turn into bullet points")
        #expect(result == .bulletPoints)
    }

    @Test func detectRewriteCommand_summarize() {
        let result = parser.detectRewriteCommand("summarize this")
        #expect(result == .summarize)
    }

    @Test func detectRewriteCommand_noCommand() {
        let result = parser.detectRewriteCommand("just some regular text")
        #expect(result == nil)
    }
}

// MARK: - StyleFormatter Tests

@Suite("StyleFormatter")
struct StyleFormatterTests {
    let formatter = StyleFormatter()

    @Test func formatWithBuiltInStyle_casual() {
        let result = formatter.formatWithBuiltInStyle("Hello, this is a test.", styleName: "Casual")
        #expect(!result.isEmpty)
    }

    @Test func formatWithBuiltInStyle_work() {
        let result = formatter.formatWithBuiltInStyle("I can't do it.", styleName: "Work")
        // Work style formalizes: can't → cannot
        #expect(result.contains("cannot"))
    }

    @Test func formatWithBuiltInStyle_email() {
        let result = formatter.formatWithBuiltInStyle("Please send the files.", styleName: "Email")
        // Email wraps in email format
        #expect(result.contains("Hi"))
    }

    @Test func formatWithBuiltInStyle_unknownStyle() {
        let input = "Hello world."
        let result = formatter.formatWithBuiltInStyle(input, styleName: "NonExistent")
        #expect(result == input)
    }

    @Test func format_removeFillers() {
        let style = StylePreset(name: "Test", removeFillers: true)
        let result = formatter.format("I um think so", style: style)
        #expect(!result.contains("um"))
    }

    @Test func format_formalize() {
        let style = StylePreset(name: "Test", formalize: true)
        let result = formatter.format("I can't go", style: style)
        #expect(result.contains("cannot"))
    }

    @Test func format_concise() {
        let style = StylePreset(name: "Test", concise: true)
        let result = formatter.format("in order to help", style: style)
        #expect(result.contains("to"))
        #expect(!result.contains("in order to"))
    }
}

// MARK: - SnippetExpander Tests

@Suite("SnippetExpander")
struct SnippetExpanderTests {
    let expander = SnippetExpander()

    @Test func expand_replaceTrigger() {
        let snippets = [Snippet(trigger: "/sig", expansion: "Best regards,\nDivyam")]
        let result = expander.expand("Thanks /sig", using: snippets)
        #expect(result.contains("Best regards"))
        #expect(!result.contains("/sig"))
    }

    @Test func expand_multipleTriggers() {
        let snippets = [
            Snippet(trigger: "/hi", expansion: "Hello there!"),
            Snippet(trigger: "/bye", expansion: "Goodbye!"),
        ]
        let result = expander.expand("/hi and /bye", using: snippets)
        #expect(result.contains("Hello there!"))
        #expect(result.contains("Goodbye!"))
    }

    @Test func expand_emptySnippets() {
        let result = expander.expand("some text /sig", using: [])
        #expect(result == "some text /sig")
    }

    @Test func expand_noMatch() {
        let snippets = [Snippet(trigger: "/sig", expansion: "Best")]
        let result = expander.expand("just text", using: snippets)
        #expect(result == "just text")
    }

    @Test func expand_longerTriggerMatchedFirst() {
        let snippets = [
            Snippet(trigger: "/s", expansion: "Short"),
            Snippet(trigger: "/sig", expansion: "Signature"),
        ]
        let result = expander.expand("use /sig here", using: snippets)
        #expect(result.contains("Signature"))
    }
}

// MARK: - ExportImportService Tests

@Suite("ExportImportService")
struct ExportImportServiceTests {
    let service = ExportImportService()

    @Test func roundTrip_emptyData() throws {
        let original = ExportData()
        let json = try service.exportToJSON(original)
        let imported = try service.importFromJSON(json)
        #expect(imported.snippets.isEmpty)
        #expect(imported.customWords.isEmpty)
        #expect(imported.dictationHistory.isEmpty)
        #expect(imported.version == 1)
    }

    @Test func roundTrip_withSnippets() throws {
        var data = ExportData()
        data.snippets = [
            SnippetDTO(trigger: "/sig", expansion: "Best,\nMe", category: "General"),
            SnippetDTO(trigger: "/addr", expansion: "123 Main St", category: "Personal"),
        ]
        let json = try service.exportToJSON(data)
        let imported = try service.importFromJSON(json)
        #expect(imported.snippets.count == 2)
        #expect(imported.snippets[0].trigger == "/addr" || imported.snippets[1].trigger == "/addr")
    }

    @Test func roundTrip_withCustomWords() throws {
        var data = ExportData()
        data.customWords = [
            CustomWordDTO(word: "SwiftUI", pronunciationHint: nil, category: "Technical")
        ]
        let json = try service.exportToJSON(data)
        let imported = try service.importFromJSON(json)
        #expect(imported.customWords.count == 1)
        #expect(imported.customWords[0].word == "SwiftUI")
    }

    @Test func roundTrip_withHistory() throws {
        var data = ExportData()
        data.dictationHistory = [
            DictationEntryDTO(
                text: "Hello", rawText: "hello", timestamp: Date(), duration: 2.5, appName: "Notes",
                styleName: "Casual", language: "en")
        ]
        let json = try service.exportToJSON(data)
        let imported = try service.importFromJSON(json)
        #expect(imported.dictationHistory.count == 1)
        #expect(imported.dictationHistory[0].text == "Hello")
    }

    @Test func importInvalid_throws() throws {
        let bad = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            try service.importFromJSON(bad)
        }
    }
}

// MARK: - String+Cleanup Tests

@Suite("String+Cleanup")
struct StringCleanupTests {
    @Test func cleaned_normalizesWhitespace() {
        let result = "  hello   world  ".cleaned
        #expect(result == "hello world")
    }

    @Test func cleaned_normalizesNewlines() {
        let result = "hello\n\nworld".cleaned
        #expect(result == "hello world")
    }

    @Test func isBlank_emptyString() {
        #expect("".isBlank)
    }

    @Test func isBlank_whitespaceOnly() {
        #expect("   ".isBlank)
    }

    @Test func isBlank_normalString() {
        #expect(!"hello".isBlank)
    }
}

// MARK: - StylePreset Tests

@Suite("StylePreset")
struct StylePresetTests {
    @Test func builtInPresets_containsThree() {
        let presets = StylePreset.builtInPresets()
        #expect(presets.count == 3)
    }

    @Test func builtInPresets_hasExpectedNames() {
        let names = Set(StylePreset.builtInPresets().map(\.name))
        #expect(names.contains("Casual"))
        #expect(names.contains("Work"))
        #expect(names.contains("Email"))
    }

    @Test func builtInPresets_casualDoesNotFormalize() {
        let casual = StylePreset.builtInPresets().first { $0.name == "Casual" }!
        #expect(!casual.formalize)
        #expect(!casual.removeFillers)
    }

    @Test func builtInPresets_workFormalizesAndIsConcise() {
        let work = StylePreset.builtInPresets().first { $0.name == "Work" }!
        #expect(work.formalize)
        #expect(work.concise)
    }

    @Test func builtInPresets_emailHasEmailFormat() {
        let email = StylePreset.builtInPresets().first { $0.name == "Email" }!
        #expect(email.emailFormat)
    }
}

// MARK: - GrammarService Tests

@Suite("GrammarService")
struct GrammarServiceTests {
    let service = GrammarService()

    @Test func correct_fixesSubjectVerbAgreement() {
        let result = service.correct("I is going to the store")
        #expect(result.contains("I am"))
    }

    @Test func correct_fixesTheThe() {
        let result = service.correct("the the cat sat on the mat")
        #expect(!result.contains("the the"))
    }

    @Test func correct_fixesCommonMisspelling() {
        let result = service.correct("I recieve the package")
        #expect(result.contains("receive"))
    }

    @Test func correct_fixesArticleABeforeVowel() {
        let result = service.correct("a apple a day")
        #expect(result.contains("an apple"))
    }

    @Test func correct_fixesAnBeforeConsonant() {
        let result = service.correct("an dog ran away")
        #expect(result.contains("a dog"))
    }

    @Test func correct_fixesDoubleWords() {
        let result = service.correct("the cat cat sat")
        #expect(result == "the cat sat")
    }

    @Test func correct_preservesCorrectText() {
        let result = service.correct("The quick brown fox jumps over the lazy dog.")
        #expect(result == "The quick brown fox jumps over the lazy dog.")
    }

    @Test func detectLanguage_english() {
        let lang = service.detectLanguage("Hello, how are you doing today?")
        #expect(lang == "en")
    }

    @Test func detectLanguage_spanish() {
        let lang = service.detectLanguage("Hola, ¿cómo estás hoy?")
        #expect(lang == "es")
    }
}

// MARK: - MarkdownExporter Tests

@Suite("MarkdownExporter")
struct MarkdownExporterTests {
    let exporter = MarkdownExporter()

    @Test func exportEntry_containsText() {
        let dto = DictationEntryDTO(
            text: "Hello world", rawText: "hello world",
            timestamp: Date(), duration: 2.5,
            appName: "Safari", styleName: "Casual", language: "en"
        )
        let md = exporter.exportEntry(dto)
        #expect(md.contains("Hello world"))
        #expect(md.contains("hello world"))
        #expect(md.contains("Safari"))
        #expect(md.contains("2.5s"))
    }

    @Test func exportAll_containsHeader() {
        let dtos = [
            DictationEntryDTO(
                text: "First", rawText: "first", timestamp: Date(),
                duration: 1.0, appName: nil, styleName: nil, language: "en"
            ),
            DictationEntryDTO(
                text: "Second", rawText: "second", timestamp: Date(),
                duration: 2.0, appName: nil, styleName: nil, language: "en"
            ),
        ]
        let md = exporter.exportAll(dtos)
        #expect(md.contains("# Listen — Dictation History"))
        #expect(md.contains("Total entries: 2"))
        #expect(md.contains("First"))
        #expect(md.contains("Second"))
    }

    @Test func exportEntry_containsMetadata() {
        let dto = DictationEntryDTO(
            text: "Test", rawText: "test",
            timestamp: Date(), duration: 3.0,
            appName: "Notes", styleName: "Work", language: "en"
        )
        let md = exporter.exportEntry(dto)
        #expect(md.contains("| Application | Notes |"))
        #expect(md.contains("| Style | Work |"))
        #expect(md.contains("| Language | en |"))
    }
}

// MARK: - LLMService Tests

@Suite("LLMService")
struct LLMServiceTests {
    @Test func backend_displayNames() {
        #expect(LLMService.Backend.ollama.displayName == "Ollama (Local)")
        #expect(LLMService.Backend.none.displayName == "Disabled")
    }

    @Test func disabledBackend_isNotAvailable() async {
        let service = LLMService(backend: .none)
        let available = await service.isAvailable()
        #expect(!available)
    }

    @Test func disabledBackend_generateThrows() async {
        let service = LLMService(backend: .none)
        do {
            _ = try await service.generate(prompt: "test")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is LLMService.LLMError)
        }
    }

    @Test func rewriteCommand_allCasesExist() {
        #expect(RewriteCommand.allCases.count == 5)
    }

    @Test func rewriteCommand_displayNames() {
        #expect(RewriteCommand.makeShorter.displayName == "Make Shorter")
        #expect(RewriteCommand.makeProfessional.displayName == "Make Professional")
        #expect(RewriteCommand.makeCasual.displayName == "Make Casual")
        #expect(RewriteCommand.bulletPoints.displayName == "Bullet Points")
        #expect(RewriteCommand.summarize.displayName == "Summarize")
    }
}

// MARK: - LLM Response Cleaning Tests

@Suite("LLMResponseCleaning")
struct LLMResponseCleaningTests {
    let service = LLMService(backend: .none)

    @Test func cleanText_passesThrough() async {
        let result = await service.cleanLLMResponse(
            "Hello world, this is fine.",
            originalText: "hello world this is fine"
        )
        #expect(result == "Hello world, this is fine.")
    }

    @Test func stripsPreamble_hereIsTheCorrectedVersion() async {
        let result = await service.cleanLLMResponse(
            "Here is the corrected version:\n\nHello world, this is correct.",
            originalText: "hello world this is correct"
        )
        #expect(result == "Hello world, this is correct.")
    }

    @Test func stripsPreamble_hereIsTheRewrittenText() async {
        let result = await service.cleanLLMResponse(
            "Here's the rewritten text:\n\nHello world.",
            originalText: "hello world"
        )
        #expect(result == "Hello world.")
    }

    @Test func stripsPreamble_correctedVersion() async {
        let result = await service.cleanLLMResponse(
            "Corrected version:\nHello world.",
            originalText: "hello world"
        )
        #expect(result == "Hello world.")
    }

    @Test func stripsPreamble_sure() async {
        let result = await service.cleanLLMResponse(
            "Sure! Here's the corrected text:\n\nHello world.",
            originalText: "hello world"
        )
        #expect(result == "Hello world.")
    }

    @Test func stripsPostamble_changesList() async {
        let result = await service.cleanLLMResponse(
            "Hello world, this is correct.\n\nI made the following changes:\n- Changed \"helo\" to \"hello\"\n- Added comma",
            originalText: "helo world this is correct"
        )
        #expect(result == "Hello world, this is correct.")
    }

    @Test func stripsPostamble_changesApplied() async {
        let result = await service.cleanLLMResponse(
            "Hello world.\n\nChanges:\n- Fixed spelling",
            originalText: "helo world"
        )
        #expect(result == "Hello world.")
    }

    @Test func stripsBothPreambleAndPostamble() async {
        let result = await service.cleanLLMResponse(
            "Here is the corrected version:\n\nHello world.\n\nI made the following changes:\n- Fixed grammar",
            originalText: "hello world"
        )
        #expect(result == "Hello world.")
    }

    @Test func removesWrappingQuotes() async {
        let result = await service.cleanLLMResponse(
            "\"Hello world, this is correct.\"",
            originalText: "hello world this is correct"
        )
        #expect(result == "Hello world, this is correct.")
    }

    @Test func preservesQuotesWhenOriginalHadThem() async {
        let result = await service.cleanLLMResponse(
            "\"Hello world\"",
            originalText: "\"hello world\""
        )
        #expect(result == "\"Hello world\"")
    }

    @Test func stripsPreamble_caseInsensitive() async {
        let result = await service.cleanLLMResponse(
            "HERE IS THE CORRECTED TEXT:\n\nHello world.",
            originalText: "hello world"
        )
        #expect(result == "Hello world.")
    }

    @Test func stripsPreamble_certainly() async {
        let result = await service.cleanLLMResponse(
            "Certainly! Here is the rewritten text:\n\nHello world.",
            originalText: "hello world"
        )
        #expect(result == "Hello world.")
    }

    @Test func stripsPreamble_exactUserReportedIssue() async {
        // Exact LLM output a user reported — "Here is the corrected text:" preamble
        let llmOutput =
            "Here is the corrected text:\n\nI want to release this as an open-source version for the public, just a Mac version. I want to create a repository on GitHub and then push it. So, how do I do that?"
        let original =
            "I want to release this as an open-source version for the public, just a Mac version. I want to create a repository on GitHub and then push it. So, how do I do that?"
        let result = await service.cleanLLMResponse(llmOutput, originalText: original)
        #expect(result == original)
    }

    // MARK: - Meta-commentary detection

    @Test func metaCommentary_noErrorToFix() async {
        // Exact response user reported when recording silence
        let llmOutput =
            "There is no error to fix in this sentence. It appears to be an expression of exasperation or frustration, which can be grammatically correct as a standalone utterance."
        let original = "ugh"
        let result = await service.cleanLLMResponse(llmOutput, originalText: original)
        #expect(result == original)
    }

    @Test func metaCommentary_alreadyCorrect() async {
        let llmOutput = "The text is already grammatically correct. No changes needed."
        let original = "Hello world."
        let result = await service.cleanLLMResponse(llmOutput, originalText: original)
        #expect(result == original)
    }

    @Test func metaCommentary_noCorrectionsNeeded() async {
        let llmOutput = "No corrections needed. The sentence is correct as written."
        let original = "I went to the store."
        let result = await service.cleanLLMResponse(llmOutput, originalText: original)
        #expect(result == original)
    }

    @Test func metaCommentary_nothingToFix() async {
        let llmOutput = "There are no errors found in this text. It is grammatically correct."
        let original = "The quick brown fox jumps over the lazy dog."
        let result = await service.cleanLLMResponse(llmOutput, originalText: original)
        #expect(result == original)
    }

    @Test func metaCommentary_doesNotFalsePositive() async {
        // A legitimate corrected sentence that happens to contain the word "correct"
        let llmOutput = "I need to correct this document before the deadline."
        let original = "i need to correct this document before the deadline"
        let result = await service.cleanLLMResponse(llmOutput, originalText: original)
        #expect(result == "I need to correct this document before the deadline.")
    }

    @Test func isMetaCommentary_detectsExplanation() async {
        let result = await service.isMetaCommentary(
            "There is no error to fix in this sentence.",
            originalText: "hello"
        )
        #expect(result == true)
    }

    @Test func isMetaCommentary_normalTextIsNot() async {
        let result = await service.isMetaCommentary(
            "Hello, how are you?",
            originalText: "hello how are you"
        )
        #expect(result == false)
    }
}
