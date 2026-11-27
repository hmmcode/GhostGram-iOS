import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import AlertUI
import PresentationDataUtils
import PromptUI

/// The "GhostGram…" menu for a chat in the chat list.
func ghostOpenChatActions(context: AccountContext, peerId: EnginePeer.Id, controller: ViewController?) {
    guard let controller = controller else {
        return
    }
    let id = peerId.toInt64()
    let isUser = peerId.namespace == Namespaces.Peer.CloudUser
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    var actions: [TextAlertAction] = []

    let fakeTitle: String
    if let raw = GhostSettings.fakeActivities[id], let title = GhostFakeCustom.title(raw) {
        fakeTitle = "🎭 Статус: \(title)"
    } else {
        fakeTitle = "🎭 Фейковый статус…"
    }
    actions.append(TextAlertAction(type: .genericAction, title: fakeTitle, action: { [weak controller] in
        ghostChooseFakeActivity(context: context, peerId: peerId, controller: controller)
    }))

    let isLocked = GhostSettings.lockedChats.contains(id)
    actions.append(TextAlertAction(type: .genericAction, title: isLocked ? "🔓 Убрать Face ID" : "🔒 Закрыть по Face ID", action: {
        var locked = GhostSettings.lockedChats
        if isLocked {
            locked.remove(id)
        } else {
            locked.insert(id)
        }
        GhostSettings.lockedChats = locked
    }))

    let isException = GhostSettings.ghostExceptions.contains(id)
    actions.append(TextAlertAction(type: .genericAction, title: isException ? "👻 Включить призрака здесь" : "👁 Без призрака в этом чате", action: {
        var exceptions = GhostSettings.ghostExceptions
        if isException {
            exceptions.remove(id)
        } else {
            exceptions.insert(id)
        }
        GhostSettings.ghostExceptions = exceptions
    }))

    if isUser {
        let isWatched = GhostSettings.onlineWatchList.contains(id)
        actions.append(TextAlertAction(type: .genericAction, title: isWatched ? "🔕 Не сообщать о «в сети»" : "🟢 Сообщать, когда в сети", action: {
            var watched = GhostSettings.onlineWatchList
            if isWatched {
                watched.remove(id)
            } else {
                watched.insert(id)
            }
            GhostSettings.onlineWatchList = watched
        }))
        actions.append(TextAlertAction(type: .genericAction, title: "✏️ Локальное имя…", action: { [weak controller] in
            let prompt = promptController(context: context, text: "Имя только для вас", value: GhostSettings.nickname(for: id) ?? "", placeholder: "Пусто — настоящее имя", characterLimit: 64, apply: { value in
                guard let value = value else {
                    return
                }
                var nicknames = GhostSettings.nicknames
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    nicknames.removeValue(forKey: id)
                } else {
                    nicknames[id] = trimmed
                }
                GhostSettings.nicknames = nicknames
            })
            controller?.present(prompt, in: .window(.root))
        }))
    }

    actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}))
    controller.present(textAlertController(context: context, title: "👻 GhostGram", text: "", actions: actions, actionLayout: .vertical), in: .window(.root))
}

/// Picks the fake activity shown in a chat.
func ghostChooseFakeActivity(context: AccountContext, peerId: EnginePeer.Id, controller: ViewController?) {
    guard let controller = controller else {
        return
    }
    let id = peerId.toInt64()
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var actions: [TextAlertAction] = []
    for kind in GhostFakeActivityKind.allCases {
        actions.append(TextAlertAction(type: .genericAction, title: kind.title, action: {
            var items = GhostSettings.fakeActivities
            items[id] = kind.rawValue
            GhostSettings.fakeActivities = items
        }))
    }
    let current = GhostSettings.fakeActivities[id] ?? ""
    for (prefix, title, hint) in [
        (GhostFakeCustom.textPrefix, "✏️ Свой текст (эксперимент)", "Собеседник увидит под твоим именем служебное слово Telegram и твой текст, например «смотрит крутой 😎»."),
        (GhostFakeCustom.draftPrefix, "💬 Живой черновик (эксперимент)", "Собеседник увидит в чате пузырь, где этот текст как будто набирается. Работает, только если сервер разрешит это обычным аккаунтам.")
    ] {
        actions.append(TextAlertAction(type: .genericAction, title: title, action: { [weak controller] in
            let value = current.hasPrefix(prefix) ? (GhostFakeCustom.text(current) ?? "") : ""
            let prompt = promptController(context: context, text: hint, value: value, placeholder: "крутой 😎", characterLimit: 64, apply: { text in
                guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    return
                }
                var items = GhostSettings.fakeActivities
                items[id] = prefix + text
                GhostSettings.fakeActivities = items
                GhostSettings.fakeActivitiesEnabled = true
            })
            controller?.present(prompt, in: .window(.root))
        }))
    }
    if GhostSettings.fakeActivities[id] != nil {
        actions.append(TextAlertAction(type: .destructiveAction, title: "Выключить", action: {
            var items = GhostSettings.fakeActivities
            items.removeValue(forKey: id)
            GhostSettings.fakeActivities = items
        }))
    }
    actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}))
    controller.present(textAlertController(context: context, title: "Фейковый статус", text: "Собеседник будет постоянно видеть выбранный статус, пока GhostGram открыт или работает в фоне.", actions: actions, actionLayout: .vertical), in: .window(.root))
}
