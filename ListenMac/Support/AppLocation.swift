import Foundation

/// Where the app bundle is running from — used to detect the un-notarized-download failure modes
/// that silently break permissions and, in turn, the global hotkey.
enum AppLocation {
    /// True when Gatekeeper is running the app from a randomized, read-only App Translocation
    /// mount (the classic "I granted Accessibility but the fn key still does nothing" trap).
    ///
    /// When a downloaded, un-notarized app is launched from `~/Downloads` or a mounted DMG without
    /// being moved to `/Applications` first, macOS runs it from a throwaway path under
    /// `/private/var/folders/…/AppTranslocation/…`. TCC permissions the user grants there don't
    /// persist across launches, so the `NSEvent` global key monitor never receives events. Moving
    /// the app to `/Applications` and relaunching is the fix.
    static var isTranslocated: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    /// True when the app is still running from inside the mounted disk image.
    static var isRunningFromDiskImage: Bool {
        Bundle.main.bundlePath.hasPrefix("/Volumes/")
    }

    /// A user-facing warning if the install location will break permissions, else `nil`.
    static var installWarning: String? {
        if isTranslocated {
            return "Listen is running from a temporary quarantine location, so macOS won't keep "
                + "the permissions you grant. Drag Listen into your Applications folder, then "
                + "reopen it from there."
        }
        if isRunningFromDiskImage {
            return "Listen is running straight from the disk image. Drag it into your Applications "
                + "folder first, then open it from Applications — otherwise the fn hotkey and "
                + "permissions won't stick."
        }
        return nil
    }
}
