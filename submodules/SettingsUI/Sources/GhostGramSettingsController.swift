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
import PromptUI
import TelegramUIPreferences

/// Posted after any GhostGram option changes (the Dynamic Island and panic mode listen for it).
public let ghostGramSettingsChangedNotification = Notification.Name("GhostGramSettingsChanged")

// MARK: - Options

private enum GhostToggle: Int32 {
    case hideRead
    case readOnReply
    case hideStoryViews
    case hideOnline
    case hideTyping
    case hideOtherActivities
    case schedule
    case fakeActivities
    case keepDeleted
    case keepEditHistory
    case keepViewOnce
    case keepSecret
    case notifyOnDelete
    case deletedLog
    case filter
    case autoCache
    case autoCachePhotos
    case autoCacheVideos
    case autoCacheVoice
    case autoCacheFiles
    case bypassCopyProtection
    case hideScreenshots
    case hideSponsored
    case hideStories
    case profileId
    case profileLog
    case hidePhone
    case confirmVoice
    case confirmStickers
    case confirmCalls
    case extendedSpeeds
    case messageDetails
    case notes
    case seconds
    case doubleTapReply
    case noSwipeReply
    case noHaptics
    case hideNewsTab
    case hideBadge
    case dynamicIsland
    case islandBadge
    case minimalTabs
    case hideOnCapture
    case hiddenChats
    case panicShake
    case protectMenu

    var title: String {
        switch self {
        case .hideRead: return "Не отправлять «прочитано»"
        case .readOnReply: return "Читать при ответе"
        case .hideStoryViews: return "Смотреть истории незаметно"
        case .hideOnline: return "Скрывать «в сети»"
        case .hideTyping: return "Скрывать «печатает…»"
        case .hideOtherActivities: return "Скрывать запись голосовых и отправку"
        case .schedule: return "Призрак по расписанию"
        case .fakeActivities: return "Фейковые статусы"
        case .keepDeleted: return "Сохранять удалённые"
        case .keepEditHistory: return "Сохранять историю правок"
        case .keepViewOnce: return "Не сжигать одноразовые медиа"
        case .keepSecret: return "Сохранять в секретных чатах"
        case .notifyOnDelete: return "Уведомлять об удалении"
        case .deletedLog: return "Вести журнал удалённых"
        case .filter: return "Фильтры сообщений"
        case .autoCache: return "Автосохранение из личек"
        case .autoCachePhotos: return "Фото"
        case .autoCacheVideos: return "Видео"
        case .autoCacheVoice: return "Голосовые и кружки"
        case .autoCacheFiles: return "Файлы"
        case .bypassCopyProtection: return "Обходить запрет копирования"
        case .hideScreenshots: return "Скриншоты без уведомления"
        case .hideSponsored: return "Убрать рекламу в каналах"
        case .hideStories: return "Скрыть полосу историй"
        case .profileId: return "ID, дата регистрации и DC в профиле"
        case .profileLog: return "Следить за сменой имён и аватарок"
        case .hidePhone: return "Скрыть мой номер"
        case .confirmVoice: return "Подтверждать голосовые"
        case .confirmStickers: return "Подтверждать стикеры"
        case .confirmCalls: return "Подтверждать звонки"
        case .extendedSpeeds: return "Скорость до 3x"
        case .messageDetails: return "«Подробности» и Markdown в меню"
        case .notes: return "Заметки и напоминания"
        case .seconds: return "Время с секундами"
        case .doubleTapReply: return "Двойной тап — ответить"
        case .noSwipeReply: return "Отключить свайп для ответа"
        case .noHaptics: return "Отключить вибрацию"
        case .hideNewsTab: return "Скрыть вкладку новостей"
        case .hideBadge: return "Без счётчика на иконке"
        case .dynamicIsland: return "Призрак в Dynamic Island"
        case .islandBadge: return "Плашка GhostGram у островка"
        case .minimalTabs: return "Внизу только «Чаты» и «Профиль»"
        case .hideOnCapture: return "Скрывать экран при записи"
        case .hiddenChats: return "Скрытые чаты"
        case .panicShake: return "Встряхнуть — выйти (паника)"
        case .protectMenu: return "Face ID на меню GhostGram"
        }
    }

