import Foundation
import JavaScriptCore
import UserNotifications

// MARK: - Public types

/// An installed plugin as stored on disk.
public struct GhostPluginInfo: Codable, Equatable {
    public var id: String
    public var name: String
    public var version: String
    public var description: String
    public var author: String
    public var sourceURL: String?
    public var installedAt: Int32
}

/// A setting a plugin declared with `GG.settings([...])`.
public struct GhostPluginSetting {
    public let key: String
    public let title: String
    /// "bool", "text", "number" or "choice".
    public let type: String
    public let defaultValue: Any?
    public let options: [String]
    public let hint: String
}

/// What a running plugin registered: commands, buttons and settings.
public struct GhostPluginDetails {
    public let commands: [(name: String, description: String)]
    public let actions: [String]
    public let settings: [GhostPluginSetting]
    public let isRunning: Bool
}

/// A plugin listed in the online catalog.
public struct GhostCatalogEntry {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let author: String
    public let url: String
}

/// Something a plugin wants to show; handled by the UI layer.
public enum GhostPluginUIRequest {
    case alert(title: String, text: String)
    case toast(String)
    case copy(String)
    case notify(title: String, text: String, identifier: String)
    /// Opens the gallery and sends the chosen video, GIF or picture as a round video message.
    case pickRoundVideo(chatId: String, replyTo: Int32, seconds: Int)
}

/// What should happen to a message the user is sending.
public enum GhostOutgoingDecision {
    case keep
    case replace(String)
    case cancel
}

public enum GhostPluginError: LocalizedError {
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case let .invalid(text):
            return text
        }
    }
}

// MARK: - Runtime

private final class GhostPluginInstance {
    let id: String
    let context: JSContext
    var timers: [Int: DispatchWorkItem] = [:]
    var unloaded = false

    init(id: String, context: JSContext) {
        self.id = id
        self.context = context
    }
}

private final class GhostDecisionBox {
    var value: GhostOutgoingDecision = .keep
}

/// Runs GhostGram plugins: JavaScript files executed with JavaScriptCore.
///
/// Every plugin gets its own JSContext; all of them run on one serial queue. The Telegram side
/// plugs in through `sendMessage`, `uiHandler`, `savedMessagesFiles` and `setMe`, and feeds
/// messages in through `dispatchIncoming` and `transformOutgoing`.
public final class GhostPlugins {
    public static let shared = GhostPlugins()
    public static let changedNotification = Notification.Name("GhostPluginsChanged")
    public static let catalogURL = "https://raw.githubusercontent.com/hmmcode/GhostGram-iOS/master/plugins/index.json"

    /// Sends a text message: chat id (PeerId.toInt64 as a string), text, message id to reply to (0 for none).
    public var sendMessage: ((String, String, Int32) -> Void)?
    /// Sends a silent voice message with a drawn waveform: chat id, bar heights 0...31, duration in seconds, reply id.
    public var sendVoice: ((String, [Int], Int, Int32) -> Void)?
    /// Sends a square mp4 as a round video message: chat id, mp4 bytes, JPEG preview, duration, side in pixels, reply id.
    public var sendRoundVideo: ((String, Data, Data?, Double, Int, Int32) -> Void)?
    /// Shows alerts, toasts and banners. Called on the plugin queue.
    public var uiHandler: ((GhostPluginUIRequest) -> Void)?
    /// Looks up recent .js files in Saved Messages and returns (file name, contents).
    public var savedMessagesFiles: ((@escaping ([(String, String)]) -> Void) -> Void)?

    private let queue = DispatchQueue(label: "ghostgram.plugins")
    private let queueKey = DispatchSpecificKey<Bool>()
    private let lock = NSLock()
    private static let storageLock = NSLock()

    private var virtualMachine: JSVirtualMachine?
    private var instances: [String: GhostPluginInstance] = [:]
    private var order: [String] = []

    private var logs: [String: [String]] = [:]
    private var started = false
    private var runningCount = 0
    private var me: [String: Any] = [:]

    private let listKey = "ghost.plugins.list"
    private let disabledKey = "ghost.plugins.disabled"

    init() {
        self.queue.setSpecific(key: self.queueKey, value: true)
    }

    // MARK: Installed plugins

