import XCTest
@testable import SGGS

/// The hands are pure functions of a date: a real movement, not three independent pointers —
/// the hour hand advances with the minutes and the minute hand with the seconds.
final class ClockHandsTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let sydney = TimeZone(identifier: "Australia/Sydney")!

    private func date(_ h: Int, _ m: Int, _ s: Int, nanos: Int = 0, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: h, minute: m, second: s, nanosecond: nanos))!
    }
    private func deg(_ r: Double) -> Double { r * 180 / .pi }

    func testMidnightAllHandsAtTwelve() {
        let a = ClockHands.angles(for: date(0, 0, 0, tz: utc), tz: utc)
        XCTAssertEqual(deg(a.hour), 0, accuracy: 0.001)
        XCTAssertEqual(deg(a.minute), 0, accuracy: 0.001)
        XCTAssertEqual(deg(a.second), 0, accuracy: 0.001)
    }

    func testThreeOClockAndTwelveHourWrap() {
        XCTAssertEqual(deg(ClockHands.angles(for: date(3, 0, 0, tz: utc), tz: utc).hour), 90, accuracy: 0.001)
        XCTAssertEqual(deg(ClockHands.angles(for: date(15, 0, 0, tz: utc), tz: utc).hour), 90, accuracy: 0.001)
    }

    func testHandsCreepLikeARealMovement() {
        let a = ClockHands.angles(for: date(6, 44, 30, tz: utc), tz: utc)
        XCTAssertEqual(deg(a.second), 180, accuracy: 0.001)
        XCTAssertEqual(deg(a.minute), (44.5 / 60) * 360, accuracy: 0.001)            // 267°
        XCTAssertEqual(deg(a.hour), ((6 + 44.5 / 60) / 12) * 360, accuracy: 0.001)   // 202.25°
    }

    func testFractionalSecondsSweep() {
        let a = ClockHands.angles(for: date(12, 59, 59, nanos: 500_000_000, tz: utc), tz: utc)
        XCTAssertEqual(deg(a.second), 59.5 / 60 * 360, accuracy: 0.01)
        XCTAssertLessThan(deg(a.hour), 30, "12:59 is still before the 1")
    }

    func testWholeMinutesFreezesSeconds() {
        let a = ClockHands.angles(for: date(6, 44, 30, tz: utc), tz: utc, wholeMinutes: true)
        XCTAssertEqual(a.second, 0)
        XCTAssertEqual(deg(a.minute), 44.0 / 60 * 360, accuracy: 0.001)
    }

    func testTimeZoneDrivesTheFace() {
        let d = date(8, 30, 0, tz: utc)                       // 18:30 in Sydney (AEST, UTC+10)
        XCTAssertEqual(deg(ClockHands.angles(for: d, tz: sydney).hour), (6.5 / 12) * 360, accuracy: 0.001)
    }

    func testFaceTiersShedDetailOnSmallFaces() {
        let big = FaceMetrics(r: 95, center: .zero), medium = FaceMetrics(r: 55, center: .zero)
        let tiny = FaceMetrics(r: 40, center: .zero), hands = FaceMetrics(r: 20, center: .zero)
        XCTAssertTrue(big.showsDate && big.showsMinuteTicks && !big.quartersOnly)
        XCTAssertTrue(!medium.showsDate && !medium.showsMinuteTicks && !medium.quartersOnly)
        XCTAssertTrue(tiny.quartersOnly && !tiny.handsOnly)
        XCTAssertTrue(hands.handsOnly && hands.drawsFace)
        XCTAssertFalse(FaceMetrics(r: 10, center: .zero).drawsFace)
        // numerals stay clear of the rim ticks and of the minute hand's tip region
        XCTAssertLessThan(big.numeralRadius + big.numeralSize / 2, big.r - 8)
        // the renderer and the hands layer derive the SAME face from one dial
        let dial = DialMetrics(size: 320, style: .full)
        XCTAssertEqual(FaceMetrics(dial: dial).r, dial.faceRadius)
    }
}
