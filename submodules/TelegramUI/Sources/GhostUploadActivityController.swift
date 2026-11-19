import Foundation
import UIKit
import ActivityKit
import SwiftSignalKit
import TelegramCore

/// Must match GhostUploadAttributes in the widget extension (Telegram/WidgetKitWidget/GhostLiveActivity.swift).
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

/// Shows sending progress in the Dynamic Island: a flying paper plane, percent and size in KB,
/// then "Sent" with a buzz at the end.
final class GhostUploadActivityController {
    static let shared = GhostUploadActivityController()

    private var attached = Set<AccountRecordId>()
    private var disposables: [Disposable] = []
    private var snapshots: [AccountRecordId: GhostUploadSnapshot] = [:]

    // The current sending session. Finished files drop out of the upload list,
    // so the session remembers the biggest total it has seen.
    private var sessionActive = false
    private var sessionTotalBytes: Int64 = 0
    private var sessionStart = Date()
    private var lastState: GhostUploadAttributes.ContentState?
    private var lastPush = Date.distantPast
    private var pendingStart: DispatchWorkItem?
    private var activityObject: AnyObject?

    func attach(account: Account) {
        if self.attached.contains(account.id) {
            return
        }
        self.attached.insert(account.id)
        let id = account.id
        self.disposables.append((ghostUploadSnapshots(account: account)
        |> deliverOnMainQueue).start(next: { [weak self] snapshot in
            self?.snapshots[id] = snapshot
            self?.update()
        }))
    }

    private func update() {
        guard #available(iOS 16.2, *) else {
            return
        }
        let active = self.snapshots.values.filter { $0.count > 0 }
        let count = active.reduce(0) { $0 + $1.count }
        let remainingTotal = active.reduce(Int64(0)) { $0 + $1.totalBytes }
        let remainingSent = active.reduce(0.0) { $0 + Double($1.totalBytes) * $1.progress }
        let kinds = Set(active.map { $0.kind })
        let kind = kinds.count == 1 ? kinds.first! : "медиа"

        if count > 0 {
            if !self.sessionActive {
                self.sessionActive = true
                self.sessionTotalBytes = 0
                self.sessionStart = Date()
                self.lastState = nil
            }
            self.sessionTotalBytes = max(self.sessionTotalBytes, remainingTotal)
            let finishedBytes = Double(self.sessionTotalBytes - remainingTotal)
            let sent = finishedBytes + remainingSent
            let progress = self.sessionTotalBytes > 0 ? sent / Double(self.sessionTotalBytes) : active.reduce(0.0) { $0 + $1.progress } / Double(max(1, active.count))
            let state = GhostUploadAttributes.ContentState(
                progress: max(0.0, min(0.99, progress)),
                sentKB: Int(sent / 1024.0),
                totalKB: Int(Double(self.sessionTotalBytes) / 1024.0),
                count: count,
                kind: kind,
                done: false
            )
            self.push(state)
        } else if self.sessionActive {
            self.sessionActive = false
            self.finish()
        }
    }

    @available(iOS 16.2, *)
    private var activity: Activity<GhostUploadAttributes>? {
        get { return self.activityObject as? Activity<GhostUploadAttributes> }
        set { self.activityObject = newValue }
    }

    @available(iOS 16.2, *)
    private func push(_ state: GhostUploadAttributes.ContentState) {
        self.lastState = state
        if !GhostSettings.uploadIsland {
            return
        }
        if let activity = self.activity {
            // Live Activities have an update budget: about twice a second is plenty for a smooth flight.
            if Date().timeIntervalSince(self.lastPush) < 0.45 {
                return
            }
            self.lastPush = Date()
            Task {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
            return
        }
        // Tiny uploads finish before anyone could see them: start only if sending takes a moment.
        if self.pendingStart != nil {
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            self.pendingStart = nil
            guard self.sessionActive, self.activity == nil, let current = self.lastState, ActivityAuthorizationInfo().areActivitiesEnabled else {
                return
            }
            self.activity = try? Activity<GhostUploadAttributes>.request(attributes: GhostUploadAttributes(), content: ActivityContent(state: current, staleDate: nil), pushType: nil)
            self.lastPush = Date()
        }
        self.pendingStart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func finish() {
        guard #available(iOS 16.2, *) else {
            return
        }
        self.pendingStart?.cancel()
        self.pendingStart = nil
        guard let activity = self.activity else {
            return
        }
        self.activity = nil
        let total = self.lastState?.totalKB ?? 0
        let final = GhostUploadAttributes.ContentState(progress: 1.0, sentKB: total, totalKB: total, count: self.lastState?.count ?? 1, kind: self.lastState?.kind ?? "медиа", done: true)
        if UIApplication.shared.applicationState == .active {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        Task {
            // The alert makes the island pop open and the phone buzz when the app is in the background.
            let body = "Доставлено: \(final.kind)"
            let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: "Отправлено ✅"), body: LocalizedStringResource(stringLiteral: body), sound: .default)
            await activity.update(ActivityContent(state: final, staleDate: nil), alertConfiguration: alert)
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
