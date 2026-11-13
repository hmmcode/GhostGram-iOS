import Foundation
import UIKit
import CoreMotion
import LocalAuthentication
import TelegramCore
import SettingsUI

/// Set while a call the user confirmed is being re-requested.
var ghostCallConfirmBypass = false

private func ghostTopViewController() -> UIViewController? {
    var window: UIWindow?
    for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                window = keyWindow
                break
            }
        }
    }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    return controller
}

/// A plain system confirmation alert, usable from anywhere in the app.
func ghostConfirm(title: String, confirmTitle: String, action: @escaping () -> Void) {
    guard let controller = ghostTopViewController() else {
        action()
        return
    }
    let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: confirmTitle, style: .default, handler: { _ in
        action()
    }))
    controller.present(alert, animated: true, completion: nil)
}

/// Face ID / Touch ID / device passcode check. Succeeds right away when the device has no passcode.
func ghostAuthenticate(reason: String, completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    var error: NSError?
    if !context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
        completion(true)
        return
    }
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason, reply: { success, _ in
        DispatchQueue.main.async {
            completion(success)
        }
    })
}

/// Panic mode: shaking the phone sends the app to the background right away.
final class GhostPanicController {
    static let shared = GhostPanicController()

    private let motionManager = CMMotionManager()
    private var lastTrigger: Date = .distantPast
    private var observer: NSObjectProtocol?

    init() {
        self.observer = NotificationCenter.default.addObserver(forName: ghostGramSettingsChangedNotification, object: nil, queue: .main, using: { _ in
            GhostPanicController.shared.update()
        })
    }

    func update() {
        if GhostSettings.panicShake {
            self.startIfNeeded()
        } else if self.motionManager.isAccelerometerActive {
            self.motionManager.stopAccelerometerUpdates()
        }
    }

    private func startIfNeeded() {
        guard self.motionManager.isAccelerometerAvailable, !self.motionManager.isAccelerometerActive else {
            return
        }
        self.motionManager.accelerometerUpdateInterval = 0.1
        self.motionManager.startAccelerometerUpdates(to: OperationQueue.main, withHandler: { [weak self] data, _ in
            guard let self = self, let data = data else {
                return
            }
            let force = sqrt(data.acceleration.x * data.acceleration.x + data.acceleration.y * data.acceleration.y + data.acceleration.z * data.acceleration.z)
            if force > 2.7 && Date().timeIntervalSince(self.lastTrigger) > 2.0 {
                self.lastTrigger = Date()
                self.panic()
            }
        })
    }

    private func panic() {
        GhostSettings.lockAllChatsAgain()
        UIPasteboard.general.items = []
        UIControl().sendAction(NSSelectorFromString("suspend"), to: UIApplication.shared, for: nil)
    }
}
