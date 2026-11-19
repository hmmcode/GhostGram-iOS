import Foundation
import Postbox
import SwiftSignalKit

// MARK: - Rules

/// "When X happens, do Y": react, send a sticker, a GIF or a text.
public struct GhostAutomationRule: Codable, Equatable {
    public enum Trigger: String, Codable, CaseIterable {
        case privateMessage
        case mention
        case reply
        case keyword
        case person
        case groupMessage
    }

    public enum Action: String, Codable, CaseIterable {
        case reaction
        case sticker
        case gif
        case text
    }

    public var id: String
    public var enabled: Bool
    public var trigger: Trigger
    public var keyword: String
    public var person: String
    public var action: Action
    public var emoji: String
    public var text: String
    public var media: Data?
    public var withoutPack: Bool
    public var cooldown: Int
    public var asReply: Bool

    public init(trigger: Trigger = .privateMessage, action: Action = .reaction) {
        self.id = UUID().uuidString
        self.enabled = true
        self.trigger = trigger
        self.keyword = ""
        self.person = ""
        self.action = action
        self.emoji = "❤️"
        self.text = ""
        self.media = nil
        self.withoutPack = false
        self.cooldown = 60
        self.asReply = true
    }
}

public enum GhostAutomations {
    public static let changedNotification = Notification.Name("GhostAutomationsChanged")
    private static let key = "ghost.automations.rules"

    public static var rules: [GhostAutomationRule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key), let rules = try? JSONDecoder().decode([GhostAutomationRule].self, from: data) else {
                return []
            }
            return rules
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    public static func save(_ rule: GhostAutomationRule) {
        var current = rules
        if let index = current.firstIndex(where: { $0.id == rule.id }) {
            current[index] = rule
        } else {
            current.append(rule)
        }
        rules = current
    }

    public static func remove(_ id: String) {
        rules = rules.filter { $0.id != id }
    }
}

// MARK: - Media helpers for the settings screens

public extension GhostAutomationRule {
    /// The sticker or GIF this rule sends, if any.
    var mediaFile: TelegramMediaFile? {
        return self.media.flatMap(ghostDecodeMediaFile)
    }
}

public func ghostEncodeMediaFile(_ file: TelegramMediaFile) -> Data {
    let encoder = PostboxEncoder()
    encoder.encodeRootObject(file)
    return encoder.makeData()
}

public func ghostDecodeMediaFile(_ data: Data) -> TelegramMediaFile? {
    return PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? TelegramMediaFile
}

/// The emoji a sticker stands for, or "" when unknown.
public func ghostStickerEmoji(_ file: TelegramMediaFile) -> String {
    for attribute in file.attributes {
        if case let .Sticker(displayText, _, _) = attribute {
            return displayText
        }
    }
    return ""
}

/// Recently used and favourite stickers, and saved GIFs, newest first.
public func ghostPickableMedia(account: Account) -> Signal<(stickers: [TelegramMediaFile], gifs: [TelegramMediaFile]), NoError> {
    return account.postbox.transaction { transaction -> (stickers: [TelegramMediaFile], gifs: [TelegramMediaFile]) in
        var stickers: [TelegramMediaFile] = []
        var seen = Set<MediaId>()
        for item in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers) {
            if let contents = item.contents.get(SavedStickerItem.self) {
                let file = contents.file._parse()
                if !seen.contains(file.fileId) {
                    seen.insert(file.fileId)
                    stickers.append(file)
                }
            }
        }
        for item in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers) {
            if let contents = item.contents.get(RecentMediaItem.self) {
                let file = contents.media._parse()
                if !seen.contains(file.fileId) {
                    seen.insert(file.fileId)
                    stickers.append(file)
                }
            }
        }
        var gifs: [TelegramMediaFile] = []
        for item in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs) {
            if let contents = item.contents.get(RecentMediaItem.self) {
                gifs.append(contents.media._parse())
            }
        }
        return (stickers, gifs)
    }
}

/// A small picture of a sticker or GIF (WebP or JPEG bytes), downloading it when needed.
public func ghostMediaThumbnail(account: Account, file: TelegramMediaFile) -> Signal<Data?, NoError> {
    let resource: MediaResource
    if file.mimeType == "image/webp" {
        resource = file.resource
    } else if let preview = file.previewRepresentations.last {
        resource = preview.resource
    } else {
        return .single(nil)
    }
    return Signal<Data?, NoError> { subscriber in
        let fetch = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .media(media: .standalone(media: file), resource: resource)).start()
        let data = (account.postbox.mediaBox.resourceData(resource)
        |> filter { $0.complete }
        |> take(1)).start(next: { data in
            subscriber.putNext(try? Data(contentsOf: URL(fileURLWithPath: data.path)))
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetch.dispose()
            data.dispose()
        }
    }
    |> timeout(20.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
}

// MARK: - Stickers without a pack

/// A copy of the sticker that is uploaded anew, so the message has no link to its pack.
/// Returns nil when the sticker is not downloaded yet or is not a pack sticker.
public func ghostDetachedSticker(account: Account, file: TelegramMediaFile) -> TelegramMediaFile? {
    var hasPack = false
    for attribute in file.attributes {
        if case let .Sticker(_, packReference, _) = attribute, packReference != nil {
            hasPack = true
        }
    }
    guard hasPack, let path = account.postbox.mediaBox.completedResourcePath(file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path)), !data.isEmpty else {
        return nil
    }
    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
    account.postbox.mediaBox.storeResourceData(resource.id, data: data)
    let attributes = file.attributes.map { attribute -> TelegramMediaFileAttribute in
        if case let .Sticker(displayText, _, _) = attribute {
            return .Sticker(displayText: displayText, packReference: nil, maskData: nil)
        }
        return attribute
    }
    return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: Int64(data.count), attributes: attributes, alternativeRepresentations: [])
}

