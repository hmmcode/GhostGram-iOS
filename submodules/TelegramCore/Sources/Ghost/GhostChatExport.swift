import Foundation
import Postbox
import SwiftSignalKit

/// One message of a chat export, already reduced to plain values.
public struct GhostExportedMessage {
    public let id: Int32
    public let timestamp: Int32
    public let author: String?
    public let authorId: Int64?
    public let text: String
    public let media: String?
}

private func ghostExportMediaLabel(_ message: Message) -> String? {
    for media in message.media {
        if media is TelegramMediaImage {
            return "фото"
        }
        if let file = media as? TelegramMediaFile {
            if file.isVoice {
                return "голосовое"
            } else if file.isInstantVideo {
                return "кружок"
            } else if file.isMusic {
                return "музыка"
            } else if file.isVideo {
                return "видео"
            } else if file.isSticker || file.isAnimatedSticker {
                return "стикер"
            } else {
                return "файл"
            }
        }
        if media is TelegramMediaMap {
            return "геопозиция"
        }
        if media is TelegramMediaContact {
            return "контакт"
        }
        if media is TelegramMediaPoll {
            return "опрос"
        }
    }
    return nil
}

/// The messages of a chat that are stored on this device, oldest first.
public func ghostLoadChatForExport(account: Account, peerId: EnginePeer.Id, limit: Int) -> Signal<[GhostExportedMessage], NoError> {
    return account.postbox.transaction { transaction -> [GhostExportedMessage] in
        var messages: [Message] = []
        transaction.scanTopMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: limit, { message in
            messages.append(message)
            return true
        })
        messages.sort(by: { $0.index < $1.index })
        return messages.map { message in
            return GhostExportedMessage(
                id: message.id.id,
                timestamp: message.timestamp,
                author: message.author?.debugDisplayTitle,
                authorId: message.author?.id.id._internalGetInt64Value(),
                text: message.text,
                media: ghostExportMediaLabel(message)
            )
        }
    }
}
