import Foundation

/// GhostGram options added in the third batch.
public extension GhostSettings {
    private static var store: UserDefaults {
        return UserDefaults.standard
    }

    private static func flag(_ key: String, _ fallback: Bool) -> Bool {
        if store.object(forKey: key) == nil {
            return fallback
        }
        return store.bool(forKey: key)
    }

    private static func int(_ key: String, _ fallback: Int) -> Int {
        if store.object(forKey: key) == nil {
            return fallback
        }
        return store.integer(forKey: key)
    }

    private static func ids(_ key: String) -> Set<Int64> {
        guard let values = store.array(forKey: key) as? [NSNumber] else {
            return Set()
        }
        return Set(values.map { $0.int64Value })
    }

    private static func setIds(_ key: String, _ value: Set<Int64>) {
        store.set(value.sorted().map { NSNumber(value: $0) }, forKey: key)
    }

    private static func stringMap(_ key: String) -> [Int64: String] {
        guard let raw = store.dictionary(forKey: key) as? [String: String] else {
            return [:]
        }
        var result: [Int64: String] = [:]
        for (k, v) in raw {
            if let id = Int64(k) {
                result[id] = v
            }
        }
        return result
    }

    private static func setStringMap(_ key: String, _ value: [Int64: String]) {
        var raw: [String: String] = [:]
        for (k, v) in value {
            raw[String(k)] = v
        }
        store.set(raw, forKey: key)
    }

    // MARK: - Ghost schedule

    static var ghostScheduleEnabled: Bool {
        get { return flag("ghost.schedule", false) }
        set { store.set(newValue, forKey: "ghost.schedule") }
    }

    /// Hour (0...23) when the scheduled ghost mode starts.
    static var ghostScheduleFrom: Int {
        get { return int("ghost.schedule.from", 23) }
        set { store.set(newValue, forKey: "ghost.schedule.from") }
    }

    /// Hour (0...23) when the scheduled ghost mode ends.
    static var ghostScheduleTo: Int {
        get { return int("ghost.schedule.to", 8) }
        set { store.set(newValue, forKey: "ghost.schedule.to") }
    }