    var value: Bool {
        switch self {
        case .hideRead: return GhostSettings.hideReadReceipts
        case .readOnReply: return GhostSettings.readOnReply
        case .hideStoryViews: return GhostSettings.hideStoryViews
        case .hideOnline: return GhostSettings.hideOnlineStatus
        case .hideTyping: return GhostSettings.hideTyping
        case .hideOtherActivities: return GhostSettings.hideOtherActivities
        case .schedule: return GhostSettings.ghostScheduleEnabled
        case .fakeActivities: return GhostSettings.fakeActivitiesEnabled
        case .keepDeleted: return GhostSettings.keepDeletedMessages
        case .keepEditHistory: return GhostSettings.keepEditHistory
        case .keepViewOnce: return GhostSettings.keepViewOnceMedia
        case .keepSecret: return GhostSettings.keepSecretSelfDestruct
        case .notifyOnDelete: return GhostSettings.notifyOnDelete
        case .deletedLog: return GhostSettings.keepDeletedLog
        case .filter: return GhostSettings.filterEnabled
        case .autoCache: return GhostSettings.autoCachePrivateMedia
        case .autoCachePhotos: return GhostSettings.autoCachePhotos
        case .autoCacheVideos: return GhostSettings.autoCacheVideos
        case .autoCacheVoice: return GhostSettings.autoCacheVoice
        case .autoCacheFiles: return GhostSettings.autoCacheFiles
        case .bypassCopyProtection: return GhostSettings.bypassCopyProtection
        case .hideScreenshots: return GhostSettings.hideScreenshotNotifications
        case .hideSponsored: return GhostSettings.hideSponsoredMessages
        case .hideStories: return GhostSettings.hideStoriesBar
        case .profileId: return GhostSettings.showUserIdInProfile
        case .profileLog: return GhostSettings.trackProfileChanges
        case .hidePhone: return GhostSettings.hidePhoneNumber
        case .confirmVoice: return GhostSettings.confirmVoice
        case .confirmStickers: return GhostSettings.confirmStickers
        case .confirmCalls: return GhostSettings.confirmCalls
        case .extendedSpeeds: return GhostSettings.extendedPlaybackSpeeds
        case .messageDetails: return GhostSettings.showMessageDetails
        case .notes: return GhostSettings.showNotesAndReminders
        case .seconds: return GhostSettings.showSecondsInTime
        case .doubleTapReply: return GhostSettings.doubleTapReply
        case .noSwipeReply: return GhostSettings.disableSwipeReply
        case .noHaptics: return GhostSettings.disableHaptics
        case .hideNewsTab: return GhostSettings.hideNewsTab
        case .hideBadge: return GhostSettings.hideAppBadge
        case .dynamicIsland: return GhostSettings.dynamicIsland
        case .islandBadge: return GhostSettings.islandBadge
        case .minimalTabs: return GhostSettings.minimalTabs
        case .hideOnCapture: return GhostSettings.hideOnScreenRecording
        case .hiddenChats: return GhostSettings.hiddenChatsEnabled
        case .panicShake: return GhostSettings.panicShake
        case .protectMenu: return GhostSettings.protectMenu
        }
    }

    func set(_ value: Bool) {
        switch self {
        case .hideRead: GhostSettings.hideReadReceipts = value
        case .readOnReply: GhostSettings.readOnReply = value
        case .hideStoryViews: GhostSettings.hideStoryViews = value
        case .hideOnline: GhostSettings.hideOnlineStatus = value
        case .hideTyping: GhostSettings.hideTyping = value
        case .hideOtherActivities: GhostSettings.hideOtherActivities = value
        case .schedule: GhostSettings.ghostScheduleEnabled = value
        case .fakeActivities: GhostSettings.fakeActivitiesEnabled = value
        case .keepDeleted: GhostSettings.keepDeletedMessages = value
        case .keepEditHistory: GhostSettings.keepEditHistory = value
        case .keepViewOnce: GhostSettings.keepViewOnceMedia = value
        case .keepSecret: GhostSettings.keepSecretSelfDestruct = value
        case .notifyOnDelete: GhostSettings.notifyOnDelete = value
        case .deletedLog: GhostSettings.keepDeletedLog = value
        case .filter: GhostSettings.filterEnabled = value
        case .autoCache: GhostSettings.autoCachePrivateMedia = value
        case .autoCachePhotos: GhostSettings.autoCachePhotos = value
        case .autoCacheVideos: GhostSettings.autoCacheVideos = value
        case .autoCacheVoice: GhostSettings.autoCacheVoice = value
        case .autoCacheFiles: GhostSettings.autoCacheFiles = value
        case .bypassCopyProtection: GhostSettings.bypassCopyProtection = value
        case .hideScreenshots: GhostSettings.hideScreenshotNotifications = value
        case .hideSponsored: GhostSettings.hideSponsoredMessages = value
        case .hideStories: GhostSettings.hideStoriesBar = value
        case .profileId: GhostSettings.showUserIdInProfile = value
        case .profileLog: GhostSettings.trackProfileChanges = value
        case .hidePhone: GhostSettings.hidePhoneNumber = value
        case .confirmVoice: GhostSettings.confirmVoice = value
        case .confirmStickers: GhostSettings.confirmStickers = value
        case .confirmCalls: GhostSettings.confirmCalls = value
        case .extendedSpeeds: GhostSettings.extendedPlaybackSpeeds = value
        case .messageDetails: GhostSettings.showMessageDetails = value
        case .notes: GhostSettings.showNotesAndReminders = value
        case .seconds: GhostSettings.showSecondsInTime = value
        case .doubleTapReply: GhostSettings.doubleTapReply = value
        case .noSwipeReply: GhostSettings.disableSwipeReply = value
        case .noHaptics: GhostSettings.disableHaptics = value
        case .hideNewsTab: GhostSettings.hideNewsTab = value
        case .hideBadge: GhostSettings.hideAppBadge = value
        case .dynamicIsland: GhostSettings.dynamicIsland = value
        case .islandBadge: GhostSettings.islandBadge = value
        case .minimalTabs: GhostSettings.minimalTabs = value
        case .hideOnCapture: GhostSettings.hideOnScreenRecording = value
        case .hiddenChats: GhostSettings.hiddenChatsEnabled = value
        case .panicShake: GhostSettings.panicShake = value
        case .protectMenu: GhostSettings.protectMenu = value
        }
    }
}