/// With "Stickers without pack" on, every pack sticker the user sends is re-uploaded on its own.
func ghostDetachStickersIfNeeded(account: Account, messages: [EnqueueMessage]) -> [EnqueueMessage] {
    if !GhostSettings.stickersWithoutPack {
        return messages
    }
    return messages.map { message -> EnqueueMessage in
        guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message, let file = mediaReference?.media as? TelegramMediaFile, file.isSticker, let detached = ghostDetachedSticker(account: account, file: file) else {
            return message
        }
        return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: .standalone(media: detached), threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])
    }
}

// MARK: - Upload progress for the Dynamic Island

public struct GhostUploadSnapshot: Equatable {
    public let count: Int
    public let progress: Double
    public let totalBytes: Int64
    public let kind: String

    public static let empty = GhostUploadSnapshot(count: 0, progress: 0.0, totalBytes: 0, kind: "")
}

private func ghostResourceBytes(_ account: Account, _ resource: MediaResource) -> Int64 {
    if let size = resource.size, size > 0 {
        return size
    }
    if let path = account.postbox.mediaBox.completedResourcePath(resource), let attributes = try? FileManager.default.attributesOfItem(atPath: path), let size = attributes[.size] as? NSNumber {
        return size.int64Value
    }
    return 0
}

/// Media messages that are being uploaded right now, summed up.
public func ghostUploadSnapshots(account: Account) -> Signal<GhostUploadSnapshot, NoError> {
    return account.pendingMessageManager.pendingMediaUploads
    |> mapToSignal { uploads -> Signal<GhostUploadSnapshot, NoError> in
        if uploads.isEmpty {
            return .single(.empty)
        }
        return account.postbox.transaction { transaction -> GhostUploadSnapshot in
            var total: Int64 = 0
            var weighted = 0.0
            var plain = 0.0
            var kinds = Set<String>()
            for (id, progress) in uploads {
                plain += Double(progress)
                guard let message = transaction.getMessage(id) else {
                    continue
                }
                var bytes: Int64 = 0
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        bytes += file.size ?? ghostResourceBytes(account, file.resource)
                        if file.isInstantVideo {
                            kinds.insert("кружок")
                        } else if file.isVoice {
                            kinds.insert("голосовое")
                        } else if file.isSticker {
                            kinds.insert("стикер")
                        } else if file.isAnimated {
                            kinds.insert("гифка")
                        } else if file.isVideo {
                            kinds.insert("видео")
                        } else {
                            kinds.insert("файл")
                        }
                    } else if let image = media as? TelegramMediaImage {
                        if let largest = image.representations.last {
                            bytes += ghostResourceBytes(account, largest.resource)
                        }
                        kinds.insert("фото")
                    }
                }
                total += bytes
                weighted += Double(bytes) * Double(progress)
            }
            let progress = total > 0 ? weighted / Double(total) : plain / Double(max(1, uploads.count))
            let kind = kinds.count == 1 ? kinds.first! : "медиа"
            return GhostUploadSnapshot(count: uploads.count, progress: max(0.0, min(1.0, progress)), totalBytes: total, kind: kind)
        }
    }
}

// MARK: - Engine

private let ghostAutomationLock = NSLock()
private var ghostAutomationAccounts: [AccountRecordId] = []
private var ghostAutomationDisposables: [Disposable] = []
private var ghostAutomationLastFired: [String: Double] = [:]

private func ghostAutomationShouldFire(_ key: String, cooldown: Int) -> Bool {
    let now = CFAbsoluteTimeGetCurrent()
    ghostAutomationLock.lock()
    defer {
        ghostAutomationLock.unlock()
    }
    if let last = ghostAutomationLastFired[key], now - last < Double(max(0, cooldown)) {
        return false
    }
    ghostAutomationLastFired[key] = now
    return true
}

/// A fresh copy of a saved sticker/GIF (file references expire), with the matching reference.
private func ghostFreshReference(transaction: Transaction, file: TelegramMediaFile) -> AnyMediaReference {
    for item in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs) {
        if let contents = item.contents.get(RecentMediaItem.self), contents.media._parse().fileId == file.fileId {
            return .savedGif(media: contents.media._parse())
        }
    }
    for item in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers) {
        if let contents = item.contents.get(SavedStickerItem.self), contents.file._parse().fileId == file.fileId {
            return .savedSticker(media: contents.file._parse())
        }
    }
    for item in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentStickers) {
        if let contents = item.contents.get(RecentMediaItem.self), contents.media._parse().fileId == file.fileId {
            return .recentSticker(media: contents.media._parse())
        }
    }
    for attribute in file.attributes {
        if case let .Sticker(_, packReference, _) = attribute, let packReference = packReference {
            return .stickerPack(stickerPack: packReference, media: file)
        }
    }
    return .standalone(media: file)
}

