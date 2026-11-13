import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TextFormat
import LocalizedPeerData
import LocalAuthentication

/// Posted after any GhostGram option changes (the Dynamic Island listens for it).
public let ghostGramSettingsChangedNotification = Notification.Name("GhostGramSettingsChanged")

// MARK: - Options

private enum GhostToggle: Int32 {
    case hideRead
    case readOnReply
    case hideStoryViews
    case hideOnline
    case hideTyping
    case keepDeleted
    case keepEditHistory
    case keepViewOnce
    case notifyOnDelete
    case deletedLog
    case autoCache
    case autoCachePhotos
    case autoCacheVideos
    case autoCacheVoice
    case autoCacheFiles
    case bypassCopyProtection
    case hideScreenshots
    case hideSponsored
    case hideStories
    case hidePhone
    case confirmVoice
    case confirmStickers
    case extendedSpeeds
    case messageDetails
    case dynamicIsland
    case hiddenChats

    var title: String {
        switch self {
        case .hideRead: return "Не отправлять «прочитано»"
        case .readOnReply: return "Читать при ответе"
        case .hideStoryViews: return "Смотреть истории незаметно"
        case .hideOnline: return "Скрывать «в сети»"
        case .hideTyping: return "Скрывать «печатает…»"
        case .keepDeleted: return "Сохранять удалённые"
        case .keepEditHistory: return "Сохранять историю правок"
        case .keepViewOnce: return "Не сжигать одноразовые медиа"
        case .notifyOnDelete: return "Уведомлять об удалении"
        case .deletedLog: return "Вести журнал удалённых"
        case .autoCache: return "Автосохранение из личек"
        case .autoCachePhotos: return "Фото"
        case .autoCacheVideos: return "Видео"
        case .autoCacheVoice: return "Голосовые и кружки"
        case .autoCacheFiles: return "Файлы"
        case .bypassCopyProtection: return "Обходить запрет копирования"
        case .hideScreenshots: return "Скриншоты без уведомления"
        case .hideSponsored: return "Убрать рекламу в каналах"
        case .hideStories: return "Скрыть полосу историй"
        case .hidePhone: return "Скрыть мой номер"
        case .confirmVoice: return "Подтверждать голосовые"
        case .confirmStickers: return "Подтверждать стикеры"
        case .extendedSpeeds: return "Скорость до 3x"
        case .messageDetails: return "«Подробности» в меню"
        case .dynamicIsland: return "Призрак в Dynamic Island"
        case .hiddenChats: return "Скрытые чаты"
        }
    }

    var value: Bool {
        switch self {
        case .hideRead: return GhostSettings.hideReadReceipts
        case .readOnReply: return GhostSettings.readOnReply
        case .hideStoryViews: return GhostSettings.hideStoryViews
        case .hideOnline: return GhostSettings.hideOnlineStatus
        case .hideTyping: return GhostSettings.hideTyping
        case .keepDeleted: return GhostSettings.keepDeletedMessages
        case .keepEditHistory: return GhostSettings.keepEditHistory
        case .keepViewOnce: return GhostSettings.keepViewOnceMedia
        case .notifyOnDelete: return GhostSettings.notifyOnDelete
        case .deletedLog: return GhostSettings.keepDeletedLog
        case .autoCache: return GhostSettings.autoCachePrivateMedia
        case .autoCachePhotos: return GhostSettings.autoCachePhotos
        case .autoCacheVideos: return GhostSettings.autoCacheVideos
        case .autoCacheVoice: return GhostSettings.autoCacheVoice
        case .autoCacheFiles: return GhostSettings.autoCacheFiles
        case .bypassCopyProtection: return GhostSettings.bypassCopyProtection
        case .hideScreenshots: return GhostSettings.hideScreenshotNotifications
        case .hideSponsored: return GhostSettings.hideSponsoredMessages
        case .hideStories: return GhostSettings.hideStoriesBar
        case .hidePhone: return GhostSettings.hidePhoneNumber
        case .confirmVoice: return GhostSettings.confirmVoice
        case .confirmStickers: return GhostSettings.confirmStickers
        case .extendedSpeeds: return GhostSettings.extendedPlaybackSpeeds
        case .messageDetails: return GhostSettings.showMessageDetails
        case .dynamicIsland: return GhostSettings.dynamicIsland
        case .hiddenChats: return GhostSettings.hiddenChatsEnabled
        }
    }