private enum GhostLink: Int32 {
    case scheduleHours
    case onlineDelay
    case exceptions
    case fakeList
    case deletedStyle
    case deletedLog
    case deletedStats
    case keywords
    case ignored
    case cacheLimit
    case profileLog
    case watchList
    case nicknames
    case onlineNow
    case chatListTitle
    case amoled
    case openById
    case hiddenChats
    case lockedChats
    case stats
    case presets
    case exportSettings
    case importSettings
    case reset
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
    case link(id: Int32, section: Int32, link: GhostLink, title: String, label: String, destructive: Bool)
    case footer(id: Int32, section: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .link(_, section, _, _, _, _), let .footer(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .link(id, _, _, _, _, _), let .footer(id, _, _):
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
        case let .link(_, _, link, title, label, destructive):
            if destructive {
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.open(link)
                })
            }
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

private func delayTitle(_ seconds: Int) -> String {
    return seconds <= 0 ? "Выкл" : "\(seconds) сек"
}

private func hourTitle(_ hour: Int) -> String {
    return String(format: "%02d:00", hour)
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
    func link(_ section: Int32, _ link: GhostLink, _ title: String, _ label: String = "", destructive: Bool = false) {
        entries.append(.link(id: next(), section: section, link: link, title: title, label: label, destructive: destructive))
    }
    func header(_ section: Int32, _ text: String) {
        entries.append(.header(id: next(), section: section, text: text))
    }
    func footer(_ section: Int32, _ text: String) {
        entries.append(.footer(id: next(), section: section, text: text))
    }

    header(0, "👻 РЕЖИМ ПРИЗРАКА")
    toggle(0, .hideRead)
    toggle(0, .readOnReply, enabled: GhostSettings.hideReadReceipts || GhostSettings.ghostScheduleEnabled)
    toggle(0, .hideStoryViews)
    toggle(0, .hideOnline)
    toggle(0, .hideTyping)
    toggle(0, .hideOtherActivities)
    toggle(0, .schedule)
    link(0, .scheduleHours, "Расписание", "\(hourTitle(GhostSettings.ghostScheduleFrom))–\(hourTitle(GhostSettings.ghostScheduleTo))")
    link(0, .onlineDelay, "Не в сети после открытия", delayTitle(GhostSettings.onlineDelaySeconds))
    link(0, .exceptions, "Исключения", "\(GhostSettings.ghostExceptions.count)")
    footer(0, "Собеседник не увидит, что вы прочитали сообщение, прослушали голосовое или посмотрели историю. По расписанию призрак включается сам. В исключениях он не действует.")

    header(1, "🎭 ФЕЙКОВЫЕ СТАТУСЫ")
    toggle(1, .fakeActivities)
    link(1, .fakeList, "Чаты со статусом", "\(GhostSettings.fakeActivities.count)")
    footer(1, "В выбранном чате постоянно висит «печатает…», «записывает голосовое», «играет в игру» и т. п. Включается долгим нажатием на чат → «👻 GhostGram…».")

    header(2, "🗑 СООБЩЕНИЯ")
    toggle(2, .keepDeleted)
    toggle(2, .keepEditHistory)
    toggle(2, .keepViewOnce)
    toggle(2, .keepSecret)
    toggle(2, .notifyOnDelete, enabled: GhostSettings.keepDeletedMessages)
    toggle(2, .deletedLog, enabled: GhostSettings.keepDeletedMessages)
    link(2, .deletedStyle, "Пометка удалённых", GhostSettings.deletedMarkStyle == 1 ? "удалено" : "🗑")
    link(2, .deletedLog, "Журнал удалённых", "\(GhostDeletedLog.entries().count)")
    link(2, .deletedStats, "Кто сколько удалил")
    footer(2, "Старые версии правок — в меню сообщения → «История правок». Сохраняется только то, что успело прийти на телефон.")

    header(3, "🚫 ФИЛЬТРЫ")
    toggle(3, .filter)
    link(3, .keywords, "Скрывать слова", "\(GhostSettings.filterKeywords.count)")
    link(3, .ignored, "Игнор-лист", "\(GhostSettings.ignoredUsers.count)")
    footer(3, "Сообщения с этими словами и от людей из игнор-листа не показываются. Добавить в игнор — меню сообщения → «Игнорировать автора».")

    header(4, "📥 МЕДИА")
    toggle(4, .autoCache)
    let cacheOn = GhostSettings.autoCachePrivateMedia
    toggle(4, .autoCachePhotos, enabled: cacheOn)
    toggle(4, .autoCacheVideos, enabled: cacheOn)
    toggle(4, .autoCacheVoice, enabled: cacheOn)
    toggle(4, .autoCacheFiles, enabled: cacheOn)
    link(4, .cacheLimit, "Максимальный размер", cacheLimitTitle(GhostSettings.autoCacheLimitMB))
    footer(4, "Медиа из личных чатов скачивается сразу, поэтому остаётся у вас, даже если собеседник его удалит.")

    header(5, "🔓 КОНТЕНТ")
    toggle(5, .bypassCopyProtection)
    toggle(5, .hideScreenshots)
    toggle(5, .hideSponsored)
    toggle(5, .hideStories)
    footer(5, "Обход запрета позволяет сохранять и копировать из защищённых чатов и каналов. Пересылку оттуда сервер всё равно не пропустит.")

    header(6, "👤 ЛЮДИ")
    toggle(6, .profileId)
    toggle(6, .profileLog)
    link(6, .profileLog, "Журнал изменений профилей", "\(GhostProfileLog.entries().count)")
    link(6, .watchList, "Сообщать, когда в сети", "\(GhostSettings.onlineWatchList.count)")
    link(6, .nicknames, "Локальные имена", "\(GhostSettings.nicknames.count)")
    link(6, .onlineNow, "Кто сейчас в сети")
    link(6, .openById, "🔎 Открыть профиль по ID")
    footer(6, "Дата регистрации примерная — оценивается по ID. Локальные имена видите только вы.")

    header(7, "✨ ИНТЕРФЕЙС")
    toggle(7, .hidePhone)
    toggle(7, .confirmVoice)
    toggle(7, .confirmStickers)
    toggle(7, .confirmCalls)
    toggle(7, .extendedSpeeds)
    toggle(7, .messageDetails)
    toggle(7, .notes)
    toggle(7, .seconds)
    toggle(7, .doubleTapReply)
    toggle(7, .noSwipeReply)
    toggle(7, .noHaptics)
    toggle(7, .hideNewsTab)
    toggle(7, .hideBadge)
    toggle(7, .dynamicIsland)
    toggle(7, .islandBadge)
    toggle(7, .minimalTabs)
    link(7, .amoled, "🖤 Включить AMOLED-тему")
    link(7, .chatListTitle, "Заголовок списка чатов", GhostSettings.customChatListTitle ?? "Чаты")
    footer(7, "Часть изменений интерфейса применяется после перезапуска приложения.")

    header(8, "🔒 БЕЗОПАСНОСТЬ")
    toggle(8, .hiddenChats)
    link(8, .hiddenChats, "Открыть скрытые чаты", "\(GhostSettings.hiddenChats.count)")
    link(8, .lockedChats, "Чаты под Face ID", "\(GhostSettings.lockedChats.count)")
    toggle(8, .panicShake)
    toggle(8, .hideOnCapture)
    toggle(8, .protectMenu)
    footer(8, "Скрыть или закрыть чат: долгое нажатие на чат в списке. Паника: резко встряхните телефон — GhostGram свернётся, закрытые чаты снова потребуют Face ID.")

    header(9, "📊 СТАТИСТИКА")
    link(9, .stats, "Моя статистика")

    header(10, "⚙️ УПРАВЛЕНИЕ")
    link(10, .presets, "Пресеты")
    link(10, .exportSettings, "Экспорт настроек")
    link(10, .importSettings, "Импорт из буфера")
    link(10, .reset, "Сбросить все настройки GhostGram", destructive: true)
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

private func ghostChoose(context: AccountContext, from: ViewController, title: String, text: String, options: [(String, () -> Void)]) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var actions: [TextAlertAction] = []
    for (optionTitle, action) in options {
        actions.append(TextAlertAction(type: .genericAction, title: optionTitle, action: action))
    }
    actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}))
    from.present(textAlertController(context: context, title: title, text: text, actions: actions, actionLayout: .vertical), in: .window(.root))
}

