import Foundation
import UIKit
import UserNotifications
import TelegramCore

/// Shows what GhostGram plugins ask for: alerts, toasts, clipboard copies and banners.
enum GhostPluginUI {
    private static var installed = false
    private static var toastWindow: UIWindow?
    private static var toastGeneration = 0

    static func install() {
        if installed {
            return
        }
        installed = true
        GhostPlugins.shared.uiHandler = { request in
            DispatchQueue.main.async {
                handle(request)
            }
        }
    }

    private static func handle(_ request: GhostPluginUIRequest) {
        switch request {
        case let .alert(title, text):
            presentAlert(title: title, text: text)
        case let .toast(text):
            showToast(text)
        case let .copy(text):
            UIPasteboard.general.string = text
            showToast("📋 Скопировано")
        case let .notify(title, text, identifier):
            if UIApplication.shared.applicationState == .active {
                showToast(text.isEmpty ? title : "\(title)\n\(text)")
            } else {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = text
                content.sound = .default
                content.threadIdentifier = "ghostgram-plugins"
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil), withCompletionHandler: nil)
            }
        }
    }

    private static var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    private static func topController() -> UIViewController? {
        guard let scene = activeScene else {
            return nil
        }
        let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first(where: { $0 !== toastWindow })
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private static func presentAlert(title: String, text: String) {
        guard let controller = topController() else {
            return
        }
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Скопировать", style: .default, handler: { _ in
            UIPasteboard.general.string = text
        }))
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        controller.present(alert, animated: true, completion: nil)
    }

    private static func showToast(_ text: String) {
        guard let scene = activeScene, !text.isEmpty else {
            return
        }
        toastGeneration += 1
        let generation = toastGeneration
        toastWindow?.isHidden = true

        let bounds = scene.screen.bounds
        let width = min(bounds.width - 32.0, 420.0)
        let label = UILabel()
        label.text = text
        label.numberOfLines = 4
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        label.textAlignment = .center
        let labelSize = label.sizeThatFits(CGSize(width: width - 32.0, height: 200.0))
        let height = max(44.0, ceil(labelSize.height) + 24.0)

        let topInset = scene.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 47.0
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: floor((bounds.width - width) / 2.0), y: topInset + 8.0, width: width, height: height)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 2.0)
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false

        let root = UIViewController()
        root.view.backgroundColor = .clear
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
        blur.frame = CGRect(origin: .zero, size: window.frame.size)
        blur.layer.cornerRadius = min(22.0, height / 2.0)
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        root.view.addSubview(blur)
        label.frame = CGRect(x: 16.0, y: 0.0, width: width - 32.0, height: height)
        root.view.addSubview(label)
        window.rootViewController = root
        window.alpha = 0.0
        window.isHidden = false
        toastWindow = window

        UIView.animate(withDuration: 0.2, animations: {
            window.alpha = 1.0
        })
        let duration = min(6.0, 2.0 + Double(text.count) / 30.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: {
            if generation != toastGeneration {
                return
            }
            UIView.animate(withDuration: 0.25, animations: {
                window.alpha = 0.0
            }, completion: { _ in
                if generation == toastGeneration {
                    window.isHidden = true
                    toastWindow = nil
                }
            })
        })
    }
}
