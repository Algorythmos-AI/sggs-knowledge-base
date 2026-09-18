import Foundation
import GurbaniSearchKit

/// The reading journey: a quiet record of which daily practices were completed on each Nitnem
/// day, for the reader's own reflection. Pure — it takes a lookup of completed practices per
/// day key and lays out a month grid; nothing here is gamified.
///
/// A "practice" is one of the three daily readings, keyed by the focus category: the morning
/// banis, Rehras Sahib, Kirtan Sohila. A day can carry up to three.

struct JourneyDay: Equatable, Identifiable {
    let date: Date
    let dayKey: String
    let practices: Set<BaniCategory>   // subset of {nitnemMorning, nitnemEvening, nitnemNight}
    let inMonth: Bool                  // false for the leading/trailing days of adjacent months
    let isToday: Bool
    var id: String { dayKey + (inMonth ? "" : "·pad") }
    var dayNumber: Int { Calendar.current.component(.day, from: date) }
}

enum NitnemJourney {
    static let practices: [BaniCategory] = [.nitnemMorning, .nitnemEvening, .nitnemNight]

    /// The weeks of `month`, honouring `calendar.firstWeekday`, with adjacent-month padding.
    static func month(_ month: Date,
                      completed: (String) -> Set<BaniCategory>,
                      today: Date = NitnemClock.now(),
                      calendar: Calendar = .current) -> [JourneyDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        let todayKey = NitnemClock.dayKey(today, calendar: calendar)
        let monthComp = calendar.component(.month, from: month)
        var days: [JourneyDay] = []
        var cursor = firstWeek.start
        // six rows cover any month layout. A calendar cell maps to the Nitnem day NAMED after
        // that calendar date (the plain Y-M-D), not the 03:00-shifted key of its midnight.
        for _ in 0..<42 {
            let dc = calendar.dateComponents([.year, .month, .day], from: cursor)
            let key = String(format: "%04d-%02d-%02d", dc.year ?? 0, dc.month ?? 0, dc.day ?? 0)
            days.append(JourneyDay(
                date: cursor, dayKey: key, practices: completed(key),
                inMonth: calendar.component(.month, from: cursor) == monthComp,
                isToday: key == todayKey))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if cursor >= monthInterval.end && calendar.component(.weekday, from: cursor) == calendar.firstWeekday {
                break   // stop at the week boundary once we're past the month
            }
        }
        return days
    }

    /// Consecutive Nitnem days with at least one completed practice, ending today or (if today
    /// is not yet started) yesterday.
    static func consecutiveDays(endingAt today: Date = NitnemClock.now(),
                                completed: (String) -> Set<BaniCategory>,
                                calendar: Calendar = .current) -> Int {
        var day = today
        var n = 0
        if completed(NitnemClock.dayKey(day, calendar: calendar)).isEmpty {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        while !completed(NitnemClock.dayKey(day, calendar: calendar)).isEmpty {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }
}

extension BaniCategory {
    /// Short label for a completed practice ("Morning", "Rehras", "Sohila").
    var practiceLabel: String {
        switch self {
        case .nitnemMorning: return "Morning"
        case .nitnemEvening: return "Rehras"
        case .nitnemNight: return "Sohila"
        default: return sectionTitle
        }
    }
}
