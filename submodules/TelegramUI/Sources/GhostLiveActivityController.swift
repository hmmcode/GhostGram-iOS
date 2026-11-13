import Foundation
import ActivityKit
import TelegramCore
import SettingsUI

/// Must match GhostActivityAttributes in the widget extension (Telegram/WidgetKitWidget/GhostLiveActivity.swift).
struct GhostActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var hideRead: Bool
        var hideOnline: Bool
        var hideTyping: Bool
        var hideStories: Bool
    }
}

/// Shows a ghost in the Dynamic Island while ghost mode is on and the option is enabled.
final class GhostLiveActivityController {
    static let shared = GhostLiveActivityController()

    private var observer: NSObjectProtocol?

    func start() {
        if self.observer == nil {
            self.observer = NotificationCenter.default.addObserver(forName: ghostGramSettingsChangedNotification, object: nil, queue: .main, using: { _ in
                GhostLiveActivityController.shared.update()
            })
        }
        self.update()
    }

    func update() {
        guard #available(iOS 16.2, *) else {
            return
        }
        let state = GhostActivityAttributes.ContentState(
            hideRead: GhostSettings.hideReadReceipts,
            hideOnline: GhostSettings.hideOnlineStatus,
            hideTyping: GhostSettings.hideTyping,
            hideStories: GhostSettings.hideStoryViews
        )
        let content = ActivityContent(state: state, staleDate: nil)
        let activities = Activity<GhostActivityAttributes>.activities
        if GhostSettings.dynamicIsland && GhostSettings.isAnyGhostModeOn {
            if let activity = activities.first {
                Task {
                    await activity.update(content)
                }
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                let _ = try? Activity<GhostActivityAttributes>.request(attributes: GhostActivityAttributes(), content: content, pushType: nil)
            }
        } else {
            for activity in activities {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
