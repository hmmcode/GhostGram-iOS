import Foundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import TelegramCore

/// Lets a plugin pick a video, GIF, screenshot or photo and sends it as a round video message.
final class GhostRoundVideoPicker: NSObject, PHPickerViewControllerDelegate {
    private static var current: GhostRoundVideoPicker?

    private let chatId: String
    private let replyTo: Int32
    private let seconds: Int
    private let toast: (String) -> Void

    private init(chatId: String, replyTo: Int32, seconds: Int, toast: @escaping (String) -> Void) {
        self.chatId = chatId
        self.replyTo = replyTo
        self.seconds = seconds
        self.toast = toast
        super.init()
    }

    static func present(from controller: UIViewController?, chatId: String, replyTo: Int32, seconds: Int, toast: @escaping (String) -> Void) {
        guard let controller = controller else {
            toast("⚠️ Не получилось открыть галерею")
            return
        }
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .any(of: [.videos, .images])
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        let handler = GhostRoundVideoPicker(chatId: chatId, replyTo: replyTo, seconds: seconds, toast: toast)
        current = handler
        picker.delegate = handler
        controller.present(picker, animated: true, completion: nil)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        defer {
            GhostRoundVideoPicker.current = nil
        }
        guard let provider = results.first?.itemProvider else {
            return
        }
        toast("⏳ Делаю кружок…")

        if provider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { data, error in
                guard let data = data else {
                    self.fail(error)
                    return
                }
                GhostRoundVideoMaker.fromAnimatedImage(data, minSeconds: 3.0, completion: self.finish)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url else {
                    self.fail(error)
                    return
                }
                // The provided file disappears when this block returns, so keep a copy.
                let copy = FileManager.default.temporaryDirectory.appendingPathComponent("ghost-source-\(UInt64.random(in: 1 ... UInt64.max)).\(url.pathExtension.isEmpty ? "mov" : url.pathExtension)")
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                } catch {
                    self.fail(error)
                    return
                }
                GhostRoundVideoMaker.fromVideo(copy) { result in
                    try? FileManager.default.removeItem(at: copy)
                    self.finish(result)
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                guard let data = data else {
                    self.fail(error)
                    return
                }
                // Animated PNG/HEICS also go through the frame path; plain pictures become a still clip.
                GhostRoundVideoMaker.fromAnimatedImage(data, minSeconds: Double(self.seconds), completion: self.finish)
            }
        } else {
            toast("⚠️ Этот файл не подходит. Выбери видео, гифку или картинку")
        }
    }

    private func fail(_ error: Error?) {
        let text = error?.localizedDescription ?? "неизвестная ошибка"
        DispatchQueue.main.async {
            self.toast("⚠️ Кружок не получился: \(text)")
        }
    }

    private func finish(_ result: Swift.Result<GhostRoundVideoMaker.Result, Error>) {
        switch result {
        case let .failure(error):
            fail(error)
        case let .success(made):
            defer {
                try? FileManager.default.removeItem(at: made.url)
            }
            guard let data = try? Data(contentsOf: made.url), !data.isEmpty else {
                fail(nil)
                return
            }
            let thumbnail = made.thumbnail.flatMap { GhostRoundVideoMaker.jpeg($0) }
            GhostPlugins.shared.sendRoundVideo?(chatId, data, thumbnail, made.duration, GhostRoundVideoMaker.side, replyTo)
            DispatchQueue.main.async {
                self.toast("🔵 Кружок отправлен")
            }
        }
    }
}
