import Foundation
import WidgetKit
import GurbaniPahar

/// The Raag Now widget's timeline model and math — in `Shared` (compiled into the app and
/// the extension) so the unit-test target can pin it without linking the widget bundle.

/// Everything one entry needs, resolved at ITS OWN date (never `Date.now`): the pahar,
/// the eight windows, the countdown target and the raags — so a timeline entry rendered at
/// 5:47 PM says 5:47 PM's truth even though it was computed hours earlier.
struct RaagNowEntry: TimelineEntry {
    let date: Date
    let pahar: Int
    let windows: [Pahar.Window]
    let sunrise: Int?
    let sunset: Int?
    let nextPahar: Int
    let boundaryDate: Date
    let raags: [String]            // roman
    let raagsGurmukhi: [String]    // verbatim Gurmukhi names, parallel to `raags` when present
    let beads: [Int: Int]
    let hasSnapshot: Bool
    let solar: Bool

    var minutesNow: Int { PaharFormat.minutesOfDay(date) }
    var model: PaharDialModel {
        PaharDialModel(windows: windows, current: pahar, minutesNow: minutesNow,
                       sunrise: sunrise, sunset: sunset, beads: beads)
    }
    var windowText: String { PaharFormat.window(windows[pahar - 1], on: date) }
}

/// The reader's clock configuration as the widget sees it: the App-Group suite first
/// (written the moment the app's picker/location changes), the snapshot as a fallback.
struct RaagClockConfig: Equatable {
    var solar: Bool
    var lat: Double?
    var lon: Double?

    static func current(snapshot: WidgetSnapshot?) -> RaagClockConfig {
        let mode = SharedDefaults.suite.string(forKey: SharedDefaults.clockModeKey) ?? snapshot?.clockMode ?? "fixed"
        let coords = SharedDefaults.solarCoords()
        return RaagClockConfig(solar: mode == "solar",
                               lat: coords?.lat ?? snapshot?.solarLat,
                               lon: coords?.lon ?? snapshot?.solarLon)
    }

    /// Usable sunrise/sunset for the calendar day of `date`, or nil → fixed clock
    /// (fixed mode, no coordinates, polar day/night).
    func sun(on date: Date, tz: TimeZone = .current) -> (sunrise: Int, sunset: Int)? {
        guard solar, let lat, let lon else { return nil }
        return PaharFormat.usableSun(PaharFormat.sunTimes(on: date, lat: lat, lon: lon, tz: tz))
    }
}

/// Pure timeline math, kept out of the provider so it is unit-testable without WidgetKit.
enum RaagNowTimeline {
    /// Hand freshness: the face is redrawn at least this often (WidgetKit repaints the
    /// digital time itself via `Text(date, style: .time)`; only the hand needs entries).
    static let cadenceMinutes = 15
    static let maxEntries = 120

    static func entry(at date: Date, config: RaagClockConfig, snapshot: WidgetSnapshot?,
                      tz: TimeZone = .current) -> RaagNowEntry {
        let m = PaharFormat.minutesOfDay(date, tz: tz)
        let sun = config.sun(on: date, tz: tz)
        let p = sun.map { Pahar.paharSolar(m, sunrise: $0.sunrise, sunset: $0.sunset) } ?? Pahar.paharFromMinutes(m)
        let windows = (1...8).map { q in
            sun.map { Pahar.solarWindow(q, sunrise: $0.sunrise, sunset: $0.sunset) } ?? Pahar.window(q)
        }
        let b = sun.map { Pahar.nextBoundary(m, mode: "solar", sunrise: $0.sunrise, sunset: $0.sunset) }
            ?? Pahar.nextBoundary(m, mode: "fixed")
        var beads: [Int: Int] = [:]
        for q in 1...8 { beads[q] = snapshot?.paharRaags[q]?.count ?? 0 }
        return RaagNowEntry(date: date, pahar: p, windows: windows, sunrise: sun?.sunrise, sunset: sun?.sunset,
                            nextPahar: b.nextPahar, boundaryDate: date.addingTimeInterval(TimeInterval(b.minutes * 60)),
                            raags: snapshot?.paharRaags[p] ?? [],
                            raagsGurmukhi: snapshot?.paharRaagsGurmukhi?[p] ?? [],
                            beads: beads, hasSnapshot: snapshot != nil, solar: sun != nil)
    }

    /// Entry dates for the next 24 h: now, every pahar boundary (wall-clock, DST-safe) and a
    /// 15-minute cadence — merged, sorted, de-duplicated, capped.
    static func dates(from now: Date, config: RaagClockConfig, tz: TimeZone = .current) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let horizon = now.addingTimeInterval(24 * 3600)
        var set: Set<Date> = [now]

        // 15-minute cadence on wall-clock quarter hours
        let quarter = TimeInterval(cadenceMinutes * 60)
        var t = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / quarter).rounded(.down) * quarter + quarter)
        while t < horizon { set.insert(t); t = t.addingTimeInterval(quarter) }

        // pahar boundaries: each is a WALL-CLOCK minute on a calendar day, resolved through
        // Calendar so a DST change never drifts the boundary by an hour
        for dayOffset in 0...1 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let sun = config.sun(on: day, tz: tz)
            for p in 1...8 {
                let w = sun.map { Pahar.solarWindow(p, sunrise: $0.sunrise, sunset: $0.sunset) } ?? Pahar.window(p)
                if let d = PaharFormat.date(minuteOfDay: w.start, on: day, tz: tz), d > now, d < horizon {
                    set.insert(d)
                }
            }
        }
        return Array(set.sorted().prefix(maxEntries))
    }
}

