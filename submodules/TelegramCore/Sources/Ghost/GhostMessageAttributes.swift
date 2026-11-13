import Foundation
import Postbox

/// Marks a message that was deleted on the server but kept on this device.
public final class GhostDeletedMessageAttribute: MessageAttribute {
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    public required init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

/// Earlier versions of an edited message, oldest first.
public final class GhostEditHistoryMessageAttribute: MessageAttribute {
    public struct Entry: Equatable {
        public let text: String
        public let date: Int32

        public init(text: String, date: Int32) {
            self.text = text
            self.date = date
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public required init(decoder: PostboxDecoder) {
        let texts = decoder.decodeStringArrayForKey("t")
        let dates = decoder.decodeInt32ArrayForKey("d")
        var entries: [Entry] = []
        for i in 0 ..< min(texts.count, dates.count) {
            entries.append(Entry(text: texts[i], date: dates[i]))
        }
        self.entries = entries
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.entries.map { $0.text }, forKey: "t")
        encoder.encodeInt32Array(self.entries.map { $0.date }, forKey: "d")
    }
}

public extension Message {
    var ghostDeletedAttribute: GhostDeletedMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? GhostDeletedMessageAttribute {
                return attribute
            }
        }
        return nil
    }

    var ghostEditHistory: [GhostEditHistoryMessageAttribute.Entry] {
        for attribute in self.attributes {
            if let attribute = attribute as? GhostEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

private func ghostCurrentTimestamp() -> Int32 {
    return Int32(Date().timeIntervalSince1970)
}

private func ghostStoreMessage(_ message: Message, attributes: [MessageAttribute]) -> StoreMessage {
    var storeForwardInfo: StoreMessageForwardInfo?
    if let forwardInfo = message.forwardInfo {
        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
    }
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: attributes, media: message.media)
}

/// Whether a server-side removal of this message may be turned into a local "deleted" mark.
private func ghostCanKeep(_ message: Message) -> Bool {
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    if message.id.namespace != Namespaces.Message.Cloud {
        return false
    }
    return true
}

/// Marks the messages as deleted instead of removing them, when the user wants deleted messages kept.
/// Returns the ids that must still be deleted for real.
func ghostKeepDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    if !GhostSettings.keepDeletedMessages {
        return ids
    }
    var remaining: [MessageId] = []
    let now = ghostCurrentTimestamp()
    for id in ids {
        guard let message = transaction.getMessage(id), ghostCanKeep(message) else {
            remaining.append(id)
            continue
        }
        if message.ghostDeletedAttribute != nil {
            continue
        }
        transaction.updateMessage(id, update: { current in
            var attributes = current.attributes
            attributes.append(GhostDeletedMessageAttribute(date: now))
            return .update(ghostStoreMessage(current, attributes: attributes))
        })
    }
    return remaining
}

/// Global-id variant, used by private chats and basic groups.
func ghostKeepDeletedMessagesWithGlobalIds(transaction: Transaction, ids: [Int32]) -> [Int32] {
    if !GhostSettings.keepDeletedMessages {
        return ids
    }
    var remaining: [Int32] = []
    for globalId in ids {
        let messageIds = transaction.messageIdsForGlobalIds([globalId])
        if messageIds.isEmpty {
            remaining.append(globalId)
            continue
        }
        if !ghostKeepDeletedMessages(transaction: transaction, ids: messageIds).isEmpty {
            remaining.append(globalId)
        }
    }
    return remaining
}

private func ghostIsExpired(_ media: [Media]) -> Bool {
    return media.contains(where: { $0 is TelegramMediaExpiredContent })
}

private func ghostHasViewableMedia(_ media: [Media]) -> Bool {
    return media.contains(where: { $0 is TelegramMediaImage || $0 is TelegramMediaFile })
}

/// Applied to an incoming edit: records the previous text and keeps view-once media from being wiped.
func ghostAdjustEditedMessage(previous: Message, updated: StoreMessage) -> StoreMessage {
    var result = updated
    if GhostSettings.keepViewOnceMedia && ghostIsExpired(updated.media) && ghostHasViewableMedia(previous.media) {
        result = result.withUpdatedMedia(previous.media.filter { !($0 is TelegramMediaExpiredContent) })
    }
    if GhostSettings.keepEditHistory && previous.text != updated.text && !previous.text.isEmpty {
        var entries = previous.ghostEditHistory
        let previousDate = previous.editedTime ?? previous.timestamp
        if entries.last?.text != previous.text {
            entries.append(GhostEditHistoryMessageAttribute.Entry(text: previous.text, date: previousDate))
        }
        var attributes = result.attributes.filter { !($0 is GhostEditHistoryMessageAttribute) }
        attributes.append(GhostEditHistoryMessageAttribute(entries: entries))
        result = result.withUpdatedAttributes(attributes)
    }
    return result
}

/// Keeps the GhostGram attributes across every Postbox update (holes, refetches, edits).
func ghostMergeMessageAttributes(previous: [MessageAttribute], updated: inout [MessageAttribute]) {
    if let deleted = previous.first(where: { $0 is GhostDeletedMessageAttribute }), !updated.contains(where: { $0 is GhostDeletedMessageAttribute }) {
        updated.append(deleted)
    }
    if let history = previous.first(where: { $0 is GhostEditHistoryMessageAttribute }), !updated.contains(where: { $0 is GhostEditHistoryMessageAttribute }) {
        updated.append(history)
    }
}

/// Instead of wiping an opened view-once or self-destructing message (isRemove == false), or removing a message
/// whose auto-delete timer fired (isRemove == true), keeps it as a normal message. Returns true when it was kept.
func ghostKeepAutoremovedMessage(transaction: Transaction, id: MessageId, isRemove: Bool) -> Bool {
    if isRemove {
        if !GhostSettings.keepDeletedMessages {
            return false
        }
    } else if !GhostSettings.keepViewOnceMedia {
        return false
    }
    guard let message = transaction.getMessage(id), ghostCanKeep(message) else {
        return false
    }
    let now = ghostCurrentTimestamp()
    transaction.updateMessage(id, update: { current in
        var attributes = current.attributes.filter { !($0 is AutoremoveTimeoutMessageAttribute) && !($0 is AutoclearTimeoutMessageAttribute) }
        if isRemove && !attributes.contains(where: { $0 is GhostDeletedMessageAttribute }) {
            attributes.append(GhostDeletedMessageAttribute(date: now))
        }
        return .update(ghostStoreMessage(current, attributes: attributes))
    })
    return true
}
