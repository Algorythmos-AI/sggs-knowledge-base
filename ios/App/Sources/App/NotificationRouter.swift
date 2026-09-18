import Foundation
import SwiftUI
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Reads the reminder preferences and keeps the pending local notifications in step with them.
/// All scheduling goes through a `NotificationScheduling` seam so tests never touch the real
/// center. Rescheduling is idempotent: it always clears the `nitnem.` prefix and re-adds the plan.
@MainActor
final class NitnemReminderController: ObservableObject {
    private let scheduler: NotificationScheduling

    static func prefKey(_ band: NitnemBand) -> String { "sggs_reminder_\(band.rawValue)" }
    static func minuteKey(_ band: NitnemBand) -> String { "sggs_reminder_\(band.rawValue)_min" }

    init(scheduler: NotificationScheduling) { self.scheduler = scheduler }

    /// Whether a band's reminder toggle is on.
    func isEnabled(_ band: NitnemBand, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Self.prefKey(band))
    }
    /// The reminder minute-of-day for a band (its default until the reader changes it).
    func minute(_ band: NitnemBand, defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: Self.minuteKey(band)) as? Int ?? NitnemReminders.defaultMinute(band)
    }

    /// The enabled bands mapped to their times — the input to the pure planner.
    private func enabledMap(defaults: UserDefaults) -> [NitnemBand: Int] {
        var out: [NitnemBand: Int] = [:]
        for band in NitnemReminders.bands where defaults.bool(forKey: Self.prefKey(band)) {
            out[band] = minute(band, defaults: defaults)
        }
        return out
    }

    /// Turn a band's reminder on (asking permission the first time) or off. Returns the value the
    /// toggle should settle on: a denied permission snaps it back to off with a Settings nudge.
    @discardableResult
    func setEnabled(_ on: Bool, band: NitnemBand, defaults: UserDefaults = .standard,
                    completedToday: Set<NitnemBand> = []) async -> Bool {
        if on {
            let status = await scheduler.authorizationStatus()
            if status == .denied {
                defaults.set(false, forKey: Self.prefKey(band))
                await reschedule(defaults: defaults, completedToday: completedToday)
                return false
            }
            if status == .notDetermined {
                let granted = await scheduler.requestAuthorization()
                if !granted {
                    defaults.set(false, forKey: Self.prefKey(band))
                    await reschedule(defaults: defaults, completedToday: completedToday)
                    return false
                }
            }
        }
        defaults.set(on, forKey: Self.prefKey(band))
        await reschedule(defaults: defaults, completedToday: completedToday)
        return on
    }

    /// True when the OS has denied notifications for the app (so the UI can show a Settings link).
    func authStatusIsDenied() async -> Bool { await scheduler.authorizationStatus() == .denied }

    /// Rewrite the pending set from the current preferences. Cheap and safe to call on foreground,
    /// on a time change, and after a bani is marked read.
    func reschedule(defaults: UserDefaults = .standard, now: Date = NitnemClock.now(),
                    completedToday: Set<NitnemBand> = []) async {
        await scheduler.removeAll(withPrefix: NitnemReminders.idPrefix)
        let enabled = enabledMap(defaults: defaults)
        guard !enabled.isEmpty else { return }
        let plan = NitnemReminders.plan(now: now, enabled: enabled, completedToday: completedToday)
        await scheduler.add(plan)
    }
}

#if canImport(UserNotifications)
/// Routes a tapped reminder to `sggs://nitnem` and keeps banners off the screen while the app is
/// foregrounded (no nudge over the page the reader is on). One shared instance, set as the
/// center's delegate at launch.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    let onOpen: @MainActor @Sendable (URL) -> Void
    init(onOpen: @escaping @MainActor @Sendable (URL) -> Void) { self.onOpen = onOpen }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []   // already in the app — never cover the reader with our own banner
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let raw = response.notification.request.content.userInfo["url"] as? String ?? "sggs://nitnem"
        guard let url = URL(string: raw) else { return }
        let open = onOpen
        await MainActor.run { open(url) }
    }
}
#endif