private func ghostInform(context: AccountContext, from: ViewController?, title: String, text: String) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    from?.present(textAlertController(context: context, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
}

public func ghostGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    var currentRevision = 0
    let refresh: () -> Void = {
        currentRevision += 1
        revision.set(currentRevision)
    }
    let changed: () -> Void = {
        NotificationCenter.default.post(name: ghostGramSettingsChangedNotification, object: nil)
        refresh()
    }

    var openImpl: ((GhostLink) -> Void)?

    let arguments = GhostGramSettingsArguments(toggle: { option, value in
        option.set(value)
        changed()
    }, open: { link in
        openImpl?(link)
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("GhostGram 👻"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ghostGramSettingsEntries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { [weak controller] _ in
        refresh()
        if !GhostSettings.onboardingShown {
            GhostSettings.onboardingShown = true
            ghostInform(context: context, from: controller, title: "Добро пожаловать в GhostGram 👻", text: "Здесь всё, что умеет GhostGram. Начать проще всего с «Пресетов» внизу: «Невидимка» включает режим призрака, «Архивариус» — сохранение удалённого. Действия для отдельного чата — долгое нажатие на чат → «👻 GhostGram…», для сообщения — долгое нажатие на сообщение.")
        }
    }

    openImpl = { [weak controller] link in
        guard let controller = controller else {
            return
        }
        switch link {
        case .scheduleHours:
            var fromOptions: [(String, () -> Void)] = []
            for fromHour in [20, 21, 22, 23, 0, 1, 2] {
                fromOptions.append((hourTitle(fromHour), { [weak controller] in
                    GhostSettings.ghostScheduleFrom = fromHour
                    guard let controller = controller else {
                        return
                    }
                    var toOptions: [(String, () -> Void)] = []
                    for toHour in [6, 7, 8, 9, 10, 11] {
                        toOptions.append((hourTitle(toHour), {
                            GhostSettings.ghostScheduleTo = toHour
                            changed()
                        }))
                    }
                    ghostChoose(context: context, from: controller, title: "До скольки", text: "", options: toOptions)
                }))
            }
            ghostChoose(context: context, from: controller, title: "Призрак включается в", text: "", options: fromOptions)
        case .onlineDelay:
            var options: [(String, () -> Void)] = []
            for seconds in [0, 10, 30, 60, 120] {
                options.append((delayTitle(seconds), {
                    GhostSettings.onlineDelaySeconds = seconds
                    changed()
                }))
            }
            ghostChoose(context: context, from: controller, title: "Не в сети после открытия", text: "Сколько секунд после открытия GhostGram вы остаётесь «не в сети».", options: options)
        case .exceptions:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .exceptions))
        case .fakeList:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .fake))
        case .deletedStyle:
            ghostChoose(context: context, from: controller, title: "Пометка удалённых", text: "", options: [
                ("🗑 Значок корзины", {
                    GhostSettings.deletedMarkStyle = 0
                    changed()
                }),
                ("Слово «удалено»", {
                    GhostSettings.deletedMarkStyle = 1
                    changed()
                })
            ])
        case .deletedLog:
            ghostPushController(controller, ghostDeletedLogController(context: context))
        case .deletedStats:
            var counts: [String: Int] = [:]
            for entry in GhostDeletedLog.entries() {
                counts[entry.authorTitle, default: 0] += 1
            }
            let rows = counts.sorted(by: { $0.value > $1.value }).prefix(100).map { ($0.key, "\($0.value)") }
            ghostPushController(controller, ghostInfoListController(context: context, title: "Кто сколько удалил", rows: Array(rows), emptyText: "Пока никто ничего не удалял."))
        case .keywords:
            let prompt = promptController(context: context, text: "Скрывать сообщения со словами", value: GhostSettings.filterKeywords.joined(separator: ", "), placeholder: "через запятую", characterLimit: 2000, apply: { value in
                guard let value = value else {
                    return
                }
                GhostSettings.filterKeywords = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                changed()
            })
            controller.present(prompt, in: .window(.root))
        case .ignored:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .ignored))
        case .cacheLimit:
            var options: [(String, () -> Void)] = []
            for limit in [10, 50, 200, 1000, 0] {
                options.append((cacheLimitTitle(limit), {
                    GhostSettings.autoCacheLimitMB = limit
                    changed()
                }))
            }
            ghostChoose(context: context, from: controller, title: "Максимальный размер", text: "Файлы больше этого размера не скачиваются автоматически.", options: options)
        case .profileLog:
            ghostPushController(controller, ghostProfileLogController(context: context))
        case .watchList:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .watch))
        case .nicknames:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .nicknames))
        case .onlineNow:
            ghostPushController(controller, ghostOnlineNowController(context: context))
        case .amoled:
            let nightTheme = PresentationThemeReference.builtin(.night)
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                var updated = current.withUpdatedTheme(nightTheme)
                var autoSwitch = updated.automaticThemeSwitchSetting
                autoSwitch.theme = nightTheme
                updated.automaticThemeSwitchSetting = autoSwitch
                var wallpapers = updated.themeSpecificChatWallpapers
                wallpapers[nightTheme.index] = .color(0x000000)
                if let accentColor = updated.themeSpecificAccentColors[nightTheme.index] {
                    wallpapers[coloredThemeIndex(reference: nightTheme, accentColor: accentColor)] = .color(0x000000)
                }
                return updated.withUpdatedThemeSpecificChatWallpapers(wallpapers)
            }).start()
            ghostInform(context: context, from: controller, title: "AMOLED-тема включена", text: "Чёрный фон везде, включая чаты. Вернуть прежнюю тему можно в «Оформлении».")
        case .openById:
            let prompt = promptController(context: context, text: "ID пользователя, группы или канала", value: "", placeholder: "Например 123456789 или -100…", characterLimit: 24, apply: { value in
                guard let value = value else {
                    return
                }
                var digits = value.trimmingCharacters(in: .whitespacesAndNewlines)
                var candidates: [EnginePeer.Id] = []
                if digits.hasPrefix("-100") {
                    digits.removeFirst(4)
                    if let raw = Int64(digits) {
                        candidates.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(raw)))
                    }
                } else if digits.hasPrefix("-") {
                    digits.removeFirst(1)
                    if let raw = Int64(digits) {
                        candidates.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(raw)))
                    }
                } else if let raw = Int64(digits) {
                    for namespace in [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup] {
                        candidates.append(EnginePeer.Id(namespace: namespace, id: EnginePeer.Id.Id._internalFromInt64Value(raw)))
                    }
                }
                if candidates.isEmpty {
                    ghostInform(context: context, from: controller, title: "Неверный ID", text: "Нужны только цифры.")
                    return
                }
                let _ = (context.engine.data.get(EngineDataList(candidates.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
                |> deliverOnMainQueue).start(next: { [weak controller] peers in
                    if let peer = peers.compactMap({ $0 }).first, let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        ghostPushController(controller, infoController)
                    } else {
                        ghostInform(context: context, from: controller, title: "Профиль не найден", text: "Telegram открывает профиль по ID, только если этот человек или чат уже встречался вам: в общих группах, каналах, пересланных сообщениях. Если он где-то пересекался с вами, откройте тот чат и попробуйте снова.")
                    }
                })
            })
            controller.present(prompt, in: .window(.root))
        case .chatListTitle:
            let prompt = promptController(context: context, text: "Заголовок над списком чатов", value: GhostSettings.customChatListTitle ?? "", placeholder: "Пусто — «Чаты»", characterLimit: 40, apply: { value in
                guard let value = value else {
                    return
                }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                GhostSettings.customChatListTitle = trimmed.isEmpty ? nil : trimmed
                changed()
            })
            controller.present(prompt, in: .window(.root))
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
        case .lockedChats:
            ghostPushController(controller, ghostPeerListController(context: context, kind: .locked))
        case .stats:
            let rows: [(String, String)] = [
                ("Отправлено сегодня", "\(GhostStats.sent(lastDays: 1))"),
                ("Отправлено за 7 дней", "\(GhostStats.sent(lastDays: 7))"),
                ("Отправлено за 30 дней", "\(GhostStats.sent(lastDays: 30))"),
                ("Отправлено всего (с установки)", "\(GhostStats.sentTotal)"),
                ("Сохранено удалённых", "\(GhostDeletedLog.entries().count)"),
                ("Изменений профилей", "\(GhostProfileLog.entries().count)"),
                ("Скрытых чатов", "\(GhostSettings.hiddenChats.count)"),
                ("Чатов с фейковым статусом", "\(GhostSettings.fakeActivities.count)")
            ]
            ghostPushController(controller, ghostInfoListController(context: context, title: "Моя статистика", rows: rows, emptyText: ""))
        case .presets:
            ghostChoose(context: context, from: controller, title: "Пресеты", text: "Включают сразу группу настроек. Остальное не трогают.", options: [
                ("👻 Невидимка", {
                    GhostSettings.apply(preset: .invisible)
                    changed()
                }),
                ("🗄 Архивариус", {
                    GhostSettings.apply(preset: .archivist)
                    changed()
                }),
                ("🙂 Обычный (выключить призрака)", {
                    GhostSettings.apply(preset: .regular)
                    changed()
                })
            ])
        case .exportSettings:
            UIPasteboard.general.string = GhostSettings.exportJSON()
            ghostInform(context: context, from: controller, title: "Скопировано", text: "Настройки GhostGram скопированы в буфер обмена. Сохраните их в заметках, чтобы потом восстановить через «Импорт из буфера».")
        case .importSettings:
            let count = GhostSettings.importJSON(UIPasteboard.general.string ?? "")
            changed()
            ghostInform(context: context, from: controller, title: count > 0 ? "Готово" : "Не получилось", text: count > 0 ? "Восстановлено настроек: \(count)." : "В буфере нет настроек GhostGram.")
        case .reset:
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            controller.present(textAlertController(context: context, title: "Сбросить всё?", text: "Все настройки GhostGram вернутся к стандартным. Журналы и сохранённые сообщения останутся.", actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: "Сбросить", action: {
                    GhostSettings.resetAll()
                    GhostSettings.onboardingShown = true
                    changed()
                })
            ]), in: .window(.root))
        }
    }

    return controller
}

