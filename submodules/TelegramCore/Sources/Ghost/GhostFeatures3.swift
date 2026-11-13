import Foundation
import UserNotifications
import Postbox
import SwiftSignalKit
internal import TelegramApi

// MARK: - Fake chat activities

/// An activity GhostGram can show permanently in a chosen chat.
public enum GhostFakeActivityKind: String, CaseIterable {
    case typing
    case voice
    case roundVideo
    case photo
    case video
    case file
    case game
    case sticker

    public var title: String {
        switch self {
        case .typing: return "печатает…"
        case .voice: return "записывает голосовое…"
        case .roundVideo: return "записывает кружок…"
        case .photo: return "отправляет фото…"
        case .video: return "отправляет видео…"
        case .file: return "отправляет файл…"
        case .game: return "играет в игру…"
        case .sticker: return "выбирает стикер…"
        }
    }

    var activity: PeerInputActivity {
        switch self {
        case .typing: return .typingText
        case .voice: return .recordingVoice
        case .roundVideo: return .recordingInstantVideo
        case .photo: return .uploadingPhoto(progress: 42)
        case .video: return .uploadingVideo(progress: 42)
        case .file: return .uploadingFile(progress: 42)
        case .game: return .playingGame
        case .sticker: return .choosingSticker
        }
    }
}

private final class GhostFakeActivityRunner {
    private weak var account: Account?
    private var timer: DispatchSourceTimer?

    init(account: Account) {
        self.account = account
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 3.0, repeating: 4.5)
        timer.setEventHandler(handler: { [weak self] in
            self?.tick()
        })
        self.timer = timer
        timer.resume()
    }

    deinit {
        self.timer?.cancel()
    }

    private func tick() {
        guard let account = self.account, GhostSettings.fakeActivitiesEnabled else {
            return
        }
        let items = GhostSettings.fakeActivities
        if items.isEmpty {
            return
        }
        let network = account.network
        let _ = (account.postbox.transaction { transaction -> [(Api.InputPeer, PeerInputActivity)] in
            var result: [(Api.InputPeer, PeerInputActivity)] = []
            for (id, raw) in items {
                guard let kind = GhostFakeActivityKind(rawValue: raw), let peer = transaction.getPeer(PeerId(id)), let inputPeer = apiInputPeer(peer) else {
                    continue
                }
                result.append((inputPeer, kind.activity))
            }
            return result
        }
        |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { requests in
            for (inputPeer, activity) in requests {
                let _ = (network.request(Api.functions.messages.setTyping(flags: 0, peer: inputPeer, topMsgId: nil, action: actionFromActivity(activity)))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }).start()
            }
        })
    }
}

private var ghostFakeActivityRunners: [GhostFakeActivityRunner] = []
private let ghostFakeActivityLock = NSLock()

/// Starts sending the fake activities chosen in GhostGram for this account.
public func ghostStartFakeActivities(account: Account) {
    ghostFakeActivityLock.lock()
    defer { ghostFakeActivityLock.unlock() }
    ghostFakeActivityRunners.append(GhostFakeActivityRunner(account: account))
}

// MARK: - Profile change log

public struct GhostProfileLogEntry: Codable, Equatable {
    public let peerId: Int64
    public let date: Int32
    public let title: String
    public let change: String
}

public enum GhostProfileLog {
    private static let limit = 2000
    private static let lock = NSLock()

