import Foundation
import SwiftData

/// A single scratchpad note for drafting and refining text.
@Model
public final class ScratchpadNote {
    @Attribute(.unique) public var id: UUID
    /// The note content.
    public var content: String
    /// Optional title (first line or user-set).
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
