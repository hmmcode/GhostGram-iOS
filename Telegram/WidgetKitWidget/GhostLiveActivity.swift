import Foundation
import SwiftUI
import WidgetKit
import ActivityKit

/// Must match GhostActivityAttributes in TelegramUI (GhostLiveActivityController.swift).
struct GhostActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var hideRead: Bool
        var hideOnline: Bool
        var hideTyping: Bool
        var hideStories: Bool
    }
}

@available(iOS 16.1, *)
private func ghostSummary(_ state: GhostActivityAttributes.ContentState) -> String {
    var parts: [String] = []
    if state.hideRead {
        parts.append("прочитано")
    }
    if state.hideOnline {
        parts.append("в сети")
    }
    if state.hideTyping {
        parts.append("печатает")
    }
    if state.hideStories {
        parts.append("истории")
    }
    if parts.isEmpty {
        return "Призрак выключен"
    }
    return "Скрыто: " + parts.joined(separator: ", ")
}

@available(iOS 16.1, *)
struct GhostLiveActivityWidget: Widget {
    private let accent = Color(red: 0.54, green: 0.36, blue: 1.0)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GhostActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Text("👻")
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Режим призрака")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(ghostSummary(context.state))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Text("GhostGram")
                    .font(.caption2)
                    .foregroundColor(self.accent)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(self.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("👻")
                        .font(.system(size: 30))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("GhostGram")
                        .font(.caption)
                        .foregroundColor(self.accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(ghostSummary(context.state))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            } compactLeading: {
                Text("👻")
            } compactTrailing: {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(self.accent)
            } minimal: {
                Text("👻")
            }
            .keylineTint(self.accent)
        }
    }
}

@available(iOS 16.1, *)
struct AllWidgetsWithGhost: WidgetBundle {
    var body: some Widget {
        Static_Widget()
        Static_AvatarsWidget()
        GhostLiveActivityWidget()
    }
}