    private static var fileURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("ghost-profile-log.json")
    }

    public static func entries() -> [GhostProfileLogEntry] {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard let url = self.fileURL, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([GhostProfileLogEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    static func add(_ entry: GhostProfileLogEntry) {
        var entries = self.entries()
        self.lock.lock()
        defer { self.lock.unlock() }
        entries.insert(entry, at: 0)
        if entries.count > self.limit {
            entries.removeLast(entries.count - self.limit)
        }
        if let url = self.fileURL, let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    public static func clear() {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let url = self.fileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private func ghostUserName(_ user: TelegramUser) -> String {
    let name = [user.firstName ?? "", user.lastName ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    return name
}

/// Remembers name, username and photo changes of contacts.
func ghostTrackProfileChange(transaction: Transaction, previous: TelegramUser?, updated: TelegramUser) {
    guard GhostSettings.trackProfileChanges, let previous = previous, transaction.isPeerContact(peerId: updated.id) else {
        return
    }
    var changes: [String] = []
    let oldName = ghostUserName(previous)
    let newName = ghostUserName(updated)
    if !oldName.isEmpty && !newName.isEmpty && oldName != newName {
        changes.append("имя: \(oldName) → \(newName)")
    }
    if let oldUsername = previous.username, let newUsername = updated.username, oldUsername != newUsername {
        changes.append("ник: @\(oldUsername) → @\(newUsername)")
    } else if previous.username != nil && updated.username == nil && !updated.photo.isEmpty {
        changes.append("убрал(а) ник @\(previous.username ?? "")")
    }
    if let oldPhoto = previous.photo.first?.resource.id, let newPhoto = updated.photo.first?.resource.id, oldPhoto != newPhoto {
        changes.append("сменил(а) аватарку")
    }
    if changes.isEmpty {
        return
    }
    let title = newName.isEmpty ? oldName : newName
    let now = Int32(Date().timeIntervalSince1970)
    for change in changes {
        GhostProfileLog.add(GhostProfileLogEntry(peerId: updated.id.toInt64(), date: now, title: title, change: change))
    }
}

// MARK: - "Came online" notifications

func ghostCheckOnlineWatch(transaction: Transaction, presences: [PeerId: PeerPresence]) {
    let watched = GhostSettings.onlineWatchList
    if watched.isEmpty {
        return
    }
    for (peerId, presence) in presences {
        guard watched.contains(peerId.toInt64()), let presence = presence as? TelegramUserPresence, case .present = presence.status else {
            continue
        }
        if let previous = transaction.getPeerPresence(peerId: peerId) as? TelegramUserPresence, case .present = previous.status {
            continue
        }
        var name = "Контакт"
        if let user = transaction.getPeer(peerId) as? TelegramUser {
            name = GhostSettings.nickname(for: peerId.toInt64()) ?? ghostUserName(user)
        }
        let content = UNMutableNotificationContent()
        content.title = "🟢 \(name) в сети"
        content.threadIdentifier = "ghostgram-online"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ghostgram-online-\(peerId.toInt64())", content: content, trigger: nil), withCompletionHandler: nil)
    }
}

// MARK: - Message filter

/// Hides incoming messages from ignored users or with filtered words.
public func ghostShouldHideMessage(_ message: Message) -> Bool {
    guard GhostSettings.filterEnabled, message.flags.contains(.Incoming) else {
        return false
    }
    if let authorId = message.author?.id, GhostSettings.ignoredUsers.contains(authorId.toInt64()) {
        return true
    }
    let keywords = GhostSettings.filterKeywords
    if keywords.isEmpty || message.text.isEmpty {
        return false
    }
    let text = message.text.lowercased()
    for keyword in keywords {
        let keyword = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        if !keyword.isEmpty && text.contains(keyword) {
            return true
        }
    }
    return false
}

// MARK: - Notes and reminders

public enum GhostNotes {
    private static func key(_ id: MessageId) -> String {
        return "\(id.peerId.toInt64())_\(id.namespace)_\(id.id)"
    }

    private static var all: [String: String] {
        get { return (UserDefaults.standard.dictionary(forKey: "ghost.notesMap") as? [String: String]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "ghost.notesMap") }
    }

    public static func note(for id: MessageId) -> String? {
        if let value = all[key(id)], !value.isEmpty {
            return value
        }
        return nil
    }

    public static func setNote(_ note: String?, for id: MessageId) {
        var notes = all
        if let note = note, !note.isEmpty {
            notes[key(id)] = note
        } else {
            notes.removeValue(forKey: key(id))
        }
        all = notes
    }
}

/// Schedules a local reminder about a message.
public func ghostScheduleReminder(chatTitle: String, text: String, after seconds: TimeInterval) {
    let content = UNMutableNotificationContent()
    content.title = "⏰ Напоминание: \(chatTitle)"
    content.body = text.isEmpty ? "Сообщение" : text
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5.0, seconds), repeats: false)
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ghostgram-reminder-\(UUID().uuidString)", content: content, trigger: trigger), withCompletionHandler: nil)
}

// MARK: - Statistics

public enum GhostStats {
    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static var sentByDay: [String: Int] {
        get { return (UserDefaults.standard.dictionary(forKey: "ghost.stats.sent") as? [String: Int]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "ghost.stats.sent") }
    }

    static func countSent(_ count: Int) {
        if count <= 0 {
            return
        }
        var values = sentByDay
        let key = dayKey(Date())
        values[key] = (values[key] ?? 0) + count
        sentByDay = values
    }

    /// Messages sent in the last `days` days, including today.
    public static func sent(lastDays days: Int) -> Int {
        let values = sentByDay
        var total = 0
        for offset in 0 ..< max(1, days) {
            if let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                total += values[dayKey(date)] ?? 0
            }
        }
        return total
    }

    public static var sentTotal: Int {
        return sentByDay.values.reduce(0, +)
    }
}

// MARK: - Edit history diff

/// Word diff between two texts: removed words as [-word-], added words as {+word+}.
public func ghostDiff(old: String, new: String) -> String {
    let a = old.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    let b = new.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    if a.count * b.count > 250_000 {
        return "было: \(old)\nстало: \(new)"
    }
    var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    if !a.isEmpty && !b.isEmpty {
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                if a[i] == b[j] {
                    table[i][j] = table[i + 1][j + 1] + 1
                } else {
                    table[i][j] = max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
    }
    var result: [String] = []
    var i = 0
    var j = 0
    while i < a.count && j < b.count {
        if a[i] == b[j] {
            result.append(a[i])
            i += 1
            j += 1
        } else if table[i + 1][j] >= table[i][j + 1] {
            result.append("[-\(a[i])-]")
            i += 1
        } else {
            result.append("{+\(b[j])+}")
            j += 1
        }
    }
    while i < a.count {
        result.append("[-\(a[i])-]")
        i += 1
    }
    while j < b.count {
        result.append("{+\(b[j])+}")
        j += 1
    }
    return result.joined(separator: " ")
}

// MARK: - Profile info

/// Rough account creation month estimated from the user id.
public func ghostEstimatedRegistration(userId: Int64) -> String {
    let points: [(Int64, Int, Int)] = [
        (1_000_000, 2013, 8), (10_000_000, 2014, 3), (50_000_000, 2014, 10), (100_000_000, 2015, 2),
        (200_000_000, 2016, 3), (300_000_000, 2016, 11), (400_000_000, 2017, 7), (500_000_000, 2018, 2),
        (700_000_000, 2018, 12), (900_000_000, 2019, 9), (1_100_000_000, 2020, 2), (1_300_000_000, 2020, 5),
        (1_500_000_000, 2020, 11), (1_700_000_000, 2021, 2), (2_000_000_000, 2021, 9), (5_000_000_000, 2021, 10),
        (5_500_000_000, 2022, 8), (6_000_000_000, 2023, 3), (6_500_000_000, 2023, 10), (7_000_000_000, 2024, 4),
        (7_500_000_000, 2024, 11), (8_000_000_000, 2025, 5), (8_500_000_000, 2025, 12)
    ]
    func monthIndex(_ year: Int, _ month: Int) -> Double {
        return Double(year * 12 + (month - 1))
    }
    var value: Double
    if userId <= points[0].0 {
        value = monthIndex(points[0].1, points[0].2)
    } else if userId >= points[points.count - 1].0 {
        value = monthIndex(points[points.count - 1].1, points[points.count - 1].2)
    } else {
        value = 0.0
        for k in 0 ..< points.count - 1 {
            let (id0, y0, m0) = points[k]
            let (id1, y1, m1) = points[k + 1]
            if userId >= id0 && userId <= id1 {
                let t = Double(userId - id0) / Double(id1 - id0)
                value = monthIndex(y0, m0) + t * (monthIndex(y1, m1) - monthIndex(y0, m0))
                break
            }
        }
    }
    let total = Int(value.rounded())
    let months = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]
    return "~\(months[total % 12]) \(total / 12)"
}

/// The data center a user's profile photo is stored in (usually the user's home DC).
public func ghostUserDatacenter(_ user: TelegramUser) -> Int? {
    if let resource = user.photo.first?.resource as? CloudPeerPhotoSizeMediaResource {
        return resource.datacenterId
    }
    return nil
}

// MARK: - Markdown

/// Message text with its formatting written as Markdown.
public func ghostMarkdown(text: String, entities: [MessageTextEntity]) -> String {
    var insertions: [(position: Int, order: Int, value: String)] = []
    for entity in entities {
        let open: String
        let close: String
        switch entity.type {
        case .Bold:
            open = "**"
            close = "**"
        case .Italic:
            open = "_"
            close = "_"
        case .Code:
            open = "`"
            close = "`"
        case .Pre:
            open = "```\n"
            close = "\n```"
        case .Strikethrough:
            open = "~~"
            close = "~~"
        case .Underline:
            open = "__"
            close = "__"
        case .Spoiler:
            open = "||"
            close = "||"
        case let .TextUrl(url):
            open = "["
            close = "](\(url))"
        default:
            continue
        }
        insertions.append((entity.range.lowerBound, 1, open))
        insertions.append((entity.range.upperBound, 0, close))
    }
    let result = NSMutableString(string: text)
    let sorted = insertions.sorted(by: { lhs, rhs in
        if lhs.position != rhs.position {
            return lhs.position > rhs.position
        }
        return lhs.order > rhs.order
    })
    for insertion in sorted {
        let position = max(0, min(result.length, insertion.position))
        result.insert(insertion.value, at: position)
    }
    return result as String
}
