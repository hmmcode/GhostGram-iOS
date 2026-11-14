import Foundation
import UIKit
import UniformTypeIdentifiers
import TelegramCore

// MARK: - Entry point

private let ghostPluginTint = UIColor(red: 0.62, green: 0.45, blue: 1.0, alpha: 1.0)

/// Opens GhostGram → Plugins as a sheet over the current screen.
public func ghostPresentPluginsScreen(from presenter: UIViewController?, dark: Bool) {
    let navigation = UINavigationController(rootViewController: GhostPluginsListController())
    navigation.overrideUserInterfaceStyle = dark ? .dark : .light
    navigation.view.tintColor = ghostPluginTint
    navigation.navigationBar.prefersLargeTitles = true
    navigation.modalPresentationStyle = .pageSheet
    var top: UIViewController? = presenter?.view.window?.rootViewController ?? presenter
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
        top = presented
    }
    top?.present(navigation, animated: true, completion: nil)
}

// MARK: - Helpers

private func ghostAlert(_ controller: UIViewController, title: String, text: String, actions: [UIAlertAction] = []) {
    let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
    if actions.isEmpty {
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    } else {
        for action in actions {
            alert.addAction(action)
        }
    }
    controller.present(alert, animated: true, completion: nil)
}

private func ghostCell(_ tableView: UITableView, style: UIListContentConfiguration, text: String, secondary: String? = nil, color: UIColor? = nil) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    var content = style
    content.text = text
    content.secondaryText = secondary
    content.secondaryTextProperties.numberOfLines = 3
    if let color = color {
        content.textProperties.color = color
    }
    cell.contentConfiguration = content
    return cell
}

private func ghostSwitch(isOn: Bool, changed: @escaping (Bool) -> Void) -> UISwitch {
    let view = UISwitch()
    view.isOn = isOn
    view.onTintColor = ghostPluginTint
    view.addAction(UIAction(handler: { action in
        if let sender = action.sender as? UISwitch {
            changed(sender.isOn)
        }
    }), for: .valueChanged)
    return view
}

private func ghostShowInstallResult(_ controller: UIViewController, _ result: Result<GhostPluginInfo, Error>, open: @escaping (GhostPluginInfo) -> Void) {
    switch result {
    case let .success(info):
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ghostAlert(controller, title: "✅ «\(info.name)» установлен", text: info.description.isEmpty ? "Плагин уже работает. Команды плагинов — напиши .plugins в любом чате." : info.description, actions: [
            UIAlertAction(title: "Открыть", style: .default, handler: { _ in open(info) }),
            UIAlertAction(title: "Готово", style: .cancel, handler: nil)
        ])
    case let .failure(error):
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        ghostAlert(controller, title: "Не получилось", text: error.localizedDescription)
    }
}

/// A spinner alert that stays up long enough to finish presenting before it is dismissed.
private final class GhostLoading {
    let alert: UIAlertController
    let started = Date()

    init(alert: UIAlertController) {
        self.alert = alert
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        let delay = max(0.0, 0.7 - Date().timeIntervalSince(self.started))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
            if self.alert.presentingViewController != nil {
                self.alert.dismiss(animated: animated, completion: completion)
            } else {
                completion()
            }
        })
    }
}

private func ghostLoadingAlert(_ controller: UIViewController, text: String) -> GhostLoading {
    let alert = UIAlertController(title: nil, message: text + "\n\n", preferredStyle: .alert)
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.startAnimating()
    alert.view.addSubview(spinner)
    NSLayoutConstraint.activate([
        spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
        spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20.0)
    ])
    controller.present(alert, animated: true, completion: nil)
    return GhostLoading(alert: alert)
}

// MARK: - Plugin list

private final class GhostPluginsListController: UITableViewController, UIDocumentPickerDelegate {
    private enum AddRow: Int, CaseIterable {
        case catalog
        case saved
        case file
        case clipboard
        case link
    }

    private var plugins: [GhostPluginInfo] = []
    private var observer: NSObjectProtocol?

    init() {
        super.init(style: .insetGrouped)
        self.title = "Плагины"
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
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction(handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        self.observer = NotificationCenter.default.addObserver(forName: GhostPlugins.changedNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.reload()
        })
        self.reload()
    }

    private func reload() {
        self.plugins = GhostPlugins.shared.installed
        self.tableView.reloadData()
    }

