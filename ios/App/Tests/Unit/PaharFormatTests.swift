import XCTest
import GurbaniPahar
@testable import SGGS

/// The display layer of the Raag Clock: the reader's own wall clock (12/24-h, locale), the
/// pahar windows on it, wrap-safe and DST-safe. `Pahar.*` is pinned separately by the golden
/// vectors; these tests pin the presentation that sits on top.
final class PaharFormatTests: XCTestCase {

    private let us = Locale(identifier: "en_US")
    private let gb = Locale(identifier: "en_GB")
    private let sydney = TimeZone(identifier: "Australia/Sydney")!
    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testHourCycle() {
        XCTAssertTrue(PaharFormat.hourCycleIs12(us))
        XCTAssertFalse(PaharFormat.hourCycleIs12(gb))
    }

    func testTimeFollowsLocale() {
        let d = date(2026, 9, 18, 14, 51, tz: utc)
        XCTAssertEqual(PaharFormat.time(d, locale: us, tz: utc), "2:51 PM")
        XCTAssertEqual(PaharFormat.time(d, locale: gb, tz: utc), "14:51")
        XCTAssertFalse(PaharFormat.time(d, locale: us, tz: utc).contains("\u{202F}"), "narrow spaces are normalised")
    }

    func testMinutesOfDayRespectsTimeZone() {
        let d = date(2026, 9, 18, 14, 51, tz: utc)
        XCTAssertEqual(PaharFormat.minutesOfDay(d, tz: utc), 14 * 60 + 51)
        XCTAssertEqual(PaharFormat.minutesOfDay(d, tz: sydney), 0 * 60 + 51)   // AEST = UTC+10 → 00:51 next day
    }

    func testFixedWindowsMatchThePinnedStrings() {
        let day = date(2026, 9, 18, 12, 0, tz: utc)
        // the load-bearing XCUITest string is "4th pahar of day  ·  3–6 PM" under en_US
        XCTAssertEqual(PaharFormat.window(Pahar.window(4), on: day, locale: us, tz: utc), "3–6 PM")
        XCTAssertEqual(PaharFormat.window(Pahar.window(1), on: day, locale: us, tz: utc), "6–9 AM")
        XCTAssertEqual(PaharFormat.window(Pahar.window(2), on: day, locale: us, tz: utc), "9 AM–12 PM")
        XCTAssertEqual(PaharFormat.window(Pahar.window(6), on: day, locale: us, tz: utc), "9 PM–12 AM")   // wraps midnight
        XCTAssertEqual(PaharFormat.window(Pahar.window(7), on: day, locale: us, tz: utc), "12–3 AM")
        XCTAssertEqual(PaharFormat.window(Pahar.window(4), on: day, locale: gb, tz: utc), "15:00–18:00")
        XCTAssertEqual(PaharFormat.window(Pahar.window(6), on: day, locale: gb, tz: utc), "21:00–00:00")
    }

    func testSolarWindowKeepsMinutes() {
        let day = date(2026, 9, 18, 12, 0, tz: utc)
        let w = Pahar.Window(start: 5 * 60 + 51, end: 8 * 60 + 50)
        XCTAssertEqual(PaharFormat.window(w, on: day, locale: us, tz: utc), "5:51–8:50 AM")
        XCTAssertEqual(PaharFormat.window(w, on: day, locale: gb, tz: utc), "05:51–08:50")
    }

    /// Sydney springs forward on 2026-10-04 at 02:00 → 03:00. A window that starts at 03:00
    /// (pahar 8) must still render 3 AM, not drift to 4 AM as `midnight + 180 min` would.
    func testDSTSpringForwardDayRendersWallClock() {
        let day = date(2026, 10, 4, 12, 0, tz: sydney)
        XCTAssertEqual(PaharFormat.window(Pahar.window(8), on: day, locale: us, tz: sydney), "3–6 AM")
        let start = PaharFormat.date(minuteOfDay: 180, on: day, tz: sydney)!
        XCTAssertEqual(PaharFormat.minutesOfDay(start, tz: sydney), 180)
    }

    /// Fall back (2026-04-05, 03:00 → 02:00 in Sydney): 2 AM exists twice; the window still
    /// says 12–3 AM and the resolved instant is the first 02:00-free minute the calendar picks.
    func testDSTFallBackDayRendersWallClock() {
        let day = date(2026, 4, 5, 12, 0, tz: sydney)
        XCTAssertEqual(PaharFormat.window(Pahar.window(7), on: day, locale: us, tz: sydney), "12–3 AM")
    }

    func testWrapToNextDay() {
        let day = date(2026, 9, 18, 23, 30, tz: utc)
        let end = PaharFormat.date(minuteOfDay: 0, on: day, dayOffset: 1, tz: utc)!
        XCTAssertEqual(end, date(2026, 9, 19, 0, 0, tz: utc))
        XCTAssertEqual(PaharFormat.minutesOfDay(date(2026, 9, 18, 23, 59, tz: utc), tz: utc), 1439)
    }