// MARK: - Simple info lists

private enum GhostInfoListEntry: ItemListNodeEntry {
    case row(index: Int32, title: String, value: String)
    case empty(text: String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case let .row(index, _, _):
            return index
        case .empty:
            return -1
        }
    }

    static func <(lhs: GhostInfoListEntry, rhs: GhostInfoListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .row(_, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ghostInfoListController(context: AccountContext, title: String, rows: [(String, String)], emptyText: String) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [GhostInfoListEntry] = []
        for (index, row) in rows.enumerated() {
            entries.append(.row(index: Int32(index), title: row.0, value: row.1))
        }
        if entries.isEmpty {
            entries.append(.empty(text: emptyText))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, Void()))
    }
    return ItemListController(context: context, state: signal)
}

// MARK: - Chat lists

private enum GhostPeerListKind: Equatable {
    case exceptions
    case hidden
    case locked
    case watch
    case ignored
    case fake
    case nicknames

    var title: String {
        switch self {
        case .exceptions: return "Исключения"
        case .hidden: return "Скрытые чаты"
        case .locked: return "Чаты под Face ID"
        case .watch: return "Сообщать, когда в сети"
        case .ignored: return "Игнор-лист"
        case .fake: return "Фейковые статусы"
        case .nicknames: return "Локальные имена"
        }
    }

