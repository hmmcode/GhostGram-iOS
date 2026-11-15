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

    plugins.sendVoice = { [weak account] chatId, bars, seconds, replyTo in
        guard let account = account, let rawId = Int64(chatId) else {
            return
        }
        let peerId = PeerId(rawId)
        var reply: EngineMessageReplySubject?
        if replyTo != 0 {
            reply = EngineMessageReplySubject(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyTo), quote: nil, innerSubject: nil)
        }
        let audio = ghostSilentOggOpus(seconds: seconds)
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        let resource = LocalFileMediaResource(fileId: randomId)
        account.postbox.mediaBox.storeResourceData(resource.id, data: audio)
        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(audio.count), attributes: [.Audio(isVoice: true, duration: seconds, title: nil, performer: nil, waveform: ghostWaveformBitstream(bars))], alternativeRepresentations: [])
        let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: reply, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
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


/// Packs bar heights (0...31) into Telegram's 5-bit little-endian waveform bitstream.
func ghostWaveformBitstream(_ bars: [Int]) -> Data {
    let bitCount = bars.count * 5
    var bytes = [UInt8](repeating: 0, count: (bitCount + 7) / 8)
    for (index, bar) in bars.enumerated() {
        let value = max(0, min(31, bar))
        for bit in 0 ..< 5 where (value >> bit) & 1 == 1 {
            let position = index * 5 + bit
            bytes[position / 8] |= UInt8(1 << (position % 8))
        }
    }
    return Data(bytes)
}

private let ghostOggCrcTable: [UInt32] = (0 ..< 256).map { index -> UInt32 in
    var crc = UInt32(index) << 24
    for _ in 0 ..< 8 {
        crc = (crc & 0x80000000) != 0 ? (crc << 1) ^ 0x04C11DB7 : (crc << 1)
    }
    return crc
}

private func ghostOggPage(packets: [[UInt8]], headerType: UInt8, granule: Int64, serial: UInt32, sequence: UInt32) -> Data {
    var segments: [UInt8] = []
    var body: [UInt8] = []
    for packet in packets {
        var remaining = packet.count
        while remaining >= 255 {
            segments.append(255)
            remaining -= 255
        }
        segments.append(UInt8(remaining))
        body.append(contentsOf: packet)
    }
    var page: [UInt8] = Array("OggS".utf8)
    page.append(0)
    page.append(headerType)
    withUnsafeBytes(of: UInt64(bitPattern: granule).littleEndian) { page.append(contentsOf: $0) }
    withUnsafeBytes(of: serial.littleEndian) { page.append(contentsOf: $0) }
    withUnsafeBytes(of: sequence.littleEndian) { page.append(contentsOf: $0) }
    let crcOffset = page.count
    page.append(contentsOf: [0, 0, 0, 0])
    page.append(UInt8(segments.count))
    page.append(contentsOf: segments)
    page.append(contentsOf: body)
    var crc: UInt32 = 0
    for byte in page {
        crc = (crc << 8) ^ ghostOggCrcTable[Int(((crc >> 24) & 0xff) ^ UInt32(byte))]
    }
    withUnsafeBytes(of: crc.littleEndian) { raw in
        for i in 0 ..< 4 {
            page[crcOffset + i] = raw[i]
        }
    }
    return Data(page)
}

/// A valid mono Ogg Opus file of the given length made of silent 20 ms frames.
func ghostSilentOggOpus(seconds: Int) -> Data {
    let serial = UInt32.random(in: 1 ... UInt32.max)
    let preSkip: UInt16 = 312
    var head: [UInt8] = Array("OpusHead".utf8)
    head.append(1)
    head.append(1)
    withUnsafeBytes(of: preSkip.littleEndian) { head.append(contentsOf: $0) }
    withUnsafeBytes(of: UInt32(48000).littleEndian) { head.append(contentsOf: $0) }
    head.append(contentsOf: [0, 0, 0])
    var tags: [UInt8] = Array("OpusTags".utf8)
    let vendor = Array("GhostGram".utf8)
    withUnsafeBytes(of: UInt32(vendor.count).littleEndian) { tags.append(contentsOf: $0) }
    tags.append(contentsOf: vendor)
    tags.append(contentsOf: [0, 0, 0, 0])

    var result = Data()
    var sequence: UInt32 = 0
    result.append(ghostOggPage(packets: [head], headerType: 0x02, granule: 0, serial: serial, sequence: sequence))
    sequence += 1
    result.append(ghostOggPage(packets: [tags], headerType: 0x00, granule: 0, serial: serial, sequence: sequence))
    sequence += 1

    let silentFrame: [UInt8] = [0xF8, 0xFF, 0xFE]
    let totalFrames = max(1, seconds) * 50
    var written = 0
    while written < totalFrames {
        let count = min(50, totalFrames - written)
        written += count
        let isLast = written == totalFrames
        let granule = Int64(preSkip) + Int64(written) * 960
        result.append(ghostOggPage(packets: Array(repeating: silentFrame, count: count), headerType: isLast ? 0x04 : 0x00, granule: granule, serial: serial, sequence: sequence))
        sequence += 1
    }
    return result
}
