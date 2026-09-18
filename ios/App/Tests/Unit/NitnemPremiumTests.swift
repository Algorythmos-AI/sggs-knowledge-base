import XCTest
import GurbaniSearchKit
@testable import SGGS

/// The premium-pass robustness guarantees: one 03:00 Nitnem day, positions that survive a
/// registry rebuild, a progress file that never overwrites a newer schema, and the day arc.
@MainActor
final class NitnemDayClockTests: XCTestCase {
    private func at(_ h: Int, _ m: Int = 0, day: Int = 18) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = day; c.hour = h; c.minute = m
        return Calendar.current.date(from: c)!
    }

    func testDayRollsAtThreeAM() {
        // 22:00 and 00:30 the next calendar day are the SAME Nitnem day
        XCTAssertEqual(NitnemClock.dayKey(at(22, 0, day: 18)), "2026-09-18")
        XCTAssertEqual(NitnemClock.dayKey(at(0, 30, day: 19)), "2026-09-18")
        XCTAssertEqual(NitnemClock.dayKey(at(2, 59, day: 19)), "2026-09-18")
        // 03:00 rolls to the new day
        XCTAssertEqual(NitnemClock.dayKey(at(3, 0, day: 19)), "2026-09-19")
        XCTAssertEqual(NitnemClock.dayKey(at(8, 0, day: 19)), "2026-09-19")
    }

    func testSohilaReadAtNightStaysDoneAfterMidnight() {
        let store = NitnemProgressStore(url: tempURL())
        store.markComplete("sohila", on: at(22, 0, day: 18))
        XCTAssertTrue(store.isCompleted("sohila", on: at(0, 30, day: 19)), "still done just after midnight")
        XCTAssertFalse(store.isCompleted("sohila", on: at(4, 0, day: 19)), "a new Nitnem day after 03:00")
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("np-\(UUID().uuidString).json")
    }
}

@MainActor
final class NitnemAnchorResumeTests: XCTestCase {
    private func line(_ seq: Int, lineId: Int) -> BaniLine {
        BaniLine(seq: seq, lineGroup: 1, gurmukhi: "x", translit: "", isHeader: false,
                 isRahao: false, markers: [], citation: .sggs(ang: 1, lineId: lineId, compId: 1))
    }
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("np-\(UUID().uuidString).json")
    }

    func testResumeBySeqWhenRegistryUnchanged() {
        let store = NitnemProgressStore(url: tempURL())
        let lines = (1...100).map { line($0, lineId: 1000 + $0) }
        store.setPosition("japji", seq: 40, anchor: 1040, nLines: 100)
        XCTAssertEqual(store.resumeSeq(for: "japji", lines: lines), 40)
    }

    func testResumeByAnchorWhenRegistryChanged() {
        let store = NitnemProgressStore(url: tempURL())
        // saved when the bani had 100 lines; now it has 101 (a line was inserted before seq 40)
        store.setPosition("japji", seq: 40, anchor: 1040, nLines: 100)
        let shifted = (1...101).map { line($0, lineId: 1000 + $0 - 1) }  // line 1040 now sits at seq 41
        XCTAssertEqual(store.resumeSeq(for: "japji", lines: shifted), 41)
    }

    func testResumeUnresolvableFallsToTop() {
        let store = NitnemProgressStore(url: tempURL())
        store.setPosition("japji", seq: 40, anchor: 999999, nLines: 100)   // anchor no longer exists
        let lines = (1...50).map { line($0, lineId: 1000 + $0) }
        XCTAssertNil(store.resumeSeq(for: "japji", lines: lines))
    }

    func testLegacyFileWithoutAnchorStillResumes() {
        let store = NitnemProgressStore(url: tempURL())
        store.setPosition("japji", seq: 30)   // no anchor / nLines (a 1.2.x-shaped write)
        let lines = (1...100).map { line($0, lineId: 1000 + $0) }
        XCTAssertEqual(store.resumeSeq(for: "japji", lines: lines), 30)
    }

    func testNeverOverwritesANewerSchema() throws {
        let url = tempURL()
        try Data(#"{"schemaVersion": 9, "banis": {}}"#.utf8).write(to: url)
        let store = NitnemProgressStore(url: url)
        XCTAssertTrue(store.isReadOnly)
        store.markComplete("japji")               // must be a no-op on disk
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(onDisk.contains("9") && !onDisk.contains("japji"), "newer file must be preserved unchanged: \(onDisk)")
    }
}

@MainActor
final class DayArcModelTests: XCTestCase {
    func testBandBoundaries() {
        XCTAssertEqual(DayArcModel(date: date(3, 0)).currentBand, .amritVela)
        XCTAssertEqual(DayArcModel(date: date(8, 59)).currentBand, .amritVela)
        XCTAssertEqual(DayArcModel(date: date(9, 0)).currentBand, .day)
        XCTAssertEqual(DayArcModel(date: date(17, 0)).currentBand, .evening)
        XCTAssertEqual(DayArcModel(date: date(21, 0)).currentBand, .night)
        XCTAssertEqual(DayArcModel(date: date(1, 0)).currentBand, .night)
    }

    func testMarkerFractionWrapsAtThreeAM() {
        XCTAssertEqual(DayArcModel(date: date(3, 0)).markerFraction, 0, accuracy: 0.001)
        XCTAssertEqual(DayArcModel(date: date(15, 0)).markerFraction, 0.5, accuracy: 0.001)  // 12h after 3am
        XCTAssertEqual(DayArcModel(date: date(2, 59)).markerFraction, 1439.0/1440, accuracy: 0.001)
    }

    func testDaylightFlag() {
        XCTAssertTrue(DayArcModel(date: date(6, 0)).isDaylight)
        XCTAssertTrue(DayArcModel(date: date(12, 0)).isDaylight)
        XCTAssertFalse(DayArcModel(date: date(19, 0)).isDaylight)
        XCTAssertFalse(DayArcModel(date: date(23, 0)).isDaylight)
    }

    private func date(_ h: Int, _ m: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 18; c.hour = h; c.minute = m
        return Calendar.current.date(from: c)!
    }
}