    var footer: String {
        switch self {
        case .exceptions: return "В этих чатах «прочитано» и «печатает» отправляются как обычно."
        case .hidden: return "Эти чаты не показываются в списке чатов. Нажмите на чат, чтобы открыть его или вернуть в список."
        case .locked: return "Эти чаты открываются только после Face ID."
        case .watch: return "Придёт уведомление, когда человек появится в сети (пока GhostGram работает)."
        case .ignored: return "Сообщения этих людей не показываются в группах и чатах."
        case .fake: return "В этих чатах собеседники постоянно видят выбранный статус."
        case .nicknames: return "Эти имена видите только вы."
        }
    }

    var onlyUsers: Bool {
        switch self {
        case .watch, .ignored, .nicknames:
            return true
        default:
            return false
        }
    }

    var peerIds: Set<Int64> {
        switch self {
        case .exceptions: return GhostSettings.ghostExceptions
        case .hidden: return GhostSettings.hiddenChats
        case .locked: return GhostSettings.lockedChats
        case .watch: return GhostSettings.onlineWatchList
        case .ignored: return GhostSettings.ignoredUsers
        case .fake: return Set(GhostSettings.fakeActivities.keys)
        case .nicknames: return Set(GhostSettings.nicknames.keys)
        }
    }

    func label(_ id: Int64) -> String {
        switch self {
        case .fake:
            return GhostSettings.fakeActivities[id].flatMap { GhostFakeActivityKind(rawValue: $0)?.title } ?? ""
        case .nicknames:
            return GhostSettings.nicknames[id] ?? ""
        default:
            return ""
        }
    }

