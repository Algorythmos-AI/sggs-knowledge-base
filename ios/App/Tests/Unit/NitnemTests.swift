import XCTest
import GurbaniSearchKit
@testable import SGGS

/// The Nitnem home's time bands are a pure function of the wall clock; the progress store is
/// a small versioned file that must never crash and must survive a corrupt file.
@MainActor
final class NitnemScheduleTests: XCTestCase {
    func testBandsAcrossTheDay() {
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 3 * 60), .amritVela)      // 03:00
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 5 * 60 + 30), .amritVela) // 05:30
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 9 * 60), .day)            // 09:00
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 12 * 60), .day)           // 12:00
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 17 * 60), .evening)       // 17:00
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 18 * 60 + 30), .evening)  // 18:30
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 21 * 60), .night)         // 21:00
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 23 * 60 + 30), .night)    // 23:30
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 0), .night)               // midnight
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 2 * 60 + 59), .night)     // 02:59
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: 1440 + 60 * 4), .amritVela) // wraps
        XCTAssertEqual(NitnemSchedule.band(minutesSinceMidnight: -60), .night)             // wraps back
    }

    func testBandFocusAndOrder() {
        XCTAssertEqual(NitnemBand.amritVela.focus, .nitnemMorning)
        XCTAssertEqual(NitnemBand.evening.focus, .nitnemEvening)
        XCTAssertEqual(NitnemBand.night.focus, .nitnemNight)
        for band in NitnemBand.allCases {
            XCTAssertEqual(Set(band.order), [.nitnemMorning, .nitnemEvening, .nitnemNight], "\(band) lists every Nitnem category")
        }
    }

    func testNextSkipsCompletedAndRespectsOrder() {
        func b(_ key: String, _ cat: BaniCategory, _ order: Int, isDefault: Bool = true) -> BaniSummary {
            BaniSummary(key: key, variant: "", isDefault: isDefault, titleGm: key, titleEn: key, category: cat,
                        orderNo: order, nLines: 10, nGroups: 1, hasExtra: false, estimatedMinutes: 1,
                        descriptionEn: nil, sourceLabel: "")
        }
        let banis = [b("anand", .nitnemMorning, 50), b("japji", .nitnemMorning, 10), b("jaap", .nitnemMorning, 20),
                     b("rehras", .nitnemEvening, 60)]
        XCTAssertEqual(NitnemSchedule.next(in: .amritVela, from: banis) { _ in false }?.key, "japji")
        XCTAssertEqual(NitnemSchedule.next(in: .amritVela, from: banis) { $0.key == "japji" }?.key, "jaap")
        XCTAssertNil(NitnemSchedule.next(in: .amritVela, from: banis) { $0.category == .nitnemMorning })
        XCTAssertEqual(NitnemSchedule.next(in: .evening, from: banis) { _ in false }?.key, "rehras")
    }

    func testRehrasVariantPreference() {
        XCTAssertEqual(NitnemPrefs.variant(for: "rehras", rehras: "taksal"), "taksal")
        XCTAssertEqual(NitnemPrefs.variant(for: "rehras", rehras: "garbage"), "sgpc")
        XCTAssertEqual(NitnemPrefs.variant(for: "japji", rehras: "taksal"), "")
        XCTAssertEqual(NitnemPrefs.progressId(key: "rehras", variant: "taksal"), "rehras/taksal")
        XCTAssertEqual(NitnemPrefs.progressId(key: "japji", variant: ""), "japji")
    }

    func testBaniKeyAllowlist() {
        XCTAssertTrue(Router.isValidBaniKey("japji"))
        XCTAssertTrue(Router.isValidBaniKey("asa_di_vaar"))
        XCTAssertFalse(Router.isValidBaniKey(""))
        XCTAssertFalse(Router.isValidBaniKey("../etc"))
        XCTAssertFalse(Router.isValidBaniKey("Japji"))
        XCTAssertFalse(Router.isValidBaniKey(String(repeating: "a", count: 33)))
    }
}

@MainActor
final class NitnemProgressTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("nitnem-\(UUID().uuidString).json")
    }

    func testPositionCompletionAndFraction() {
        let store = NitnemProgressStore(url: tempURL())
        XCTAssertEqual(store.fraction(for: "japji", total: 385), 0)
        store.setPosition("japji", seq: 77)
        XCTAssertEqual(store.progress(for: "japji")?.lastSeq, 77)
        XCTAssertEqual(store.fraction(for: "japji", total: 385), 77.0 / 385.0, accuracy: 0.0001)
        store.markComplete("japji")
        XCTAssertTrue(store.isCompleted("japji"))
        XCTAssertEqual(store.fraction(for: "japji", total: 385), 1)
        XCTAssertEqual(store.progress(for: "japji")?.lastSeq, 0, "a completed bani reopens at the top")
        store.resetPosition("japji")
        XCTAssertTrue(store.isCompleted("japji"), "start again keeps the day's completion")
    }

    func testPersistsAcrossReload() {
        let url = tempURL()
        let a = NitnemProgressStore(url: url)
        a.setPosition("sukhmani", seq: 900)
        a.markComplete("sohila")
        let b = NitnemProgressStore(url: url)
        XCTAssertEqual(b.progress(for: "sukhmani")?.lastSeq, 900)
        XCTAssertTrue(b.isCompleted("sohila"))
    }

    func testCorruptFileIsEmptyNeverCrashes() throws {
        let url = tempURL()
        try Data("{not json".utf8).write(to: url)
        let store = NitnemProgressStore(url: url)
        XCTAssertTrue(store.file.banis.isEmpty)
        store.setPosition("japji", seq: 3)                 // and it recovers by writing a fresh file
        XCTAssertEqual(NitnemProgressStore(url: url).progress(for: "japji")?.lastSeq, 3)
        try Data(#"{"schemaVersion": 99, "banis": {}}"#.utf8).write(to: url)
        XCTAssertTrue(NitnemProgressStore(url: url).file.banis.isEmpty, "an unknown schema is treated as empty")
    }

    func testStreakCountsConsecutiveDays() {
        let store = NitnemProgressStore(url: tempURL())
        let cal = Calendar.current
        let today = Date()
        let ids = ["japji", "jaap"]
        XCTAssertEqual(store.streak(for: ids, on: today), 0)
        for back in 1...3 {
            let d = cal.date(byAdding: .day, value: -back, to: today)!
            for id in ids { store.markComplete(id, on: d) }
        }
        XCTAssertEqual(store.streak(for: ids, on: today), 3, "yesterday's streak still counts until today is done")
        for id in ids { store.markComplete(id, on: today) }
        XCTAssertEqual(store.streak(for: ids, on: today), 4)
        store.markComplete("sohila", on: today)
        XCTAssertEqual(store.streak(for: ["sohila"], on: today), 1)
    }

    func testCompletedDaysAreCapped() {
        let store = NitnemProgressStore(url: tempURL())
        let cal = Calendar.current
        for back in 0..<(NitnemProgressStore.maxCompletedDays + 20) {
            store.markComplete("japji", on: cal.date(byAdding: .day, value: -back, to: Date())!)
        }
        XCTAssertEqual(store.progress(for: "japji")?.completedDays.count, NitnemProgressStore.maxCompletedDays)
    }

    func testDayKeyIsLocalCalendarDay() {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 18; c.hour = 23; c.minute = 59
        let d = Calendar.current.date(from: c)!
        XCTAssertEqual(NitnemProgressStore.dayKey(d), "2026-09-18")
    }
}
