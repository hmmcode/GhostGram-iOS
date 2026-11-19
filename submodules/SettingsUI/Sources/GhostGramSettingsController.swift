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
    case downloadBoost
    case glassProfile
    case advertiseBadge
    case showBadges
    case hiddenChats
    case panicShake
    case protectMenu
    case uploadIsland
    case stickersWithoutPack

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
        case .downloadBoost: return "Ускоритель загрузок"
        case .glassProfile: return "Стеклянный профиль"
        case .advertiseBadge: return "👻 у моего имени для юзеров GhostGram"
        case .showBadges: return "Показывать 👻 у юзеров GhostGram"
        case .hiddenChats: return "Скрытые чаты"
        case .panicShake: return "Встряхнуть — выйти (паника)"
        case .protectMenu: return "Face ID на меню GhostGram"
        case .uploadIsland: return "Отправка в Dynamic Island"
        case .stickersWithoutPack: return "Стикеры без стикерпака"
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
        case .downloadBoost: return GhostSettings.downloadBoost
        case .glassProfile: return GhostSettings.glassProfile
        case .advertiseBadge: return GhostSettings.advertiseGhostGram
        case .showBadges: return GhostSettings.showGhostBadges
        case .hiddenChats: return GhostSettings.hiddenChatsEnabled
        case .panicShake: return GhostSettings.panicShake
        case .protectMenu: return GhostSettings.protectMenu
        case .uploadIsland: return GhostSettings.uploadIsland
        case .stickersWithoutPack: return GhostSettings.stickersWithoutPack
        }
    }

    var icon: UIImage? {
        let pair: (String, UIColor)
        switch self {
        case .hideRead: pair = ("checkmark.circle", .systemBlue)
        case .readOnReply: pair = ("arrowshape.turn.up.left.fill", .systemTeal)
        case .hideStoryViews: pair = ("circle.dashed", .systemPink)
        case .hideOnline: pair = ("wifi.slash", .systemGreen)
        case .hideTyping: pair = ("ellipsis.bubble.fill", .systemIndigo)
        case .hideOtherActivities: pair = ("mic.slash.fill", .systemOrange)
        case .schedule: pair = ("moon.stars.fill", .systemPurple)
        case .fakeActivities: pair = ("theatermasks.fill", .systemPink)
        case .keepDeleted: pair = ("trash.slash.fill", .systemRed)
        case .keepEditHistory: pair = ("pencil.and.outline", .systemOrange)
        case .keepViewOnce: pair = ("flame.fill", .systemOrange)
        case .keepSecret: pair = ("lock.doc.fill", .systemGreen)
        case .notifyOnDelete: pair = ("bell.badge.fill", .systemRed)
        case .deletedLog: pair = ("list.bullet.rectangle.fill", .systemGray)
        case .filter: pair = ("line.3.horizontal.decrease.circle.fill", .systemIndigo)
        case .autoCache: pair = ("tray.and.arrow.down.fill", .systemBlue)
        case .autoCachePhotos: pair = ("photo.fill", .systemBlue)
        case .autoCacheVideos: pair = ("video.fill", .systemPurple)
        case .autoCacheVoice: pair = ("waveform", .systemOrange)
        case .autoCacheFiles: pair = ("doc.fill", .systemGray)
        case .bypassCopyProtection: pair = ("doc.on.doc.fill", .systemTeal)
        case .hideScreenshots: pair = ("camera.viewfinder", .systemGreen)
        case .hideSponsored: pair = ("megaphone.fill", .systemRed)
        case .hideStories: pair = ("rectangle.stack.fill", .systemPink)
        case .profileId: pair = ("number", .systemBlue)
        case .profileLog: pair = ("person.text.rectangle.fill", .systemIndigo)
        case .hidePhone: pair = ("phone.down.fill", .systemGreen)
        case .confirmVoice: pair = ("mic.fill", .systemOrange)
        case .confirmStickers: pair = ("face.smiling.inverse", .systemYellow)
        case .confirmCalls: pair = ("phone.fill", .systemGreen)
        case .extendedSpeeds: pair = ("speedometer", .systemRed)
        case .messageDetails: pair = ("info.circle.fill", .systemBlue)
        case .notes: pair = ("note.text", .systemYellow)
        case .seconds: pair = ("clock.fill", .systemGray)
        case .doubleTapReply: pair = ("hand.tap.fill", .systemTeal)
        case .noSwipeReply: pair = ("hand.draw.fill", .systemGray)
        case .noHaptics: pair = ("iphone.radiowaves.left.and.right", .systemGray)
        case .hideNewsTab: pair = ("newspaper.fill", .systemOrange)
        case .hideBadge: pair = ("app.badge.fill", .systemRed)
        case .dynamicIsland: pair = ("capsule.fill", .black)
        case .islandBadge: pair = ("tag.fill", .systemPurple)
        case .minimalTabs: pair = ("dock.rectangle", .systemBlue)
        case .hideOnCapture: pair = ("record.circle", .systemRed)
        case .downloadBoost: pair = ("bolt.fill", .systemYellow)
        case .glassProfile: pair = ("sparkles", .systemCyan)
        case .advertiseBadge: pair = ("person.badge.plus", .systemPurple)
        case .showBadges: pair = ("eye.fill", .systemPurple)
        case .hiddenChats: pair = ("eye.slash.fill", .systemGray)
        case .panicShake: pair = ("iphone.gen3.radiowaves.left.and.right", .systemRed)
        case .protectMenu: pair = ("faceid", .systemGreen)
        case .uploadIsland: pair = ("paperplane.fill", .systemBlue)
        case .stickersWithoutPack: pair = ("shippingbox.fill", .systemOrange)
        }
        return ghostSettingsIcon(pair.0, pair.1)
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
        case .downloadBoost: GhostSettings.downloadBoost = value
        case .glassProfile: GhostSettings.glassProfile = value
        case .advertiseBadge: GhostSettings.advertiseGhostGram = value
        case .showBadges: GhostSettings.showGhostBadges = value
        case .hiddenChats: GhostSettings.hiddenChatsEnabled = value
        case .panicShake: GhostSettings.panicShake = value
        case .protectMenu: GhostSettings.protectMenu = value
        case .uploadIsland: GhostSettings.uploadIsland = value
        case .stickersWithoutPack: GhostSettings.stickersWithoutPack = value
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
    case plugins
    case hiddenChats
    case lockedChats
    case stats
    case presets
    case exportSettings
    case importSettings
    case reset
    case automations

    var icon: UIImage? {
        let pair: (String, UIColor)
        switch self {
        case .scheduleHours: pair = ("clock.fill", .systemPurple)
        case .onlineDelay: pair = ("hourglass", .systemGreen)
        case .exceptions: pair = ("person.crop.circle.badge.xmark", .systemGray)
        case .fakeList: pair = ("list.bullet", .systemPink)
        case .deletedStyle: pair = ("paintbrush.fill", .systemOrange)
        case .deletedLog: pair = ("list.bullet.rectangle.fill", .systemRed)
        case .deletedStats: pair = ("chart.bar.fill", .systemRed)
        case .keywords: pair = ("textformat", .systemIndigo)
        case .ignored: pair = ("person.fill.xmark", .systemGray)
        case .cacheLimit: pair = ("externaldrive.fill", .systemBlue)
        case .profileLog: pair = ("clock.arrow.circlepath", .systemIndigo)
        case .watchList: pair = ("bell.fill", .systemGreen)
        case .nicknames: pair = ("character.cursor.ibeam", .systemTeal)
        case .onlineNow: pair = ("dot.radiowaves.left.and.right", .systemGreen)
        case .chatListTitle: pair = ("textformat.size", .systemBlue)
        case .amoled: pair = ("moon.fill", .black)
        case .openById: pair = ("magnifyingglass", .systemBlue)
        case .plugins: pair = ("puzzlepiece.extension.fill", .systemPurple)
        case .hiddenChats: pair = ("eye.slash.fill", .systemGray)
        case .lockedChats: pair = ("lock.fill", .systemGreen)
        case .stats: pair = ("chart.pie.fill", .systemBlue)
        case .presets: pair = ("wand.and.stars", .systemPurple)
        case .exportSettings: pair = ("square.and.arrow.up.fill", .systemBlue)
        case .importSettings: pair = ("square.and.arrow.down.fill", .systemGreen)
        case .reset: pair = ("arrow.counterclockwise", .systemRed)
        case .automations: pair = ("bolt.fill", .systemOrange)
        }
        return ghostSettingsIcon(pair.0, pair.1)
    }
}

