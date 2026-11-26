import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import Display

// GhostGram second batch (ideas from exteraGram): message screenshots, song lyrics, chat export.

private func ghostExtrasTopViewController() -> UIViewController? {
    var window: UIWindow?
    for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene, let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            window = keyWindow
            break
        }
    }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    return controller
}

/// The system share sheet (save to Photos, send to another app, Files).
func ghostShare(_ items: [Any]) {
    guard let controller = ghostExtrasTopViewController() else {
        return
    }
    let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1.0, height: 1.0)
    }
    controller.present(activity, animated: true, completion: nil)
}

private func ghostShowAlert(title: String, text: String) {
    guard let controller = ghostExtrasTopViewController() else {
        return
    }
    let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    controller.present(alert, animated: true, completion: nil)
}

// MARK: - Message screenshot

/// The part of an image that is not transparent.
private func ghostVisibleBounds(_ image: CGImage) -> CGRect? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else {
        return nil
    }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else {
        return nil
    }
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0 ..< height {
        let row = y * width * 4
        for x in 0 ..< width where pixels[row + x * 4 + 3] > 10 {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
    if maxX < minX || maxY < minY {
        return nil
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// A picture of a message bubble on a GhostGram background, ready to share.
func ghostMessageScreenshot(view: UIView) -> UIImage? {
    let size = view.bounds.size
    guard size.width > 1.0, size.height > 1.0 else {
        return nil
    }
    let scale = UIScreen.main.scale
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = scale
    let raw = UIGraphicsImageRenderer(size: size, format: format).image { context in
        view.layer.render(in: context.cgContext)
    }
    guard let rawImage = raw.cgImage else {
        return nil
    }
    let pixelCrop = ghostVisibleBounds(rawImage) ?? CGRect(x: 0, y: 0, width: rawImage.width, height: rawImage.height)
    guard let cropped = rawImage.cropping(to: pixelCrop) else {
        return nil
    }
    let content = CGSize(width: pixelCrop.width / scale, height: pixelCrop.height / scale)
    let padding: CGFloat = 24.0
    let footer: CGFloat = 26.0
    let outSize = CGSize(width: max(content.width + padding * 2.0, 220.0), height: content.height + padding * 2.0 + footer)
    return UIGraphicsImageRenderer(size: outSize, format: format).image { context in
        let colors = [UIColor(rgb: 0x23263a).cgColor, UIColor(rgb: 0x151722).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: outSize.width, y: outSize.height), options: [])
        }
        let origin = CGPoint(x: floor((outSize.width - content.width) / 2.0), y: padding)
        UIImage(cgImage: cropped, scale: scale, orientation: .up).draw(in: CGRect(origin: origin, size: content))
        let watermark = NSAttributedString(string: "👻 GhostGram", attributes: [
            .font: UIFont.systemFont(ofSize: 12.0, weight: .semibold),
            .foregroundColor: UIColor(white: 1.0, alpha: 0.45)
        ])
        let markSize = watermark.size()
        watermark.draw(at: CGPoint(x: outSize.width - markSize.width - 14.0, y: outSize.height - markSize.height - 10.0))
    }
}

// MARK: - Lyrics

private final class GhostLyricsController: UIViewController {
    private let songTitle: String
    private let lyrics: String

    init(title: String, lyrics: String) {
        self.songTitle = title
        self.lyrics = lyrics
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(rgb: 0x151722)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
        blur.frame = self.view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(blur)

        let titleLabel = UILabel()
        titleLabel.text = self.songTitle
        titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(titleLabel)

        let close = UIButton(type: .system)
        close.setTitle("Готово", for: .normal)
        close.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        close.tintColor = UIColor(rgb: 0xa9b0ff)
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
        self.view.addSubview(close)

        let textView = UITextView()
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.textColor = UIColor(white: 1.0, alpha: 0.92)
        textView.font = UIFont.systemFont(ofSize: 20.0, weight: .semibold)
        textView.text = self.lyrics
        textView.textContainerInset = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 40.0, right: 16.0)
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(textView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 18.0),
            titleLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: close.leadingAnchor, constant: -12.0),
            close.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            close.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16.0),
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),
            textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }

    @objc private func closePressed() {
        self.dismiss(animated: true, completion: nil)
    }
}

/// Plain lyrics: timestamps like "[01:23.45]" are removed from synced lyrics.
private func ghostCleanLyrics(_ text: String) -> String {
    let lines = text.components(separatedBy: "\n").map { line -> String in
        var line = line
        while line.hasPrefix("["), let close = line.firstIndex(of: "]") {
            line = String(line[line.index(after: close)...])
        }
        return line.trimmingCharacters(in: .whitespaces)
    }
    return lines.joined(separator: "\n")
}

