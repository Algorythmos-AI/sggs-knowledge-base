import XCTest
import WidgetKit
@testable import SGGS

@MainActor
final class NitnemTimelineTests: XCTestCase {
    private func date(_ h: Int, _ m: Int = 0, day: Int = 18) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        return c.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))!
    }
    private func snapshot(morning: [String]) -> WidgetSnapshot {
        let banis = morning.map { NitnemWidgetData.Bani(id: $0, key: $0, titleEn: $0.capitalized, titleGm: $0, minutes: 10, nLines: 100) }
        return WidgetSnapshot(generatedAt: .now, hukamGurmukhi: "", hukamTranslit: "", hukamAng: 1, hukamCompId: 2,
                              paharRaags: [:], nitnem: NitnemWidgetData(sets: ["morning": banis, "evening": [], "night": [
                                NitnemWidgetData.Bani(id: "sohila", key: "sohila", titleEn: "Kirtan Sohila", titleGm: "x", minutes: 5, nLines: 56)]]))
    }
    private func progress(_ completed: [String: [String]]) -> NitnemProgressReading {
        var banis: [String: NitnemProgressReading.Entry] = [:]
        for (id, days) in completed { banis[id] = .init(lastSeq: 0, completedDays: days, nLines: nil) }
        return NitnemProgressReading(banis: banis)
    }

    func testEntryPicksBandAndSet() {
        let snap = snapshot(morning: ["japji", "jaap"])
        let e = NitnemTimeline.entry(at: date(5, 0), snapshot: snap, progress: progress([:]))
        XCTAssertEqual(e.band, .amritVela)
        XCTAssertEqual(e.total, 2)
        XCTAssertEqual(e.next?.id, "japji")
        XCTAssertFalse(e.allDone)
    }

    func testNextSkipsCompleted() {
        let snap = snapshot(morning: ["japji", "jaap"])
        let key = NitnemClock.dayKey(date(5, 0))
        let e = NitnemTimeline.entry(at: date(5, 0), snapshot: snap, progress: progress(["japji": [key]]))
        XCTAssertEqual(e.next?.id, "jaap")
        XCTAssertEqual(e.doneCount, 1)
    }

    func testAllDone() {
        let snap = snapshot(morning: ["japji"])
        let key = NitnemClock.dayKey(date(5, 0))
        let e = NitnemTimeline.entry(at: date(5, 0), snapshot: snap, progress: progress(["japji": [key]]))
        XCTAssertNil(e.next)
        XCTAssertTrue(e.allDone)
    }

    func testCompletionFollowsThe0300NitnemDay() {
        let snap = snapshot(morning: [])
        // Sohila read at 22:00 on the 18th
        let key = NitnemClock.dayKey(date(22, 0, day: 18))
        let p = progress(["sohila": [key]])
        // an entry at 00:30 on the 19th is the SAME Nitnem day → still complete
        let night = NitnemTimeline.entry(at: date(0, 30, day: 19), snapshot: snap, progress: p)
        XCTAssertTrue(night.allDone, "sohila still complete just after midnight")
        // an entry at 04:00 on the 19th is a NEW Nitnem day → not complete
        let morning = NitnemTimeline.entry(at: date(4, 0, day: 19), snapshot: snap, progress: p)
        XCTAssertEqual(morning.band, .amritVela)
    }

    func testDatesIncludeBandBoundaries() {
        let now = date(10, 0)   // during the day band
        let dates = NitnemTimeline.dates(from: now)
        XCTAssertEqual(dates.first, now)
        // the next boundary is 17:00 today
        let mins = dates.map { Calendar.current.dateComponents([.hour, .minute], from: $0) }
        XCTAssertTrue(mins.contains { $0.hour == 17 && $0.minute == 0 }, "17:00 boundary present")
        XCTAssertTrue(mins.contains { $0.hour == 21 && $0.minute == 0 }, "21:00 boundary present")
        XCTAssertTrue(mins.contains { $0.hour == 3 && $0.minute == 0 }, "03:00 rollover present")
        XCTAssertLessThan(dates.count, 20)
    }
}
