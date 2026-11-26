import Foundation
import Postbox

/// GhostGram options ported from exteraGram ideas (fourth batch).
public extension GhostSettings {
    private static var store4: UserDefaults {
        return UserDefaults.standard
    }

    private static func flag4(_ key: String, _ fallback: Bool) -> Bool {
        if store4.object(forKey: key) == nil {
            return fallback
        }
        return store4.bool(forKey: key)
    }

    /// Voice messages are turned into text on the phone (iOS speech recognition), no Premium needed.
    static var localTranscription: Bool {
        get { return flag4("ghost.localTranscription", true) }
        set { store4.set(newValue, forKey: "ghost.localTranscription") }
    }

    /// "150*3=" in the message field gets the answer appended.
    static var inlineCalculator: Bool {
        get { return flag4("ghost.inlineCalc", true) }
        set { store4.set(newValue, forKey: "ghost.inlineCalc") }
    }

    /// "Repeat", "To Saved Messages" and "Author's messages" in the message menu.
    static var extraMessageMenu: Bool {
        get { return flag4("ghost.extraMenu", true) }
        set { store4.set(newValue, forKey: "ghost.extraMenu") }
    }

    /// What a double tap on a message does: 0 reaction, 1 reply, 2 copy text, 3 save to Saved Messages, 4 nothing.
    static var doubleTapAction: Int {
        get {
            if store4.object(forKey: "ghost.doubleTapAction") == nil {
                return GhostSettings.doubleTapReply ? 1 : 0
            }
            return store4.integer(forKey: "ghost.doubleTapAction")
        }
        set { store4.set(newValue, forKey: "ghost.doubleTapAction") }
    }

    static var doubleTapActionTitles: [String] {
        return ["Реакция", "Ответить", "Копировать текст", "В Избранное", "Ничего"]
    }

    /// "был 5 ч назад" instead of "был сегодня в 9:41".
    static var relativeLastSeen: Bool {
        get { return flag4("ghost.relativeLastSeen", false) }
        set { store4.set(newValue, forKey: "ghost.relativeLastSeen") }
    }

    /// 1 234 instead of 1.2K for views, subscribers and reactions.
    static var exactNumbers: Bool {
        get { return flag4("ghost.exactNumbers", false) }
        set { store4.set(newValue, forKey: "ghost.exactNumbers") }
    }

    /// A pencil instead of the word "edited".
    static var editedIcon: Bool {
        get { return flag4("ghost.editedIcon", false) }
        set { store4.set(newValue, forKey: "ghost.editedIcon") }
    }

    /// How many times a channel post was forwarded, next to its time.
    static var showForwardsCount: Bool {
        get { return flag4("ghost.forwardsCount", false) }
        set { store4.set(newValue, forKey: "ghost.forwardsCount") }
    }

    /// Bubbles without the little tail.
    static var removeMessageTail: Bool {
        get { return flag4("ghost.noTail", false) }
        set { store4.set(newValue, forKey: "ghost.noTail") }
    }

    static var hideReactionsPrivate: Bool {
        get { return flag4("ghost.hideReactions.private", false) }
        set { store4.set(newValue, forKey: "ghost.hideReactions.private") }
    }

    static var hideReactionsGroups: Bool {
        get { return flag4("ghost.hideReactions.groups", false) }
        set { store4.set(newValue, forKey: "ghost.hideReactions.groups") }
    }

    static var hideReactionsChannels: Bool {
        get { return flag4("ghost.hideReactions.channels", false) }
        set { store4.set(newValue, forKey: "ghost.hideReactions.channels") }
    }

    /// Cuts "zalgo" text (letters buried under stacks of accents) down to readable letters.
    static var filterZalgo: Bool {
        get { return flag4("ghost.filterZalgo", true) }
        set { store4.set(newValue, forKey: "ghost.filterZalgo") }
    }

    /// Round video messages start with the back camera.
    static var roundRearCamera: Bool {
        get { return flag4("ghost.roundRear", false) }
        set { store4.set(newValue, forKey: "ghost.roundRear") }
    }

    /// Photos from the gallery are always sent in HD.
    static var alwaysHDPhotos: Bool {
        get { return flag4("ghost.alwaysHD", false) }
        set { store4.set(newValue, forKey: "ghost.alwaysHD") }
    }

    /// Swipe actions in the chat list trade sides.
    static var swapChatSwipes: Bool {
        get { return flag4("ghost.swapSwipes", false) }
        set { store4.set(newValue, forKey: "ghost.swapSwipes") }
    }

    /// No live camera tile in the attachment gallery.
    static var hideCameraTile: Bool {
        get { return flag4("ghost.hideCameraTile", false) }
        set { store4.set(newValue, forKey: "ghost.hideCameraTile") }
    }

    /// The music player panel takes the colour of the album cover.
    static var playerCoverColors: Bool {
        get { return flag4("ghost.playerCoverColors", true) }
        set { store4.set(newValue, forKey: "ghost.playerCoverColors") }
    }

    /// A lyrics button in the music player.
    static var playerLyricsButton: Bool {
        get { return flag4("ghost.playerLyrics", true) }
        set { store4.set(newValue, forKey: "ghost.playerLyrics") }
    }

    static func hidesReactions(message: Message) -> Bool {
        if !hideReactionsPrivate && !hideReactionsGroups && !hideReactionsChannels {
            return false
        }
        let peerId = message.id.peerId
        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
            return hideReactionsPrivate
        }
        if peerId.namespace == Namespaces.Peer.CloudChannel, let channel = message.peers[peerId] as? TelegramChannel, case .broadcast = channel.info {
            return hideReactionsChannels
        }
        return hideReactionsGroups
    }
}

/// Reactions of a message, or nothing when GhostGram hides reactions in this kind of chat.
public func ghostMergedMessageReactions(message: Message, isTags: Bool) -> ReactionsMessageAttribute? {
    if !isTags && GhostSettings.hidesReactions(message: message) {
        return nil
    }
    return mergedMessageReactions(attributes: message.attributes, isTags: isTags)
}

/// Returns the text with runs of stacked combining marks cut to two, or nil when nothing had to change.
public func ghostStripZalgo(_ text: String) -> String? {
    var scalars = String.UnicodeScalarView()
    var run = 0
    var removed = 0
    for scalar in text.unicodeScalars {
        let category = scalar.properties.generalCategory
        if category == .nonspacingMark || category == .enclosingMark {
            run += 1
            if run > 2 {
                removed += 1
                continue
            }
        } else {
            run = 0
        }
        scalars.append(scalar)
    }
    if removed < 3 {
        return nil
    }
    return String(scalars)
}
