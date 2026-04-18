import Foundation

/// Codable transfer objects for export/import of user data.
/// These are separate from SwiftData models to keep serialization clean.

public struct ExportData: Codable {
    public var version: Int = 1
    public var exportDate: Date
    public var snippets: [SnippetDTO]
    public var customWords: [CustomWordDTO]
    public var dictationHistory: [DictationEntryDTO]

    public init(
        snippets: [SnippetDTO] = [], customWords: [CustomWordDTO] = [],
        dictationHistory: [DictationEntryDTO] = []
    ) {
        self.exportDate = Date()
        self.snippets = snippets
        self.customWords = customWords
        self.dictationHistory = dictationHistory
    }
}

public struct SnippetDTO: Codable {
    public var trigger: String
    public var expansion: String
    public var category: String

    public init(trigger: String, expansion: String, category: String) {
        self.trigger = trigger
        self.expansion = expansion
        self.category = category
    }
}

public struct CustomWordDTO: Codable {
    public var word: String
    public var pronunciationHint: String?
    public var category: String

    public init(word: String, pronunciationHint: String?, category: String) {
        self.word = word
        self.pronunciationHint = pronunciationHint
        self.category = category
    }
}

public struct DictationEntryDTO: Codable {
    public var text: String
    public var rawText: String
    public var timestamp: Date
    public var duration: Double
    public var appName: String?
    public var styleName: String?
    public var language: String

    public init(
        text: String, rawText: String, timestamp: Date, duration: Double, appName: String?,
        styleName: String?, language: String
    ) {
        self.text = text
        self.rawText = rawText
        self.timestamp = timestamp
        self.duration = duration
        self.appName = appName
        self.styleName = styleName
        self.language = language
    }
}

/// Service for exporting and importing user data as JSON.
public struct ExportImportService {
    public init() {}

    /// Encode export data to pretty-printed JSON Data.
    public func exportToJSON(_ data: ExportData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }

    /// Decode import data from JSON Data.
    public func importFromJSON(_ jsonData: Data) throws -> ExportData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportData.self, from: jsonData)
    }
}
