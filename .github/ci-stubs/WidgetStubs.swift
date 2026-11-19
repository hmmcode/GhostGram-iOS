// Stand-ins for the stock Telegram widgets so GhostLiveActivity.swift type-checks on its own. Not part of the app.
import SwiftUI
import WidgetKit

struct Static_Widget: Widget {
    var body: some WidgetConfiguration {
        EmptyWidgetConfiguration()
    }
}

struct Static_AvatarsWidget: Widget {
    var body: some WidgetConfiguration {
        EmptyWidgetConfiguration()
    }
}
