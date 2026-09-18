import XCTest
@testable import SGGS

@MainActor
final class AutoScrollTests: XCTestCase {
    func testNextOffsetAdvancesByRate() {
        // 30 pt/s for 0.5 s → +15
        XCTAssertEqual(AutoScrollMath.nextOffset(current: 100, maxY: 1000, pointsPerSecond: 30, dt: 0.5), 115, accuracy: 0.001)
    }
    func testNextOffsetClampsToEnd() {
        XCTAssertEqual(AutoScrollMath.nextOffset(current: 995, maxY: 1000, pointsPerSecond: 60, dt: 0.5), 1000)
    }
    func testNextOffsetIgnoresStalledFrame() {
        XCTAssertEqual(AutoScrollMath.nextOffset(current: 100, maxY: 1000, pointsPerSecond: 30, dt: 0), 100)
        XCTAssertEqual(AutoScrollMath.nextOffset(current: 100, maxY: 1000, pointsPerSecond: 30, dt: 5), 100)
    }
    func testPaceScalesWithFontAndLowPower() {
        let base = AutoScrollMath.pointsPerSecond(.steady, fontSize: 24, lowPower: false, override: [:])
        XCTAssertEqual(base, AutoScrollPace.steady.basePointsPerSecond, accuracy: 0.001)
        let big = AutoScrollMath.pointsPerSecond(.steady, fontSize: 32, lowPower: false, override: [:])
        XCTAssertGreaterThan(big, base, "a larger font scrolls faster in points so it reads the same")
        let low = AutoScrollMath.pointsPerSecond(.steady, fontSize: 24, lowPower: true, override: [:])
        XCTAssertEqual(low, base * 0.5, accuracy: 0.001)
    }
    func testEnvOverrideWins() {
        XCTAssertEqual(AutoScrollMath.pointsPerSecond(.slow, fontSize: 24, lowPower: false, override: ["SGGS_AUTOSCROLL_PPS": "200"]), 200)
    }
    func testControllerStateMachine() {
        let c = AutoScrollController()
        XCTAssertFalse(c.available)
        c.toggle(); XCTAssertFalse(c.isRunning, "no scroll view → cannot start")
        let sv = UIScrollView()          // retained for the test's lifetime (view hierarchy holds it in the app)
        c.attach(sv)
        XCTAssertTrue(c.available)
        c.start(); XCTAssertTrue(c.isRunning)
        c.pause(); XCTAssertFalse(c.isRunning)
        c.start(); c.attach(nil)
        XCTAssertFalse(c.available); XCTAssertFalse(c.isRunning, "detaching stops it")
    }
}
