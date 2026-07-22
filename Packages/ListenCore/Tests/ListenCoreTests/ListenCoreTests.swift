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

// MARK: - LLM Output Contract Tests

@Suite("LLMOutputContract")
struct LLMOutputContractTests {
    typealias Invariant = LLMService.OutputInvariant

    func validate(_ raw: String, input: String, _ invariant: Invariant = .preservesContent)
        throws -> String
    {
        try LLMService.validated(raw, input: input, invariant: invariant)
    }

    // MARK: Extraction by markers (structural — replaces all preamble/postamble patterns)

    @Test func extractsTextBetweenMarkers() throws {
        let result = try validate(
            "<output>Hello world, this is fine.</output>",
            input: "hello world this is fine")
        #expect(result == "Hello world, this is fine.")
    }

    @Test func preambleOutsideMarkersIsDiscarded() throws {
        // The historical "Here is the corrected version:" incident — now dropped by
        // construction because it's outside the markers, not by a regex that knows the phrase.
        let result = try validate(
            "Here is the corrected version:\n<output>Hello world, this is correct.</output>",
            input: "hello world this is correct")
        #expect(result == "Hello world, this is correct.")
    }

    @Test func postambleOutsideMarkersIsDiscarded() throws {
        let result = try validate(
            "<output>Hello world, this is correct.</output>\nI made the following changes:\n- Fixed spelling",
            input: "helo world this is correct")
        #expect(result == "Hello world, this is correct.")
    }

    @Test func missingMarkersIsRejected() {
        #expect(throws: LLMService.LLMError.self) {
            _ = try validate("Hello world.", input: "hello world")
        }
    }

    @Test func emptyOutputIsRejected() {
        #expect(throws: LLMService.LLMError.self) {
            _ = try validate("<output>  </output>", input: "hello world")
        }
    }

    // MARK: Content-preservation invariant (structural — replaces meta-phrase denylists)

    @Test func metaCommentaryInsteadOfTextIsRejected() {
        // Historical incident: grammar pass returned commentary, not the corrected text. The
        // invariant rejects it because none of the input's words survive — no phrase list.
        #expect(throws: LLMService.LLMError.self) {
            _ = try validate(
                "<output>There is no error to fix in this sentence. It appears to be an expression of exasperation.</output>",
                input: "ugh")
        }
    }

    @Test func alreadyCorrectCommentaryIsRejected() {
        #expect(throws: LLMService.LLMError.self) {
            _ = try validate(
                "<output>The text is already grammatically correct. No changes needed.</output>",
                input: "Hello world.")
        }
    }

    @Test func answeringAQuestionInsteadOfFormattingIsRejected() {
        // Real incident: user dictated a short question; the 8B model replied with paragraphs
        // of invented fiction about an internet outage.
        let hallucination =
            "<output>I'm experiencing some issues with my internet connection right now. It's been really slow all morning and I've tried restarting my router but it's still not working properly. Firstly, the speed test that I ran earlier showed a download speed of only 2 megabits per second. Secondly, when I try to load websites they freeze on me. Thirdly, my email client is taking ages to sync.</output>"
        #expect(throws: LLMService.LLMError.self) {
            _ = try validate(hallucination, input: "why are you so slow")
        }
    }

    @Test func totalRewriteIsRejected() {
        #expect(throws: LLMService.LLMError.self) {
            _ = try validate(
                "<output>The weather is lovely today and the birds are singing.</output>",
                input: "remind me to call mom tomorrow afternoon")
        }
    }

    @Test func honestReformattingIsAccepted() throws {
        let result = try validate(
            "<output>I need three things from the store:\n1. Milk\n2. Eggs\n3. Bread</output>",
            input: "i need three things from the store first milk second eggs third bread")
        #expect(result.contains("1. Milk"))
    }

    @Test func fillerRemovalIsAccepted() throws {
        let result = try validate(
            "<output>I think we should ship the feature tomorrow.</output>",
            input: "um so like I think we should you know ship the feature tomorrow")
        #expect(result == "I think we should ship the feature tomorrow.")
    }

    @Test func legitimateCorrectionThatMentionsCorrectIsAccepted() throws {
        // A sentence containing the word "correct" must not be mistaken for commentary —
        // the old phrase-denylist approach was vulnerable to exactly this false positive.
        let result = try validate(
            "<output>I need to correct this document before the deadline.</output>",
            input: "i need to correct this document before the deadline")
        #expect(result == "I need to correct this document before the deadline.")
    }

    // MARK: Transform invariant (rewrites may change words — only the contract is checked)

    @Test func summarizeMayShortenAndReword() throws {
        let result = try validate(
            "<output>Call mom tomorrow.</output>",
            input: "so I was thinking that at some point tomorrow I really need to remember to call my mother",
            .transforms)
        #expect(result == "Call mom tomorrow.")
    }
}

// MARK: - DictationFormatter (rule-based smart formatting)

@Suite("DictationFormatter")
struct DictationFormatterTests {
    let formatter = DictationFormatter()

    @Test func ordinalEnumeration_becomesNumberedList() {
        let result = formatter.format("first milk second eggs third bread")
        #expect(result == "1. Milk\n2. Eggs\n3. Bread")
    }

    @Test func enumerationWithLeadIn_keepsLeadInAsHeader() {
        let result = formatter.format(
            "I need three things from the store first milk second eggs and third bread")
        #expect(result == "I need three things from the store:\n1. Milk\n2. Eggs\n3. Bread")
    }

    @Test func numberWordEnumeration_becomesNumberedList() {
        let result = formatter.format("number one design number two build number three ship")
        #expect(result == "1. Design\n2. Build\n3. Ship")
    }

    @Test func singleOrdinal_isNotTreatedAsList() {
        // "first" appearing once in normal prose must not trigger a list.
        let result = formatter.format("first of all I want to say thank you")
        #expect(!result.contains("\n"))
    }

    @Test func outOfOrderOrdinals_doNotFormAList() {
        // Only a sequence starting at 1 and counting up should form a list.
        let result = formatter.format("the third option is best")
        #expect(!result.contains("1."))
    }

    @Test func plainProse_isTidiedNotListed() {
        let result = formatter.format("this is just a normal sentence")
        #expect(result == "This is just a normal sentence")
    }

    @Test func empty_returnsEmpty() {
        #expect(formatter.format("") == "")
    }
}
