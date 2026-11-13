import Foundation

/// GhostGram options. Stored in UserDefaults so every module can read them without plumbing.
public enum GhostSettings {
    private static let defaults = UserDefaults.standard

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return fallback
        }
        return defaults.bool(forKey: key)
    }

    /// Keep messages that other people delete, marked as deleted.
    public static var keepDeletedMessages: Bool {
        get { return bool("ghost.keepDeleted", true) }
        set { defaults.set(newValue, forKey: "ghost.keepDeleted") }
    }

    /// Remember the previous text of edited messages.
    public static var keepEditHistory: Bool {
        get { return bool("ghost.keepEditHistory", true) }
        set { defaults.set(newValue, forKey: "ghost.keepEditHistory") }
    }

    /// Do not send read receipts (messages, voice/video listened, stories viewed).
    public static var hideReadReceipts: Bool {
        get { return bool("ghost.hideRead", false) }
        set { defaults.set(newValue, forKey: "ghost.hideRead") }
    }

    /// Always report the account as offline.
    public static var hideOnlineStatus: Bool {
        get { return bool("ghost.hideOnline", false) }
        set { defaults.set(newValue, forKey: "ghost.hideOnline") }
    }

    /// Do not send "typing" and other chat activities.
    public static var hideTyping: Bool {
        get { return bool("ghost.hideTyping", false) }
        set { defaults.set(newValue, forKey: "ghost.hideTyping") }
    }

    /// Keep view-once and self-destructing photos and videos after they are opened.
    public static var keepViewOnceMedia: Bool {
        get { return bool("ghost.keepViewOnce", true) }
        set { defaults.set(newValue, forKey: "ghost.keepViewOnce") }
    }
}
