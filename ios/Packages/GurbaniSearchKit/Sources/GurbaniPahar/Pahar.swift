import Foundation

/// Pure pahar computation — the byte-parity Swift port of `frontend/src/scripts/pahar.js`,
/// pinned by contract/golden_pahar.ndjson (2,183 vectors generated from the real JS under
/// TZ=UTC; the 47-assertion test-pahar.mjs gate as a cross-language contract).
///
/// Convention (fixed-clock): pahar 1 = 06:00–09:00 … pahar 8 = 03:00–06:00, eight 3-hour
/// watches anchored at 6 AM. Pahar 7 (00:00–03:00) deliberately has no raags — that absence
/// is displayed content, not a gap. All arithmetic is integer minutes-since-local-midnight
/// with half-open intervals [start, end) — no floats at boundaries. DST days are wall-clock
/// by design (a pahar is what the local clock says it is).
///
/// Solar mode: sunrise/sunset via the NOAA solar-position equations (constants ported
/// VERBATIM from pahar.js — never re-derived). Traditionally pahars were solar: 4 equal
/// watches of daylight (sunrise→sunset) and 4 of night, stretching with the season.
///
/// Dependency-free on purpose: no Date/Calendar/TimeZone inside the math (callers convert
/// a wall-clock time to minutes-since-midnight and a calendar date to (y, m, d)) — this is
/// what lets widgets/watch link it without CSQLite, and what keeps the contract exact.
public enum Pahar {

    public struct Window: Sendable, Equatable {
        public let start: Int   // minutes since local midnight, inclusive
        public let end: Int     // exclusive; may wrap past midnight
        public init(start: Int, end: Int) { self.start = start; self.end = end }
    }

    public struct SunTimes: Sendable, Equatable {
        public let sunrise: Int?   // minutes since local midnight; nil when polar
        public let sunset: Int?
        public let polar: Bool     // sun never rises/sets — callers fall back to fixed mode
        public init(sunrise: Int?, sunset: Int?, polar: Bool) {
            self.sunrise = sunrise; self.sunset = sunset; self.polar = polar
        }
    }

    public struct Boundary: Sendable, Equatable {
        public let nextPahar: Int
        public let minutes: Int
        public init(nextPahar: Int, minutes: Int) { self.nextPahar = nextPahar; self.minutes = minutes }
    }

    private static let ord = ["", "1st", "2nd", "3rd", "4th"]

    /// Fixed-clock pahar (1–8) from minutes-since-midnight (any integer; wraps like the JS).
    public static func paharFromMinutes(_ m: Int) -> Int {
        ((((m - 360) % 1440) + 1440) % 1440) / 180 + 1
    }

    /// Fixed-clock window of a pahar: [startMin, endMin) since midnight (end may wrap).
    public static func window(_ p: Int) -> Window {
        let start = (360 + (p - 1) * 180) % 1440
        return Window(start: start, end: (start + 180) % 1440)
    }

    /// "1st pahar of day" … "4th pahar of night".
    public static func label(_ p: Int) -> String {
        let q = min(max(p, 1), 8)           // public API: never trap on an out-of-range pahar
        return q <= 4 ? "\(ord[q]) pahar of day" : "\(ord[q - 4]) pahar of night"
    }

    /// '15:00' → '3 PM' (whole hours stay terse; minutes kept when present).
    public static func fmt12(_ hhmm: String) -> String {
        if hhmm.isEmpty { return "" }
        let parts = hhmm.split(separator: ":", omittingEmptySubsequences: false)
        let h = Int(parts.first.map(String.init) ?? "") ?? 0
        let m = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        let h24 = ((h % 24) + 24) % 24
        let ap = h24 < 12 ? "AM" : "PM"
        let h12v = h24 % 12
        let h12 = h12v == 0 ? 12 : h12v
        return m != 0 ? "\(h12):\(String(format: "%02d", m)) \(ap)" : "\(h12) \(ap)"
    }

    /// Fixed-clock range of a pahar as e.g. "3–6 PM" / "9 PM–12 AM".
    public static func range(_ p: Int) -> String {
        let w = window(p)
        func f(_ min: Int) -> String { fmt12("\(min / 60):\(String(format: "%02d", min % 60))") }
        let a = f(w.start), b = f(w.end)
        let aParts = a.split(separator: " "), bParts = b.split(separator: " ")
        let (ah, aap) = (String(aParts[0]), String(aParts[1]))
        let (bh, bap) = (String(bParts[0]), String(bParts[1]))
        return aap == bap ? "\(ah)–\(bh) \(bap)" : "\(a)–\(b)"
    }

