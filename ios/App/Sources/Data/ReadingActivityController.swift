import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Starts, updates and ends the reading Live Activity for the bani reader. Opt-in (default off),
/// self-disabling when the platform hook is unavailable, and defensive: it never starts under a UI
/// test, only updates on a whole-percent change and no more than every 10 s, and always carries a
/// stale date so a forgotten activity fades on its own.
@MainActor
final class ReadingActivityController: ObservableObject {
    static let enabledKey = "sggs_live_activity"

    private var lastPercent: Int?
    private var lastUpdate: Date?
    #if canImport(ActivityKit)
    private var activity: Activity<NitnemActivityAttributes>?
    #endif

    /// Whether the reader has opted in AND the platform allows activities right now.
    var isAvailable: Bool {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return false }
        if DebugHooks.isUITest { return false }
        #if canImport(ActivityKit)
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }

    func start(key: String, titleEn: String, titleGm: String, fraction: Double, sectionLabel: String, now: Date = Date()) {
        #if canImport(ActivityKit)
        guard isAvailable, activity == nil else { return }
        let percent = ReadingActivityPolicy.wholePercent(fraction)
        let state = NitnemActivityAttributes.ContentState(progress: Double(percent) / 100, sectionLabel: sectionLabel, done: false)
        let content = ActivityContent(state: state, staleDate: ReadingActivityPolicy.staleDate(from: now))
        let attrs = NitnemActivityAttributes(key: key, titleEn: titleEn, titleGm: titleGm)
        activity = try? Activity.request(attributes: attrs, content: content, pushType: nil)
        lastPercent = percent
        lastUpdate = now
        #endif
    }

    func update(fraction: Double, sectionLabel: String, now: Date = Date()) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        guard ReadingActivityPolicy.shouldUpdate(lastPercent: lastPercent, newFraction: fraction, lastUpdate: lastUpdate, now: now) else { return }
        let percent = ReadingActivityPolicy.wholePercent(fraction)
        let state = NitnemActivityAttributes.ContentState(progress: Double(percent) / 100, sectionLabel: sectionLabel, done: false)
        let id = activity.id
        let stale = ReadingActivityPolicy.staleDate(from: now)
        Task.detached {   // detached so the Activity never crosses an actor boundary
            if let a = Activity<NitnemActivityAttributes>.activities.first(where: { $0.id == id }) {
                await a.update(ActivityContent(state: state, staleDate: stale))
            }
        }
        lastPercent = percent
        lastUpdate = now
        #endif
    }

    func end(done: Bool) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        let final = NitnemActivityAttributes.ContentState(progress: done ? 1 : activity.content.state.progress, sectionLabel: "", done: done)
        let id = activity.id
        let policy: ActivityUIDismissalPolicy = done ? .default : .immediate
        Task.detached {
            if let a = Activity<NitnemActivityAttributes>.activities.first(where: { $0.id == id }) {
                await a.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: policy)
            }
        }
        self.activity = nil
        lastPercent = nil
        lastUpdate = nil
        #endif
    }

    /// End any activity left over from a previous launch (a crash/kill mid-read). Call at startup.
    static func sweepOrphaned() {
        #if canImport(ActivityKit)
        Task.detached {
            for activity in Activity<NitnemActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
