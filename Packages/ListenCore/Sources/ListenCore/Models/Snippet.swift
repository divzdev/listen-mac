import Foundation
import SwiftData

/// A text snippet that expands a short trigger into a longer phrase.
/// Example: trigger "/sig" → expansion "Best regards,\nDivyam"
@Model
public final class Snippet {
    @Attribute(.unique) public var id: UUID
    /// Short text the user types to trigger expansion (e.g. "/sig").
    public var trigger: String
    /// Full text that replaces the trigger.
    public var expansion: String
    /// Optional category for organization.
    public var category: String
    public var createdAt: Date

    public init(trigger: String, expansion: String, category: String = "General") {
        self.id = UUID()
        self.trigger = trigger
        self.expansion = expansion
        self.category = category
        self.createdAt = Date()
    }
}
