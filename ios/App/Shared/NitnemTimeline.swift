import Foundation
import WidgetKit

/// The Nitnem widget's timeline model + math — in `Shared` (app + extension) so it is
/// unit-testable without WidgetKit. Each entry resolves at ITS OWN date; completion is keyed by
/// the 03:00 Nitnem day, so state flips correctly at the day rollover.
struct NitnemEntry: TimelineEntry {
    let date: Date
    let band: NitnemBand
    let banis: [NitnemWidgetData.Bani]
    let completed: [String: Bool]
    let fractions: [String: Double]
    let hasNitnem: Bool

    /// The next unread bani of this band, or nil when the set is complete.
    var next: NitnemWidgetData.Bani? { banis.first { completed[$0.id] != true } }
    var doneCount: Int { banis.filter { completed[$0.id] == true }.count }
    var total: Int { banis.count }
    var allDone: Bool { total > 0 && doneCount == total }
    /// Set completion 0…1 (whole banis), for the accessory gauge.
    var setFraction: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }
}

enum NitnemTimeline {
    static func entry(at date: Date, snapshot: WidgetSnapshot?, progress: NitnemProgressReading) -> NitnemEntry {
        let band = NitnemBand.band(at: date)
        let banis = snapshot?.nitnem?.sets[band.setKey] ?? []
        var completed: [String: Bool] = [:]
        var fractions: [String: Double] = [:]
        for b in banis {
            completed[b.id] = progress.isCompleted(b.id, on: date)
            fractions[b.id] = progress.fraction(b.id, total: b.nLines, on: date)
        }
        return NitnemEntry(date: date, band: band, banis: banis,
                           completed: completed, fractions: fractions,
                           hasNitnem: snapshot?.nitnem != nil)
    }

    /// Entry dates over the next 48 h: now, plus each band boundary (03:00, 09:00, 17:00, 21:00)
    /// wall-clock and DST-safe (03:00 is also the Nitnem-day rollover, so no separate midnight).
    static func dates(from now: Date, tz: TimeZone = .current) -> [Date] {
        var out: Set<Date> = [now]
        let boundaries = [180, 540, 1020, 1260]
        for dayOffset in 0...2 {
            for m in boundaries {
                if let d = PaharFormat.date(minuteOfDay: m, on: now, dayOffset: dayOffset, tz: tz),
                   d > now, d < now.addingTimeInterval(48 * 3600) {
                    out.insert(d)
                }
            }
        }
        return out.sorted()
    }
}