    static var isGhostScheduleActive: Bool {
        if !ghostScheduleEnabled {
            return false
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let from = ghostScheduleFrom
        let to = ghostScheduleTo
        if from == to {
            return true
        } else if from < to {
            return hour >= from && hour < to
        } else {
            return hour >= from || hour < to
        }
    }

    static var effectiveHideRead: Bool {
        return hideReadReceipts || isGhostScheduleActive
    }

    static var effectiveHideOnline: Bool {
        return hideOnlineStatus || isGhostScheduleActive || isOnlineDelayActive
    }

    static var effectiveHideTyping: Bool {
        return hideTyping || isGhostScheduleActive
    }

    static var effectiveHideStoryViews: Bool {
        return hideStoryViews || isGhostScheduleActive
    }

    // MARK: - Online delay

    /// Stay offline for this many seconds after opening the app (0 = off).
    static var onlineDelaySeconds: Int {
        get { return int("ghost.onlineDelay", 0) }
        set { store.set(newValue, forKey: "ghost.onlineDelay") }
    }

    /// Set by the app when it becomes active.
    static func markAppBecameActive() {
        ghostAppActiveSince = Date().timeIntervalSince1970
    }

    static var isOnlineDelayActive: Bool {
        let delay = onlineDelaySeconds
        if delay <= 0 {
            return false
        }
        return Date().timeIntervalSince1970 - ghostAppActiveSince < Double(delay)
    }

    // MARK: - Activities

    /// Hide "recording voice", "sending photo" and other non-typing activities.
    static var hideOtherActivities: Bool {
        get { return flag("ghost.hideOtherActivities", false) }
        set { store.set(newValue, forKey: "ghost.hideOtherActivities") }
    }

    /// Fake activity shown permanently in chosen chats: peer id -> GhostFakeActivityKind raw value.
    static var fakeActivities: [Int64: String] {
        get { return stringMap("ghost.fakeActivities") }
        set { setStringMap("ghost.fakeActivities", newValue) }
    }

    static var fakeActivitiesEnabled: Bool {
        get { return flag("ghost.fakeActivitiesEnabled", true) }
        set { store.set(newValue, forKey: "ghost.fakeActivitiesEnabled") }
    }

    // MARK: - Security

    /// Shake the phone to leave the app instantly.
    static var panicShake: Bool {
        get { return flag("ghost.panicShake", false) }
        set { store.set(newValue, forKey: "ghost.panicShake") }
    }

    /// Chats that ask for Face ID before opening.
    static var lockedChats: Set<Int64> {
        get { return ids("ghost.lockedChats") }
        set { setIds("ghost.lockedChats", newValue) }
    }

    /// Ask for Face ID before opening the GhostGram menu.
    static var protectMenu: Bool {
        get { return flag("ghost.protectMenu", false) }
        set { store.set(newValue, forKey: "ghost.protectMenu") }
    }

    static func isChatUnlockedForSession(_ peerId: Int64) -> Bool {
        return ghostUnlockedChats.contains(peerId)
    }

    static func unlockChatForSession(_ peerId: Int64) {
        ghostUnlockedChats.insert(peerId)
    }

    static func lockAllChatsAgain() {
        ghostUnlockedChats.removeAll()
    }

    // MARK: - Messages

    /// 0 = trash icon, 1 = "deleted" word.
    static var deletedMarkStyle: Int {
        get { return int("ghost.deletedStyle", 0) }
        set { store.set(newValue, forKey: "ghost.deletedStyle") }
    }

    static var showSecondsInTime: Bool {
        get { return flag("ghost.seconds", false) }
        set { store.set(newValue, forKey: "ghost.seconds") }
    }

    static var keepSecretSelfDestruct: Bool {
        get { return flag("ghost.keepSecret", false) }
        set { store.set(newValue, forKey: "ghost.keepSecret") }
    }

    /// Words that hide incoming messages containing them.
    static var filterKeywords: [String] {
        get { return (store.array(forKey: "ghost.keywords") as? [String]) ?? [] }
        set { store.set(newValue, forKey: "ghost.keywords") }
    }

    static var filterEnabled: Bool {
        get { return flag("ghost.filterEnabled", true) }
        set { store.set(newValue, forKey: "ghost.filterEnabled") }
    }

    /// Users whose messages are hidden.
    static var ignoredUsers: Set<Int64> {
        get { return ids("ghost.ignored") }
        set { setIds("ghost.ignored", newValue) }
    }

    /// Double tap on a message replies instead of reacting.
    static var doubleTapReply: Bool {
        get { return flag("ghost.doubleTapReply", false) }
        set { store.set(newValue, forKey: "ghost.doubleTapReply") }
    }

    static var showNotesAndReminders: Bool {
        get { return flag("ghost.notes", true) }
        set { store.set(newValue, forKey: "ghost.notes") }
    }

    // MARK: - Profiles

    static var showUserIdInProfile: Bool {
        get { return flag("ghost.profileId", true) }
        set { store.set(newValue, forKey: "ghost.profileId") }
    }

    static var trackProfileChanges: Bool {
        get { return flag("ghost.profileLog", true) }
        set { store.set(newValue, forKey: "ghost.profileLog") }
    }

    /// Contacts whose coming online is announced with a notification.
    static var onlineWatchList: Set<Int64> {
        get { return ids("ghost.onlineWatch") }
        set { setIds("ghost.onlineWatch", newValue) }
    }

    /// Local names for users, shown instead of their real names.
    static var nicknames: [Int64: String] {
        get { return stringMap("ghost.nicknames") }
        set { setStringMap("ghost.nicknames", newValue) }
    }

    static func nickname(for peerId: Int64) -> String? {
        if let value = nicknames[peerId], !value.isEmpty {
            return value
        }
        return nil
    }

    // MARK: - Interface

    static var confirmCalls: Bool {
        get { return flag("ghost.confirmCalls", false) }
        set { store.set(newValue, forKey: "ghost.confirmCalls") }
    }

    static var hideNewsTab: Bool {
        get { return flag("ghost.hideNewsTab", false) }
        set { store.set(newValue, forKey: "ghost.hideNewsTab") }
    }

    static var hideAppBadge: Bool {
        get { return flag("ghost.hideBadge", false) }
        set { store.set(newValue, forKey: "ghost.hideBadge") }
    }

    static var disableSwipeReply: Bool {
        get { return flag("ghost.noSwipeReply", false) }
        set { store.set(newValue, forKey: "ghost.noSwipeReply") }
    }

    /// "GhostGram" pill around the Dynamic Island while the app is open.
    static var islandBadge: Bool {
        get { return flag("ghost.islandBadge", true) }
        set { store.set(newValue, forKey: "ghost.islandBadge") }
    }

    /// Bottom bar with only Chats and Settings (no Calls, no News).
    static var minimalTabs: Bool {
        get { return flag("ghost.minimalTabs", false) }
        set { store.set(newValue, forKey: "ghost.minimalTabs") }
    }

    /// Bigger download parts (1 MB) and more of them in parallel.
    static var downloadBoost: Bool {
        get { return flag("ghost.downloadBoost", true) }
        set { store.set(newValue, forKey: "ghost.downloadBoost") }
    }

    /// Profile screen over a blurred avatar, with translucent cards.
    static var glassProfile: Bool {
        get { return flag("ghost.glassProfile", true) }
        set { store.set(newValue, forKey: "ghost.glassProfile") }
    }

    /// Cover the app with black while the screen is being recorded or mirrored.
    static var hideOnScreenRecording: Bool {
        get { return flag("ghost.hideOnCapture", false) }
        set { store.set(newValue, forKey: "ghost.hideOnCapture") }
    }

    /// Read directly by the Display module, which cannot see TelegramCore.
    static var disableHaptics: Bool {
        get { return flag("ghost.noHaptics", false) }
        set { store.set(newValue, forKey: "ghost.noHaptics") }
    }

    /// Title above the chat list; nil keeps "Chats".
    static var customChatListTitle: String? {
        get {
            let value = store.string(forKey: "ghost.chatListTitle") ?? ""
            return value.isEmpty ? nil : value
        }
        set { store.set(newValue ?? "", forKey: "ghost.chatListTitle") }
    }

    static var onboardingShown: Bool {
        get { return flag("ghost.onboardingShown", false) }
        set { store.set(newValue, forKey: "ghost.onboardingShown") }
    }

    // MARK: - Backup, reset, presets

    /// All GhostGram settings as JSON (lists and names included).
    static func exportJSON() -> String {
        var result: [String: Any] = [:]
        for (key, value) in store.dictionaryRepresentation() where key.hasPrefix("ghost.") {
            if JSONSerialization.isValidJSONObject([value]) {
                result[key] = value
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    /// Restores settings exported with `exportJSON`. Returns the number of restored keys.
    static func importJSON(_ text: String) -> Int {
        guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data), let dictionary = object as? [String: Any] else {
            return 0
        }
        var count = 0
        for (key, value) in dictionary where key.hasPrefix("ghost.") {
            store.set(value, forKey: key)
            count += 1
        }
        return count
    }

    static func resetAll() {
        for key in store.dictionaryRepresentation().keys where key.hasPrefix("ghost.") {
            store.removeObject(forKey: key)
        }
    }

    enum Preset {
        case invisible
        case archivist
        case regular
    }

    static func apply(preset: Preset) {
        switch preset {
        case .invisible:
            hideReadReceipts = true
            readOnReply = true
            hideStoryViews = true
            hideOnlineStatus = true
            hideTyping = true
            hideOtherActivities = true
            hideScreenshotNotifications = true
        case .archivist:
            keepDeletedMessages = true
            keepEditHistory = true
            keepViewOnceMedia = true
            keepDeletedLog = true
            notifyOnDelete = true
            autoCachePrivateMedia = true
            trackProfileChanges = true
        case .regular:
            hideReadReceipts = false
            hideStoryViews = false
            hideOnlineStatus = false
            hideTyping = false
            hideOtherActivities = false
            ghostScheduleEnabled = false
        }
    }
}

private var ghostAppActiveSince: Double = 0
private var ghostUnlockedChats = Set<Int64>()
