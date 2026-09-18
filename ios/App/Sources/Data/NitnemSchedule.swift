import Foundation
import GurbaniSearchKit

// `NitnemBand` (the enum, titles, band-from-clock, glow, set key) lives in `Shared/NitnemBand.swift`
// so the widget can use it. The category-based ordering below is app-only (it needs BaniCategory).

extension NitnemBand {
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
    /// Band for a wall-clock time (delegates to the widget-safe `NitnemBand`).
    static func band(minutesSinceMidnight m: Int) -> NitnemBand { NitnemBand.band(minutesSinceMidnight: m) }
    static func band(at date: Date, calendar: Calendar = .current) -> NitnemBand { NitnemBand.band(at: date, calendar: calendar) }

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