    func set(_ value: Bool) {
        switch self {
        case .hideRead: GhostSettings.hideReadReceipts = value
        case .readOnReply: GhostSettings.readOnReply = value
        case .hideStoryViews: GhostSettings.hideStoryViews = value
        case .hideOnline: GhostSettings.hideOnlineStatus = value
        case .hideTyping: GhostSettings.hideTyping = value
        case .keepDeleted: GhostSettings.keepDeletedMessages = value
        case .keepEditHistory: GhostSettings.keepEditHistory = value
        case .keepViewOnce: GhostSettings.keepViewOnceMedia = value
        case .notifyOnDelete: GhostSettings.notifyOnDelete = value
        case .deletedLog: GhostSettings.keepDeletedLog = value
        case .autoCache: GhostSettings.autoCachePrivateMedia = value
        case .autoCachePhotos: GhostSettings.autoCachePhotos = value
        case .autoCacheVideos: GhostSettings.autoCacheVideos = value
        case .autoCacheVoice: GhostSettings.autoCacheVoice = value
        case .autoCacheFiles: GhostSettings.autoCacheFiles = value
        case .bypassCopyProtection: GhostSettings.bypassCopyProtection = value
        case .hideScreenshots: GhostSettings.hideScreenshotNotifications = value
        case .hideSponsored: GhostSettings.hideSponsoredMessages = value
        case .hideStories: GhostSettings.hideStoriesBar = value
        case .hidePhone: GhostSettings.hidePhoneNumber = value
        case .confirmVoice: GhostSettings.confirmVoice = value
        case .confirmStickers: GhostSettings.confirmStickers = value
        case .extendedSpeeds: GhostSettings.extendedPlaybackSpeeds = value
        case .messageDetails: GhostSettings.showMessageDetails = value
        case .dynamicIsland: GhostSettings.dynamicIsland = value
        case .hiddenChats: GhostSettings.hiddenChatsEnabled = value
        }
    }
}

private enum GhostLink: Int32 {
    case exceptions
    case deletedLog
    case cacheLimit
    case hiddenChats
}

private final class GhostGramSettingsArguments {
    let toggle: (GhostToggle, Bool) -> Void
    let open: (GhostLink) -> Void

    init(toggle: @escaping (GhostToggle, Bool) -> Void, open: @escaping (GhostLink) -> Void) {
        self.toggle = toggle
        self.open = open
    }
}

private enum GhostGramSettingsEntry: ItemListNodeEntry {
    case header(id: Int32, section: Int32, text: String)
    case toggle(id: Int32, section: Int32, option: GhostToggle, value: Bool, enabled: Bool)
    case link(id: Int32, section: Int32, link: GhostLink, title: String, label: String)
    case footer(id: Int32, section: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .link(_, section, _, _, _), let .footer(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .link(id, _, _, _, _), let .footer(id, _, _):
            return id
        }
    }

