import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - Pure planning (no UserNotifications import → unit-testable on any platform)

/// One local reminder to schedule. `date` is a wall-clock fire time; `id` is stable per band+day
/// so re-planning replaces, never duplicates. Title/body carry no Gurmukhi, no counts, no emoji —
/// a quiet nudge, never a scoreboard (brand book §7, "Reminders").
struct PlannedReminder: Equatable, Sendable {
    let id: String
    let band: NitnemBand
    let date: Date
    let title: String
    let body: String
}

/// The reminder domain: which bands can nudge, their default times, and the pure schedule math.
/// A band maps to one daily set (morning / Rehras / Sohila); `.day` is folded into `.amritVela`
/// because it is the same morning set, so exactly three bands can remind.
enum NitnemReminders {
    /// The bands the user can enable a reminder for.
    static let bands: [NitnemBand] = [.amritVela, .evening, .night]
    /// How many days ahead we materialise (dated, non-repeating so a done band goes quiet):
    /// 3 bands × 14 = 42 requests, well under the 64-per-app iOS cap.
    static let horizonDays = 14
    static let idPrefix = "nitnem."

    /// Default reminder minute-of-day per band (amrit vela 06:00, Rehras 18:00, Sohila 21:30).
    static func defaultMinute(_ band: NitnemBand) -> Int {
        switch band {
        case .amritVela, .day: return 6 * 60
        case .evening: return 18 * 60
        case .night: return 21 * 60 + 30
        }
    }

    /// Lock-screen copy — the band name and one calm line. No scripture, no numbers, no emoji.
    static func copy(_ band: NitnemBand) -> (title: String, body: String) {
        switch band {
        case .amritVela, .day: return ("Amrit Vela", "The morning banis, when you are ready.")
        case .evening: return ("Rehras Sahib", "As the day draws to a close.")
        case .night: return ("Kirtan Sohila", "A quiet moment before rest.")
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func id(band: NitnemBand, dayKey: String) -> String { "\(idPrefix)\(band.rawValue).\(dayKey)" }

    /// The next `horizonDays` fire dates for each enabled band, strictly in the future. Today's
    /// occurrence is dropped when it has already passed or the band's set is done for today, so a
    /// reader who has finished is never nudged. Deterministic given `now`, `enabled` and a calendar.
    static func plan(now: Date,
                     enabled: [NitnemBand: Int],
                     completedToday: Set<NitnemBand> = [],
                     calendar: Calendar = .current) -> [PlannedReminder] {
        var cal = calendar
        cal.timeZone = calendar.timeZone
        var out: [PlannedReminder] = []
        for band in bands {
            guard let minute = enabled[band] else { continue }
            let (title, body) = copy(band)
            let midnight = cal.startOfDay(for: now)
            var scheduled = 0
            var offset = 0
            // walk forward day by day until we have `horizonDays` future fire times for this band
            while scheduled < horizonDays, offset < horizonDays + 2 {
                defer { offset += 1 }
                guard let day = cal.date(byAdding: .day, value: offset, to: midnight),
                      let fire = cal.date(byAdding: .minute, value: minute, to: day) else { continue }
                if fire <= now { continue }                                   // already passed
                if offset == 0 && completedToday.contains(band) { continue }  // done today
                let dayKey = dayFormatter.string(from: fire)
                out.append(PlannedReminder(id: id(band: band, dayKey: dayKey), band: band, date: fire, title: title, body: body))
                scheduled += 1
            }
        }
        return out
    }
}

// MARK: - Scheduling seam (a protocol so tests use a fake, never the real center)

/// The slice of `UNUserNotificationCenter` the controller needs, behind a protocol so a fake can
/// stand in under `SGGS_UITEST` and in unit tests — the real center is never touched in a test.
protocol NotificationScheduling: Sendable {
    func authorizationStatus() async -> NitnemAuthStatus
    /// Returns the granted decision; never throws (a denial is a value, not an error).
    func requestAuthorization() async -> Bool
    func pendingIds(withPrefix prefix: String) async -> [String]
    func add(_ reminders: [PlannedReminder]) async
    func remove(ids: [String]) async
    func removeAll(withPrefix prefix: String) async
}

enum NitnemAuthStatus: Sendable { case notDetermined, denied, authorized, provisional }

#if canImport(UserNotifications)
/// The real scheduler. Non-repeating calendar triggers; the tap deep-links to `sggs://nitnem`
/// through `userInfo` (routed by `NotificationRouter`). No badge, no sound beyond the default.
struct SystemNotificationScheduler: NotificationScheduling {
    private var center: UNUserNotificationCenter { .current() }   // the shared singleton; not stored (non-Sendable)

    func authorizationStatus() async -> NitnemAuthStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .ephemeral: return .authorized
        case .provisional: return .provisional
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    func requestAuthorization() async -> Bool {
        // Provisional (quiet, no prompt) delivery: the reminder lands silently in the list, the
        // reader is never interrupted by a permission alert. They can promote it in Settings.
        (try? await center.requestAuthorization(options: [.alert, .sound, .provisional])) ?? false
    }

    func pendingIds(withPrefix prefix: String) async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
    }

    func add(_ reminders: [PlannedReminder]) async {
        let cal = Calendar.current
        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.userInfo = ["url": "sggs://nitnem"]
            content.interruptionLevel = .passive        // never a hard interruption while reading
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: r.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: r.id, content: content, trigger: trigger))
        }
    }

    func remove(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func removeAll(withPrefix prefix: String) async {
        let ids = await pendingIds(withPrefix: prefix)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
#endif

/// An in-memory scheduler used under `SGGS_UITEST` and by unit tests. It always grants
/// authorization (no system prompt in a test) and records the pending set so tests can inspect it.
actor FakeNotificationScheduler: NotificationScheduling {
    private(set) var pending: [PlannedReminder] = []
    private let grants: Bool
    var status: NitnemAuthStatus
    init(grants: Bool = true, status: NitnemAuthStatus = .authorized) { self.grants = grants; self.status = status }

    func authorizationStatus() async -> NitnemAuthStatus { status }
    func requestAuthorization() async -> Bool { if grants { status = .authorized }; return grants }
    func pendingIds(withPrefix prefix: String) async -> [String] { pending.map(\.id).filter { $0.hasPrefix(prefix) } }
    func add(_ reminders: [PlannedReminder]) async { pending.append(contentsOf: reminders) }
    func remove(ids: [String]) async { let s = Set(ids); pending.removeAll { s.contains($0.id) } }
    func removeAll(withPrefix prefix: String) async { pending.removeAll { $0.id.hasPrefix(prefix) } }
    func snapshot() -> [PlannedReminder] { pending }
}