    private var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = base.appendingPathComponent("GhostPlugins", isDirectory: true)
        let _ = try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    public var installed: [GhostPluginInfo] {
        guard let data = UserDefaults.standard.data(forKey: self.listKey), let list = try? JSONDecoder().decode([GhostPluginInfo].self, from: data) else {
            return []
        }
        return list
    }

    private func saveInstalled(_ list: [GhostPluginInfo]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: self.listKey)
        }
    }

    private var disabledIds: Set<String> {
        get {
            return Set(UserDefaults.standard.stringArray(forKey: self.disabledKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: self.disabledKey)
        }
    }

    public func isEnabled(_ id: String) -> Bool {
        return !self.disabledIds.contains(id)
    }

    public func isRunning(_ id: String) -> Bool {
        return self.queue.sync {
            return self.instances[id] != nil
        }
    }

    /// True while at least one plugin is running; lets the message hooks return immediately otherwise.
    public var hasRunningPlugins: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.runningCount > 0
    }

    public func setEnabled(_ id: String, _ enabled: Bool) {
        var disabled = self.disabledIds
        if enabled {
            disabled.remove(id)
        } else {
            disabled.insert(id)
        }
        self.disabledIds = disabled
        self.queue.async {
            if enabled {
                self.loadPlugin(id)
            } else {
                self.unloadPlugin(id)
                self.appendLog(id, "info", "■ Выключен")
            }
            self.postChanged()
        }
    }

    /// Loads every enabled plugin. Safe to call more than once.
    public func start() {
        self.lock.lock()
        let wasStarted = self.started
        self.started = true
        self.lock.unlock()
        if wasStarted {
            return
        }
        self.queue.async {
            for info in self.installed where self.isEnabled(info.id) {
                self.loadPlugin(info.id)
            }
            self.postChanged()
        }
    }

    public func setMe(_ info: [String: Any]) {
        self.lock.lock()
        self.me = info
        self.lock.unlock()
    }

    // MARK: Installing

    /// Reads `// @key value` lines from the top of a plugin file.
    public static func parseHeader(_ source: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in source.components(separatedBy: .newlines).prefix(80) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.hasPrefix("//") {
                continue
            }
            var body = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if !body.hasPrefix("@") {
                continue
            }
            body.removeFirst()
            let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let key = parts.first else {
                continue
            }
            let value = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
            if result[String(key).lowercased()] == nil {
                result[String(key).lowercased()] = value
            }
        }
        return result
    }

    private static func sanitizeId(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-_")
        var result = ""
        for character in value.lowercased() {
            if allowed.contains(character) {
                result.append(character)
            } else if character == " " || character == "." {
                result.append("-")
            }
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        if result.isEmpty {
            result = "plugin-\(UInt(bitPattern: value.hashValue) % 1000000)"
        }
        return String(result.prefix(48))
    }

    /// Returns the parser's message when the source is not valid JavaScript, without running it.
    public static func syntaxError(_ source: String) -> String? {
        let maybeContext: JSContext? = JSContext()
        guard let context = maybeContext else {
            return nil
        }
        var message: String?
        context.exceptionHandler = { _, exception in
            message = GhostPlugins.describe(exception)
        }
        let constructor: JSValue? = context.objectForKeyedSubscript("Function")
        let _ = constructor?.construct(withArguments: [source])
        return message
    }

    static func describe(_ exception: JSValue?) -> String {
        guard let exception = exception else {
            return "Неизвестная ошибка"
        }
        var text: String = exception.toString() ?? "Ошибка"
        if let line = exception.objectForKeyedSubscript("line"), line.isNumber {
            text += " (строка \(line.toInt32()))"
        }
        return text
    }

    /// Saves and starts a plugin. Replaces an installed plugin with the same id.
    @discardableResult
    public func install(source rawSource: String, fileName: String? = nil, sourceURL: String? = nil) throws -> GhostPluginInfo {
        let source = rawSource.replacingOccurrences(of: "\r\n", with: "\n")
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw GhostPluginError.invalid("Файл пустой.")
        }
        if trimmed.hasPrefix("<") {
            throw GhostPluginError.invalid("Это веб-страница, а не плагин. Нужна прямая ссылка на .js файл.")
        }
        if let error = GhostPlugins.syntaxError(source) {
            throw GhostPluginError.invalid("В коде плагина ошибка: \(error)")
        }
        let header = GhostPlugins.parseHeader(source)
        let baseName = fileName.map { ($0 as NSString).deletingPathExtension } ?? ""
        var name = header["name"] ?? ""
        if name.isEmpty {
            name = baseName.isEmpty ? "Плагин" : baseName
        }
        var idSource = header["id"] ?? ""
        if idSource.isEmpty {
            idSource = baseName.isEmpty ? name : baseName
        }
        let id = GhostPlugins.sanitizeId(idSource)
        guard let directory = self.directory else {
            throw GhostPluginError.invalid("Нет доступа к папке плагинов.")
        }
        try source.write(to: directory.appendingPathComponent(id + ".js"), atomically: true, encoding: .utf8)

        var list = self.installed
        let previous = list.first(where: { $0.id == id })
        var version = header["version"] ?? ""
        if version.isEmpty {
            version = "1.0"
        }
        let info = GhostPluginInfo(
            id: id,
            name: name,
            version: version,
            description: header["description"] ?? "",
            author: header["author"] ?? "",
            sourceURL: sourceURL ?? previous?.sourceURL,
            installedAt: Int32(Date().timeIntervalSince1970)
        )
        if let index = list.firstIndex(where: { $0.id == id }) {
            list[index] = info
        } else {
            list.append(info)
        }
        self.saveInstalled(list)
        var disabled = self.disabledIds
        disabled.remove(id)
        self.disabledIds = disabled

        self.queue.async {
            self.unloadPlugin(id)
            self.loadPlugin(id)
            self.postChanged()
        }
        return info
    }

    public func remove(_ id: String) {
        self.saveInstalled(self.installed.filter { $0.id != id })
        var disabled = self.disabledIds
        disabled.remove(id)
        self.disabledIds = disabled
        if let directory = self.directory {
            let _ = try? FileManager.default.removeItem(at: directory.appendingPathComponent(id + ".js"))
        }
        GhostPlugins.storageLock.lock()
        UserDefaults.standard.removeObject(forKey: GhostPlugins.storageKey(id))
        GhostPlugins.storageLock.unlock()
        self.lock.lock()
        self.logs[id] = nil
        self.lock.unlock()
        self.queue.async {
            self.unloadPlugin(id)
            self.postChanged()
        }
    }

    public func reload(_ id: String) {
        self.queue.async {
            self.unloadPlugin(id)
            if self.isEnabled(id) {
                self.loadPlugin(id)
            }
            self.postChanged()
        }
    }

    public func source(of id: String) -> String? {
        guard let directory = self.directory else {
            return nil
        }
        return try? String(contentsOf: directory.appendingPathComponent(id + ".js"), encoding: .utf8)
    }

    // MARK: Network installs

    /// Turns github.com "blob" page links into raw file links.
    public static func normalizedURL(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("https://github.com/") && text.contains("/blob/") {
            text = text.replacingOccurrences(of: "https://github.com/", with: "https://raw.githubusercontent.com/")
            text = text.replacingOccurrences(of: "/blob/", with: "/")
        }
        return text
    }

    private func download(_ urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
        let normalized = GhostPlugins.normalizedURL(urlString)
        guard var components = URLComponents(string: normalized), let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            completion(.failure(GhostPluginError.invalid("Неверная ссылка.")))
            return
        }
        if components.host == "raw.githubusercontent.com" {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))"))
            components.queryItems = items
        }
        guard let url = components.url else {
            completion(.failure(GhostPluginError.invalid("Неверная ссылка.")))
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
        request.setValue("GhostGram", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let data = data, let text = String(data: data, encoding: .utf8) else {
                completion(.failure(GhostPluginError.invalid(status == 404 ? "Файл не найден (404)." : "Сервер ответил \(status).")))
                return
            }
            completion(.success(text))
        }).resume()
    }

    /// Downloads and installs a plugin. The completion runs on the main queue.
    public func install(fromURL urlString: String, completion: @escaping (Result<GhostPluginInfo, Error>) -> Void) {
        let normalized = GhostPlugins.normalizedURL(urlString)
        self.download(normalized, completion: { result in
            let outcome: Result<GhostPluginInfo, Error>
            switch result {
            case let .success(text):
                do {
                    let fileName = URL(string: normalized)?.lastPathComponent
                    outcome = .success(try self.install(source: text, fileName: fileName, sourceURL: normalized))
                } catch {
                    outcome = .failure(error)
                }
            case let .failure(error):
                outcome = .failure(error)
            }
            DispatchQueue.main.async {
                completion(outcome)
            }
        })
    }

    /// Loads the plugin catalog. The completion runs on the main queue.
    public func fetchCatalog(completion: @escaping (Result<[GhostCatalogEntry], Error>) -> Void) {
        let base = GhostPlugins.catalogURL
        self.download(base, completion: { result in
            let outcome: Result<[GhostCatalogEntry], Error>
            switch result {
            case let .success(text):
                if let data = text.data(using: .utf8), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let items = object["plugins"] as? [[String: Any]] {
                    let folder = URL(string: base)?.deletingLastPathComponent().absoluteString ?? ""
                    var entries: [GhostCatalogEntry] = []
                    for item in items {
                        guard let id = item["id"] as? String, let file = item["file"] as? String else {
                            continue
                        }
                        let url = file.hasPrefix("http") ? file : folder + file
                        entries.append(GhostCatalogEntry(
                            id: id,
                            name: item["name"] as? String ?? id,
                            version: item["version"] as? String ?? "1.0",
                            description: item["description"] as? String ?? "",
                            author: item["author"] as? String ?? "",
                            url: url
                        ))
                    }
                    outcome = .success(entries)
                } else {
                    outcome = .failure(GhostPluginError.invalid("Каталог повреждён."))
                }
            case let .failure(error):
                outcome = .failure(error)
            }
            DispatchQueue.main.async {
                completion(outcome)
            }
        })
    }

    /// True when `candidate` is a higher dotted version than `current`.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0 ..< max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y {
                return x > y
            }
        }
        return false
    }

    /// Finds recent .js files in Saved Messages. The completion runs on the main queue.
    public func findSavedMessagesFiles(completion: @escaping ([(String, String)]) -> Void) {
        guard let lookup = self.savedMessagesFiles else {
            completion([])
            return
        }
        lookup({ files in
            DispatchQueue.main.async {
                completion(files)
            }
        })
    }

    // MARK: Settings, buttons, logs

    private static func storageKey(_ id: String) -> String {
        return "ghost.plugin.store.\(id)"
    }

    private static func storage(_ id: String) -> [String: String] {
        storageLock.lock()
        defer { storageLock.unlock() }
        return UserDefaults.standard.dictionary(forKey: storageKey(id)) as? [String: String] ?? [:]
    }

    private static func updateStorage(_ id: String, _ f: (inout [String: String]) -> Void) {
        storageLock.lock()
        defer { storageLock.unlock() }
        var values = UserDefaults.standard.dictionary(forKey: storageKey(id)) as? [String: String] ?? [:]
        f(&values)
        UserDefaults.standard.set(values, forKey: storageKey(id))
    }

    public func details(_ id: String) -> GhostPluginDetails {
        return self.queue.sync { () -> GhostPluginDetails in
            let running = self.instances[id] != nil
            guard let instance = self.instances[id], let raw = self.call(instance, "__ggInfo", [])?.toString(), let data = raw.data(using: .utf8), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return GhostPluginDetails(commands: [], actions: [], settings: [], isRunning: running)
            }
            var commands: [(name: String, description: String)] = []
            for item in object["commands"] as? [[String: Any]] ?? [] {
                commands.append((name: item["name"] as? String ?? "", description: item["description"] as? String ?? ""))
            }
            var settings: [GhostPluginSetting] = []
            for item in object["settings"] as? [[String: Any]] ?? [] {
                settings.append(GhostPluginSetting(
                    key: item["key"] as? String ?? "",
                    title: item["title"] as? String ?? "",
                    type: item["type"] as? String ?? "text",
                    defaultValue: item["default"],
                    options: item["options"] as? [String] ?? [],
                    hint: item["hint"] as? String ?? ""
                ))
            }
            return GhostPluginDetails(commands: commands, actions: object["actions"] as? [String] ?? [], settings: settings, isRunning: running)
        }
    }

    public func settingValue(_ id: String, _ setting: GhostPluginSetting) -> Any? {
        guard let raw = GhostPlugins.storage(id)["setting:" + setting.key], let data = raw.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return setting.defaultValue
        }
        return value
    }

    public func setSettingValue(_ id: String, key: String, value: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]), let text = String(data: data, encoding: .utf8) else {
            return
        }
        GhostPlugins.updateStorage(id, { $0["setting:" + key] = text })
        let payload = GhostPlugins.jsonString(["key": key]) ?? "{}"
        self.queue.async {
            if let instance = self.instances[id] {
                self.call(instance, "__ggDispatch", ["settings", payload])
            }
        }
    }

    public func runAction(_ id: String, index: Int) {
        self.queue.async {
            if let instance = self.instances[id] {
                self.call(instance, "__ggRunAction", [index])
            }
        }
    }

    public func logs(_ id: String) -> [String] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.logs[id] ?? []
    }

    public func clearLogs(_ id: String) {
        self.lock.lock()
        self.logs[id] = nil
        self.lock.unlock()
    }

    private func appendLog(_ id: String, _ level: String, _ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let mark: String
        switch level {
        case "error":
            mark = "❌ "
        case "warn":
            mark = "⚠️ "
        case "info":
            mark = "• "
        default:
            mark = ""
        }
        let line = "\(formatter.string(from: Date())) \(mark)\(text)"
        self.lock.lock()
        var lines = self.logs[id] ?? []
        lines.append(line)
        if lines.count > 300 {
            lines.removeFirst(lines.count - 300)
        }
        self.logs[id] = lines
        self.lock.unlock()
    }

    /// Lists every command of every running plugin.
    public func commandsHelp() -> String {
        var lines: [String] = []
        for info in self.installed where self.isEnabled(info.id) {
            let details = self.details(info.id)
            for command in details.commands {
                lines.append(command.description.isEmpty ? command.name : "\(command.name) — \(command.description)")
            }
            if details.commands.isEmpty && details.isRunning {
                lines.append("(\(info.name): без команд)")
            }
        }
        return lines.isEmpty ? "Нет запущенных плагинов с командами." : lines.joined(separator: "\n")
    }

    private func postChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: GhostPlugins.changedNotification, object: nil)
        }
    }

    // MARK: Message hooks

    /// Runs the plugins' outgoing hooks and commands for a text message the user is sending.
    /// Waits at most 0.8 s; returns `.keep` when plugins are slow or a plugin itself is sending.
    public func transformOutgoing(chatId: String, chatType: String, chatTitle: String, text: String, replyTo: Int32) -> GhostOutgoingDecision {
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isHelp = lowered == ".plugins" || lowered == ".плагины"
        if !self.hasRunningPlugins && !isHelp {
            return .keep
        }
        if DispatchQueue.getSpecific(key: self.queueKey) != nil {
            return .keep
        }
        if isHelp {
            let help = self.commandsHelp()
            self.uiHandler?(.alert(title: "🧩 Команды плагинов", text: help))
            return .cancel
        }
        let box = GhostDecisionBox()
        let semaphore = DispatchSemaphore(value: 0)
        self.queue.async {
            box.value = self.runOutgoing(chatId: chatId, chatType: chatType, chatTitle: chatTitle, text: text, replyTo: replyTo)
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 0.8) == .timedOut {
            return .keep
        }
        return box.value
    }

    private func runOutgoing(chatId: String, chatType: String, chatTitle: String, text: String, replyTo: Int32) -> GhostOutgoingDecision {
        var current = text
        var changed = false
        for id in self.order {
            guard let instance = self.instances[id] else {
                continue
            }
            let payload: [String: Any] = [
                "chatId": chatId,
                "chatType": chatType,
                "chatTitle": chatTitle,
                "text": current,
                "replyTo": Int(replyTo),
                "out": true,
                "date": Int(Date().timeIntervalSince1970)
            ]
            guard let json = GhostPlugins.jsonString(payload), let resultText = self.call(instance, "__ggOutgoing", [json])?.toString(), let data = resultText.data(using: .utf8), let decision = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                continue
            }
            switch decision["action"] as? String ?? "keep" {
            case "cancel":
                return .cancel
            case "replace":
                if let newText = decision["text"] as? String {
                    current = newText
                    changed = true
                }
            default:
                break
            }
        }
        return changed ? .replace(current) : .keep
    }

    /// Hands an incoming message to the plugins' `GG.on('message')` handlers.
    public func dispatchIncoming(_ payload: [String: Any]) {
        guard self.hasRunningPlugins, let json = GhostPlugins.jsonString(payload) else {
            return
        }
        self.queue.async {
            for id in self.order {
                if let instance = self.instances[id] {
                    self.call(instance, "__ggDispatch", ["message", json])
                }
            }
        }
    }

    static func jsonString(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Loading (plugin queue only)

    private func refreshRunningCount() {
        let count = self.instances.count
        self.lock.lock()
        self.runningCount = count
        self.lock.unlock()
    }

    @discardableResult
    private func call(_ instance: GhostPluginInstance, _ function: String, _ arguments: [Any]) -> JSValue? {
        if instance.unloaded {
            return nil
        }
        guard let value = instance.context.objectForKeyedSubscript(function), value.isObject else {
            return nil
        }
        return value.call(withArguments: arguments)
    }

    private func unloadPlugin(_ id: String) {
        guard let instance = self.instances.removeValue(forKey: id) else {
            return
        }
        self.order.removeAll(where: { $0 == id })
        instance.unloaded = true
        for (_, item) in instance.timers {
            item.cancel()
        }
        instance.timers.removeAll()
        instance.context.exceptionHandler = nil
        self.refreshRunningCount()
    }

    private func loadPlugin(_ id: String) {
        if self.instances[id] != nil {
            return
        }
        guard let info = self.installed.first(where: { $0.id == id }) else {
            return
        }
        guard let source = self.source(of: id) else {
            self.appendLog(id, "error", "Файл плагина не найден")
            return
        }
        if self.virtualMachine == nil {
            self.virtualMachine = JSVirtualMachine()
        }
        guard let context = JSContext(virtualMachine: self.virtualMachine) else {
            self.appendLog(id, "error", "Не удалось создать JS-контекст")
            return
        }
        context.name = "GhostGram · \(info.name)"
        let instance = GhostPluginInstance(id: id, context: context)
        context.exceptionHandler = { [weak self] _, exception in
            self?.appendLog(id, "error", GhostPlugins.describe(exception))
        }
        self.installNatives(instance)
        context.evaluateScript(ghostPluginPrelude, withSourceURL: URL(string: "ghostgram://prelude.js"))
        self.instances[id] = instance
        self.order.append(id)
        self.refreshRunningCount()
        self.appendLog(id, "info", "▶︎ Запущен, версия \(info.version)")
        context.evaluateScript(source, withSourceURL: URL(string: "ghostgram://plugins/\(id).js"))
        self.call(instance, "__ggDispatch", ["start", "{}"])
    }

    private func installNatives(_ instance: GhostPluginInstance) {
        let id = instance.id
        let context = instance.context
        guard let native = JSValue(newObjectIn: context) else {
            return
        }
        func define(_ name: String, _ block: AnyObject) {
            native.setObject(block, forKeyedSubscript: name as NSString)
        }

        let log: @convention(block) (JSValue, JSValue) -> Void = { [weak self] level, text in
            self?.appendLog(id, level.toString() ?? "log", text.toString() ?? "")
        }
        define("log", unsafeBitCast(log, to: AnyObject.self))

        let setTimer: @convention(block) (JSValue, JSValue) -> Void = { [weak self, weak instance] timerId, milliseconds in
            guard let self = self, let instance = instance, !instance.unloaded else {
                return
            }
            let key = Int(timerId.toInt32())
            instance.timers[key]?.cancel()
            let item = DispatchWorkItem(block: { [weak self, weak instance] in
                guard let self = self, let instance = instance, !instance.unloaded else {
                    return
                }
                instance.timers[key] = nil
                self.call(instance, "__ggTimer", [key])
            })
            instance.timers[key] = item
            var delay = milliseconds.toDouble()
            if !delay.isFinite || delay < 0.0 {
                delay = 0.0
            }
            self.queue.asyncAfter(deadline: .now() + delay / 1000.0, execute: item)
        }
        define("setTimer", unsafeBitCast(setTimer, to: AnyObject.self))

        let clearTimer: @convention(block) (JSValue) -> Void = { [weak instance] timerId in
            let key = Int(timerId.toInt32())
            instance?.timers[key]?.cancel()
            instance?.timers[key] = nil
        }
        define("clearTimer", unsafeBitCast(clearTimer, to: AnyObject.self))

        let send: @convention(block) (JSValue, JSValue, JSValue) -> Void = { [weak self] chatId, text, replyTo in
            guard let self = self else {
                return
            }
            let chat = chatId.toString() ?? ""
            let body = text.toString() ?? ""
            if chat.isEmpty || body.isEmpty {
                return
            }
            if let sendMessage = self.sendMessage {
                sendMessage(chat, body, replyTo.toInt32())
            } else {
                self.appendLog(id, "error", "Отправка пока недоступна: аккаунт ещё не загрузился")
            }
        }
        define("send", unsafeBitCast(send, to: AnyObject.self))

        let sendVoice: @convention(block) (JSValue, JSValue, JSValue, JSValue) -> Void = { [weak self] chatId, wave, duration, replyTo in
            guard let self = self else {
                return
            }
            let chat = chatId.toString() ?? ""
            guard !chat.isEmpty, let data = (wave.toString() ?? "").data(using: .utf8), let raw = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
                self.appendLog(id, "error", "GG.sendVoice: неверная волна")
                return
            }
            let bars = raw.prefix(100).map { item -> Int in
                let value = (item as? NSNumber)?.doubleValue ?? 0
                return max(0, min(31, Int(value.rounded())))
            }
            if bars.isEmpty {
                return
            }
            let seconds = max(1, min(600, Int(duration.toInt32())))
            if let sendVoice = self.sendVoice {
                sendVoice(chat, bars, seconds, replyTo.toInt32())
            } else {
                self.appendLog(id, "error", "Отправка пока недоступна: аккаунт ещё не загрузился")
            }
        }
        define("sendVoice", unsafeBitCast(sendVoice, to: AnyObject.self))

        let pickRound: @convention(block) (JSValue, JSValue, JSValue) -> Void = { [weak self] chatId, replyTo, seconds in
            guard let self = self else {
                return
            }
            let chat = chatId.toString() ?? ""
            if chat.isEmpty {
                return
            }
            guard let handler = self.uiHandler, self.sendRoundVideo != nil else {
                self.appendLog(id, "error", "Кружки пока недоступны: аккаунт ещё не загрузился")
                return
            }
            handler(.pickRoundVideo(chatId: chat, replyTo: replyTo.toInt32(), seconds: max(1, min(60, Int(seconds.toInt32())))))
        }
        define("pickRound", unsafeBitCast(pickRound, to: AnyObject.self))

        let notify: @convention(block) (JSValue, JSValue, JSValue, JSValue) -> Void = { [weak self] title, body, delay, identifier in
            let titleText = title.toString() ?? ""
            let bodyText = body.toString() ?? ""
            var requestId = identifier.toString() ?? ""
            if requestId.isEmpty || requestId == "undefined" {
                requestId = UUID().uuidString
            }
            let fullId = "ghostgram-plugin-\(id)-\(requestId)"
            let seconds = delay.toDouble()
            if seconds.isFinite && seconds >= 1.0 {
                let content = UNMutableNotificationContent()
                content.title = titleText
                content.body = bodyText
                content.sound = .default
                content.threadIdentifier = "ghostgram-plugin-\(id)"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: fullId, content: content, trigger: trigger), withCompletionHandler: nil)
            } else if let handler = self?.uiHandler {
                handler(.notify(title: titleText, text: bodyText, identifier: fullId))
            }
        }
        define("notify", unsafeBitCast(notify, to: AnyObject.self))

        let cancelNotify: @convention(block) (JSValue) -> Void = { identifier in
            let fullId = "ghostgram-plugin-\(id)-\(identifier.toString() ?? "")"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [fullId])
        }
        define("cancelNotify", unsafeBitCast(cancelNotify, to: AnyObject.self))

        let ui: @convention(block) (JSValue, JSValue, JSValue) -> Void = { [weak self] kind, first, second in
            guard let handler = self?.uiHandler else {
                return
            }
            let a = first.toString() ?? ""
            let b = second.toString() ?? ""
            switch kind.toString() ?? "" {
            case "alert":
                handler(.alert(title: a, text: b))
            case "copy":
                handler(.copy(a))
            default:
                handler(.toast(a))
            }
        }
        define("ui", unsafeBitCast(ui, to: AnyObject.self))

        let storageGet: @convention(block) (JSValue) -> JSValue = { key in
            let current: JSContext = JSContext.current()
            if let value = GhostPlugins.storage(id)[key.toString() ?? ""] {
                return JSValue(object: value, in: current)
            }
            return JSValue(nullIn: current)
        }
        define("storageGet", unsafeBitCast(storageGet, to: AnyObject.self))

        let storageSet: @convention(block) (JSValue, JSValue) -> Void = { key, value in
            let name = key.toString() ?? ""
            let text = value.toString() ?? ""
            GhostPlugins.updateStorage(id, { $0[name] = text })
        }
        define("storageSet", unsafeBitCast(storageSet, to: AnyObject.self))

        let storageRemove: @convention(block) (JSValue) -> Void = { key in
            let name = key.toString() ?? ""
            GhostPlugins.updateStorage(id, { $0[name] = nil })
        }
        define("storageRemove", unsafeBitCast(storageRemove, to: AnyObject.self))

        let storageKeys: @convention(block) () -> String = {
            return GhostPlugins.jsonString(Array(GhostPlugins.storage(id).keys)) ?? "[]"
        }
        define("storageKeys", unsafeBitCast(storageKeys, to: AnyObject.self))

        let me: @convention(block) () -> String = { [weak self] in
            guard let self = self else {
                return ""
            }
            self.lock.lock()
            let info = self.me
            self.lock.unlock()
            if info.isEmpty {
                return ""
            }
            return GhostPlugins.jsonString(info) ?? ""
        }
        define("me", unsafeBitCast(me, to: AnyObject.self))

        let appVersion: @convention(block) () -> String = {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
        define("appVersion", unsafeBitCast(appVersion, to: AnyObject.self))

        let fetch: @convention(block) (JSValue, JSValue, JSValue, JSValue, JSValue, JSValue) -> Void = { [weak self, weak instance] requestId, url, method, headers, body, timeout in
            let request = Int(requestId.toInt32())
            let finish: (Int, String, String, String) -> Void = { [weak self, weak instance] status, text, error, headersJson in
                guard let self = self else {
                    return
                }
                self.queue.async {
                    guard let instance = instance, !instance.unloaded else {
                        return
                    }
                    self.call(instance, "__ggFetchDone", [request, status, text, error, headersJson])
                }
            }
            guard let target = URL(string: url.toString() ?? ""), let scheme = target.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                finish(0, "", "Неверная ссылка", "{}")
                return
            }
            var urlRequest = URLRequest(url: target)
            urlRequest.httpMethod = method.toString() ?? "GET"
            var seconds = timeout.toDouble()
            if !seconds.isFinite || seconds <= 0.0 {
                seconds = 30.0
            }
            urlRequest.timeoutInterval = min(120.0, max(1.0, seconds))
            if let headerData = (headers.toString() ?? "{}").data(using: .utf8), let values = (try? JSONSerialization.jsonObject(with: headerData)) as? [String: Any] {
                for (name, value) in values {
                    urlRequest.setValue("\(value)", forHTTPHeaderField: name)
                }
            }
            let bodyText = body.toString() ?? ""
            if !bodyText.isEmpty {
                urlRequest.httpBody = bodyText.data(using: .utf8)
            }
            if urlRequest.value(forHTTPHeaderField: "User-Agent") == nil {
                urlRequest.setValue("GhostGram", forHTTPHeaderField: "User-Agent")
            }
            URLSession.shared.dataTask(with: urlRequest, completionHandler: { data, response, error in
                let http = response as? HTTPURLResponse
                var responseHeaders: [String: String] = [:]
                if let http = http {
                    for (name, value) in http.allHeaderFields {
                        responseHeaders["\(name)".lowercased()] = "\(value)"
                    }
                }
                var text = ""
                if let data = data {
                    text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                }
                finish(http?.statusCode ?? 0, text, error?.localizedDescription ?? "", GhostPlugins.jsonString(responseHeaders) ?? "{}")
            }).resume()
        }
        define("fetch", unsafeBitCast(fetch, to: AnyObject.self))

        context.setObject(native, forKeyedSubscript: "__native" as NSString)
    }
}
