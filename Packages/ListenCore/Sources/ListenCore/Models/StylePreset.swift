import Foundation
import SwiftData

/// A named text style preset that controls how raw transcripts are formatted.
@Model
public final class StylePreset {
    @Attribute(.unique) public var id: UUID
    public var name: String
    /// Whether to remove filler words (um, uh, like).
    public var removeFillers: Bool
    /// Whether to make language more formal.
    public var formalize: Bool
    /// Whether to apply concise rewriting (shorten verbose phrases).
    public var concise: Bool
    /// Whether to add email-style greeting/closing.
    public var emailFormat: Bool
    /// Whether this is a built-in preset (not deletable).
    public var isBuiltIn: Bool
    public var createdAt: Date

    public init(
        name: String,
        removeFillers: Bool = true,
        formalize: Bool = false,
        concise: Bool = false,
        emailFormat: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.removeFillers = removeFillers
        self.formalize = formalize
        self.concise = concise
        self.emailFormat = emailFormat
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
    }

    /// The three built-in style presets.
    public static func builtInPresets() -> [StylePreset] {
        [
            StylePreset(name: "Casual", removeFillers: false, formalize: false, concise: false, emailFormat: false, isBuiltIn: true),
            StylePreset(name: "Work", removeFillers: true, formalize: true, concise: true, emailFormat: false, isBuiltIn: true),
            StylePreset(name: "Email", removeFillers: true, formalize: true, concise: false, emailFormat: true, isBuiltIn: true),
        ]
    }
}