    func remove(_ id: Int64) {
        switch self {
        case .exceptions:
            var value = GhostSettings.ghostExceptions
            value.remove(id)
            GhostSettings.ghostExceptions = value
        case .hidden:
            var value = GhostSettings.hiddenChats
            value.remove(id)
            GhostSettings.hiddenChats = value
        case .locked:
            var value = GhostSettings.lockedChats
            value.remove(id)
            GhostSettings.lockedChats = value
        case .watch:
            var value = GhostSettings.onlineWatchList
            value.remove(id)
            GhostSettings.onlineWatchList = value
        case .ignored:
            var value = GhostSettings.ignoredUsers
            value.remove(id)
            GhostSettings.ignoredUsers = value
        case .fake:
            var value = GhostSettings.fakeActivities
            value.removeValue(forKey: id)
            GhostSettings.fakeActivities = value
        case .nicknames:
            var value = GhostSettings.nicknames
            value.removeValue(forKey: id)
            GhostSettings.nicknames = value
        }
    }

    func insert(_ id: Int64) {
        switch self {
        case .exceptions:
            var value = GhostSettings.ghostExceptions
            value.insert(id)
            GhostSettings.ghostExceptions = value
        case .hidden:
            var value = GhostSettings.hiddenChats
            value.insert(id)
            GhostSettings.hiddenChats = value
        case .locked:
            var value = GhostSettings.lockedChats
            value.insert(id)
            GhostSettings.lockedChats = value
        case .watch:
            var value = GhostSettings.onlineWatchList
            value.insert(id)
            GhostSettings.onlineWatchList = value
        case .ignored:
            var value = GhostSettings.ignoredUsers
            value.insert(id)
            GhostSettings.ignoredUsers = value
        case .fake, .nicknames:
            break
        }
    }

    var removeTitle: String {
        switch self {
        case .hidden: return "Вернуть в список чатов"
        case .locked: return "Убрать Face ID"
        case .fake: return "Выключить статус"
        case .nicknames: return "Вернуть настоящее имя"
        default: return "Убрать из списка"
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
    case add
    case peer(index: Int32, peer: EnginePeer, title: String, label: String)
    case footer(text: String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int64 {
        switch self {
        case .add:
            return Int64.min
        case let .peer(_, peer, _, _):
            return peer.id.toInt64()
        case .footer:
            return Int64.max
        }
    }

    private var sortIndex: Int32 {
        switch self {
        case .add:
            return 0
        case let .peer(index, _, _, _):
            return 1 + index
        case .footer:
            return Int32.max
        }
    }

    static func ==(lhs: GhostPeerListEntry, rhs: GhostPeerListEntry) -> Bool {
        switch lhs {
        case .add:
            if case .add = rhs {
                return true
            }
            return false
        case let .peer(index, peer, title, label):
            if case let .peer(rhsIndex, rhsPeer, rhsTitle, rhsLabel) = rhs, index == rhsIndex, peer.id == rhsPeer.id, title == rhsTitle, label == rhsLabel {
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
        case .add:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Добавить чат", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case let .peer(_, peer, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, context: arguments.context, iconPeer: peer, title: title, label: label, sectionId: self.section, style: .blocks, action: {
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
        if kind != .fake && kind != .nicknames {
            entries.append(.add)
        }
        for (index, peer) in peers.enumerated() {
            entries.append(.peer(index: Int32(index), peer: peer, title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), label: kind.label(peer.id.toInt64())))
        }
        entries.append(.footer(text: kind.footer))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(kind.title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    selectImpl = { [weak controller] peer in
        guard let controller = controller else {
            return
        }
        var options: [(String, () -> Void)] = []
        if kind == .hidden || kind == .locked || kind == .fake {
            options.append(("Открыть чат", { [weak controller] in
                ghostOpenChat(context: context, from: controller, peerId: peer.id, messageId: nil)
            }))
        }
        options.append((kind.removeTitle, {
            kind.remove(peer.id.toInt64())
            refresh()
        }))
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        ghostChoose(context: context, from: controller, title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), text: "", options: options)
    }

    addImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        let filter: ChatListNodePeersFilter = kind.onlyUsers ? [.excludeSavedMessages, .doNotSearchMessages, .onlyPrivateChats] : [.excludeSavedMessages, .doNotSearchMessages]
        let picker = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter))
        picker.peerSelected = { [weak picker] peer, _ in
            kind.insert(peer.id.toInt64())
            refresh()
            picker?.dismiss()
        }
        ghostPushController(controller, picker)
    }

    return controller
}

// MARK: - Online now

private func ghostOnlineNowController(context: AccountContext) -> ViewController {
    var selectImpl: ((EnginePeer) -> Void)?
    let selectArguments = GhostPeerListArguments(context: context, select: { peer in
        selectImpl?(peer)
    }, add: {})

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, context.engine.data.subscribe(TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)))
    |> map { presentationData, contacts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [GhostPeerListEntry] = []
        var index: Int32 = 0
        let now = Int32(Date().timeIntervalSince1970)
        for peer in contacts.peers {
            guard let presence = contacts.presences[peer.id], case let .present(until) = presence.status, until > now else {
                continue
            }
            entries.append(.peer(index: index, peer: peer, title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), label: "в сети"))
            index += 1
        }
        entries.append(.footer(text: entries.isEmpty ? "Сейчас никого из контактов нет в сети." : "Контакты, которые сейчас в сети. Нажмите, чтобы открыть чат."))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Сейчас в сети"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, selectArguments))
    }

    let controller = ItemListController(context: context, state: signal)
    selectImpl = { [weak controller] peer in
        ghostOpenChat(context: context, from: controller, peerId: peer.id, messageId: nil)
    }
    return controller
}

