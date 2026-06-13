import Foundation
import SwiftData

/// A single dictation transcript entry stored in history.
@Model
public final class DictationEntry {
    @Attribute(.unique) public var id: UUID
    /// Cleaned/formatted text that was inserted.
    public var text: String
    /// Raw transcript before cleanup.
    public var rawText: String
    public var timestamp: Date
    /// Duration of the audio recording in seconds.
    public var duration: Double
    /// Bundle identifier of the app that was focused during dictation.
    public var appBundleID: String?
    /// Display name of the app that was focused.
    public var appName: String?
    /// Style preset name used for formatting.
    public var styleName: String?
    /// Language code (e.g. "en", "es").
    public var language: String
    public var isFavorite: Bool = false
    /// Pinned entries surface above the date-grouped history and survive bulk clears.
    /// Default value lets SwiftData migrate existing stores automatically.
    public var isPinned: Bool = false

    public init(
        text: String,
        rawText: String,
        duration: Double,
        appBundleID: String? = nil,
        appName: String? = nil,
        styleName: String? = nil,
        language: String = "en"
    ) {
        self.id = UUID()
        self.text = text
        self.rawText = rawText
        self.timestamp = Date()
        self.duration = duration
        self.appBundleID = appBundleID
        self.appName = appName
        self.styleName = styleName
        self.language = language
        self.isFavorite = false
    }
}
