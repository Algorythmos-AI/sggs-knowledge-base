import XCTest
import GurbaniPahar
@testable import SGGS

/// The widget timeline is correct by construction: every entry speaks for its own date,
/// pahar boundaries land on wall-clock minutes (DST-safe), the hand is never more than
/// 15 minutes stale, and the entry count stays inside WidgetKit's budget.
final class RaagNowTimelineTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!
    private let sydney = TimeZone(identifier: "Australia/Sydney")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func snapshot() -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: .now, hukamGurmukhi: "", hukamTranslit: "", hukamAng: 1, hukamCompId: 2,
                       paharRaags: [4: ["maajh", "gaurhee"], 1: ["aasaa"]],
                       paharRaagsGurmukhi: [4: ["ਮਾਝ", "ਗਉੜੀ"], 1: ["ਆਸਾ"]])
    }

    func testEntryUsesItsOwnDate() {
        let cfg = RaagClockConfig(solar: false)
        let e = RaagNowTimeline.entry(at: date(2026, 9, 18, 16, 40, tz: utc), config: cfg, snapshot: snapshot(), tz: utc)
        XCTAssertEqual(e.pahar, 4)
        XCTAssertEqual(e.raags, ["maajh", "gaurhee"])
        XCTAssertEqual(e.raagsGurmukhi, ["ਮਾਝ", "ਗਉੜੀ"])
        XCTAssertEqual(e.nextPahar, 5)
        XCTAssertEqual(e.boundaryDate, date(2026, 9, 18, 18, 0, tz: utc))
        XCTAssertEqual(e.beads[4], 2)
        XCTAssertEqual(e.beads[7], 0)
        XCTAssertFalse(e.solar)
        XCTAssertTrue(e.hasSnapshot)
        let night = RaagNowTimeline.entry(at: date(2026, 9, 18, 1, 0, tz: utc), config: cfg, snapshot: nil, tz: utc)
        XCTAssertEqual(night.pahar, 7)
        XCTAssertFalse(night.hasSnapshot)
    }

    func testFixedTimelineCadenceBoundariesAndBudget() {
        let now = date(2026, 9, 18, 16, 40, tz: utc).addingTimeInterval(23)
        let dates = RaagNowTimeline.dates(from: now, config: RaagClockConfig(solar: false), tz: utc)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count, "no duplicate entries")
        XCTAssertLessThanOrEqual(dates.count, RaagNowTimeline.maxEntries)
        XCTAssertGreaterThan(dates.count, 96, "15-min cadence + 8 boundaries expected")
        // every fixed boundary in the next 24 h is present, on the wall clock
        for h in [18, 21, 0, 3, 6, 9, 12, 15] {
            let dayOffset = h < 16 ? 1 : 0
            let b = date(2026, 9, 18 + dayOffset, h, 0, tz: utc)
            XCTAssertTrue(dates.contains(b), "missing boundary \(h):00")
        }
        // the hand is never more than 15 min stale
        for (a, b) in zip(dates, dates.dropFirst()) {
            XCTAssertLessThanOrEqual(b.timeIntervalSince(a), 15 * 60 + 1)
        }
        XCTAssertLessThan(dates.last!.timeIntervalSince(now), 24 * 3600)
    }

    /// Sydney spring-forward (2026-10-04 02:00 → 03:00): the 03:00 boundary must be the real
    /// 03:00 AEDT instant, i.e. only two hours after 01:00 AEST, never "midnight + 180 min".
    func testDSTBoundariesAreWallClock() {
        let now = date(2026, 10, 3, 20, 0, tz: sydney)
        let dates = RaagNowTimeline.dates(from: now, config: RaagClockConfig(solar: false), tz: sydney)
        let three = date(2026, 10, 4, 3, 0, tz: sydney)
        XCTAssertTrue(dates.contains(three))
        let midnight = date(2026, 10, 4, 0, 0, tz: sydney)
        XCTAssertEqual(three.timeIntervalSince(midnight), 2 * 3600, "the clock skips 02:00 that night")
        let e = RaagNowTimeline.entry(at: three, config: RaagClockConfig(solar: false), snapshot: nil, tz: sydney)
        XCTAssertEqual(e.pahar, 8)
    }

    func testSolarConfigDrivesPaharAndFallsBackWhenPolar() {
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        let amritsar = RaagClockConfig(solar: true, lat: 31.63, lon: 74.87)
        let e = RaagNowTimeline.entry(at: date(2026, 9, 18, 6, 30, tz: kolkata), config: amritsar, snapshot: nil, tz: kolkata)
        XCTAssertTrue(e.solar)
        XCTAssertEqual(e.pahar, 1, "06:30 in Amritsar is just after sunrise → 1st pahar of day")
        XCTAssertNotNil(e.sunrise)
        let dates = RaagNowTimeline.dates(from: date(2026, 9, 18, 6, 10, tz: kolkata), config: amritsar, tz: kolkata)
        XCTAssertLessThanOrEqual(dates.count, RaagNowTimeline.maxEntries)
        XCTAssertEqual(dates, dates.sorted())

        let polar = RaagClockConfig(solar: true, lat: 78.22, lon: 15.63)
        let p = RaagNowTimeline.entry(at: date(2026, 12, 21, 16, 40, tz: utc), config: polar, snapshot: nil, tz: utc)
        XCTAssertFalse(p.solar, "polar night → fixed clock")
        XCTAssertEqual(p.pahar, 4)

        let noCoords = RaagClockConfig(solar: true)
        XCTAssertFalse(RaagNowTimeline.entry(at: .now, config: noCoords, snapshot: nil).solar)
    }

    func testOldSnapshotStillDecodes() throws {
        let legacy = """
        {"generatedAt":0,"hukamGurmukhi":"x","hukamTranslit":"","hukamAng":1,"hukamCompId":2,"paharRaags":{"4":["maajh"]}}
        """.data(using: .utf8)!
        let snap = try JSONDecoder().decode(WidgetSnapshot.self, from: legacy)
        XCTAssertNil(snap.clockMode)
        XCTAssertNil(snap.solarLat)
        XCTAssertEqual(snap.paharRaags[4], ["maajh"])
    }

    /// Restores whatever the device held, so the test never changes a reader's stored location.
    func testSharedDefaultsCoordsRoundTrip() {
        let before = SharedDefaults.suite.string(forKey: SharedDefaults.solarCoordsKey)
        defer {
            if let before { SharedDefaults.suite.set(before, forKey: SharedDefaults.solarCoordsKey) }
            else { SharedDefaults.suite.removeObject(forKey: SharedDefaults.solarCoordsKey) }
        }
        SharedDefaults.storeSolarCoords(lat: 31.634567, lon: 74.872345)
        XCTAssertEqual(SharedDefaults.solarCoords()?.lat, 31.63)   // rounded to ~1 km
        XCTAssertEqual(SharedDefaults.solarCoords()?.lon, 74.87)
        SharedDefaults.storeSolarCoords(lat: -33.8688, lon: 151.2093)
        XCTAssertEqual(SharedDefaults.solarCoords()?.lat, -33.87)
        SharedDefaults.suite.set("garbage", forKey: SharedDefaults.solarCoordsKey)
        XCTAssertNil(SharedDefaults.solarCoords(), "unparseable coords are ignored, not trapped")
    }
}
