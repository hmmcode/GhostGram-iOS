import Foundation
import UIKit
import TelegramCore

// MARK: - Entry point

private let ghostAutoTint = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)

/// A sticker or GIF the user can pick: the encoded file plus a fallback emoji.
public struct GhostPickItem {
    public let data: Data
    public let emoji: String
    public let key: String

    public init(data: Data, emoji: String, key: String) {
        self.data = data
        self.emoji = emoji
        self.key = key
    }
}

/// How the screen reaches the account's stickers and GIFs (kept as closures so this file stays UIKit-only).
public final class GhostAutomationsMedia {
    let load: (@escaping (_ stickers: [GhostPickItem], _ gifs: [GhostPickItem]) -> Void) -> Void
    let thumbnail: (GhostPickItem, @escaping (UIImage?) -> Void) -> Void

    public init(load: @escaping (@escaping (_ stickers: [GhostPickItem], _ gifs: [GhostPickItem]) -> Void) -> Void, thumbnail: @escaping (GhostPickItem, @escaping (UIImage?) -> Void) -> Void) {
        self.load = load
        self.thumbnail = thumbnail
    }
}

/// Opens GhostGram → Auto actions as a sheet.
public func ghostPresentAutomationsScreen(from presenter: UIViewController?, dark: Bool, media: GhostAutomationsMedia) {
    let navigation = UINavigationController(rootViewController: GhostAutomationsListController(media: media))
    navigation.overrideUserInterfaceStyle = dark ? .dark : .light
    navigation.view.tintColor = ghostAutoTint
    navigation.navigationBar.prefersLargeTitles = true
    navigation.modalPresentationStyle = .pageSheet
    var top: UIViewController? = presenter?.view.window?.rootViewController ?? presenter
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
        top = presented
    }
    top?.present(navigation, animated: true, completion: nil)
}

// MARK: - Words

extension GhostAutomationRule.Trigger {
    var title: String {
        switch self {
        case .privateMessage: return "Мне написали в личку"
        case .mention: return "Меня тегнули в группе"
        case .reply: return "Ответили на моё сообщение"
        case .keyword: return "Кто-то написал слово…"
        case .person: return "Написал определённый человек"
        case .groupMessage: return "Любое сообщение в группе"
        }
    }

    var short: String {
        switch self {
        case .privateMessage: return "пишут в личку"
        case .mention: return "тегнули в группе"
        case .reply: return "ответили мне"
        case .keyword: return "есть слово"
        case .person: return "пишет человек"
        case .groupMessage: return "сообщение в группе"
        }
    }

    var symbol: String {
        switch self {
        case .privateMessage: return "bubble.left.fill"
        case .mention: return "at"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .keyword: return "text.magnifyingglass"
        case .person: return "person.crop.circle.fill"
        case .groupMessage: return "person.3.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .privateMessage: return .systemBlue
        case .mention: return .systemPurple
        case .reply: return .systemTeal
        case .keyword: return .systemIndigo
        case .person: return .systemGreen
        case .groupMessage: return .systemOrange
        }
    }
}

extension GhostAutomationRule.Action {
    var title: String {
        switch self {
        case .reaction: return "Поставить реакцию"
        case .sticker: return "Отправить стикер"
        case .gif: return "Отправить гифку"
        case .text: return "Ответить текстом"
        }
    }

    var symbol: String {
        switch self {
        case .reaction: return "heart.fill"
        case .sticker: return "face.smiling.inverse"
        case .gif: return "play.rectangle.fill"
        case .text: return "text.bubble.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .reaction: return .systemPink
        case .sticker: return .systemYellow
        case .gif: return .systemGreen
        case .text: return .systemBlue
        }
    }
}

private func ghostAutoSummary(_ rule: GhostAutomationRule) -> String {
    var when = rule.trigger.short
    if rule.trigger == .keyword, !rule.keyword.isEmpty {
        when = "есть слово «\(rule.keyword)»"
    } else if rule.trigger == .person, !rule.person.isEmpty {
        when = "пишет \(rule.person)"
    }
    let what: String
    switch rule.action {
    case .reaction: what = "реакция \(rule.emoji)"
    case .sticker: what = rule.withoutPack ? "стикер (без пака)" : "стикер"
    case .gif: what = "гифка"
    case .text: what = "«\(rule.text.prefix(30))»"
    }
    return "Когда \(when) → \(what)"
}

