import Foundation
import UserNotifications
import Postbox
import SwiftSignalKit
internal import TelegramApi

// MARK: - Deleted messages log

/// A deleted message remembered for the "Deleted messages" screen.
public struct GhostDeletedLogEntry: Codable, Equatable {
    public let peerId: Int64
    public let namespace: Int32
    public let id: Int32
    public let timestamp: Int32
    public let deletedAt: Int32
    public let chatTitle: String
    public let authorTitle: String
    public let text: String

    public var messageId: MessageId {
        return MessageId(peerId: PeerId(self.peerId), namespace: self.namespace, id: self.id)
    }
}

/// File-backed list of deleted messages, newest first, capped at `limit` entries.
public enum GhostDeletedLog {
    private static let limit = 3000
    private static let lock = NSLock()
    private static var cache: [GhostDeletedLogEntry]?

    private static var fileURL: URL? {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return directory.appendingPathComponent("ghost-deleted-log.json")
    }

    private static func load() -> [GhostDeletedLogEntry] {
        if let cache = self.cache {
            return cache
        }
        var result: [GhostDeletedLogEntry] = []
        if let url = self.fileURL, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([GhostDeletedLogEntry].self, from: data) {
            result = decoded
        }
        self.cache = result
        return result
    }

    private static func save(_ entries: [GhostDeletedLogEntry]) {
        self.cache = entries
        if let url = self.fileURL, let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    public static func entries() -> [GhostDeletedLogEntry] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.load()
    }

    static func add(_ newEntries: [GhostDeletedLogEntry]) {
        if newEntries.isEmpty {
            return
        }
        self.lock.lock()
        defer { self.lock.unlock() }
        var entries = self.load()
        entries.insert(contentsOf: newEntries, at: 0)
        if entries.count > self.limit {
            entries.removeLast(entries.count - self.limit)
        }
        self.save(entries)
    }

    public static func clear() {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.save([])
    }
}

/// Short text for a message: its text, or a label for its media.
func ghostMessagePreview(_ message: Message) -> String {
    var mediaLabel: String?
    for media in message.media {
        if media is TelegramMediaImage {
            mediaLabel = "📷 Фото"
        } else if let file = media as? TelegramMediaFile {
            if file.isVoice {
                mediaLabel = "🎤 Голосовое"
            } else if file.isInstantVideo {
                mediaLabel = "⏺ Кружок"
            } else if file.isSticker {
                mediaLabel = "Стикер"
            } else if file.isVideo {
                mediaLabel = "🎬 Видео"
            } else {
                mediaLabel = "📎 Файл"
            }
        }
    }
    if message.text.isEmpty {
        return mediaLabel ?? "Сообщение"
    }
    if let mediaLabel = mediaLabel {
        return "\(mediaLabel): \(message.text)"
    }
    return message.text
}

/// Records kept deleted messages in the log and posts a notification about them.
func ghostReportDeletedMessages(_ messages: [Message], deletedAt: Int32) {
    let incoming = messages.filter { $0.flags.contains(.Incoming) }
    if incoming.isEmpty {
        return
    }
    if GhostSettings.keepDeletedLog {
        let entries = incoming.map { message -> GhostDeletedLogEntry in
            let chatTitle = message.peers[message.id.peerId]?.debugDisplayTitle ?? ""
            let authorTitle = message.author?.debugDisplayTitle ?? chatTitle
            return GhostDeletedLogEntry(peerId: message.id.peerId.toInt64(), namespace: message.id.namespace, id: message.id.id, timestamp: message.timestamp, deletedAt: deletedAt, chatTitle: chatTitle, authorTitle: authorTitle, text: ghostMessagePreview(message))
        }
        GhostDeletedLog.add(entries)
    }
    if GhostSettings.notifyOnDelete {
        let content = UNMutableNotificationContent()
        if incoming.count == 1, let message = incoming.first {
            let author = message.author?.debugDisplayTitle ?? "Кто-то"
            content.title = "🗑 \(author) удалил(а) сообщение"
            content.body = ghostMessagePreview(message)
        } else {
            let chatTitle = incoming.first.flatMap { $0.peers[$0.id.peerId]?.debugDisplayTitle } ?? ""
            content.title = "🗑 Удалено сообщений: \(incoming.count)"
            content.body = chatTitle
        }
        content.threadIdentifier = "ghostgram-deleted"
        let request = UNNotificationRequest(identifier: "ghostgram-deleted-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// MARK: - Ghost mode

/// While read receipts are hidden, marks the chat as read on the server when I send a message there.
func ghostReadOnReply(transaction: Transaction, account: Account, peerId: PeerId) {
    guard GhostSettings.effectiveHideRead, GhostSettings.readOnReply, !GhostSettings.isGhostException(peerId.toInt64()) else {
        return
    }
    guard peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
        return
    }
    guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
        return
    }
    guard let states = transaction.getPeerReadStates(peerId), let entry = states.first(where: { $0.0 == Namespaces.Message.Cloud }) else {
        return
    }
    guard case let .idBased(maxIncomingReadId, _, _, _, _) = entry.1, maxIncomingReadId > 0 else {
        return
    }
    let request: Signal<Void, NoError>
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        guard let inputChannel = apiInputChannel(peer) else {
            return
        }
        request = account.network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: maxIncomingReadId))
        |> map { _ -> Void in
            return Void()
        }
        |> `catch` { _ -> Signal<Void, NoError> in
            return .complete()
        }
    } else {
        request = account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxIncomingReadId))
        |> map { _ -> Void in
            return Void()
        }
        |> `catch` { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    let _ = request.start()
}

// MARK: - Stories

/// Empties the stories row above the chat list when the user hides it.
public func ghostFilterStorySubscriptions(_ signal: Signal<EngineStorySubscriptions, NoError>) -> Signal<EngineStorySubscriptions, NoError> {
    return signal
    |> map { subscriptions -> EngineStorySubscriptions in
        if GhostSettings.hideStoriesBar {
            return EngineStorySubscriptions(accountItem: nil, items: [], hasMoreToken: nil)
        }
        return subscriptions
    }
}

// MARK: - Media

/// Forces automatic download of media in private chats, so it can be kept after deletion.
public func ghostShouldForceAutodownload(isPrivateChat: Bool, media: EngineMedia?) -> Bool {
    guard GhostSettings.autoCachePrivateMedia, isPrivateChat, let media = media else {
        return false
    }
    let limitMB = GhostSettings.autoCacheLimitMB
    let limit: Int64 = limitMB <= 0 ? Int64.max : Int64(limitMB) * 1024 * 1024
    switch media {
    case .image:
        return GhostSettings.autoCachePhotos
    case let .file(file):
        if file.isSticker {
            return false
        }
        let allowed: Bool
        if file.isVoice || file.isInstantVideo {
            allowed = GhostSettings.autoCacheVoice
        } else if file.isVideo {
            allowed = GhostSettings.autoCacheVideos
        } else {
            allowed = GhostSettings.autoCacheFiles
        }
        if !allowed {
            return false
        }
        return (file.size ?? 0) <= limit
    default:
        return false
    }
}
