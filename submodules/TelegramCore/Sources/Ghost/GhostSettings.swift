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

    private static func peerSet(_ key: String) -> Set<Int64> {
        guard let values = defaults.array(forKey: key) as? [NSNumber] else {
            return Set()
        }
        return Set(values.map { $0.int64Value })
    }

    private static func setPeerSet(_ key: String, _ value: Set<Int64>) {
        defaults.set(value.sorted().map { NSNumber(value: $0) }, forKey: key)
    }

    // MARK: - Messages

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

    /// Keep view-once and self-destructing photos and videos after they are opened.
    public static var keepViewOnceMedia: Bool {
        get { return bool("ghost.keepViewOnce", true) }
        set { defaults.set(newValue, forKey: "ghost.keepViewOnce") }
    }

    /// Show a notification when someone deletes a message.
    public static var notifyOnDelete: Bool {
        get { return bool("ghost.notifyOnDelete", false) }
        set { defaults.set(newValue, forKey: "ghost.notifyOnDelete") }
    }

    /// Keep a log of deleted messages for the "Deleted messages" screen.
    public static var keepDeletedLog: Bool {
        get { return bool("ghost.deletedLog", true) }
        set { defaults.set(newValue, forKey: "ghost.deletedLog") }
    }

    // MARK: - Ghost mode

    /// Do not send read receipts for messages and listened voice / video messages.
    public static var hideReadReceipts: Bool {
        get { return bool("ghost.hideRead", false) }
        set { defaults.set(newValue, forKey: "ghost.hideRead") }
    }

    /// While read receipts are hidden, still mark a chat as read when I send a message there.
    public static var readOnReply: Bool {
        get { return bool("ghost.readOnReply", true) }
        set { defaults.set(newValue, forKey: "ghost.readOnReply") }
    }

    /// Do not mark stories as viewed.
    public static var hideStoryViews: Bool {
        get { return bool("ghost.hideStoryViews", false) }
        set { defaults.set(newValue, forKey: "ghost.hideStoryViews") }
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

    /// Chats where ghost mode does not apply (read receipts and typing are sent as usual).
    public static var ghostExceptions: Set<Int64> {
        get { return peerSet("ghost.exceptions") }
        set { setPeerSet("ghost.exceptions", newValue) }
    }

    public static func isGhostException(_ peerId: Int64) -> Bool {
        return ghostExceptions.contains(peerId)
    }

    public static func shouldHideRead(peerId: Int64) -> Bool {
        return effectiveHideRead && !isGhostException(peerId)
    }

    public static func shouldHideTyping(peerId: Int64) -> Bool {
        return effectiveHideTyping && !isGhostException(peerId)
    }

    // MARK: - Media

    /// Download media from private chats right away, so it survives deletion.
    public static var autoCachePrivateMedia: Bool {
        get { return bool("ghost.autoCache", false) }
        set { defaults.set(newValue, forKey: "ghost.autoCache") }
    }

    public static var autoCachePhotos: Bool {
        get { return bool("ghost.autoCache.photos", true) }
        set { defaults.set(newValue, forKey: "ghost.autoCache.photos") }
    }

    public static var autoCacheVideos: Bool {
        get { return bool("ghost.autoCache.videos", true) }
        set { defaults.set(newValue, forKey: "ghost.autoCache.videos") }
    }

    public static var autoCacheVoice: Bool {
        get { return bool("ghost.autoCache.voice", true) }
        set { defaults.set(newValue, forKey: "ghost.autoCache.voice") }
    }

    public static var autoCacheFiles: Bool {
        get { return bool("ghost.autoCache.files", false) }
        set { defaults.set(newValue, forKey: "ghost.autoCache.files") }
    }

    /// Size limit in megabytes; 0 means no limit.
    public static var autoCacheLimitMB: Int {
        get {
            if defaults.object(forKey: "ghost.autoCache.limit") == nil {
                return 50
            }
            return defaults.integer(forKey: "ghost.autoCache.limit")
        }
        set { defaults.set(newValue, forKey: "ghost.autoCache.limit") }
    }

    // MARK: - Content

    /// Allow saving and copying from chats and channels that forbid it.
    public static var bypassCopyProtection: Bool {
        get { return bool("ghost.bypassCopyProtection", false) }
        set { defaults.set(newValue, forKey: "ghost.bypassCopyProtection") }
    }

    /// Do not tell the other side of a secret chat about screenshots.
    public static var hideScreenshotNotifications: Bool {
        get { return bool("ghost.hideScreenshots", false) }
        set { defaults.set(newValue, forKey: "ghost.hideScreenshots") }
    }

    /// Do not load sponsored messages in channels.
    public static var hideSponsoredMessages: Bool {
        get { return bool("ghost.hideSponsored", true) }
        set { defaults.set(newValue, forKey: "ghost.hideSponsored") }
    }

    /// Hide the stories row above the chat list.
    public static var hideStoriesBar: Bool {
        get { return bool("ghost.hideStories", false) }
        set { defaults.set(newValue, forKey: "ghost.hideStories") }
    }

    // MARK: - Interface

    /// Hide my phone number in my own profile and in Settings.
    public static var hidePhoneNumber: Bool {
        get { return bool("ghost.hidePhone", false) }
        set { defaults.set(newValue, forKey: "ghost.hidePhone") }
    }

    /// Ask before sending a recorded voice or video message.
    public static var confirmVoice: Bool {
        get { return bool("ghost.confirmVoice", false) }
        set { defaults.set(newValue, forKey: "ghost.confirmVoice") }
    }

    /// Ask before sending a sticker or GIF.
    public static var confirmStickers: Bool {
        get { return bool("ghost.confirmStickers", false) }
        set { defaults.set(newValue, forKey: "ghost.confirmStickers") }
    }

    /// Offer 2.5x and 3x playback speed for voice and video messages.
    public static var extendedPlaybackSpeeds: Bool {
        get { return bool("ghost.extendedSpeeds", true) }
        set { defaults.set(newValue, forKey: "ghost.extendedSpeeds") }
    }

    /// Show the "Details" item (ids, exact time) in the message menu.
    public static var showMessageDetails: Bool {
        get { return bool("ghost.messageDetails", true) }
        set { defaults.set(newValue, forKey: "ghost.messageDetails") }
    }

    /// Show a ghost in the Dynamic Island while ghost mode is on.
    public static var dynamicIsland: Bool {
        get { return bool("ghost.dynamicIsland", false) }
        set { defaults.set(newValue, forKey: "ghost.dynamicIsland") }
    }

    // MARK: - Hidden chats

    /// Chats removed from the chat list. They open from Settings → GhostGram → Hidden chats.
    public static var hiddenChats: Set<Int64> {
        get { return peerSet("ghost.hiddenChats") }
        set { setPeerSet("ghost.hiddenChats", newValue) }
    }

    public static var hiddenChatsEnabled: Bool {
        get { return bool("ghost.hiddenChatsEnabled", true) }
        set { defaults.set(newValue, forKey: "ghost.hiddenChatsEnabled") }
    }

    public static func isChatHidden(_ peerId: Int64) -> Bool {
        return hiddenChatsEnabled && hiddenChats.contains(peerId)
    }

    /// Whether anything in ghost mode is on (for the Dynamic Island).
    public static var isAnyGhostModeOn: Bool {
        return effectiveHideRead || hideOnlineStatus || isGhostScheduleActive || hideTyping || hideStoryViews
    }
}
