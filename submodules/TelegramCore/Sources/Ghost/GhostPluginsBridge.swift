import Foundation
import Postbox
import SwiftSignalKit

// Connects the plugin runtime (GhostPluginRuntime.swift) to a Telegram account.

private let ghostPluginBridgeLock = NSLock()
private var ghostPluginBridgeAccounts: [AccountRecordId] = []
private var ghostPluginBridgeDisposables: [Disposable] = []
private var ghostPluginChatTitles: [Int64: String] = [:]

private func ghostPluginUserName(_ user: TelegramUser) -> String {
    let name = [user.firstName ?? "", ghostStripNameMarker(user.lastName ?? "")].filter { !$0.isEmpty }.joined(separator: " ")
    return name.isEmpty ? (user.username ?? "") : name
}

private func ghostPluginPeerName(_ peer: Peer?) -> String {
    if let user = peer as? TelegramUser {
        return ghostPluginUserName(user)
    } else if let group = peer as? TelegramGroup {
        return group.title
    } else if let channel = peer as? TelegramChannel {
        return channel.title
    }
    return ""
}

private func ghostPluginChatType(_ peerId: PeerId, accountPeerId: PeerId) -> String {
    if peerId == accountPeerId {
        return "saved"
    }
    switch peerId.namespace {
    case Namespaces.Peer.CloudUser:
        return "private"
    case Namespaces.Peer.CloudGroup:
        return "group"
    case Namespaces.Peer.CloudChannel:
        return "channel"
    case Namespaces.Peer.SecretChat:
        return "secret"
    default:
        return "private"
    }
}

private func ghostPluginMediaType(_ message: Message) -> String {
    for media in message.media {
        if media is TelegramMediaImage {
            return "photo"
        } else if let file = media as? TelegramMediaFile {
            if file.isSticker {
                return "sticker"
            } else if file.isVoice {
                return "voice"
            } else if file.isInstantVideo {
                return "round"
            } else if file.isVideo {
                return "video"
            } else if file.isMusic {
                return "music"
            }
            return "file"
        }
    }
    return message.media.isEmpty ? "" : "other"
}

private func ghostPluginPayload(_ message: Message, notify: Bool, accountPeerId: PeerId) -> [String: Any] {
    let peerId = message.id.peerId
    let chatPeer = message.peers[peerId]
    var chatType = ghostPluginChatType(peerId, accountPeerId: accountPeerId)
    if let channel = chatPeer as? TelegramChannel {
        if case .broadcast = channel.info {
            chatType = "channel"
        } else {
            chatType = "group"
        }
    }
    var chatTitle = ghostPluginPeerName(chatPeer)
    let author = message.author
    let fromName = ghostPluginPeerName(author)
    if chatTitle.isEmpty {
        chatTitle = fromName
    }
    var fromIsBot = false
    if let user = author as? TelegramUser {
        fromIsBot = user.botInfo != nil
    }
    var replyTo = 0
    for attribute in message.attributes {
        if let attribute = attribute as? ReplyMessageAttribute {
            replyTo = Int(attribute.messageId.id)
        }
    }
    ghostPluginBridgeLock.lock()
    ghostPluginChatTitles[peerId.toInt64()] = chatTitle
    ghostPluginBridgeLock.unlock()
    return [
        "id": Int(message.id.id),
        "chatId": "\(peerId.toInt64())",
        "chatType": chatType,
        "chatTitle": chatTitle,
        "fromId": author.flatMap { "\($0.id.toInt64())" } ?? "",
        "fromUserId": author.flatMap { "\($0.id.id._internalGetInt64Value())" } ?? "",
        "fromName": fromName,
        "fromUsername": author?.addressName ?? "",
        "fromIsBot": fromIsBot,
        "text": message.text,
        "date": Int(message.timestamp),
        "out": !message.flags.contains(.Incoming),
        "muted": !notify,
        "replyTo": replyTo,
        "media": ghostPluginMediaType(message)
    ]
}