private func ghostCooldownTitle(_ seconds: Int) -> String {
    switch seconds {
    case ..<1: return "Каждый раз"
    case 1 ..< 3600: return "Раз в \(seconds / 60) мин"
    case 3600 ..< 86400: return "Раз в \(seconds / 3600) ч"
    default: return "Раз в день"
    }
}

private func ghostSymbol(_ name: String, _ color: UIColor) -> UIImage? {
    return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))?.withTintColor(color, renderingMode: .alwaysOriginal)
}

private func ghostAutoSwitch(isOn: Bool, changed: @escaping (Bool) -> Void) -> UISwitch {
    let view = UISwitch()
    view.isOn = isOn
    view.onTintColor = ghostAutoTint
    view.addAction(UIAction(handler: { action in
        if let sender = action.sender as? UISwitch {
            changed(sender.isOn)
        }
    }), for: .valueChanged)
    return view
}

private func ghostAskText(_ controller: UIViewController, title: String, text: String, value: String, placeholder: String, done: @escaping (String) -> Void) {
    let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
    alert.addTextField { field in
        field.text = value
        field.placeholder = placeholder
        field.clearButtonMode = .whileEditing
    }
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Готово", style: .default, handler: { _ in
        done(alert.textFields?.first?.text ?? "")
    }))
    controller.present(alert, animated: true, completion: nil)
}

// MARK: - List

private final class GhostAutomationsListController: UITableViewController {
    private let media: GhostAutomationsMedia
    private var rules: [GhostAutomationRule] = []
    private var observer: NSObjectProtocol?

    private struct Template {
        let title: String
        let make: () -> GhostAutomationRule
    }

    private let templates: [Template] = [
        Template(title: "❤️ Лайк на каждое сообщение в личке", make: {
            var rule = GhostAutomationRule(trigger: .privateMessage, action: .reaction)
            rule.emoji = "❤️"
            rule.cooldown = 0
            return rule
        }),
        Template(title: "👀 Реакция, когда тегнули в группе", make: {
            var rule = GhostAutomationRule(trigger: .mention, action: .reaction)
            rule.emoji = "👀"
            rule.cooldown = 0
            return rule
        }),
        Template(title: "🖼 Стикер, когда ответили на моё сообщение", make: {
            return GhostAutomationRule(trigger: .reply, action: .sticker)
        }),
        Template(title: "💤 Автоответ «Я занят»", make: {
            var rule = GhostAutomationRule(trigger: .privateMessage, action: .text)
            rule.text = "Я сейчас занят, отвечу позже 👻"
            rule.cooldown = 3600
            return rule
        })
    ]

