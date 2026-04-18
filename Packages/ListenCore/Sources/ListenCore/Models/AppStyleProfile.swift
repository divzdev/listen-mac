import Foundation
import SwiftData

/// Maps a specific app (by bundle ID) to a preferred style preset.
/// When the user dictates while that app is focused, its style is auto-selected.
@Model
public final class AppStyleProfile {
    @Attribute(.unique) public var id: UUID
    /// The app's bundle identifier (e.g. "com.apple.mail").
    public var appBundleID: String
    /// Display name of the app.
    public var appName: String
    /// Name of the style preset to use for this app.
    public var styleName: String
    public var createdAt: Date

    public init(appBundleID: String, appName: String, styleName: String) {
        self.id = UUID()
        self.appBundleID = appBundleID
        self.appName = appName
        self.styleName = styleName
        self.createdAt = Date()
    }
}