/// Looks the song up on LRCLIB (a free, open lyrics database) and shows the words.
func ghostShowLyrics(title: String, performer: String, duration: Int) {
    func request(_ path: String, _ items: [URLQueryItem], _ completion: @escaping (Any?) -> Void) {
        var components = URLComponents(string: "https://lrclib.net" + path)
        components?.queryItems = items
        guard let url = components?.url else {
            completion(nil)
            return
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 10.0
        urlRequest.setValue("GhostGram (https://github.com/hmmcode/GhostGram-iOS)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: urlRequest, completionHandler: { data, _, _ in
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            DispatchQueue.main.async {
                completion(json)
            }
        }).resume()
    }
    func lyrics(from entry: [String: Any]) -> String? {
        if let plain = entry["plainLyrics"] as? String, !plain.isEmpty {
            return plain
        }
        if let synced = entry["syncedLyrics"] as? String, !synced.isEmpty {
            return ghostCleanLyrics(synced)
        }
        return nil
    }
    func present(_ text: String?) {
        let heading = performer.isEmpty ? title : "\(performer) — \(title)"
        guard let text = text else {
            ghostShowAlert(title: "Текст не найден", text: "Для «\(heading)» в открытой базе LRCLIB текста нет.")
            return
        }
        let controller = GhostLyricsController(title: heading, lyrics: text)
        controller.modalPresentationStyle = .pageSheet
        ghostExtrasTopViewController()?.present(controller, animated: true, completion: nil)
    }
    var exact: [URLQueryItem] = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: performer)]
    if duration > 0 {
        exact.append(URLQueryItem(name: "duration", value: "\(duration)"))
    }
    request("/api/get", exact, { result in
        if let entry = result as? [String: Any], let text = lyrics(from: entry) {
            present(text)
            return
        }
        request("/api/search", [URLQueryItem(name: "q", value: "\(performer) \(title)".trimmingCharacters(in: .whitespaces))], { result in
            let entries = (result as? [[String: Any]]) ?? []
            present(entries.lazy.compactMap { lyrics(from: $0) }.first)
        })
    })
}

// MARK: - Chat export

private func ghostMediaLabel(_ message: Message) -> String? {
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

private func ghostHTMLEscape(_ text: String) -> String {
    return text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\n", with: "<br>")
}

/// Writes the messages of a chat that are on this phone into an HTML or JSON file and opens the share sheet.
func ghostExportChat(context: AccountContext, peerId: PeerId, title: String, json: Bool) {
    let _ = (context.account.postbox.transaction { transaction -> [Message] in
        var result: [Message] = []
        transaction.scanTopMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: 20000, { message in
            result.append(message)
            return true
        })
        return result
    }
    |> deliverOn(Queue.concurrentDefaultQueue())).startStandalone(next: { messages in
        let ordered = messages.sorted(by: { $0.index < $1.index })
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        let safeTitle = String(title.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }.map(Character.init)).trimmingCharacters(in: .whitespaces)
        let fileName = "GhostGram-\(safeTitle.isEmpty ? "chat" : safeTitle).\(json ? "json" : "html")"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var data = Data()
        if json {
            var list: [[String: Any]] = []
            for message in ordered {
                var entry: [String: Any] = [
                    "id": Int(message.id.id),
                    "date": dateFormatter.string(from: Date(timeIntervalSince1970: Double(message.timestamp))),
                    "text": message.text
                ]
                if let author = message.author {
                    entry["from"] = author.debugDisplayTitle
                    entry["from_id"] = author.id.id._internalGetInt64Value()
                }
                if let media = ghostMediaLabel(message) {
                    entry["media"] = media
                }
                list.append(entry)
            }
            let root: [String: Any] = ["chat": title, "exported_by": "GhostGram", "count": list.count, "messages": list]
            data = (try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])) ?? Data()
        } else {
            var html = "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\(ghostHTMLEscape(title))</title>"
            html += "<style>body{margin:0;background:#151722;color:#e7e8ee;font:15px -apple-system,Segoe UI,sans-serif}main{max-width:720px;margin:0 auto;padding:20px}h1{font-size:20px}.m{background:#ffffff10;border-radius:14px;padding:10px 12px;margin:8px 0}.h{color:#a9b0ff;font-weight:600;font-size:13px}.d{color:#7c8191;font-size:12px;margin-left:6px;font-weight:400}.media{color:#9ca1b4;font-style:italic}</style></head><body><main>"
            html += "<h1>\(ghostHTMLEscape(title))</h1><p class=\"d\">Сообщений: \(ordered.count) · экспорт GhostGram</p>"
            for message in ordered {
                let author = message.author?.debugDisplayTitle ?? title
                html += "<div class=\"m\"><div class=\"h\">\(ghostHTMLEscape(author))<span class=\"d\">\(dateFormatter.string(from: Date(timeIntervalSince1970: Double(message.timestamp))))</span></div>"
                if let media = ghostMediaLabel(message) {
                    html += "<div class=\"media\">[\(media)]</div>"
                }
                if !message.text.isEmpty {
                    html += "<div>\(ghostHTMLEscape(message.text))</div>"
                }
                html += "</div>"
            }
            html += "</main></body></html>"
            data = html.data(using: .utf8) ?? Data()
        }
        let written = (try? data.write(to: url, options: .atomic)) != nil
        DispatchQueue.main.async {
            if written && !ordered.isEmpty {
                ghostShare([url])
            } else {
                ghostShowAlert(title: "Не получилось", text: "В этом чате на телефоне нет сохранённых сообщений.")
            }
        }
    })
}
