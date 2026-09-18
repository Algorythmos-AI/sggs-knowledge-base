import SwiftUI

/// The time-of-day band, widget-safe (in `Shared`, no GurbaniSearchKit) so the app, the widget
/// and reminders all agree. Category-based ordering (`order`, `focus`) is an app-side extension.
enum NitnemBand: String, Sendable, CaseIterable {
    case amritVela   // 03:00–09:00
    case day         // 09:00–17:00
    case evening     // 17:00–21:00
    case night       // 21:00–03:00

    var title: String {
        switch self {
        case .amritVela: return "Amrit Vela"
        case .day: return "Morning banis"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var caption: String {
        switch self {
        case .amritVela: return "The five morning banis."
        case .day: return "The five morning banis, whenever the day allows."
        case .evening: return "Rehras Sahib, as the day closes."
        case .night: return "Kirtan Sohila before rest."
        }
    }

    /// Which daily set to surface: the morning banis, Rehras, or Sohila.
    var setKey: String {
        switch self {
        case .amritVela, .day: return "morning"
        case .evening: return "evening"
        case .night: return "night"
        }
    }

    /// Where the hero's gold glow sits for this band (colour never changes, only the corner).
    var glowCenter: UnitPoint {
        switch self {
        case .amritVela: return .bottomLeading
        case .day: return .top
        case .evening: return .topTrailing
        case .night: return .topLeading
        }
    }

    /// Band for a wall-clock time (minutes since local midnight). Half-open, wraps at midnight.
    static func band(minutesSinceMidnight m: Int) -> NitnemBand {
        let x = ((m % 1440) + 1440) % 1440
        switch x {
        case 180..<540: return .amritVela
        case 540..<1020: return .day
        case 1020..<1260: return .evening
        default: return .night
        }
    }

    static func band(at date: Date, calendar: Calendar = .current) -> NitnemBand {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return band(minutesSinceMidnight: (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    /// The next band-boundary minute-of-day at or after `m` (03:00, 09:00, 17:00, 21:00).
    static func nextBoundaryMinute(after m: Int) -> Int {
        let bounds = [180, 540, 1020, 1260, 180 + 1440]
        let x = ((m % 1440) + 1440) % 1440
        return bounds.first { $0 > x } ?? (180 + 1440)
    }
}