/// Runs plugin hooks on text messages the user sends. `nil` means a plugin cancelled the message.
func ghostPluginsTransformOutgoing(accountPeerId: PeerId, peerId: PeerId, messages: [EnqueueMessage]) -> [EnqueueMessage?] {
    let plugins = GhostPlugins.shared
    return messages.map { message -> EnqueueMessage? in
        guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message, mediaReference == nil, !text.isEmpty else {
            return message
        }
        ghostPluginBridgeLock.lock()
        let title = ghostPluginChatTitles[peerId.toInt64()] ?? ""
        ghostPluginBridgeLock.unlock()
        let decision = plugins.transformOutgoing(
            chatId: "\(peerId.toInt64())",
            chatType: ghostPluginChatType(peerId, accountPeerId: accountPeerId),
            chatTitle: title,
            text: text,
            replyTo: replyToMessageId?.messageId.id ?? 0
        )
        switch decision {
        case .keep:
            return message
        case .cancel:
            return nil
        case let .replace(newText):
            if newText == text {
                return message
            }
            if newText.isEmpty {
                return nil
            }
            let updatedAttributes = attributes.filter { !($0 is TextEntitiesMessageAttribute) }
            return .message(text: newText, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        }
    }
}

private func ghostPluginLoadFile(account: Account, message: Message, file: TelegramMediaFile) -> Signal<(String, String?), NoError> {
    let name = file.fileName ?? "plugin.js"
    return Signal<(String, String?), NoError> { subscriber in
        let reference = MediaResourceReference.media(media: AnyMediaReference.message(message: MessageReference(message), media: file), resource: file.resource)
        let fetchDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(account.peerId), userContentType: .file, reference: reference).start()
        let dataDisposable = (account.postbox.mediaBox.resourceData(file.resource)
        |> filter { $0.complete }
        |> take(1)).start(next: { data in
            let contents = (try? Data(contentsOf: URL(fileURLWithPath: data.path))).flatMap { String(data: $0, encoding: .utf8) }
            subscriber.putNext((name, contents))
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetchDisposable.dispose()
            dataDisposable.dispose()
        }
    }
    |> timeout(30.0, queue: Queue.concurrentDefaultQueue(), alternate: .single((name, nil)))
}

/// Connects plugins to an account: sending, incoming messages, "me", Saved Messages import.
public func ghostPluginsAttach(account: Account) {
    ghostPluginBridgeLock.lock()
    if ghostPluginBridgeAccounts.contains(account.id) {
        ghostPluginBridgeLock.unlock()
        return
    }
    ghostPluginBridgeAccounts.append(account.id)
    ghostPluginBridgeLock.unlock()

    let plugins = GhostPlugins.shared
    let accountPeerId = account.peerId

    plugins.sendMessage = { [weak account] chatId, text, replyTo in
        guard let account = account, let rawId = Int64(chatId) else {
            return
        }
        let peerId = PeerId(rawId)
        var reply: EngineMessageReplySubject?
        if replyTo != 0 {
            reply = EngineMessageReplySubject(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyTo), quote: nil, innerSubject: nil)
        }
        let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: reply, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
    }

    plugins.savedMessagesFiles = { [weak account] completion in
        guard let account = account else {
            completion([])
            return
        }
        let _ = (account.postbox.transaction { transaction -> [(Message, TelegramMediaFile)] in
            var result: [(Message, TelegramMediaFile)] = []
            var names = Set<String>()
            transaction.scanTopMessages(peerId: account.peerId, namespace: Namespaces.Message.Cloud, limit: 400, { message in
                for media in message.media {
                    if let file = media as? TelegramMediaFile, let name = file.fileName, name.lowercased().hasSuffix(".js"), !names.contains(name) {
                        names.insert(name)
                        result.append((message, file))
                    }
                }
                return result.count < 20
            })
            return result
        }
        |> mapToSignal { items -> Signal<[(String, String)], NoError> in
            if items.isEmpty {
                return .single([])
            }
            let signals = items.map { item -> Signal<(String, String?), NoError> in
                return ghostPluginLoadFile(account: account, message: item.0, file: item.1)
            }
            return combineLatest(signals)
            |> map { loaded -> [(String, String)] in
                var files: [(String, String)] = []
                for (name, contents) in loaded {
                    if let contents = contents {
                        files.append((name, contents))
                    }
                }
                return files
            }
        }).start(next: { files in
            completion(files)
        })
    }

    let _ = (account.postbox.transaction { transaction -> [String: Any] in
        guard let user = transaction.getPeer(accountPeerId) as? TelegramUser else {
            return [:]
        }
        return [
            "id": "\(accountPeerId.id._internalGetInt64Value())",
            "chatId": "\(accountPeerId.toInt64())",
            "name": ghostPluginUserName(user),
            "username": user.username ?? ""
        ]
    }).start(next: { info in
        if !info.isEmpty {
            GhostPlugins.shared.setMe(info)
        }
    })

    let disposable = account.stateManager.notificationMessages.start(next: { list in
        if !GhostPlugins.shared.hasRunningPlugins {
            return
        }
        for (messages, _, notify, _) in list {
            for message in messages {
                GhostPlugins.shared.dispatchIncoming(ghostPluginPayload(message, notify: notify, accountPeerId: accountPeerId))
            }
        }
    })
    ghostPluginBridgeLock.lock()
    ghostPluginBridgeDisposables.append(disposable)
    ghostPluginBridgeLock.unlock()

    plugins.start()
}