    func testCountdown() {
        XCTAssertEqual(PaharFormat.countdown(minutes: 0), "now")
        XCTAssertEqual(PaharFormat.countdown(minutes: 57), "in 57 min")
        XCTAssertEqual(PaharFormat.countdown(minutes: 120), "in 2 h")
        XCTAssertEqual(PaharFormat.countdown(minutes: 177), "in 2 h 57 min")
        XCTAssertEqual(PaharFormat.countdownSpoken(minutes: 61), "in 1 hour 1 minute")
    }

    func testNextMinuteBoundary() {
        let d = date(2026, 9, 18, 14, 51, tz: utc).addingTimeInterval(17)
        XCTAssertEqual(PaharFormat.nextMinuteBoundary(after: d), date(2026, 9, 18, 14, 52, tz: utc))
    }

    func testJSTimezoneOffsetSign() {
        let d = date(2026, 9, 18, 12, 0, tz: utc)
        XCTAssertEqual(PaharFormat.jsTZOffsetMinutes(for: d, tz: TimeZone(identifier: "Asia/Kolkata")!), -330)
        XCTAssertEqual(PaharFormat.jsTZOffsetMinutes(for: d, tz: utc), 0)
    }

    func testUsableSunRejectsPolarAndDegenerate() {
        XCTAssertNil(PaharFormat.usableSun(nil))
        XCTAssertNil(PaharFormat.usableSun(Pahar.SunTimes(sunrise: nil, sunset: nil, polar: true)))
        XCTAssertNil(PaharFormat.usableSun(Pahar.SunTimes(sunrise: 360, sunset: 360, polar: false)))
        XCTAssertNotNil(PaharFormat.usableSun(Pahar.SunTimes(sunrise: 351, sunset: 1067, polar: false)))
        // Amritsar in September: sunrise ≈ 6 AM, sunset ≈ 6:30 PM local
        let s = PaharFormat.sunTimes(on: date(2026, 9, 18, 12, 0, tz: TimeZone(identifier: "Asia/Kolkata")!),
                                     lat: 31.63, lon: 74.87, tz: TimeZone(identifier: "Asia/Kolkata")!)
        XCTAssertFalse(s.polar)
        XCTAssertEqual(s.sunrise! / 60, 6)
        XCTAssertEqual(s.sunset! / 60, 18)
        // Longyearbyen in December: polar night → fixed fallback
        let p = PaharFormat.sunTimes(on: date(2026, 12, 21, 12, 0, tz: utc), lat: 78.22, lon: 15.63, tz: utc)
        XCTAssertTrue(p.polar)
    }

    func testWeekdayDayComplication() {
        let d = date(2026, 9, 19, 12, 0, tz: utc)             // a Saturday
        let usv = PaharFormat.weekdayDay(d, locale: us, tz: utc)
        XCTAssertEqual(usv.weekday, "SAT"); XCTAssertEqual(usv.day, "19")
        XCTAssertEqual(PaharFormat.weekdayDay(d, locale: gb, tz: utc).weekday, "SAT")
        let de = PaharFormat.weekdayDay(d, locale: Locale(identifier: "de_DE"), tz: utc)
        XCTAssertEqual(de.weekday, "SA", "trailing abbreviation dot is trimmed")
        // the calendar day follows the reader's zone: 20:00 UTC Saturday is already Sunday in Sydney
        XCTAssertEqual(PaharFormat.weekdayDay(date(2026, 9, 19, 20, 0, tz: utc), locale: us, tz: sydney).weekday, "SUN")
    }

    func testDialNumerals() {
        XCTAssertEqual(PaharFormat.dialNumerals(locale: us).map(\.label), ["12 AM", "6 AM", "12 PM", "6 PM"])
        XCTAssertEqual(PaharFormat.dialNumerals(locale: gb).map(\.label), ["00", "06", "12", "18"])
    }

    // MARK: dial geometry

    func testDialAnglesNoonTopMidnightBottom() {
        XCTAssertEqual(DialMetrics.angle(720).degrees, 270, accuracy: 0.001)   // noon → top
        XCTAssertEqual(DialMetrics.angle(0).degrees, 90, accuracy: 0.001)      // midnight → bottom
        let m = DialMetrics(size: 300, style: .full)
        XCTAssertGreaterThan(m.hollowWidth, 100)
        XCTAssertLessThan(m.numeralRadius + 6, 150, "numerals must not clip the canvas")
        // hit-test round trip for every 3-hour boundary
        for h in stride(from: 0, to: 24, by: 3) {
            let pt = m.point(minute: Double(h * 60) + 0.5, radius: (m.inner + m.outer) / 2)
            XCTAssertEqual(m.minute(at: pt)!, h * 60, accuracy: 1)
        }
        XCTAssertNil(m.minute(at: m.center), "the hollow is not a tap target")
    }

    func testDialModelsCoverTheDay() {
        let f = PaharDialModel.fixed(current: 4, minutesNow: 1000)
        XCTAssertEqual(f.windows.count, 8)
        XCTAssertEqual(f.windows.reduce(0) { $0 + ((($1.end - $1.start) % 1440) + 1440) % 1440 }, 1440)
        let s = PaharDialModel.solar(sunrise: 351, sunset: 1067, current: 1, minutesNow: 400)
        XCTAssertEqual(s.windows.reduce(0) { $0 + ((($1.end - $1.start) % 1440) + 1440) % 1440 }, 1440)
        XCTAssertEqual(s.sunrise, 351)
    }
}
