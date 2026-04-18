import Foundation
import SwiftData

/// A custom word added to the user's personal dictionary.
/// Helps the transcription engine recognize names, jargon, etc.
@Model
public final class CustomWord {
    @Attribute(.unique) public var id: UUID
    /// The word or phrase to recognize.
    public var word: String
    /// Optional pronunciation hint for the speech engine.
    public var pronunciationHint: String?
    /// Category for grouping (e.g. "Names", "Technical").
    public var category: String
    public var createdAt: Date

    public init(word: String, pronunciationHint: String? = nil, category: String = "General") {
        self.id = UUID()
        self.word = word
        self.pronunciationHint = pronunciationHint
        self.category = category
        self.createdAt = Date()
    }
}
