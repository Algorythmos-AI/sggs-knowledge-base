import XCTest
@testable import SGGS

final class ReadingActivityPolicyTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testWholePercentFloorsAndClamps() {
        XCTAssertEqual(ReadingActivityPolicy.wholePercent(0), 0)
        XCTAssertEqual(ReadingActivityPolicy.wholePercent(0.129), 12)
        XCTAssertEqual(ReadingActivityPolicy.wholePercent(0.999), 99)
        XCTAssertEqual(ReadingActivityPolicy.wholePercent(1.0), 100)
        XCTAssertEqual(ReadingActivityPolicy.wholePercent(1.5), 100)
        XCTAssertEqual(ReadingActivityPolicy.wholePercent(-0.2), 0)
    }

    func testFirstUpdateAlwaysLands() {
        XCTAssertTrue(ReadingActivityPolicy.shouldUpdate(lastPercent: nil, newFraction: 0.0, lastUpdate: nil, now: t0))
    }

    func testNoUpdateWithoutWholePercentChange() {
        // 12% -> 12.9% is still 12%, no visible change
        XCTAssertFalse(ReadingActivityPolicy.shouldUpdate(lastPercent: 12, newFraction: 0.129,
                                                          lastUpdate: t0, now: t0.addingTimeInterval(30)))
    }

    func testThrottledUnder10Seconds() {
        // percent changed 12 -> 13 but only 5 s elapsed
        XCTAssertFalse(ReadingActivityPolicy.shouldUpdate(lastPercent: 12, newFraction: 0.13,
                                                          lastUpdate: t0, now: t0.addingTimeInterval(5)))
    }

    func testUpdatesOnPercentChangeAfterInterval() {
        XCTAssertTrue(ReadingActivityPolicy.shouldUpdate(lastPercent: 12, newFraction: 0.13,
                                                         lastUpdate: t0, now: t0.addingTimeInterval(11)))
    }

    func testStaleDateIs20Minutes() {
        XCTAssertEqual(ReadingActivityPolicy.staleDate(from: t0).timeIntervalSince(t0), 20 * 60, accuracy: 0.5)
    }
}
