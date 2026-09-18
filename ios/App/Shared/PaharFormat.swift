import Foundation
import GurbaniPahar

/// Locale-aware DISPLAY formatting for the Raag Clock (app + widgets). This is the one place
/// a minute-of-day meets a real `Date`, `Calendar`, `TimeZone` and `Locale`, so the reader
/// sees their own wall clock ("2:51 PM" in New York, "14:51" in Berlin) while the pahar
/// arithmetic in `Pahar` stays the dependency-free, byte-parity port of pahar.js.
///
/// `Pahar.fmt12` / `Pahar.range` are NOT touched — they are pinned by the golden vectors.
/// Everything here is presentation only.
enum PaharFormat {

    // MARK: minute-of-day ↔ Date

    /// Minutes since local midnight for a date in a time zone (0…1439).
    static func minutesOfDay(_ date: Date, tz: TimeZone = .current) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// A wall-clock minute on the calendar day of `day`, resolved through `Calendar` so a DST
    /// transition renders the real clock (never `day + minutes`). `dayOffset` = +1 for "tomorrow"
    /// (a window that wraps past midnight). Returns nil only if the calendar cannot place the
    /// components (a non-existent minute inside a spring-forward gap resolves forward).
    static func date(minuteOfDay m: Int, on day: Date, dayOffset: Int = 0, tz: TimeZone = .current) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let wrapped = ((m % 1440) + 1440) % 1440
        guard let base = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: day)) else { return nil }
        var c = cal.dateComponents([.year, .month, .day], from: base)
        c.hour = wrapped / 60
        c.minute = wrapped % 60
        c.second = 0
        return cal.date(from: c)
    }

    /// The next whole-minute boundary after `date` — `TimelineView(.periodic(from:by:))` starts
    /// here so the digits flip exactly when the status-bar clock does.
    static func nextMinuteBoundary(after date: Date = Date()) -> Date {
        let t = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (t / 60).rounded(.down) * 60 + 60)
    }

    /// pahar.js `getTimezoneOffset()` sign convention (UTC+5:30 → −330). Centralised so the
    /// solar math is fed the same sign from the screen, the widget and the tests.
    static func jsTZOffsetMinutes(for date: Date, tz: TimeZone = .current) -> Int {
        -tz.secondsFromGMT(for: date) / 60
    }

    /// NOAA sunrise/sunset for the calendar day containing `day` at (lat, lon), in that zone.
    static func sunTimes(on day: Date, lat: Double, lon: Double, tz: TimeZone = .current) -> Pahar.SunTimes {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: day)
        return Pahar.sunTimes(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1,
                              lat: lat, lon: lon, tzOffsetMin: jsTZOffsetMinutes(for: day, tz: tz))
    }

    /// Usable solar times (non-polar, both present) or nil → callers fall back to the fixed clock.
    static func usableSun(_ s: Pahar.SunTimes?) -> (sunrise: Int, sunset: Int)? {
        guard let s, !s.polar, let sr = s.sunrise, let ss = s.sunset, sr != ss else { return nil }
        return (sr, ss)
    }

    // MARK: locale

    /// True when the reader's clock is 12-hour (the device "24-Hour Time" switch is honoured
    /// through `Locale.current`).
    static func hourCycleIs12(_ locale: Locale = .current) -> Bool {
        switch locale.hourCycle {
        case .oneToTwelve, .zeroToEleven: return true
        default: return false
        }
    }

    /// Foundation separates the meridiem with a NARROW NO-BREAK SPACE (U+202F); a plain space
    /// reads identically, copies cleanly and keeps the pinned UI-test strings stable.
    private static func plainSpaces(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// "2:51 PM" / "14:51" — the reader's own clock.
    static func time(_ date: Date, locale: Locale = .current, tz: TimeZone = .current) -> String {
        plainSpaces(date.formatted(Date.FormatStyle(locale: locale, timeZone: tz)
            .hour(.defaultDigits(amPM: .abbreviated)).minute()))
    }

    /// Hour-only, for windows that start and end on the hour: "3 PM" / "15:00".
    private static func hourOnly(_ date: Date, locale: Locale, tz: TimeZone) -> String {
        if hourCycleIs12(locale) {
            return plainSpaces(date.formatted(Date.FormatStyle(locale: locale, timeZone: tz)
                .hour(.defaultDigits(amPM: .abbreviated))))
        }
        return time(date, locale: locale, tz: tz)
    }

    /// The meridiem suffix (" PM") of a formatted time, if the locale shows one.
    private static func meridiemSuffix(_ s: String, locale: Locale) -> String? {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        for sym in [cal.amSymbol, cal.pmSymbol] where !sym.isEmpty {
            for sep in [" ", ""] where s.hasSuffix(sep + sym) { return sep + sym }
        }
        return nil
    }

    /// A pahar window on the reader's clock, on the calendar day of `day`:
    /// fixed "3–6 PM" / "9 PM–12 AM" / "15:00–18:00", solar "5:51–8:50 AM". A shared meridiem
    /// is written once (like `Pahar.range`), a differing one on both ends. Wrap-safe.
    static func window(_ w: Pahar.Window, on day: Date, locale: Locale = .current, tz: TimeZone = .current) -> String {
        guard let start = date(minuteOfDay: w.start, on: day, tz: tz),
              let end = date(minuteOfDay: w.end, on: day, dayOffset: w.end <= w.start ? 1 : 0, tz: tz)
        else { return Pahar.range(1) }   // unreachable in practice; never crash a clock
        let onTheHour = w.start % 60 == 0 && w.end % 60 == 0
        var a = onTheHour ? hourOnly(start, locale: locale, tz: tz) : time(start, locale: locale, tz: tz)
        let b = onTheHour ? hourOnly(end, locale: locale, tz: tz) : time(end, locale: locale, tz: tz)
        if hourCycleIs12(locale),
           let sa = meridiemSuffix(a, locale: locale), let sb = meridiemSuffix(b, locale: locale), sa == sb {
            a = String(a.dropLast(sa.count))
        }
        return "\(a)–\(b)"
    }

    /// "in 57 min" · "in 2 h 57 min" · "now".
    static func countdown(minutes: Int) -> String {
        if minutes <= 0 { return "now" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "in \(m) min" }
        if m == 0 { return "in \(h) h" }
        return "in \(h) h \(m) min"
    }

    /// Spoken form for VoiceOver: "2 hours 57 minutes".
    static func countdownSpoken(minutes: Int) -> String {
        if minutes <= 0 { return "now" }
        let h = minutes / 60, m = minutes % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        return "in " + parts.joined(separator: " ")
    }

    /// The four cardinal numerals of the 24-hour dial (minute-of-day → label), in the reader's
    /// hour cycle. 12-h faces say "6 AM · 12 PM · 6 PM · 12 AM"; 24-h faces "06 · 12 · 18 · 00".
    static func dialNumerals(locale: Locale = .current) -> [(minute: Int, label: String)] {
        if hourCycleIs12(locale) {
            return [(0, "12 AM"), (360, "6 AM"), (720, "12 PM"), (1080, "6 PM")]
        }
        return [(0, "00"), (360, "06"), (720, "12"), (1080, "18")]
    }
}