private func ghostAutomationMatches(_ rule: GhostAutomationRule, message: Message, accountPeerId: PeerId) -> Bool {
    let peerId = message.id.peerId
    let isPrivate = peerId.namespace == Namespaces.Peer.CloudUser
    var isGroup = peerId.namespace == Namespaces.Peer.CloudGroup
    if let channel = message.peers[peerId] as? TelegramChannel, case .group = channel.info {
        isGroup = true
    }
    switch rule.trigger {
    case .privateMessage:
        return isPrivate
    case .groupMessage:
        return isGroup
    case .mention:
        if !isGroup {
            return false
        }
        if message.tags.contains(.unseenPersonalMessage) {
            return true
        }
        return message.attributes.contains(where: { $0 is ConsumablePersonalMentionMessageAttribute })
    case .reply:
        for attribute in message.attributes {
            if let reply = attribute as? ReplyMessageAttribute, let replied = message.associatedMessages[reply.messageId], replied.author?.id == accountPeerId {
                return true
            }
        }
        return false
    case .keyword:
        let keyword = rule.keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !keyword.isEmpty && message.text.lowercased().contains(keyword)
    case .person:
        var wanted = rule.person.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if wanted.hasPrefix("@") {
            wanted.removeFirst()
        }
        guard !wanted.isEmpty, let user = message.author as? TelegramUser else {
            return false
        }
        if let username = user.username, username.lowercased() == wanted {
            return true
        }
        let name = [user.firstName ?? "", user.lastName ?? ""].filter { !$0.isEmpty }.joined(separator: " ").lowercased()
        return name == wanted || "\(user.id.id._internalGetInt64Value())" == wanted
    }
}

private func ghostAutomationRun(_ rule: GhostAutomationRule, message: Message, account: Account) {
    let peerId = message.id.peerId
    let reply: EngineMessageReplySubject? = rule.asReply ? EngineMessageReplySubject(messageId: message.id, quote: nil, innerSubject: nil) : nil
    switch rule.action {
    case .reaction:
        let emoji = rule.emoji.isEmpty ? "❤️" : rule.emoji
        let _ = updateMessageReactionsInteractively(account: account, messageIds: [message.id], reactions: [.builtin(emoji)], isLarge: false, storeAsRecentlyUsed: false).start()
    case .text:
        let text = rule.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return
        }
        let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: reply, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
    case .sticker, .gif:
        guard let file = rule.mediaFile else {
            return
        }
        let _ = (account.postbox.transaction { transaction -> AnyMediaReference in
            return ghostFreshReference(transaction: transaction, file: file)
        }
        |> deliverOnMainQueue).start(next: { reference in
            var mediaReference = reference
            if rule.action == .sticker && rule.withoutPack, let fresh = reference.media as? TelegramMediaFile, let detached = ghostDetachedSticker(account: account, file: fresh) {
                mediaReference = .standalone(media: detached)
            }
            let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: mediaReference, threadId: nil, replyToMessageId: reply, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
        })
    }
}

/// Watches incoming messages of an account and runs the user's auto actions.
public func ghostAutomationsAttach(account: Account) {
    ghostAutomationLock.lock()
    if ghostAutomationAccounts.contains(account.id) {
        ghostAutomationLock.unlock()
        return
    }
    ghostAutomationAccounts.append(account.id)
    ghostAutomationLock.unlock()

    let accountPeerId = account.peerId
    let disposable = account.stateManager.notificationMessages.start(next: { [weak account] list in
        guard let account = account, GhostSettings.automationsEnabled else {
            return
        }
        let rules = GhostAutomations.rules.filter { $0.enabled }
        if rules.isEmpty {
            return
        }
        let now = Int32(Date().timeIntervalSince1970)
        for (messages, _, _, _) in list {
            for message in messages {
                guard message.flags.contains(.Incoming), message.id.peerId.namespace != Namespaces.Peer.SecretChat, abs(now - message.timestamp) < 120 else {
                    continue
                }
                if let author = message.author as? TelegramUser, author.botInfo != nil || author.id == accountPeerId {
                    continue
                }
                for rule in rules where ghostAutomationMatches(rule, message: message, accountPeerId: accountPeerId) {
                    if ghostAutomationShouldFire("\(account.peerId.toInt64())|\(rule.id)|\(message.id.peerId.toInt64())", cooldown: rule.cooldown) {
                        ghostAutomationRun(rule, message: message, account: account)
                    }
                }
            }
        }
    })
    ghostAutomationLock.lock()
    ghostAutomationDisposables.append(disposable)
    ghostAutomationLock.unlock()
}