// MARK: - Logs

private final class GhostLogArguments {
    let open: (Int32) -> Void
    let clear: () -> Void

    init(open: @escaping (Int32) -> Void, clear: @escaping () -> Void) {
        self.open = open
        self.clear = clear
    }
}

private enum GhostLogListEntry: ItemListNodeEntry {
    case search(text: String)
    case item(index: Int32, label: String, text: String)
    case empty(text: String)
    case clear

    var section: ItemListSectionId {
        switch self {
        case .search:
            return 0
        case .item, .empty:
            return 1
        case .clear:
            return 2
        }
    }

    var stableId: Int32 {
        switch self {
        case .search:
            return -2
        case let .item(index, _, _):
            return index
        case .empty:
            return -1
        case .clear:
            return Int32.max
        }
    }

    static func <(lhs: GhostLogListEntry, rhs: GhostLogListEntry) -> Bool {
        if lhs.section != rhs.section {
            return lhs.section < rhs.section
        }
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GhostLogArguments
        switch self {
        case let .search(text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: text.isEmpty ? "🔎 Поиск" : "🔎 \(text)", label: text.isEmpty ? "" : "сбросить", sectionId: self.section, style: .blocks, action: {
                arguments.open(-2)
            })
        case let .item(index, label, text):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: label, text: text, style: .blocks, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: {
                arguments.open(index)
            })
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
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
    var query = ""
    var shown: [GhostDeletedLogEntry] = []

    var openImpl: ((Int32) -> Void)?
    var clearImpl: (() -> Void)?
    let arguments = GhostLogArguments(open: { index in
        openImpl?(index)
    }, clear: {
        clearImpl?()
    })

    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM HH:mm"

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [GhostLogListEntry] = [.search(text: query)]
        let lowered = query.lowercased()
        let logEntries = GhostDeletedLog.entries().filter { entry in
            return lowered.isEmpty || entry.text.lowercased().contains(lowered) || entry.authorTitle.lowercased().contains(lowered) || entry.chatTitle.lowercased().contains(lowered)
        }
        shown = Array(logEntries.prefix(500))
        if shown.isEmpty {
            entries.append(.empty(text: query.isEmpty ? "Пока ничего не удаляли." : "Ничего не найдено."))
        } else {
            for (index, entry) in shown.enumerated() {
                var label = entry.authorTitle
                if !entry.chatTitle.isEmpty && entry.chatTitle != entry.authorTitle {
                    label += " · \(entry.chatTitle)"
                }
                label += " · " + formatter.string(from: Date(timeIntervalSince1970: Double(entry.deletedAt)))
                entries.append(.item(index: Int32(index), label: label, text: entry.text))
            }
            entries.append(.clear)
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Журнал удалённых"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    openImpl = { [weak controller] index in
        guard let controller = controller else {
            return
        }
        if index == -2 {
            if !query.isEmpty {
                query = ""
                refresh()
                return
            }
            let prompt = promptController(context: context, text: "Поиск по удалённым", value: "", placeholder: "Текст, имя или чат", characterLimit: 100, apply: { value in
                query = value ?? ""
                refresh()
            })
            controller.present(prompt, in: .window(.root))
            return
        }
        guard index >= 0 && Int(index) < shown.count else {
            return
        }
        let entry = shown[Int(index)]
        ghostChoose(context: context, from: controller, title: entry.authorTitle, text: entry.text, options: [
            ("Перейти к сообщению", { [weak controller] in
                ghostOpenChat(context: context, from: controller, peerId: entry.messageId.peerId, messageId: entry.messageId)
            }),
            ("Копировать текст", {
                UIPasteboard.general.string = entry.text
            }),
            ("Экспортировать весь журнал", {
                let lines = GhostDeletedLog.entries().map { item -> String in
                    return "[\(formatter.string(from: Date(timeIntervalSince1970: Double(item.deletedAt))))] \(item.authorTitle) (\(item.chatTitle)): \(item.text)"
                }
                UIPasteboard.general.string = lines.joined(separator: "\n")
            })
        ])
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

private func ghostProfileLogController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    var currentRevision = 0
    let refresh: () -> Void = {
        currentRevision += 1
        revision.set(currentRevision)
    }
    var shown: [GhostProfileLogEntry] = []

    var openImpl: ((Int32) -> Void)?
    var clearImpl: (() -> Void)?
    let arguments = GhostLogArguments(open: { index in
        openImpl?(index)
    }, clear: {
        clearImpl?()
    })

    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM HH:mm"

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [GhostLogListEntry] = []
        shown = Array(GhostProfileLog.entries().prefix(500))
        if shown.isEmpty {
            entries.append(.empty(text: "Пока никто из контактов не менял имя, ник или аватарку."))
        } else {
            for (index, entry) in shown.enumerated() {
                let label = entry.title + " · " + formatter.string(from: Date(timeIntervalSince1970: Double(entry.date)))
                entries.append(.item(index: Int32(index), label: label, text: entry.change))
            }
            entries.append(.clear)
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Изменения профилей"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    openImpl = { [weak controller] index in
        guard index >= 0 && Int(index) < shown.count else {
            return
        }
        let entry = shown[Int(index)]
        ghostOpenChat(context: context, from: controller, peerId: EnginePeer.Id(entry.peerId), messageId: nil)
    }

    clearImpl = {
        GhostProfileLog.clear()
        refresh()
    }

    return controller
}
