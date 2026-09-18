import Foundation

/// The single source of "now" and "which day" for everything Nitnem — the home, the reader's
/// next-bani logic, the widgets and the reminders all read it, so they can never disagree.
///
/// A **Nitnem day runs 03:00 → 03:00**: Kirtan Sohila read at 22:00 is still "done" at 00:30,
/// and the night band (21:00–03:00) never splits across two calendar days. The day key is the
/// local calendar day of `now − 3h`. Only readings between midnight and 03:00 differ from the
/// plain calendar day, and they now count for the evening they belong to.
enum NitnemClock {
    /// The Nitnem-day rollover, in seconds after local midnight (03:00).
    static let rolloverSeconds: TimeInterval = 3 * 3600

    /// Live now, or the pinned time when `SGGS_CLOCK_NOW=<minutes-since-local-midnight>` is set
    /// (XCUITests). A single definition so tests pin every surface at once.
    static func now(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Date {
        if let s = env["SGGS_CLOCK_NOW"], let m = Int(s) {
            return Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(m * 60))
        }
        return Date()
    }

    /// The Nitnem-day key (`YYYY-MM-DD`) for a date, shifted so the day rolls at 03:00.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let shifted = date.addingTimeInterval(-rolloverSeconds)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The Nitnem day immediately before the one containing `date`.
    static func previousDayKey(_ date: Date, calendar: Calendar = .current) -> String {
        dayKey(date.addingTimeInterval(-86400), calendar: calendar)
    }
}