    static func <(lhs: GhostGramSettingsEntry, rhs: GhostGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GhostGramSettingsArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, option, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: option.title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(option, value)
            })
        case let .link(_, _, link, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.open(link)
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func cacheLimitTitle(_ limitMB: Int) -> String {
    return limitMB <= 0 ? "Без лимита" : "\(limitMB) МБ"
}

private func ghostGramSettingsEntries() -> [GhostGramSettingsEntry] {
    var entries: [GhostGramSettingsEntry] = []
    var id: Int32 = 0
    func next() -> Int32 {
        id += 1
        return id
    }
    func toggle(_ section: Int32, _ option: GhostToggle, enabled: Bool = true) {
        entries.append(.toggle(id: next(), section: section, option: option, value: option.value, enabled: enabled))
    }

    entries.append(.header(id: next(), section: 0, text: "👻 РЕЖИМ ПРИЗРАКА"))
    toggle(0, .hideRead)
    toggle(0, .readOnReply, enabled: GhostSettings.hideReadReceipts)
    toggle(0, .hideStoryViews)
    toggle(0, .hideOnline)
    toggle(0, .hideTyping)
    entries.append(.link(id: next(), section: 0, link: .exceptions, title: "Исключения", label: "\(GhostSettings.ghostExceptions.count)"))
    entries.append(.footer(id: next(), section: 0, text: "Собеседник не увидит, что вы прочитали сообщение, прослушали голосовое или посмотрели историю. «Читать при ответе» отмечает чат прочитанным, когда вы сами пишете в него. В исключениях призрак не действует."))

    entries.append(.header(id: next(), section: 1, text: "🗑 СООБЩЕНИЯ"))
    toggle(1, .keepDeleted)
    toggle(1, .keepEditHistory)
    toggle(1, .keepViewOnce)
    toggle(1, .notifyOnDelete, enabled: GhostSettings.keepDeletedMessages)
    toggle(1, .deletedLog, enabled: GhostSettings.keepDeletedMessages)
    entries.append(.link(id: next(), section: 1, link: .deletedLog, title: "Журнал удалённых", label: "\(GhostDeletedLog.entries().count)"))
    entries.append(.footer(id: next(), section: 1, text: "Удалённые сообщения остаются в чате со значком 🗑. Старые версии правок — в меню сообщения → «История правок». Сохраняется только то, что успело прийти на телефон."))

    entries.append(.header(id: next(), section: 2, text: "📥 МЕДИА"))
    toggle(2, .autoCache)
    let cacheOn = GhostSettings.autoCachePrivateMedia
    toggle(2, .autoCachePhotos, enabled: cacheOn)
    toggle(2, .autoCacheVideos, enabled: cacheOn)
    toggle(2, .autoCacheVoice, enabled: cacheOn)
    toggle(2, .autoCacheFiles, enabled: cacheOn)
    entries.append(.link(id: next(), section: 2, link: .cacheLimit, title: "Максимальный размер", label: cacheLimitTitle(GhostSettings.autoCacheLimitMB)))
    entries.append(.footer(id: next(), section: 2, text: "Медиа из личных чатов скачивается сразу, поэтому остаётся у вас, даже если собеседник его удалит."))

    entries.append(.header(id: next(), section: 3, text: "🔓 КОНТЕНТ"))
    toggle(3, .bypassCopyProtection)
    toggle(3, .hideScreenshots)
    toggle(3, .hideSponsored)
    toggle(3, .hideStories)
    entries.append(.footer(id: next(), section: 3, text: "Обход запрета позволяет сохранять и копировать из защищённых чатов и каналов. Пересылку оттуда сервер всё равно не пропустит."))

    entries.append(.header(id: next(), section: 4, text: "✨ ИНТЕРФЕЙС"))
    toggle(4, .hidePhone)
    toggle(4, .confirmVoice)
    toggle(4, .confirmStickers)
    toggle(4, .extendedSpeeds)
    toggle(4, .messageDetails)
    toggle(4, .dynamicIsland)
    entries.append(.footer(id: next(), section: 4, text: "Подтверждение голосовых: после записи откроется предпросмотр, отправка — кнопкой. Dynamic Island показывает 👻, пока включён режим призрака."))

    entries.append(.header(id: next(), section: 5, text: "🔒 СКРЫТЫЕ ЧАТЫ"))
    toggle(5, .hiddenChats)
    entries.append(.link(id: next(), section: 5, link: .hiddenChats, title: "Открыть скрытые чаты", label: "\(GhostSettings.hiddenChats.count)"))
    entries.append(.footer(id: next(), section: 5, text: "Скрыть чат: долгое нажатие на чат в списке → «Скрыть чат». Скрытые чаты открываются отсюда по Face ID."))
    return entries
}

private func ghostPushController(_ from: ViewController?, _ controller: ViewController) {
    if let navigationController = from?.navigationController as? NavigationController {
        navigationController.pushViewController(controller)
    } else {
        from?.push(controller)
    }
}

private func ghostOpenChat(context: AccountContext, from: ViewController?, peerId: EnginePeer.Id, messageId: EngineMessage.Id?) {
    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> deliverOnMainQueue).start(next: { [weak from] peer in
        guard let peer = peer, let navigationController = from?.navigationController as? NavigationController else {
            return
        }
        var subject: ChatControllerSubject?
        if let messageId = messageId {
            subject = .message(id: .id(messageId), highlight: nil, timecode: nil, setupReply: false)
        }
        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: subject))
    })
}