/// The sections of the GhostGram menu; the main screen lists them like iOS Settings.
private enum GhostPage: Int32, CaseIterable {
    case ghost
    case fake
    case automations
    case messages
    case stickers
    case filters
    case media
    case content
    case people
    case island
    case interface
    case security
    case manage

    var title: String {
        switch self {
        case .ghost: return "Режим призрака"
        case .fake: return "Фейковые статусы"
        case .automations: return "Авто-действия"
        case .messages: return "Удалённые и правки"
        case .stickers: return "Стикеры"
        case .filters: return "Фильтры"
        case .media: return "Медиа и загрузки"
        case .content: return "Контент"
        case .people: return "Люди"
        case .island: return "Dynamic Island"
        case .interface: return "Интерфейс"
        case .security: return "Безопасность"
        case .manage: return "Управление"
        }
    }

    var icon: UIImage? {
        let pair: (String, UIColor)
        switch self {
        case .ghost: pair = ("eye.slash.fill", .systemPurple)
        case .fake: pair = ("theatermasks.fill", .systemPink)
        case .automations: pair = ("bolt.fill", .systemOrange)
        case .messages: pair = ("trash.slash.fill", .systemRed)
        case .stickers: pair = ("face.smiling.inverse", .systemYellow)
        case .filters: pair = ("line.3.horizontal.decrease.circle.fill", .systemIndigo)
        case .media: pair = ("arrow.down.circle.fill", .systemBlue)
        case .content: pair = ("lock.open.fill", .systemTeal)
        case .people: pair = ("person.2.fill", .systemGreen)
        case .island: pair = ("capsule.fill", .black)
        case .interface: pair = ("paintpalette.fill", .systemCyan)
        case .security: pair = ("lock.shield.fill", .systemGreen)
        case .manage: pair = ("gearshape.fill", .systemGray)
        }
        return ghostSettingsIcon(pair.0, pair.1)
    }

