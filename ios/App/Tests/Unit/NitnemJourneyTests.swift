import XCTest
import GurbaniSearchKit
@testable import SGGS

@MainActor
final class NitnemJourneyTests: XCTestCase {

    private func cal(firstWeekday: Int = 1) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Australia/Sydney")!
        c.firstWeekday = firstWeekday
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ c: Calendar, h: Int = 12) -> Date {
        var comp = DateComponents(); comp.year = y; comp.month = m; comp.day = d; comp.hour = h
        return c.date(from: comp)!
    }

    func testMonthGridHonoursFirstWeekday() {
        let c = cal(firstWeekday: 1)   // Sunday
        // Sep 2026: Sep 1 is a Tuesday. First cell (Sunday) is Aug 30.
        let grid = NitnemJourney.month(date(2026, 9, 15, c), completed: { _ in [] },
                                       today: date(2026, 9, 15, c), calendar: c)
        XCTAssertEqual(c.component(.weekday, from: grid.first!.date), c.firstWeekday)
        XCTAssertFalse(grid.first!.inMonth, "leading days belong to the previous month")
        XCTAssertTrue(grid.contains { $0.dayNumber == 15 && $0.inMonth && $0.isToday })
        XCTAssertEqual(grid.filter { $0.inMonth }.count, 30, "September has 30 days")
    }

    func testMondayFirstWeekday() {
        let c = cal(firstWeekday: 2)   // Monday
        let grid = NitnemJourney.month(date(2026, 9, 15, c), completed: { _ in [] },
                                       today: date(2026, 9, 15, c), calendar: c)
        XCTAssertEqual(c.component(.weekday, from: grid.first!.date), 2)
    }

    func testPracticesMarkedOnTheRightDay() {
        let c = cal()
        let key = NitnemClock.dayKey(date(2026, 9, 10, c), calendar: c)
        let grid = NitnemJourney.month(date(2026, 9, 15, c),
                                       completed: { $0 == key ? [.nitnemMorning, .nitnemEvening] : [] },
                                       today: date(2026, 9, 15, c), calendar: c)
        let cell = grid.first { $0.dayKey == key }
        XCTAssertEqual(cell?.practices, [.nitnemMorning, .nitnemEvening])
    }

    func testConsecutiveDays() {
        let c = cal()
        let today = date(2026, 9, 15, c)
        var done: Set<String> = []
        for back in 1...4 { done.insert(NitnemClock.dayKey(c.date(byAdding: .day, value: -back, to: today)!, calendar: c)) }
        let completed: (String) -> Set<BaniCategory> = { done.contains($0) ? [.nitnemMorning] : [] }
        // yesterday's streak counts until today is started
        XCTAssertEqual(NitnemJourney.consecutiveDays(endingAt: today, completed: completed, calendar: c), 4)
        done.insert(NitnemClock.dayKey(today, calendar: c))
        XCTAssertEqual(NitnemJourney.consecutiveDays(endingAt: today, completed: completed, calendar: c), 5)
    }

    func testDSTMonthStaysContinuous() {
        // Australia/Sydney enters DST on 2026-10-04 — the grid must still be day-by-day.
        let c = cal()
        let grid = NitnemJourney.month(date(2026, 10, 15, c), completed: { _ in [] },
                                       today: date(2026, 10, 15, c), calendar: c)
        for (a, b) in zip(grid, grid.dropFirst()) {
            let gap = c.dateComponents([.day], from: a.date, to: b.date).day
            XCTAssertEqual(gap, 1, "days must be consecutive across the DST change")
        }
        XCTAssertEqual(grid.filter { $0.inMonth }.count, 31, "October has 31 days")
    }

    func testPracticeDaysIntersection() {
        let c = cal()
        let store = NitnemProgressStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("np-\(UUID().uuidString).json"))
        let d10 = date(2026, 9, 10, c), d09 = date(2026, 9, 9, c)
        // morning = japji + jaap; complete only when BOTH were read that Nitnem day
        store.markComplete("japji", on: d10)
        store.markComplete("japji", on: d09)
        store.markComplete("jaap", on: d10)          // jaap only on the 10th
        let key10 = NitnemClock.dayKey(d10), key09 = NitnemClock.dayKey(d09)
        let out = store.practiceDays(focus: [.nitnemMorning: ["japji", "jaap"]])
        XCTAssertEqual(out[key10], [.nitnemMorning])
        XCTAssertNil(out[key09], "jaap not done that day → morning not complete")
    }
}