public func ghostGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    var currentRevision = 0
    let refresh: () -> Void = {
        currentRevision += 1
        revision.set(currentRevision)
    }

    var openImpl: ((GhostLink) -> Void)?

    let arguments = GhostGramSettingsArguments(toggle: { option, value in
        option.set(value)
        NotificationCenter.default.post(name: ghostGramSettingsChangedNotification, object: nil)
        refresh()
    }, open: { link in
        openImpl?(link)
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("GhostGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ghostGramSettingsEntries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { _ in
        refresh()
    }

    openImpl = { [weak controller] link in
        guard let controller = controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch link {
        case .exceptions:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .exceptions))
        case .deletedLog:
            ghostPushController(controller, ghostDeletedLogController(context: context))
        case .cacheLimit:
            var actions: [TextAlertAction] = []
            for limit in [10, 50, 200, 1000, 0] {
                actions.append(TextAlertAction(type: limit == GhostSettings.autoCacheLimitMB ? .defaultAction : .genericAction, title: cacheLimitTitle(limit), action: {
                    GhostSettings.autoCacheLimitMB = limit
                    refresh()
                }))
            }
            actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}))
            controller.present(textAlertController(context: context, title: "Максимальный размер", text: "Файлы больше этого размера не скачиваются автоматически.", actions: actions, actionLayout: .vertical), in: .window(.root))
        case .hiddenChats:
            let authContext = LAContext()
            var error: NSError?
            if authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                authContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Открыть скрытые чаты", reply: { [weak controller] success, _ in
                    DispatchQueue.main.async {
                        if success {
                            ghostPushController(controller, ghostPeerListController(context: context, kind: .hidden))
                        }
                    }
                })
            } else {
                ghostPushController(controller, ghostPeerListController(context: context, kind: .hidden))
            }
        }
    }

    return controller
}

// MARK: - Chat lists (exceptions, hidden chats)

private enum GhostPeerListKind {
    case exceptions
    case hidden

    var title: String {
        switch self {
        case .exceptions: return "Исключения"
        case .hidden: return "Скрытые чаты"
        }
    }

    var peerIds: Set<Int64> {
        get {
            switch self {
            case .exceptions: return GhostSettings.ghostExceptions
            case .hidden: return GhostSettings.hiddenChats
            }
        }
    }

    func setPeerIds(_ value: Set<Int64>) {
        switch self {
        case .exceptions: GhostSettings.ghostExceptions = value
        case .hidden: GhostSettings.hiddenChats = value
        }
    }
}

private final class GhostPeerListArguments {
    let context: AccountContext
    let select: (EnginePeer) -> Void
    let add: () -> Void

    init(context: AccountContext, select: @escaping (EnginePeer) -> Void, add: @escaping () -> Void) {
        self.context = context
        self.select = select
        self.add = add
    }
}

private enum GhostPeerListEntry: ItemListNodeEntry {
    case add(title: String)
    case peer(index: Int32, peer: EnginePeer, title: String)
    case footer(text: String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int64 {
        switch self {
        case .add:
            return -2
        case let .peer(_, peer, _):
            return peer.id.toInt64()
        case .footer:
            return -1
        }
    }

    private var sortIndex: Int32 {
        switch self {
        case .add:
            return 0
        case let .peer(index, _, _):
            return 1 + index
        case .footer:
            return Int32.max
        }
    }

    static func ==(lhs: GhostPeerListEntry, rhs: GhostPeerListEntry) -> Bool {
        switch lhs {
        case let .add(title):
            if case .add(title) = rhs {
                return true
            }
            return false
        case let .peer(index, peer, title):
            if case let .peer(rhsIndex, rhsPeer, rhsTitle) = rhs, index == rhsIndex, peer.id == rhsPeer.id, title == rhsTitle {
                return true
            }
            return false
        case let .footer(text):
            if case .footer(text) = rhs {
                return true
            }
            return false
        }
    }

    static func <(lhs: GhostPeerListEntry, rhs: GhostPeerListEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GhostPeerListArguments
        switch self {
        case let .add(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case let .peer(_, peer, title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, context: arguments.context, iconPeer: peer, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.select(peer)
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ghostPeerListController(context: AccountContext, kind: GhostPeerListKind) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    var currentRevision = 0
    let refresh: () -> Void = {
        currentRevision += 1
        revision.set(currentRevision)
    }

    var selectImpl: ((EnginePeer) -> Void)?
    var addImpl: (() -> Void)?
    let arguments = GhostPeerListArguments(context: context, select: { peer in
        selectImpl?(peer)
    }, add: {
        addImpl?()
    })

    let peers: Signal<[EnginePeer], NoError> = revision.get()
    |> mapToSignal { _ -> Signal<[EnginePeer], NoError> in
        let ids = kind.peerIds.sorted().map { EnginePeer.Id($0) }
        return context.engine.data.subscribe(EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
        |> map { result -> [EnginePeer] in
            var peers: [EnginePeer] = []
            for id in ids {
                if let maybePeer = result[id], let peer = maybePeer {
                    peers.append(peer)
                }
            }
            return peers
        }
    }

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, peers)
    |> map { presentationData, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [GhostPeerListEntry] = []
        entries.append(.add(title: "Добавить чат"))
        for (index, peer) in peers.enumerated() {
            entries.append(.peer(index: Int32(index), peer: peer, title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)))
        }
        switch kind {
        case .exceptions:
            entries.append(.footer(text: "В этих чатах «прочитано» и «печатает» отправляются как обычно."))
        case .hidden:
            entries.append(.footer(text: "Эти чаты не показываются в списке чатов. Нажмите на чат, чтобы открыть его или вернуть в список."))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(kind.title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    selectImpl = { [weak controller] peer in
        guard let controller = controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var actions: [TextAlertAction] = []
        if case .hidden = kind {
            actions.append(TextAlertAction(type: .defaultAction, title: "Открыть чат", action: { [weak controller] in
                ghostOpenChat(context: context, from: controller, peerId: peer.id, messageId: nil)
            }))
        }
        actions.append(TextAlertAction(type: .destructiveAction, title: kind == .hidden ? "Вернуть в список чатов" : "Убрать из исключений", action: {
            var ids = kind.peerIds
            ids.remove(peer.id.toInt64())
            kind.setPeerIds(ids)
            refresh()
        }))
        actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}))
        controller.present(textAlertController(context: context, title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), text: "", actions: actions, actionLayout: .vertical), in: .window(.root))
    }

    addImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        let picker = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeSavedMessages, .doNotSearchMessages]))
        picker.peerSelected = { [weak picker] peer, _ in
            var ids = kind.peerIds
            ids.insert(peer.id.toInt64())
            kind.setPeerIds(ids)
            refresh()
            picker?.dismiss()
        }
        ghostPushController(controller, picker)
    }

    return controller
}