    init(media: GhostAutomationsMedia) {
        self.media = media
        super.init(style: .insetGrouped)
        self.title = "Авто-действия"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction(handler: { [weak self] _ in
            self?.edit(GhostAutomationRule(), isNew: true)
        }))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction(handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        self.observer = NotificationCenter.default.addObserver(forName: GhostAutomations.changedNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.reload()
        })
        self.reload()
    }

    private func reload() {
        self.rules = GhostAutomations.rules
        self.tableView.reloadData()
    }

    private func edit(_ rule: GhostAutomationRule, isNew: Bool) {
        self.navigationController?.pushViewController(GhostAutomationEditorController(rule: rule, isNew: isNew, media: self.media), animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return max(1, self.rules.count)
        default: return self.templates.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1: return "Мои действия"
        case 2: return "Готовые идеи — нажми, чтобы добавить"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "GhostGram сам ответит стикером, гифкой, реакцией или текстом, когда тебе пишут. Работает, пока приложение открыто или недавно свёрнуто."
        case 1: return self.rules.isEmpty ? nil : "Смахни влево, чтобы удалить."
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.subtitleCell()
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 2
        content.imageProperties.reservedLayoutSize = CGSize(width: 30, height: 30)
        switch indexPath.section {
        case 0:
            content.image = ghostSymbol("bolt.fill", ghostAutoTint)
            content.text = "Авто-действия включены"
            cell.accessoryView = ghostAutoSwitch(isOn: GhostSettings.automationsEnabled, changed: { value in
                GhostSettings.automationsEnabled = value
                UISelectionFeedbackGenerator().selectionChanged()
            })
            cell.selectionStyle = .none
        case 1:
            if self.rules.isEmpty {
                content.image = ghostSymbol("plus.circle.fill", ghostAutoTint)
                content.text = "Добавить первое действие"
                content.textProperties.color = ghostAutoTint
                cell.accessoryType = .disclosureIndicator
            } else {
                let rule = self.rules[indexPath.row]
                content.image = ghostSymbol(rule.trigger.symbol, rule.trigger.color)
                content.text = rule.action.title + (rule.action == .reaction ? " \(rule.emoji)" : "")
                content.secondaryText = ghostAutoSummary(rule) + " · " + ghostCooldownTitle(rule.cooldown).lowercased()
                let id = rule.id
                cell.accessoryView = ghostAutoSwitch(isOn: rule.enabled, changed: { value in
                    var all = GhostAutomations.rules
                    if let index = all.firstIndex(where: { $0.id == id }) {
                        all[index].enabled = value
                        GhostAutomations.rules = all
                    }
                })
            }
        default:
            content.text = self.templates[indexPath.row].title
            content.image = ghostSymbol("sparkles", .systemYellow)
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 1:
            if self.rules.isEmpty {
                self.edit(GhostAutomationRule(), isNew: true)
            } else {
                self.edit(self.rules[indexPath.row], isNew: false)
            }
        case 2:
            self.edit(self.templates[indexPath.row].make(), isNew: true)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1, !self.rules.isEmpty else {
            return nil
        }
        let id = self.rules[indexPath.row].id
        return UISwipeActionsConfiguration(actions: [UIContextualAction(style: .destructive, title: "Удалить", handler: { _, _, done in
            GhostAutomations.remove(id)
            done(true)
        })])
    }
}

// MARK: - Editor

private final class GhostAutomationEditorController: UITableViewController {
    private var rule: GhostAutomationRule
    private let isNew: Bool
    private let media: GhostAutomationsMedia
    private var preview: UIImage?

    private enum Section {
        case trigger
        case action
        case what
        case options
        case delete
    }

    private var sections: [Section] {
        return self.isNew ? [.trigger, .action, .what, .options] : [.trigger, .action, .what, .options, .delete]
    }

    init(rule: GhostAutomationRule, isNew: Bool, media: GhostAutomationsMedia) {
        self.rule = rule
        self.isNew = isNew
        self.media = media
        super.init(style: .insetGrouped)
        self.title = isNew ? "Новое действие" : "Действие"
        self.navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", primaryAction: UIAction(handler: { [weak self] _ in
            self?.save()
        }))
        self.loadPreview()
    }

    private func loadPreview() {
        guard let data = self.rule.media else {
            self.preview = nil
            return
        }
        self.media.thumbnail(GhostPickItem(data: data, emoji: "", key: "rule"), { [weak self] image in
            DispatchQueue.main.async {
                self?.preview = image
                self?.tableView.reloadData()
            }
        })
    }

    private func save() {
        if self.rule.trigger == .keyword && self.rule.keyword.trimmingCharacters(in: .whitespaces).isEmpty {
            self.warn("Напиши слово, на которое реагировать.")
            return
        }
        if self.rule.trigger == .person && self.rule.person.trimmingCharacters(in: .whitespaces).isEmpty {
            self.warn("Напиши @юзернейм или имя человека.")
            return
        }
        if (self.rule.action == .sticker || self.rule.action == .gif) && self.rule.media == nil {
            self.warn(self.rule.action == .sticker ? "Выбери стикер." : "Выбери гифку.")
            return
        }
        if self.rule.action == .text && self.rule.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.warn("Напиши текст ответа.")
            return
        }
        GhostAutomations.save(self.rule)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        self.navigationController?.popViewController(animated: true)
    }

    private func warn(_ text: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let alert = UIAlertController(title: "Почти готово", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private var triggerRows: [GhostAutomationRule.Trigger] {
        return GhostAutomationRule.Trigger.allCases
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.sections[section] {
        case .trigger:
            return self.triggerRows.count + ((self.rule.trigger == .keyword || self.rule.trigger == .person) ? 1 : 0)
        case .action:
            return GhostAutomationRule.Action.allCases.count
        case .what:
            return 1
        case .options:
            switch self.rule.action {
            case .reaction: return 1
            case .sticker: return 3
            case .gif, .text: return 2
            }
        case .delete:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch self.sections[section] {
        case .trigger: return "1. Когда"
        case .action: return "2. Что сделать"
        case .what: return "3. Что именно"
        case .options: return "Настройки"
        case .delete: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch self.sections[section] {
        case .options:
            return self.rule.action == .sticker ? "«Без пака» — стикер загрузится заново, и никто не сможет открыть его стикерпак." : nil
        case .what:
            return self.rule.action == .reaction ? "Реакция ставится прямо на сообщение, которое тебе прислали." : nil
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        content.imageProperties.reservedLayoutSize = CGSize(width: 30, height: 30)
        switch self.sections[indexPath.section] {
        case .trigger:
            if indexPath.row < self.triggerRows.count {
                let trigger = self.triggerRows[indexPath.row]
                content.image = ghostSymbol(trigger.symbol, trigger.color)
                content.text = trigger.title
                cell.accessoryType = trigger == self.rule.trigger ? .checkmark : .none
            } else if self.rule.trigger == .keyword {
                content.image = ghostSymbol("pencil", .secondaryLabel)
                content.text = "Слово"
                content.secondaryText = self.rule.keyword.isEmpty ? "не задано" : self.rule.keyword
                cell.accessoryType = .disclosureIndicator
            } else {
                content.image = ghostSymbol("pencil", .secondaryLabel)
                content.text = "Кто"
                content.secondaryText = self.rule.person.isEmpty ? "не задано" : self.rule.person
                cell.accessoryType = .disclosureIndicator
            }
        case .action:
            let action = GhostAutomationRule.Action.allCases[indexPath.row]
            content.image = ghostSymbol(action.symbol, action.color)
            content.text = action.title
            cell.accessoryType = action == self.rule.action ? .checkmark : .none
        case .what:
            cell.accessoryType = .disclosureIndicator
            switch self.rule.action {
            case .reaction:
                content.text = "Реакция"
                content.secondaryText = self.rule.emoji
                content.secondaryTextProperties.font = .systemFont(ofSize: 26)
            case .sticker, .gif:
                content.text = self.rule.action == .sticker ? "Стикер" : "Гифка"
                if let preview = self.preview {
                    content.image = preview
                    content.imageProperties.maximumSize = CGSize(width: 56, height: 56)
                    content.imageProperties.reservedLayoutSize = CGSize(width: 56, height: 56)
                    content.secondaryText = "поменять"
                } else {
                    content.secondaryText = self.rule.media == nil ? "выбрать" : "выбрано ✓"
                }
            case .text:
                content.text = "Текст"
                content.secondaryText = self.rule.text.isEmpty ? "написать" : String(self.rule.text.prefix(40))
            }
        case .options:
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0:
                content.image = ghostSymbol("timer", .systemGray)
                content.text = "Не чаще чем"
                content.secondaryText = ghostCooldownTitle(self.rule.cooldown)
                cell.selectionStyle = .default
                cell.accessoryType = .disclosureIndicator
            case 1:
                content.image = ghostSymbol("arrowshape.turn.up.left", .systemGray)
                content.text = "Ответом на сообщение"
                cell.accessoryView = ghostAutoSwitch(isOn: self.rule.asReply, changed: { [weak self] value in
                    self?.rule.asReply = value
                })
            default:
                content.image = ghostSymbol("eye.slash", .systemGray)
                content.text = "Стикер без пака"
                cell.accessoryView = ghostAutoSwitch(isOn: self.rule.withoutPack, changed: { [weak self] value in
                    self?.rule.withoutPack = value
                })
            }
        case .delete:
            content = UIListContentConfiguration.cell()
            content.text = "Удалить действие"
            content.textProperties.color = .systemRed
            content.textProperties.alignment = .center
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch self.sections[indexPath.section] {
        case .trigger:
            if indexPath.row < self.triggerRows.count {
                self.rule.trigger = self.triggerRows[indexPath.row]
                UISelectionFeedbackGenerator().selectionChanged()
                tableView.reloadData()
                if self.rule.trigger == .keyword && self.rule.keyword.isEmpty {
                    self.askKeyword()
                } else if self.rule.trigger == .person && self.rule.person.isEmpty {
                    self.askPerson()
                }
            } else if self.rule.trigger == .keyword {
                self.askKeyword()
            } else {
                self.askPerson()
            }
        case .action:
            let action = GhostAutomationRule.Action.allCases[indexPath.row]
            if action != self.rule.action {
                self.rule.media = nil
                self.preview = nil
                self.rule.action = action
            }
            UISelectionFeedbackGenerator().selectionChanged()
            tableView.reloadData()
        case .what:
            self.pickWhat()
        case .options:
            if indexPath.row == 0 {
                self.pickCooldown()
            }
        case .delete:
            GhostAutomations.remove(self.rule.id)
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func askKeyword() {
        ghostAskText(self, title: "Какое слово?", text: "Сработает, если оно есть в сообщении (в любом чате).", value: self.rule.keyword, placeholder: "например: привет", done: { [weak self] value in
            self?.rule.keyword = value.trimmingCharacters(in: .whitespaces)
            self?.tableView.reloadData()
        })
    }

    private func askPerson() {
        ghostAskText(self, title: "Кто пишет?", text: "Напиши @юзернейм, имя как в Telegram или ID.", value: self.rule.person, placeholder: "@username", done: { [weak self] value in
            self?.rule.person = value.trimmingCharacters(in: .whitespaces)
            self?.tableView.reloadData()
        })
    }

    private func pickWhat() {
        switch self.rule.action {
        case .reaction:
            let picker = GhostEmojiPickerController(selected: self.rule.emoji, picked: { [weak self] emoji in
                self?.rule.emoji = emoji
                self?.tableView.reloadData()
            })
            self.navigationController?.pushViewController(picker, animated: true)
        case .sticker, .gif:
            let picker = GhostMediaPickerController(media: self.media, gifs: self.rule.action == .gif, picked: { [weak self] item, image in
                self?.rule.media = item.data
                self?.preview = image
                self?.tableView.reloadData()
            })
            self.navigationController?.pushViewController(picker, animated: true)
        case .text:
            ghostAskText(self, title: "Что ответить?", text: "Этот текст уйдёт собеседнику.", value: self.rule.text, placeholder: "Я занят, отвечу позже", done: { [weak self] value in
                self?.rule.text = value
                self?.tableView.reloadData()
            })
        }
    }

    private func pickCooldown() {
        let sheet = UIAlertController(title: "Как часто срабатывать в одном чате?", message: nil, preferredStyle: .actionSheet)
        for seconds in [0, 60, 300, 3600, 86400] {
            sheet.addAction(UIAlertAction(title: ghostCooldownTitle(seconds) + (seconds == self.rule.cooldown ? " ✓" : ""), style: .default, handler: { [weak self] _ in
                self?.rule.cooldown = seconds
                self?.tableView.reloadData()
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        sheet.popoverPresentationController?.sourceView = self.view
        self.present(sheet, animated: true, completion: nil)
    }
}

// MARK: - Emoji picker

private final class GhostEmojiPickerController: UICollectionViewController {
    private static let emojis: [String] = ["❤️", "👍", "🔥", "😂", "🥰", "👏", "😁", "🤔", "🤯", "😱", "🎉", "🤩", "🙏", "👌", "😍", "❤️‍🔥", "💯", "🤣", "⚡️", "🏆", "💔", "🤨", "😐", "🍓", "🍾", "💋", "😈", "😴", "😭", "🤓", "👻", "👀", "🎃", "🙈", "😇", "😨", "🤝", "✍️", "🤗", "🫡", "💅", "🤪", "🗿", "🆒", "💘", "🦄", "😘", "😎", "👾", "🤷", "😡", "👎", "🤡", "🥱", "🕊", "🐳", "🌚", "🌭", "🍌", "💩", "🤮", "😢"]

    private let selected: String
    private let picked: (String) -> Void

    init(selected: String, picked: @escaping (String) -> Void) {
        self.selected = selected
        self.picked = picked
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 56, height: 56)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        super.init(collectionViewLayout: layout)
        self.title = "Выбери реакцию"
        self.navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.backgroundColor = .systemGroupedBackground
        self.collectionView.register(GhostEmojiCell.self, forCellWithReuseIdentifier: "e")
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return GhostEmojiPickerController.emojis.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "e", for: indexPath) as! GhostEmojiCell
        let emoji = GhostEmojiPickerController.emojis[indexPath.item]
        cell.label.text = emoji
        cell.contentView.backgroundColor = emoji == self.selected ? ghostAutoTint.withAlphaComponent(0.25) : .secondarySystemGroupedBackground
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self.picked(GhostEmojiPickerController.emojis[indexPath.item])
        self.navigationController?.popViewController(animated: true)
    }
}

private final class GhostEmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.layer.cornerRadius = 14
        self.contentView.layer.cornerCurve = .continuous
        self.label.font = .systemFont(ofSize: 30)
        self.label.textAlignment = .center
        self.contentView.addSubview(self.label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.label.frame = self.contentView.bounds
    }
}

// MARK: - Sticker / GIF picker

private final class GhostMediaPickerController: UICollectionViewController {
    private let media: GhostAutomationsMedia
    private var showGifs: Bool
    private let picked: (GhostPickItem, UIImage?) -> Void
    private var stickers: [GhostPickItem] = []
    private var gifs: [GhostPickItem] = []
    private var images: [String: UIImage] = [:]
    private var requested = Set<String>()
    private let emptyLabel = UILabel()

    init(media: GhostAutomationsMedia, gifs: Bool, picked: @escaping (GhostPickItem, UIImage?) -> Void) {
        self.media = media
        self.showGifs = gifs
        self.picked = picked
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 24, right: 12)
        super.init(collectionViewLayout: layout)
        self.navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var items: [GhostPickItem] {
        return self.showGifs ? self.gifs : self.stickers
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.backgroundColor = .systemGroupedBackground
        self.collectionView.register(GhostMediaCell.self, forCellWithReuseIdentifier: "m")
        let segmented = UISegmentedControl(items: ["Стикеры", "Гифки"])
        segmented.selectedSegmentIndex = self.showGifs ? 1 : 0
        segmented.addAction(UIAction(handler: { [weak self] action in
            guard let self = self, let control = action.sender as? UISegmentedControl else {
                return
            }
            self.showGifs = control.selectedSegmentIndex == 1
            self.collectionView.reloadData()
            self.updateEmpty()
        }), for: .valueChanged)
        self.navigationItem.titleView = segmented

        self.emptyLabel.text = "Загружаю…"
        self.emptyLabel.textColor = .secondaryLabel
        self.emptyLabel.numberOfLines = 0
        self.emptyLabel.textAlignment = .center
        self.collectionView.backgroundView = self.emptyLabel

        self.media.load({ [weak self] stickers, gifs in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.stickers = stickers
                self.gifs = gifs
                self.collectionView.reloadData()
                self.updateEmpty()
            }
        })
    }

    private func updateEmpty() {
        if self.items.isEmpty {
            self.emptyLabel.text = self.showGifs ? "Здесь появятся гифки, которые ты сохранял или недавно отправлял." : "Здесь появятся избранные и недавние стикеры. Отправь пару стикеров в любом чате и вернись сюда."
            self.collectionView.backgroundView = self.emptyLabel
        } else {
            self.collectionView.backgroundView = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let columns: CGFloat = 4
            let width = floor((self.collectionView.bounds.width - 24 - 8 * (columns - 1)) / columns)
            if layout.itemSize.width != width {
                layout.itemSize = CGSize(width: width, height: width)
                layout.invalidateLayout()
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "m", for: indexPath) as! GhostMediaCell
        let item = self.items[indexPath.item]
        cell.key = item.key
        cell.imageView.image = self.images[item.key]
        cell.label.text = self.images[item.key] == nil ? (item.emoji.isEmpty ? (self.showGifs ? "GIF" : "🙂") : item.emoji) : nil
        if self.images[item.key] == nil && !self.requested.contains(item.key) {
            self.requested.insert(item.key)
            self.media.thumbnail(item, { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self, let image = image else {
                        return
                    }
                    self.images[item.key] = image
                    for case let visible as GhostMediaCell in self.collectionView.visibleCells where visible.key == item.key {
                        visible.imageView.image = image
                        visible.label.text = nil
                    }
                }
            })
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = self.items[indexPath.item]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self.picked(item, self.images[item.key])
        self.navigationController?.popViewController(animated: true)
    }
}

private final class GhostMediaCell: UICollectionViewCell {
    let imageView = UIImageView()
    let label = UILabel()
    var key = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.backgroundColor = .secondarySystemGroupedBackground
        self.contentView.layer.cornerRadius = 14
        self.contentView.layer.cornerCurve = .continuous
        self.contentView.clipsToBounds = true
        self.imageView.contentMode = .scaleAspectFit
        self.label.font = .systemFont(ofSize: 30)
        self.label.textAlignment = .center
        self.label.textColor = .secondaryLabel
        self.contentView.addSubview(self.imageView)
        self.contentView.addSubview(self.label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView.frame = self.contentView.bounds.insetBy(dx: 6, dy: 6)
        self.label.frame = self.contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.label.text = nil
    }
}
