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

/// Must match GhostUploadAttributes in TelegramUI (GhostUploadActivityController.swift).
struct GhostUploadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var sentKB: Int
        var totalKB: Int
        var count: Int
        var kind: String
        var done: Bool
    }
}

private func ghostKB(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    formatter.locale = Locale(identifier: "ru_RU")
    return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " КБ"
}

private let ghostBlue = Color(red: 0.16, green: 0.63, blue: 0.98)
private let ghostGreen = Color(red: 0.2, green: 0.84, blue: 0.42)

/// The paper plane flies along a dashed route; a finish flag waits at the end.
@available(iOS 16.1, *)
private struct GhostFlightTrack: View {
    let progress: Double
    let done: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let planeX = 12.0 + (width - 40.0) * (done ? 1.0 : max(0.0, min(1.0, progress)))
            ZStack(alignment: .leading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 14))
                    path.addLine(to: CGPoint(x: width - 18, y: 14))
                }
                .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                Capsule()
                    .fill(LinearGradient(colors: [ghostBlue.opacity(0.3), done ? ghostGreen : ghostBlue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, planeX), height: 4)
                    .offset(y: 0)
                    .position(x: max(4, planeX) / 2, y: 14)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(done ? ghostGreen : .white.opacity(0.6))
                    .position(x: width - 8, y: 12)
                Image(systemName: done ? "checkmark.circle.fill" : "paperplane.fill")
                    .font(.system(size: done ? 20 : 18, weight: .semibold))
                    .foregroundColor(done ? ghostGreen : ghostBlue)
                    .rotationEffect(.degrees(done ? 0 : 12))
                    .shadow(color: (done ? ghostGreen : ghostBlue).opacity(0.7), radius: 6)
                    .position(x: planeX, y: done ? 14 : 12)
            }
        }
        .frame(height: 28)
    }
}

@available(iOS 16.1, *)
private struct GhostUploadDetails: View {
    let state: GhostUploadAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(state.done ? "Отправлено" : "Отправка \(state.kind)\(state.count > 1 ? " · \(state.count) шт." : "")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(state.done ? "100%" : "\(Int((state.progress * 100.0).rounded()))%")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundColor(state.done ? ghostGreen : ghostBlue)
            }
            GhostFlightTrack(progress: state.progress, done: state.done)
            Text(state.done ? "✅ Доставлено · \(ghostKB(state.totalKB))" : "\(ghostKB(state.sentKB)) из \(ghostKB(state.totalKB))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

@available(iOS 16.1, *)
struct GhostUploadActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GhostUploadAttributes.self) { context in
            GhostUploadDetails(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(ghostBlue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    GhostUploadDetails(state: context.state)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    Image(systemName: context.state.done ? "checkmark.circle.fill" : "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(context.state.done ? ghostGreen : ghostBlue)
                        .rotationEffect(.degrees(context.state.done ? 0 : 12))
                        .offset(x: context.state.done ? 0 : CGFloat(context.state.progress) * 3.0, y: context.state.done ? 0 : -CGFloat(context.state.progress) * 2.0)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2)).frame(width: 30, height: 4)
                        Capsule().fill(context.state.done ? ghostGreen : ghostBlue).frame(width: max(3, 30 * CGFloat(context.state.done ? 1.0 : context.state.progress)), height: 4)
                    }
                }
            } compactTrailing: {
                Text(context.state.done ? "Готово" : "\(Int((context.state.progress * 100.0).rounded()))%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundColor(context.state.done ? ghostGreen : ghostBlue)
            } minimal: {
                Image(systemName: context.state.done ? "checkmark.circle.fill" : "paperplane.fill")
                    .foregroundColor(context.state.done ? ghostGreen : ghostBlue)
            }
            .keylineTint(context.state.done ? ghostGreen : ghostBlue)
        }
    }
}

@available(iOS 16.1, *)
struct AllWidgetsWithGhost: WidgetBundle {
    var body: some Widget {
        Static_Widget()
        Static_AvatarsWidget()
        GhostLiveActivityWidget()
        GhostUploadActivityWidget()
    }
}