// MARK: - Deleted messages log

private final class GhostDeletedLogArguments {
    let open: (GhostDeletedLogEntry) -> Void
    let clear: () -> Void

    init(open: @escaping (GhostDeletedLogEntry) -> Void, clear: @escaping () -> Void) {
        self.open = open
        self.clear = clear
    }
}

private enum GhostDeletedLogListEntry: ItemListNodeEntry {
    case item(index: Int32, entry: GhostDeletedLogEntry, label: String)
    case empty
    case clear

    var section: ItemListSectionId {
        switch self {
        case .item, .empty:
            return 0
        case .clear:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case let .item(index, _, _):
            return index
        case .empty:
            return -1
        case .clear:
            return Int32.max
        }
    }

    static func <(lhs: GhostDeletedLogListEntry, rhs: GhostDeletedLogListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GhostDeletedLogArguments
        switch self {
        case let .item(_, entry, label):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: label, text: entry.text, style: .blocks, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: {
                arguments.open(entry)
            })
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Пока ничего не удаляли."), sectionId: self.section)
        case .clear:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Очистить журнал", kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.clear()
            })
        }
    }
}

private func ghostDeletedLogController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    var currentRevision = 0
    let refresh: () -> Void = {
        currentRevision += 1
        revision.set(currentRevision)
    }

    var openImpl: ((GhostDeletedLogEntry) -> Void)?
    var clearImpl: (() -> Void)?
    let arguments = GhostDeletedLogArguments(open: { entry in
        openImpl?(entry)
    }, clear: {
        clearImpl?()
    })

    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM HH:mm"

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [GhostDeletedLogListEntry] = []
        let logEntries = GhostDeletedLog.entries()
        if logEntries.isEmpty {
            entries.append(.empty)
        } else {
            for (index, entry) in logEntries.prefix(500).enumerated() {
                var label = entry.authorTitle
                if !entry.chatTitle.isEmpty && entry.chatTitle != entry.authorTitle {
                    label += " · \(entry.chatTitle)"
                }
                label += " · " + formatter.string(from: Date(timeIntervalSince1970: Double(entry.deletedAt)))
                entries.append(.item(index: Int32(index), entry: entry, label: label))
            }
            entries.append(.clear)
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Журнал удалённых"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    openImpl = { [weak controller] entry in
        guard let controller = controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(textAlertController(context: context, title: entry.authorTitle, text: entry.text, actions: [
            TextAlertAction(type: .defaultAction, title: "Перейти к сообщению", action: { [weak controller] in
                ghostOpenChat(context: context, from: controller, peerId: entry.messageId.peerId, messageId: entry.messageId)
            }),
            TextAlertAction(type: .genericAction, title: presentationData.strings.Conversation_ContextMenuCopy, action: {
                UIPasteboard.general.string = entry.text
            }),
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
        ], actionLayout: .vertical), in: .window(.root))
    }

    clearImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(textAlertController(context: context, title: "Очистить журнал?", text: "Сами сообщения в чатах останутся.", actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: "Очистить", action: {
                GhostDeletedLog.clear()
                refresh()
            })
        ]), in: .window(.root))
    }

    return controller
}