    /// The switches that live on this page, used to show "3 of 6".
    var toggles: [GhostToggle] {
        switch self {
        case .ghost: return [.hideRead, .readOnReply, .hideStoryViews, .hideOnline, .hideTyping, .hideOtherActivities, .schedule]
        case .fake: return [.fakeActivities]
        case .automations: return []
        case .messages: return [.keepDeleted, .keepEditHistory, .keepViewOnce, .keepSecret, .notifyOnDelete, .deletedLog]
        case .stickers: return [.stickersWithoutPack, .confirmStickers]
        case .filters: return [.filter]
        case .media: return [.downloadBoost, .autoCache, .autoCachePhotos, .autoCacheVideos, .autoCacheVoice, .autoCacheFiles, .extendedSpeeds]
        case .content: return [.bypassCopyProtection, .hideScreenshots, .hideSponsored, .hideStories]
        case .people: return [.profileId, .profileLog]
        case .island: return [.uploadIsland, .dynamicIsland, .islandBadge]
        case .interface: return [.hidePhone, .confirmVoice, .confirmCalls, .messageDetails, .notes, .seconds, .doubleTapReply, .noSwipeReply, .noHaptics, .hideNewsTab, .hideBadge, .glassProfile, .showBadges, .advertiseBadge, .minimalTabs]
        case .security: return [.hiddenChats, .panicShake, .hideOnCapture, .protectMenu]
        case .manage: return []
        }
    }

    var label: String {
        if self == .automations {
            let count = GhostAutomations.rules.filter { $0.enabled }.count
            return count == 0 ? "" : "\(count) вкл"
        }
        let list = self.toggles
        if list.isEmpty {
            return ""
        }
        let on = list.filter { $0.value }.count
        return on == 0 ? "выкл" : "\(on) из \(list.count)"
    }
}

private final class GhostGramSettingsArguments {
    let toggle: (GhostToggle, Bool) -> Void
    let open: (GhostLink) -> Void
    let openPage: (GhostPage) -> Void

    init(toggle: @escaping (GhostToggle, Bool) -> Void, open: @escaping (GhostLink) -> Void, openPage: @escaping (GhostPage) -> Void) {
        self.toggle = toggle
        self.open = open
        self.openPage = openPage
    }
}

