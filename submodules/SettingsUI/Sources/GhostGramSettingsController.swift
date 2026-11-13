import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private enum GhostGramOption: Int32 {
    case keepDeleted
    case keepEditHistory
    case keepViewOnce
    case hideRead
    case hideOnline
    case hideTyping

    var title: String {
        switch self {
        case .keepDeleted:
            return "Сохранять удалённые сообщения"
        case .keepEditHistory:
            return "Сохранять историю правок"
        case .keepViewOnce:
            return "Не сжигать одноразовые медиа"
        case .hideRead:
            return "Не отправлять «прочитано»"
        case .hideOnline:
            return "Скрывать «в сети»"
        case .hideTyping:
            return "Скрывать «печатает…»"
        }
    }

    var value: Bool {
        switch self {
        case .keepDeleted:
            return GhostSettings.keepDeletedMessages
        case .keepEditHistory:
            return GhostSettings.keepEditHistory
        case .keepViewOnce:
            return GhostSettings.keepViewOnceMedia
        case .hideRead:
            return GhostSettings.hideReadReceipts
        case .hideOnline:
            return GhostSettings.hideOnlineStatus
        case .hideTyping:
            return GhostSettings.hideTyping
        }
    }

    func set(_ value: Bool) {
        switch self {
        case .keepDeleted:
            GhostSettings.keepDeletedMessages = value
        case .keepEditHistory:
            GhostSettings.keepEditHistory = value
        case .keepViewOnce:
            GhostSettings.keepViewOnceMedia = value
        case .hideRead:
            GhostSettings.hideReadReceipts = value
        case .hideOnline:
            GhostSettings.hideOnlineStatus = value
        case .hideTyping:
            GhostSettings.hideTyping = value
        }
    }
}

private final class GhostGramSettingsArguments {
    let toggle: (GhostGramOption, Bool) -> Void

    init(toggle: @escaping (GhostGramOption, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum GhostGramSettingsEntry: ItemListNodeEntry {
    case header(id: Int32, section: Int32, text: String)
    case option(id: Int32, section: Int32, option: GhostGramOption, value: Bool)
    case footer(id: Int32, section: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .option(_, section, _, _), let .footer(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .option(id, _, _, _), let .footer(id, _, _):
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
        case let .option(_, _, option, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: option.title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(option, value)
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ghostGramSettingsEntries() -> [GhostGramSettingsEntry] {
    var entries: [GhostGramSettingsEntry] = []
    entries.append(.header(id: 0, section: 0, text: "СООБЩЕНИЯ"))
    entries.append(.option(id: 1, section: 0, option: .keepDeleted, value: GhostGramOption.keepDeleted.value))
    entries.append(.option(id: 2, section: 0, option: .keepEditHistory, value: GhostGramOption.keepEditHistory.value))
    entries.append(.option(id: 3, section: 0, option: .keepViewOnce, value: GhostGramOption.keepViewOnce.value))
    entries.append(.footer(id: 4, section: 0, text: "Удалённые сообщения остаются в чате со значком 🗑 у времени. Старые версии отредактированных сообщений — в меню сообщения → «История правок». Хранится только то, что успело прийти на этот телефон."))

    entries.append(.header(id: 10, section: 1, text: "РЕЖИМ ПРИЗРАКА"))
    entries.append(.option(id: 11, section: 1, option: .hideRead, value: GhostGramOption.hideRead.value))
    entries.append(.option(id: 12, section: 1, option: .hideOnline, value: GhostGramOption.hideOnline.value))
    entries.append(.option(id: 13, section: 1, option: .hideTyping, value: GhostGramOption.hideTyping.value))
    entries.append(.footer(id: 14, section: 1, text: "Собеседник не увидит, что вы прочитали сообщение, прослушали голосовое или посмотрели историю. Если ответить в чат, сервер всё равно может показать вас в сети."))
    return entries
}

public func ghostGramSettingsController(context: AccountContext) -> ViewController {
    let revision = ValuePromise<Int>(0, ignoreRepeated: false)
    var currentRevision = 0

    let arguments = GhostGramSettingsArguments(toggle: { option, value in
        option.set(value)
        currentRevision += 1
        revision.set(currentRevision)
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, revision.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("GhostGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ghostGramSettingsEntries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