    private func openDetails(_ id: String) {
        self.navigationController?.pushViewController(GhostPluginDetailController(id: id), animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return max(1, self.plugins.count)
        case 1:
            return AddRow.allCases.count
        default:
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Установленные"
        case 1:
            return "Добавить плагин"
        default:
            return "Справка"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Плагины работают, пока GhostGram открыт или недавно свёрнут. Напиши .plugins в любом чате — покажу все команды."
        case 1:
            return "Самое простое: скинь .js файл себе в «Избранное» и нажми «Из Избранного»."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if self.plugins.isEmpty {
                return ghostCell(tableView, style: .subtitleCell(), text: "Пока пусто", secondary: "Открой каталог ниже — там готовые плагины.", color: .secondaryLabel)
            }
            let info = self.plugins[indexPath.row]
            let cell = ghostCell(tableView, style: .subtitleCell(), text: "\(info.name)  ·  v\(info.version)", secondary: info.description.isEmpty ? nil : info.description)
            let id = info.id
            cell.accessoryView = ghostSwitch(isOn: GhostPlugins.shared.isEnabled(id), changed: { value in
                GhostPlugins.shared.setEnabled(id, value)
            })
            return cell
        case 1:
            let row = AddRow(rawValue: indexPath.row) ?? .catalog
            let cell: UITableViewCell
            switch row {
            case .catalog:
                cell = ghostCell(tableView, style: .subtitleCell(), text: "🧩 Каталог плагинов", secondary: "Готовые плагины GhostGram, установка в одно касание")
            case .saved:
                cell = ghostCell(tableView, style: .cell(), text: "📥 Из «Избранного»")
            case .file:
                cell = ghostCell(tableView, style: .cell(), text: "📁 Из файла")
            case .clipboard:
                cell = ghostCell(tableView, style: .cell(), text: "📋 Из буфера обмена (код или ссылка)")
            case .link:
                cell = ghostCell(tableView, style: .cell(), text: "🔗 По ссылке")
            }
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            if indexPath.row == 0 {
                return ghostCell(tableView, style: .cell(), text: "⌨️ Все команды плагинов")
            }
            return ghostCell(tableView, style: .cell(), text: "❓ Как это работает")
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if !self.plugins.isEmpty {
                self.openDetails(self.plugins[indexPath.row].id)
            }
        case 1:
            switch AddRow(rawValue: indexPath.row) ?? .catalog {
            case .catalog:
                self.navigationController?.pushViewController(GhostPluginCatalogController(), animated: true)
            case .saved:
                self.importFromSavedMessages()
            case .file:
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.javaScript, .sourceCode, .plainText, .text, .data], asCopy: true)
                picker.delegate = self
                picker.allowsMultipleSelection = true
                self.present(picker, animated: true, completion: nil)
            case .clipboard:
                self.importFromClipboard()
            case .link:
                self.importFromLink()
            }
        default:
            if indexPath.row == 0 {
                DispatchQueue.global(qos: .userInitiated).async {
                    let help = GhostPlugins.shared.commandsHelp()
                    DispatchQueue.main.async {
                        ghostAlert(self, title: "⌨️ Команды", text: help)
                    }
                }
            } else {
                ghostAlert(self, title: "Как это работает", text: "Плагин — это .js файл. Его можно поставить без пересборки приложения: из каталога, из «Избранного», из файла или по ссылке.\n\nПлагины умеют: свои команды в чате (например .calc 2+2), автоответы, уведомления, напоминания, запросы в интернет, свои настройки и кнопки.\n\nКоманда — это сообщение, которое начинается с точки. Плагин заменяет его результатом или не отправляет совсем.\n\nЕсли плагин сломался — открой его и посмотри «Журнал».")
            }
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 0, !self.plugins.isEmpty else {
            return nil
        }
        let info = self.plugins[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить", handler: { _, _, completion in
            GhostPlugins.shared.remove(info.id)
            completion(true)
        })
        return UISwipeActionsConfiguration(actions: [delete])
    }

    // MARK: Imports

    private func finishInstall(_ result: Result<GhostPluginInfo, Error>) {
        self.reload()
        ghostShowInstallResult(self, result, open: { [weak self] info in
            self?.openDetails(info.id)
        })
    }

    private func installSource(_ source: String, fileName: String?) {
        do {
            let info = try GhostPlugins.shared.install(source: source, fileName: fileName)
            self.finishInstall(.success(info))
        } catch {
            self.finishInstall(.failure(error))
        }
    }

    private func installURL(_ url: String) {
        let loading = ghostLoadingAlert(self, text: "Скачиваю плагин…")
        GhostPlugins.shared.install(fromURL: url, completion: { [weak self] result in
            loading.dismiss(animated: true, completion: {
                self?.finishInstall(result)
            })
        })
    }

    private func importFromSavedMessages() {
        let loading = ghostLoadingAlert(self, text: "Ищу .js файлы в «Избранном»…")
        GhostPlugins.shared.findSavedMessagesFiles(completion: { [weak self] files in
            loading.dismiss(animated: true, completion: {
                guard let self = self else {
                    return
                }
                if files.isEmpty {
                    ghostAlert(self, title: "Ничего не нашёл", text: "Отправь .js файл плагина себе в «Избранное» (Saved Messages) и попробуй снова. Смотрю последние 400 сообщений.")
                    return
                }
                let sheet = UIAlertController(title: "Плагины в «Избранном»", message: "Выбери, что установить", preferredStyle: .actionSheet)
                for (name, source) in files {
                    let header = GhostPlugins.parseHeader(source)
                    let title = header["name"].map { "\($0) (\(name))" } ?? name
                    sheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                        self?.installSource(source, fileName: name)
                    }))
                }
                if files.count > 1 {
                    sheet.addAction(UIAlertAction(title: "Установить все (\(files.count))", style: .default, handler: { [weak self] _ in
                        guard let self = self else {
                            return
                        }
                        var installed: [String] = []
                        var failed: [String] = []
                        for (name, source) in files {
                            do {
                                let info = try GhostPlugins.shared.install(source: source, fileName: name)
                                installed.append(info.name)
                            } catch {
                                failed.append("\(name): \(error.localizedDescription)")
                            }
                        }
                        self.reload()
                        ghostAlert(self, title: "Готово", text: (installed.isEmpty ? "" : "✅ " + installed.joined(separator: ", ")) + (failed.isEmpty ? "" : "\n\n❌ " + failed.joined(separator: "\n")))
                    }))
                }
                sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
                if let popover = sheet.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1.0, height: 1.0)
                }
                self.present(sheet, animated: true, completion: nil)
            })
        })
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            ghostAlert(self, title: "Буфер пуст", text: "Скопируй код плагина или ссылку на .js файл и нажми снова.")
            return
        }
        if (text.hasPrefix("https://") || text.hasPrefix("http://")) && !text.contains("\n") {
            self.installURL(text)
        } else {
            self.installSource(text, fileName: nil)
        }
    }

    private func importFromLink() {
        let alert = UIAlertController(title: "Ссылка на плагин", message: "Прямая ссылка на .js файл (GitHub, gist и т.п.)", preferredStyle: .alert)
        alert.addTextField(configurationHandler: { field in
            field.placeholder = "https://…/plugin.js"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            if let text = UIPasteboard.general.string, text.hasPrefix("http") {
                field.text = text
            }
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Установить", style: .default, handler: { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            if !text.isEmpty {
                self?.installURL(text)
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var installed: [GhostPluginInfo] = []
        var failed: [String] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let source = String(data: data, encoding: .utf8) else {
                    failed.append("\(url.lastPathComponent): не текстовый файл")
                    continue
                }
                let info = try GhostPlugins.shared.install(source: source, fileName: url.lastPathComponent)
                installed.append(info)
            } catch {
                failed.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        self.reload()
        if installed.count == 1 && failed.isEmpty {
            self.finishInstall(.success(installed[0]))
        } else {
            ghostAlert(self, title: failed.isEmpty ? "Готово" : "Результат", text: (installed.isEmpty ? "" : "✅ " + installed.map { $0.name }.joined(separator: ", ")) + (failed.isEmpty ? "" : "\n\n❌ " + failed.joined(separator: "\n")))
        }
    }
}

// MARK: - Catalog

private final class GhostPluginCatalogController: UITableViewController {
    private var entries: [GhostCatalogEntry] = []
    private var errorText: String?
    private var isLoading = true
    private var installing: Set<String> = []

    init() {
        super.init(style: .insetGrouped)
        self.title = "Каталог"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let refresh = UIRefreshControl()
        refresh.addAction(UIAction(handler: { [weak self] _ in
            self?.load()
        }), for: .valueChanged)
        self.refreshControl = refresh
        self.load()
    }

    private func load() {
        self.isLoading = true
        self.tableView.reloadData()
        GhostPlugins.shared.fetchCatalog(completion: { [weak self] result in
            guard let self = self else {
                return
            }
            self.isLoading = false
            self.refreshControl?.endRefreshing()
            switch result {
            case let .success(entries):
                self.entries = entries
                self.errorText = nil
            case let .failure(error):
                self.errorText = error.localizedDescription
            }
            self.tableView.reloadData()
        })
    }

    private func state(_ entry: GhostCatalogEntry) -> (String, Bool) {
        if self.installing.contains(entry.id) {
            return ("…", false)
        }
        guard let installed = GhostPlugins.shared.installed.first(where: { $0.id == entry.id }) else {
            return ("Установить", true)
        }
        if GhostPlugins.isNewer(entry.version, than: installed.version) {
            return ("Обновить до \(entry.version)", true)
        }
        return ("✓ Установлен", false)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, self.entries.count)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Каталог обновляется без пересборки GhostGram. Потяни вниз, чтобы обновить. Нажми на плагин, чтобы установить."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.entries.isEmpty {
            if self.isLoading {
                let cell = ghostCell(tableView, style: .cell(), text: "Загружаю каталог…", color: .secondaryLabel)
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
                return cell
            }
            return ghostCell(tableView, style: .subtitleCell(), text: "Не удалось загрузить", secondary: self.errorText ?? "Проверь интернет и потяни вниз", color: .secondaryLabel)
        }
        let entry = self.entries[indexPath.row]
        let (label, actionable) = self.state(entry)
        var secondary = entry.description
        secondary += (secondary.isEmpty ? "" : "\n") + label
        let cell = ghostCell(tableView, style: .subtitleCell(), text: "\(entry.name)  ·  v\(entry.version)", secondary: secondary)
        cell.accessoryType = actionable ? .none : .checkmark
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < self.entries.count else {
            if !self.isLoading {
                self.load()
            }
            return
        }
        let entry = self.entries[indexPath.row]
        let (_, actionable) = self.state(entry)
        if !actionable {
            if GhostPlugins.shared.installed.contains(where: { $0.id == entry.id }) {
                self.navigationController?.pushViewController(GhostPluginDetailController(id: entry.id), animated: true)
            }
            return
        }
        self.installing.insert(entry.id)
        self.tableView.reloadRows(at: [indexPath], with: .none)
        GhostPlugins.shared.install(fromURL: entry.url, completion: { [weak self] result in
            guard let self = self else {
                return
            }
            self.installing.remove(entry.id)
            self.tableView.reloadData()
            switch result {
            case .success:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failure:
                ghostShowInstallResult(self, result, open: { _ in })
            }
        })
    }
}