private enum GhostGramSettingsEntry: ItemListNodeEntry {
    case header(id: Int32, section: Int32, text: String)
    case toggle(id: Int32, section: Int32, option: GhostToggle, value: Bool, enabled: Bool)
    case link(id: Int32, section: Int32, link: GhostLink, title: String, label: String, destructive: Bool)
    case footer(id: Int32, section: Int32, text: String)
    case page(id: Int32, section: Int32, page: GhostPage, label: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _), let .link(_, section, _, _, _, _), let .footer(_, section, _), let .page(_, section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _), let .link(id, _, _, _, _, _), let .footer(id, _, _), let .page(id, _, _, _):
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
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: option.icon, title: option.title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(option, value)
            })
        case let .link(_, _, link, title, label, destructive):
            if destructive {
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.open(link)
                })
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: link.icon, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.open(link)
            })
        case let .page(_, _, page, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: page.icon, title: page.title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openPage(page)
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

private func ghostGramSettingsEntries(page: GhostPage?) -> [GhostGramSettingsEntry] {
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
    func pageLink(_ section: Int32, _ target: GhostPage) {
        entries.append(.page(id: next(), section: section, page: target, label: target.label))
    }

    guard let page = page else {
        // The home screen: the most used switches, then every section like in iOS Settings.
        header(0, "БЫСТРО")
        toggle(0, .hideRead)
        toggle(0, .hideOnline)
        toggle(0, .keepDeleted)
        footer(0, "Самое нужное — одним касанием. Остальное разложено по разделам ниже.")

        header(1, "ПРИВАТНОСТЬ")
        pageLink(1, .ghost)
        pageLink(1, .fake)
        pageLink(1, .messages)
        pageLink(1, .security)

        header(2, "ВОЗМОЖНОСТИ")
        pageLink(2, .automations)
        link(2, .plugins, "Плагины", "\(GhostPlugins.shared.installed.filter { GhostPlugins.shared.isEnabled($0.id) }.count) вкл")
        pageLink(2, .stickers)
        pageLink(2, .island)
        pageLink(2, .media)

        header(3, "ВНЕШНИЙ ВИД И ЛЮДИ")
        pageLink(3, .interface)
        pageLink(3, .content)
        pageLink(3, .filters)
        pageLink(3, .people)

        header(4, "ЕЩЁ")
        link(4, .stats, "Моя статистика")
        pageLink(4, .manage)
        footer(4, "Действия для отдельного чата — долгое нажатие на чат → «👻 GhostGram…». Для сообщения — долгое нажатие на сообщение.")
        return entries
    }

    switch page {
    case .ghost:
        header(0, "ЧТО СКРЫВАТЬ")
        toggle(0, .hideRead)
        toggle(0, .readOnReply, enabled: GhostSettings.hideReadReceipts || GhostSettings.ghostScheduleEnabled)
        toggle(0, .hideStoryViews)
        toggle(0, .hideOnline)
        toggle(0, .hideTyping)
        toggle(0, .hideOtherActivities)
        footer(0, "Собеседник не увидит, что ты прочитал сообщение, послушал голосовое или посмотрел историю.")
        header(1, "АВТОМАТИКА")
        toggle(1, .schedule)
        link(1, .scheduleHours, "Расписание", "\(hourTitle(GhostSettings.ghostScheduleFrom))–\(hourTitle(GhostSettings.ghostScheduleTo))")
        link(1, .onlineDelay, "Не в сети после открытия", delayTitle(GhostSettings.onlineDelaySeconds))
        link(1, .exceptions, "Исключения", "\(GhostSettings.ghostExceptions.count)")
        footer(1, "По расписанию призрак включается сам. В чатах-исключениях он не действует.")
    case .fake:
        header(0, "СТАТУСЫ")
        toggle(0, .fakeActivities)
        link(0, .fakeList, "Чаты со статусом", "\(GhostSettings.fakeActivities.count)")
        footer(0, "В выбранном чате постоянно висит «печатает…», «записывает голосовое», «играет в игру». Включается долгим нажатием на чат → «👻 GhostGram…».")
    case .automations:
        header(0, "АВТО-ДЕЙСТВИЯ")
        link(0, .automations, "Открыть авто-действия", page.label)
        footer(0, "Когда тебе написали в личку, тегнули в группе, ответили или написали слово — GhostGram сам поставит реакцию, кинет стикер, гифку или ответит текстом.")
    case .messages:
        header(0, "СОХРАНЯТЬ")
        toggle(0, .keepDeleted)
        toggle(0, .keepEditHistory)
        toggle(0, .keepViewOnce)
        toggle(0, .keepSecret)
        header(1, "УДАЛЁННЫЕ")
        toggle(1, .notifyOnDelete, enabled: GhostSettings.keepDeletedMessages)
        toggle(1, .deletedLog, enabled: GhostSettings.keepDeletedMessages)
        link(1, .deletedStyle, "Пометка удалённых", GhostSettings.deletedMarkStyle == 1 ? "удалено" : "🗑")
        link(1, .deletedLog, "Журнал удалённых", "\(GhostDeletedLog.entries().count)")
        link(1, .deletedStats, "Кто сколько удалил")
        footer(1, "Старые версии правок — в меню сообщения → «История правок». Сохраняется только то, что успело прийти на телефон.")
    case .stickers:
        header(0, "СТИКЕРЫ")
        toggle(0, .stickersWithoutPack)
        toggle(0, .confirmStickers)
        footer(0, "«Без стикерпака» — каждый твой стикер загружается заново. У собеседника он выглядит как обычный стикер, но открыть его пак и добавить себе нельзя.")
    case .filters:
        header(0, "ФИЛЬТРЫ")
        toggle(0, .filter)
        link(0, .keywords, "Скрывать слова", "\(GhostSettings.filterKeywords.count)")
        link(0, .ignored, "Игнор-лист", "\(GhostSettings.ignoredUsers.count)")
        footer(0, "Сообщения с этими словами и от людей из игнор-листа не показываются. Добавить в игнор — меню сообщения → «Игнорировать автора».")
    case .media:
        header(0, "СКОРОСТЬ")
        toggle(0, .downloadBoost)
        toggle(0, .extendedSpeeds)
        header(1, "АВТОСОХРАНЕНИЕ")
        toggle(1, .autoCache)
        let cacheOn = GhostSettings.autoCachePrivateMedia
        toggle(1, .autoCachePhotos, enabled: cacheOn)
        toggle(1, .autoCacheVideos, enabled: cacheOn)
        toggle(1, .autoCacheVoice, enabled: cacheOn)
        toggle(1, .autoCacheFiles, enabled: cacheOn)
        link(1, .cacheLimit, "Максимальный размер", cacheLimitTitle(GhostSettings.autoCacheLimitMB))
        footer(1, "Медиа из личных чатов скачивается сразу, поэтому остаётся у тебя, даже если собеседник его удалит.")
    case .content:
        header(0, "КОНТЕНТ")
        toggle(0, .bypassCopyProtection)
        toggle(0, .hideScreenshots)
        toggle(0, .hideSponsored)
        toggle(0, .hideStories)
        footer(0, "Обход запрета позволяет сохранять и копировать из защищённых чатов и каналов. Пересылку оттуда сервер всё равно не пропустит.")
    case .people:
        header(0, "ПРОФИЛИ")
        toggle(0, .profileId)
        toggle(0, .profileLog)
        link(0, .profileLog, "Журнал изменений профилей", "\(GhostProfileLog.entries().count)")
        header(1, "СЛЕЖКА И ИМЕНА")
        link(1, .watchList, "Сообщать, когда в сети", "\(GhostSettings.onlineWatchList.count)")
        link(1, .onlineNow, "Кто сейчас в сети")
        link(1, .nicknames, "Локальные имена", "\(GhostSettings.nicknames.count)")
        link(1, .openById, "Открыть профиль по ID")
        footer(1, "Дата регистрации примерная — оценивается по ID. Локальные имена видишь только ты.")
    case .island:
        header(0, "ОТПРАВКА")
        toggle(0, .uploadIsland)
        footer(0, "Когда отправляешь фото, видео, гифку или файл и сворачиваешь GhostGram, в островке летит самолётик, видны проценты и вес в КБ. В конце — «Отправлено» и вибрация.")
        header(1, "ПРИЗРАК")
        toggle(1, .dynamicIsland)
        toggle(1, .islandBadge)
        footer(1, "👻 в островке, пока включён режим призрака. iOS показывает его и на экране блокировки — убрать там можно только вместе с островком.")
    case .interface:
        header(0, "ЧАТЫ")
        toggle(0, .seconds)
        toggle(0, .doubleTapReply)
        toggle(0, .noSwipeReply)
        toggle(0, .messageDetails)
        toggle(0, .notes)
        header(1, "ПОДТВЕРЖДЕНИЯ")
        toggle(1, .confirmVoice)
        toggle(1, .confirmCalls)
        header(2, "ВИД")
        toggle(2, .glassProfile)
        toggle(2, .minimalTabs)
        toggle(2, .hideNewsTab)
        toggle(2, .hideBadge)
        toggle(2, .hidePhone)
        toggle(2, .noHaptics)
        link(2, .amoled, "Включить AMOLED-тему")
        link(2, .chatListTitle, "Заголовок списка чатов", GhostSettings.customChatListTitle ?? "Чаты")
        header(3, "👻 ЗНАЧОК")
        toggle(3, .showBadges)
        toggle(3, .advertiseBadge)
        footer(3, "Часть изменений интерфейса применяется после перезапуска приложения.")
    case .security:
        header(0, "ЧАТЫ")
        toggle(0, .hiddenChats)
        link(0, .hiddenChats, "Открыть скрытые чаты", "\(GhostSettings.hiddenChats.count)")
        link(0, .lockedChats, "Чаты под Face ID", "\(GhostSettings.lockedChats.count)")
        header(1, "ЗАЩИТА")
        toggle(1, .panicShake)
        toggle(1, .hideOnCapture)
        toggle(1, .protectMenu)
        footer(1, "Скрыть или закрыть чат: долгое нажатие на чат в списке. Паника: резко встряхни телефон — GhostGram свернётся, закрытые чаты снова потребуют Face ID.")
    case .manage:
        header(0, "НАСТРОЙКИ")
        link(0, .presets, "Пресеты")
        link(0, .exportSettings, "Экспорт настроек")
        link(0, .importSettings, "Импорт из буфера")
        header(1, "")
        link(1, .reset, "Сбросить все настройки GhostGram", destructive: true)
    }
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
    return ghostGramSettingsPage(context: context, page: nil)
}

/// Gives the auto actions screen the account's stickers and GIFs.
private func ghostAutomationsMedia(context: AccountContext) -> GhostAutomationsMedia {
    let account = context.account
    return GhostAutomationsMedia(load: { completion in
        let _ = (ghostPickableMedia(account: account)
        |> deliverOnMainQueue).start(next: { result in
            let stickers = result.stickers.map { GhostPickItem(data: ghostEncodeMediaFile($0), emoji: ghostStickerEmoji($0), key: "s\($0.fileId.id)") }
            let gifs = result.gifs.map { GhostPickItem(data: ghostEncodeMediaFile($0), emoji: "", key: "g\($0.fileId.id)") }
            completion(stickers, gifs)
        })
    }, thumbnail: { item, completion in
        guard let file = ghostDecodeMediaFile(item.data) else {
            completion(nil)
            return
        }
        let _ = (ghostMediaThumbnail(account: account, file: file)
        |> deliverOnMainQueue).start(next: { data in
            completion(data.flatMap { UIImage(data: $0) })
        })
    })
}

private func ghostGramSettingsPage(context: AccountContext, page: GhostPage?) -> ViewController {
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
    var openPageImpl: ((GhostPage) -> Void)?

    let arguments = GhostGramSettingsArguments(toggle: { option, value in
        option.set(value)
        if case .advertiseBadge = option {
            ghostSyncNameMarker(account: context.account)
        }
        changed()
    }, open: { link in
        openImpl?(link)
    }, openPage: { target in
        openPageImpl?(target)
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(page?.title ?? "GhostGram 👻"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ghostGramSettingsEntries(page: page), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { [weak controller] _ in
        refresh()
        if page == nil && !GhostSettings.onboardingShown {
            GhostSettings.onboardingShown = true
            ghostInform(context: context, from: controller, title: "Добро пожаловать в GhostGram 👻", text: "Здесь всё, что умеет GhostGram. Начать проще всего с «Пресетов» внизу: «Невидимка» включает режим призрака, «Архивариус» — сохранение удалённого. Действия для отдельного чата — долгое нажатие на чат → «👻 GhostGram…», для сообщения — долгое нажатие на сообщение.")
        }
    }

    openPageImpl = { [weak controller] target in
        if target == .automations {
            openImpl?(.automations)
            return
        }
        ghostPushController(controller, ghostGramSettingsPage(context: context, page: target))
    }

    openImpl = { [weak controller] link in
        guard let controller = controller else {
            return
        }
        switch link {
        case .automations:
            let dark = context.sharedContext.currentPresentationData.with { $0 }.theme.overallDarkAppearance
            ghostPresentAutomationsScreen(from: controller, dark: dark, media: ghostAutomationsMedia(context: context))
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
        case .plugins:
            let dark = context.sharedContext.currentPresentationData.with { $0 }.theme.overallDarkAppearance
            ghostPresentPluginsScreen(from: controller, dark: dark)
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
            let prompt = promptController(context: context, text: "ID пользователя, группы или канала", value: "", placeholder: "Например 123456789 или -100…", characterLimit: 24, apply: { [weak controller] value in
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
                |> deliverOnMainQueue).start(next: { peers in
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
