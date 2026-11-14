import Foundation
import SwiftSignalKit

/// Invisible mark that GhostGram adds to the end of the user's last name.
/// Other GhostGram clients see it and draw 👻 next to the name; everyone else sees nothing.
public let ghostGramNameMarker = "\u{2063}\u{2064}"

public func ghostHasNameMarker(_ text: String?) -> Bool {
    guard let text = text else {
        return false
    }
    return text.contains(ghostGramNameMarker)
}

public func ghostStripNameMarker(_ text: String) -> String {
    return text.replacingOccurrences(of: ghostGramNameMarker, with: "")
}

/// Strips the mark from a display title and adds the 👻 badge when enabled.
public func ghostDecorateTitle(_ title: String) -> String {
    guard title.contains(ghostGramNameMarker) else {
        return title
    }
    let stripped = ghostStripNameMarker(title).trimmingCharacters(in: .whitespaces)
    if GhostSettings.showGhostBadges {
        return stripped.isEmpty ? "👻" : stripped + " 👻"
    }
    return stripped
}

/// Adds or removes the mark on the own account's last name to match the setting.
public func ghostSyncNameMarker(account: Account) {
    let engine = TelegramEngine(account: account)
    let _ = (engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: account.peerId))
    |> mapToSignal { peer -> Signal<Void, NoError> in
        guard case let .user(user)? = peer else {
            return .complete()
        }
        let lastName = user.lastName ?? ""
        let hasMarker = lastName.contains(ghostGramNameMarker)
        let wantsMarker = GhostSettings.advertiseGhostGram
        if hasMarker == wantsMarker {
            return .complete()
        }
        let cleaned = ghostStripNameMarker(lastName)
        let updatedLastName = wantsMarker ? cleaned + ghostGramNameMarker : cleaned
        return engine.accountData.updateAccountPeerName(firstName: user.firstName ?? "", lastName: updatedLastName)
    }).start()
}

public extension GhostSettings {
    /// Draw 👻 next to the names of other GhostGram users.
    static var showGhostBadges: Bool {
        get {
            if UserDefaults.standard.object(forKey: "ghost.showBadges") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "ghost.showBadges")
        }
        set { UserDefaults.standard.set(newValue, forKey: "ghost.showBadges") }
    }

    /// Mark the own name so other GhostGram users see the 👻 badge.
    static var advertiseGhostGram: Bool {
        get {
            if UserDefaults.standard.object(forKey: "ghost.advertise") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "ghost.advertise")
        }
        set { UserDefaults.standard.set(newValue, forKey: "ghost.advertise") }
    }
}
