import Foundation
import UIKit
import TelegramCore
import SettingsUI

/// A "GhostGram" pill drawn by the app itself around the Dynamic Island.
/// iOS hides an app's own Live Activity while that app is open, so other clients draw this in-app too.
final class GhostIslandBadge {
    static let shared = GhostIslandBadge()

    private var window: UIWindow?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: ghostGramSettingsChangedNotification, object: nil, queue: .main, using: { _ in
            GhostIslandBadge.shared.update()
        }))
        self.observers.append(center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main, using: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                GhostIslandBadge.shared.update()
            })
        }))
    }

    func update() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard GhostSettings.islandBadge, let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            self.window?.isHidden = true
            return
        }
        let appWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first(where: { $0 !== self.window })
        let topInset = appWindow?.safeAreaInsets.top ?? 0
        let screenBounds = scene.screen.bounds
        // Dynamic Island iPhones have a top safe area of about 59pt or more in portrait; notched ones have less.
        guard screenBounds.height > screenBounds.width, topInset >= 58.0 else {
            self.window?.isHidden = true
            return
        }

        let islandWidth: CGFloat = 126.0
        let islandHeight: CGFloat = 37.0
        let islandTop: CGFloat = 11.0
        let sideExtension: CGFloat = 22.0
        let bottomExtension: CGFloat = 17.0
        let frame = CGRect(
            x: floor((screenBounds.width - islandWidth) / 2.0) - sideExtension,
            y: islandTop,
            width: islandWidth + sideExtension * 2.0,
            height: islandHeight + bottomExtension
        )

        let window: UIWindow
        if let current = self.window, current.windowScene === scene {
            window = current
        } else {
            self.window?.isHidden = true
            // Only as large as the pill, so it never takes over the status bar style or touches.
            window = UIWindow(windowScene: scene)
            window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.statusBar.rawValue + 1.0)
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            let rootController = UIViewController()
            rootController.view.backgroundColor = .black
            rootController.view.isUserInteractionEnabled = false
            rootController.view.layer.cornerRadius = 22.0
            rootController.view.layer.cornerCurve = .continuous
            rootController.view.clipsToBounds = true

            let label = UILabel()
            label.text = "👻 GhostGram"
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 11.0, weight: .semibold)
            label.textAlignment = .center
            label.tag = 1
            rootController.view.addSubview(label)

            window.rootViewController = rootController
            self.window = window
        }
        window.frame = frame
        if let rootView = window.rootViewController?.view {
            rootView.frame = CGRect(origin: .zero, size: frame.size)
            if let label = rootView.viewWithTag(1) {
                label.frame = CGRect(x: 0.0, y: islandHeight, width: frame.width, height: bottomExtension - 3.0)
            }
        }
        window.isHidden = false
    }
}

/// Covers the app with black while the screen is recorded, mirrored or shared.
final class GhostCaptureShield {
    static let shared = GhostCaptureShield()

    private var window: UIWindow?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main, using: { _ in
            GhostCaptureShield.shared.update()
        }))
        self.observers.append(center.addObserver(forName: ghostGramSettingsChangedNotification, object: nil, queue: .main, using: { _ in
            GhostCaptureShield.shared.update()
        }))
    }

    func update() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }
        guard GhostSettings.hideOnScreenRecording, scene.screen.isCaptured else {
            self.window?.isHidden = true
            return
        }
        let window: UIWindow
        if let current = self.window, current.windowScene === scene {
            window = current
        } else {
            self.window?.isHidden = true
            window = UIWindow(windowScene: scene)
            window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.statusBar.rawValue + 2.0)
            window.backgroundColor = .black
            let rootController = UIViewController()
            rootController.view.backgroundColor = .black
            let label = UILabel()
            label.text = "👻\nИдёт запись экрана — GhostGram скрыт"
            label.numberOfLines = 0
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            rootController.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: rootController.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: rootController.view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: rootController.view.leadingAnchor, constant: 24.0)
            ])
            window.rootViewController = rootController
            self.window = window
        }
        window.frame = scene.screen.bounds
        window.isHidden = false
    }
}