    /// Ordinal day-of-year (Jan 1 = 1), proleptic Gregorian. Matches the JS
    /// `floor((date - new Date(y,0,0)) / 86400000)` computed under TZ=UTC (no DST wobble).
    static func dayOfYear(year: Int, month: Int, day: Int) -> Int {
        let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let m = min(max(month, 1), 12)      // defensive: a non-Gregorian calendar can yield 13
        return cum[m - 1] + day + ((leap && m > 2) ? 1 : 0)
    }

    /// NOAA sunrise/sunset (minutes since local midnight) for a calendar date.
    /// `tzOffsetMin` follows JS `Date.getTimezoneOffset()` convention (UTC+5:30 → -330).
    /// month is 1-based. Constants are ported verbatim from pahar.js.
    public static func sunTimes(year: Int, month: Int, day: Int,
                                lat: Double, lon: Double, tzOffsetMin: Int) -> SunTimes {
        let rad = Double.pi / 180
        let doy = dayOfYear(year: year, month: month, day: day)
        let g = (2 * Double.pi / 365) * (Double(doy) - 1)
        let eqtime = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g)
            - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        let decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g)
            - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g)
            - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
        let cosHa = (cos(90.833 * rad) / (cos(lat * rad) * cos(decl))) - tan(lat * rad) * tan(decl)
        if cosHa < -1 || cosHa > 1 { return SunTimes(sunrise: nil, sunset: nil, polar: true) }
        let haDeg = acos(cosHa) / rad
        func wrap(_ m: Double) -> Double { (m.truncatingRemainder(dividingBy: 1440) + 1440).truncatingRemainder(dividingBy: 1440) }
        let tz = Double(tzOffsetMin)
        let sunriseUtc = 720 - 4 * (lon + haDeg) - eqtime
        let sunsetUtc = 720 - 4 * (lon - haDeg) - eqtime
        return SunTimes(
            sunrise: Int(wrap(sunriseUtc - tz).rounded(.toNearestOrAwayFromZero)),
            sunset: Int(wrap(sunsetUtc - tz).rounded(.toNearestOrAwayFromZero)),
            polar: false)
    }

    /// Solar pahar (1–8): 4 equal watches sunrise→sunset, 4 sunset→next sunrise.
    /// Half-open; sunrise itself is pahar 1, sunset itself is pahar 5.
    public static func paharSolar(_ m: Int, sunrise: Int, sunset: Int) -> Int {
        let dayLen = (((sunset - sunrise) % 1440) + 1440) % 1440
        let nightLen = 1440 - dayLen
        let sinceSunrise = (((m - sunrise) % 1440) + 1440) % 1440
        if sinceSunrise < dayLen {
            return 1 + min(3, sinceSunrise * 4 / dayLen)     // non-negative ints: / == floor
        }
        let sinceSunset = sinceSunrise - dayLen
        return 5 + min(3, sinceSunset * 4 / nightLen)
    }

    /// Solar window [start, end) in minutes-since-midnight for pahar p.
    public static func solarWindow(_ p: Int, sunrise: Int, sunset: Int) -> Window {
        func wrap(_ m: Int) -> Int { ((m % 1440) + 1440) % 1440 }
        let dayLen = wrap(sunset - sunrise)
        let nightLen = 1440 - dayLen
        // JS Math.round is half-up on positives — .toNearestOrAwayFromZero matches here
        func r(_ x: Double) -> Int { Int(x.rounded(.toNearestOrAwayFromZero)) }
        if p <= 4 {
            return Window(start: wrap(sunrise + r(Double((p - 1) * dayLen) / 4)),
                          end: wrap(sunrise + r(Double(p * dayLen) / 4)))
        }
        return Window(start: wrap(sunset + r(Double((p - 5) * nightLen) / 4)),
                      end: wrap(sunset + r(Double((p - 4) * nightLen) / 4)))
    }

    /// Minutes until the next pahar boundary (and which pahar starts there).
    /// mode: "fixed" | "solar" (sunrise/sunset required for solar).
    public static func nextBoundary(_ m: Int, mode: String, sunrise: Int = 0, sunset: Int = 0) -> Boundary {
        let cur = mode == "solar" ? paharSolar(m, sunrise: sunrise, sunset: sunset) : paharFromMinutes(m)
        let next = cur % 8 + 1
        let win = mode == "solar" ? solarWindow(next, sunrise: sunrise, sunset: sunset) : window(next)
        let wait = (((win.start - m) % 1440) + 1440) % 1440
        return Boundary(nextPahar: next, minutes: wait == 0 ? 1440 : wait)
    }
}