// MARK: - Plugin details

private final class GhostPluginDetailController: UITableViewController {
    private enum Row {
        case enabled
        case info(String, String)
        case about(String)
        case command(String, String)
        case setting(GhostPluginSetting)
        case action(Int, String)
        case log
        case update
        case restart
        case share
        case delete
    }

    private let id: String
    private var sections: [(String?, String?, [Row])] = []
    private var observer: NSObjectProtocol?

    init(id: String) {
        self.id = id
        super.init(style: .insetGrouped)
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
        self.navigationItem.largeTitleDisplayMode = .never
        self.observer = NotificationCenter.default.addObserver(forName: GhostPlugins.changedNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.rebuild()
        })
        self.rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rebuild()
    }

    private func rebuild() {
        guard let info = GhostPlugins.shared.installed.first(where: { $0.id == self.id }) else {
            self.sections = []
            self.tableView.reloadData()
            return
        }
        self.title = info.name
        let details = GhostPlugins.shared.details(self.id)
        let enabled = GhostPlugins.shared.isEnabled(self.id)

        var result: [(String?, String?, [Row])] = []
        var main: [Row] = [.enabled]
        if !info.description.isEmpty {
            main.append(.about(info.description))
        }
        main.append(.info("Версия", info.version))
        if !info.author.isEmpty {
            main.append(.info("Автор", info.author))
        }
        let status: String
        if !enabled {
            status = "выключен"
        } else if details.isRunning {
            status = "работает"
        } else {
            status = "запускается…"
        }
        main.append(.info("Состояние", status))
        result.append((nil, nil, main))

        if !details.commands.isEmpty {
            result.append(("Команды", "Пиши в любом чате. Нажми, чтобы скопировать.", details.commands.map { Row.command($0.name, $0.description) }))
        }
        if !details.settings.isEmpty {
            result.append(("Настройки", nil, details.settings.map { Row.setting($0) }))
        }
        if !details.actions.isEmpty {
            result.append(("Действия", nil, details.actions.enumerated().map { Row.action($0.offset, $0.element) }))
        }
        let errors = GhostPlugins.shared.logs(self.id).filter { $0.contains("❌") }.count
        var manage: [Row] = [.log]
        if info.sourceURL != nil {
            manage.append(.update)
        }
        manage.append(contentsOf: [.restart, .share, .delete])
        result.append(("Управление", errors > 0 ? "В журнале ошибок: \(errors)" : nil, manage))
        self.sections = result
        self.tableView.reloadData()
    }

    private func settingText(_ setting: GhostPluginSetting) -> String {
        let value = GhostPlugins.shared.settingValue(self.id, setting)
        if let number = value as? NSNumber, setting.type == "number" {
            return number.stringValue
        }
        if let text = value as? String {
            return text.isEmpty ? "—" : text
        }
        if let value = value {
            return "\(value)"
        }
        return "—"
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].2.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].0
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.sections[section].1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = self.id
        switch self.sections[indexPath.section].2[indexPath.row] {
        case .enabled:
            let cell = ghostCell(tableView, style: .cell(), text: "Включён")
            cell.accessoryView = ghostSwitch(isOn: GhostPlugins.shared.isEnabled(id), changed: { value in
                GhostPlugins.shared.setEnabled(id, value)
            })
            cell.selectionStyle = .none
            return cell
        case let .info(title, value):
            let cell = ghostCell(tableView, style: .valueCell(), text: title, secondary: value)
            cell.selectionStyle = .none
            return cell
        case let .about(text):
            var content = UIListContentConfiguration.cell()
            content.text = text
            content.textProperties.numberOfLines = 0
            content.textProperties.color = .secondaryLabel
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            return cell
        case let .command(name, description):
            return ghostCell(tableView, style: .subtitleCell(), text: name, secondary: description.isEmpty ? nil : description)
        case let .setting(setting):
            if setting.type == "bool" {
                let isOn = (GhostPlugins.shared.settingValue(id, setting) as? NSNumber)?.boolValue ?? false
                let cell = ghostCell(tableView, style: .subtitleCell(), text: setting.title, secondary: setting.hint.isEmpty ? nil : setting.hint)
                cell.accessoryView = ghostSwitch(isOn: isOn, changed: { value in
                    GhostPlugins.shared.setSettingValue(id, key: setting.key, value: value)
                })
                cell.selectionStyle = .none
                return cell
            }
            let cell = ghostCell(tableView, style: .valueCell(), text: setting.title, secondary: self.settingText(setting))
            cell.accessoryType = .disclosureIndicator
            return cell
        case let .action(_, title):
            return ghostCell(tableView, style: .cell(), text: "▶︎ " + title, color: ghostPluginTint)
        case .log:
            let count = GhostPlugins.shared.logs(id).count
            let cell = ghostCell(tableView, style: .valueCell(), text: "📜 Журнал", secondary: "\(count)")
            cell.accessoryType = .disclosureIndicator
            return cell
        case .update:
            return ghostCell(tableView, style: .cell(), text: "⬇️ Обновить из источника", color: ghostPluginTint)
        case .restart:
            return ghostCell(tableView, style: .cell(), text: "🔄 Перезапустить", color: ghostPluginTint)
        case .share:
            return ghostCell(tableView, style: .cell(), text: "📤 Поделиться файлом", color: ghostPluginTint)
        case .delete:
            return ghostCell(tableView, style: .cell(), text: "Удалить плагин", color: .systemRed)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = self.id
        switch self.sections[indexPath.section].2[indexPath.row] {
        case .enabled, .info, .about:
            break
        case let .command(name, _):
            UIPasteboard.general.string = name + " "
            ghostAlert(self, title: "Скопировано", text: "«\(name)» в буфере — вставь в чат и допиши, что нужно.")
        case let .setting(setting):
            self.editSetting(setting)
        case let .action(index, _):
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            GhostPlugins.shared.runAction(id, index: index)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: { [weak self] in
                self?.rebuild()
            })
        case .log:
            self.navigationController?.pushViewController(GhostPluginLogController(id: id), animated: true)
        case .update:
            guard let url = GhostPlugins.shared.installed.first(where: { $0.id == id })?.sourceURL else {
                return
            }
            let loading = ghostLoadingAlert(self, text: "Обновляю…")
            GhostPlugins.shared.install(fromURL: url, completion: { [weak self] result in
                loading.dismiss(animated: true, completion: {
                    guard let self = self else {
                        return
                    }
                    switch result {
                    case let .success(info):
                        ghostAlert(self, title: "Готово", text: "Версия \(info.version) установлена и запущена.")
                    case let .failure(error):
                        ghostAlert(self, title: "Не получилось", text: error.localizedDescription)
                    }
                    self.rebuild()
                })
            })
        case .restart:
            GhostPlugins.shared.reload(id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .share:
            guard let source = GhostPlugins.shared.source(of: id) else {
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(id + ".js")
            let _ = try? source.write(to: url, atomically: true, encoding: .utf8)
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = share.popoverPresentationController {
                popover.sourceView = tableView
                popover.sourceRect = tableView.rectForRow(at: indexPath)
            }
            self.present(share, animated: true, completion: nil)
        case .delete:
            let name = self.title ?? "плагин"
            ghostAlert(self, title: "Удалить «\(name)»?", text: "Его настройки и данные тоже удалятся.", actions: [
                UIAlertAction(title: "Удалить", style: .destructive, handler: { [weak self] _ in
                    GhostPlugins.shared.remove(id)
                    self?.navigationController?.popViewController(animated: true)
                }),
                UIAlertAction(title: "Отмена", style: .cancel, handler: nil)
            ])
        }
    }

    private func editSetting(_ setting: GhostPluginSetting) {
        let id = self.id
        if setting.type == "choice" {
            let sheet = UIAlertController(title: setting.title, message: setting.hint.isEmpty ? nil : setting.hint, preferredStyle: .actionSheet)
            let current = self.settingText(setting)
            for option in setting.options {
                sheet.addAction(UIAlertAction(title: option == current ? "✓ " + option : option, style: .default, handler: { [weak self] _ in
                    GhostPlugins.shared.setSettingValue(id, key: setting.key, value: option)
                    self?.rebuild()
                }))
            }
            sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1.0, height: 1.0)
            }
            self.present(sheet, animated: true, completion: nil)
            return
        }
        let isNumber = setting.type == "number"
        let alert = UIAlertController(title: setting.title, message: setting.hint.isEmpty ? nil : setting.hint, preferredStyle: .alert)
        let currentValue = GhostPlugins.shared.settingValue(id, setting)
        alert.addTextField(configurationHandler: { field in
            if let number = currentValue as? NSNumber, isNumber {
                field.text = number.stringValue
            } else if let text = currentValue as? String {
                field.text = text
            }
            field.keyboardType = isNumber ? .decimalPad : .default
            field.clearButtonMode = .whileEditing
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            if isNumber {
                let number = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                GhostPlugins.shared.setSettingValue(id, key: setting.key, value: number)
            } else {
                GhostPlugins.shared.setSettingValue(id, key: setting.key, value: text)
            }
            self?.rebuild()
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - Log

private final class GhostPluginLogController: UIViewController {
    private let id: String
    private let textView = UITextView()

    init(id: String) {
        self.id = id
        super.init(nibName: nil, bundle: nil)
        self.title = "Журнал"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.largeTitleDisplayMode = .never
        self.view.backgroundColor = .systemGroupedBackground
        self.textView.isEditable = false
        self.textView.backgroundColor = .clear
        self.textView.font = UIFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
        self.textView.textContainerInset = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 24.0, right: 12.0)
        self.textView.frame = self.view.bounds
        self.textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(self.textView)

        let id = self.id
        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Очистить", primaryAction: UIAction(handler: { [weak self] _ in
                GhostPlugins.shared.clearLogs(id)
                self?.reload()
            })),
            UIBarButtonItem(systemItem: .action, primaryAction: UIAction(handler: { [weak self] _ in
                UIPasteboard.general.string = GhostPlugins.shared.logs(id).joined(separator: "\n")
                if let self = self {
                    ghostAlert(self, title: "Скопировано", text: "Журнал в буфере обмена — можно скинуть разработчику плагина.")
                }
            }))
        ]
        self.reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }

    private func reload() {
        let lines = GhostPlugins.shared.logs(self.id)
        self.textView.text = lines.isEmpty ? "Пусто. Сюда пишутся запуск плагина, его ошибки и всё, что он выводит через console.log / GG.log." : lines.joined(separator: "\n")
        if !lines.isEmpty {
            let length = self.textView.text.utf16.count
            let end = NSRange(location: max(0, length - 1), length: 1)
            self.textView.scrollRangeToVisible(end)
        }
    }
}
