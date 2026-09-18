import Foundation
import GurbaniSearchKit

/// Which part of the daily practice the clock points at. A pure function of the wall clock
/// (minutes since local midnight) — no location, no permission, testable to the minute.
/// The band only ORDERS the Nitnem home; nothing is ever hidden by it.
enum NitnemBand: String, Sendable, CaseIterable {
    case amritVela   // 03:00–09:00  the morning banis, read before dawn
    case day         // 09:00–17:00  still the morning banis, for those who read later
    case evening     // 17:00–21:00  Rehras Sahib
    case night       // 21:00–03:00  Kirtan Sohila

    var title: String {
        switch self {
        case .amritVela: return "Amrit Vela"
        case .day: return "Morning banis"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    /// One quiet line under the title (brand voice: reverent, plain, exact).
    var caption: String {
        switch self {
        case .amritVela: return "The five morning banis."
        case .day: return "The five morning banis, whenever the day allows."
        case .evening: return "Rehras Sahib, as the day closes."
        case .night: return "Kirtan Sohila before rest."
        }
    }

    /// The categories in the order the home screen lists them for this band.
    var order: [BaniCategory] {
        switch self {
        case .amritVela, .day: return [.nitnemMorning, .nitnemEvening, .nitnemNight]
        case .evening: return [.nitnemEvening, .nitnemNight, .nitnemMorning]
        case .night: return [.nitnemNight, .nitnemMorning, .nitnemEvening]
        }
    }

    /// The category the "Now" section and the Continue action work through.
    var focus: BaniCategory { order[0] }
}

enum NitnemSchedule {
    /// Band for a wall-clock time. Half-open intervals; wraps across midnight.
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

    /// The next bani to read in a band: the first of the focus category that is not yet
    /// complete today, else nil (everything done). `isComplete` is the caller's progress lookup.
    static func next(in band: NitnemBand, from banis: [BaniSummary],
                     isComplete: (BaniSummary) -> Bool) -> BaniSummary? {
        banis.filter { $0.category == band.focus && $0.isDefault }
            .sorted { $0.orderNo < $1.orderNo }
            .first { !isComplete($0) }
    }
}

/// User preferences that shape the Nitnem registry (keys are frozen: XCUITests wipe them).
enum NitnemPrefs {
    static let rehrasVariantKey = "sggs_rehras_variant"
    static let rehrasDefault = "sgpc"
    /// The variant to request for a key given the stored preference ("" = registry default).
    static func variant(for key: String, rehras: String) -> String {
        key == "rehras" ? (["sgpc", "taksal"].contains(rehras) ? rehras : rehrasDefault) : ""
    }
    /// Progress identity for a bani + variant (matches BaniSummary.id).
    static func progressId(key: String, variant: String) -> String {
        variant.isEmpty ? key : "\(key)/\(variant)"
    }
}

/// Non-SGGS text ships to the App Store only after a scholar review is attested in
/// ios/Resources/NITNEM-REVIEW.md (`REVIEWED: true`). Flip this in the same commit so the
/// in-app label stops saying "under review".
enum NitnemReview {
    static let extraTextReviewed = false
    static var extraLayerLabel: String {
        extraTextReviewed
            ? "Sri Dasam Granth / Ardaas text via ShabadOS — a separate layer, not part of Sri Guru Granth Sahib Ji."
            : "Sri Dasam Granth / Ardaas text via ShabadOS — a separate layer, not part of Sri Guru Granth Sahib Ji. Under scholarly review."
    }
}
