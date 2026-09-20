import XCTest
@testable import SGGS

@MainActor
final class NitnemRemindersTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Australia/Sydney")!; return c }
    private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    // MARK: pure planner

    func testPlanSchedules14PerEnabledBand() {
        let now = at(2026, 9, 18, 5, 0)   // before 06:00, so today's amrit vela still counts
        let plan = NitnemReminders.plan(now: now, enabled: [.amritVela: 6 * 60], calendar: cal)
        XCTAssertEqual(plan.count, 14)
        XCTAssertTrue(plan.allSatisfy { $0.band == .amritVela && $0.date > now })
        // first fire is today at 06:00
        let c = cal.dateComponents([.hour, .minute, .day], from: plan[0].date)
        XCTAssertEqual(c.hour, 6); XCTAssertEqual(c.minute, 0); XCTAssertEqual(c.day, 18)
        // ids are unique and prefixed
        XCTAssertEqual(Set(plan.map(\.id)).count, 14)
        XCTAssertTrue(plan.allSatisfy { $0.id.hasPrefix("nitnem.amritVela.") })
    }

    func testTodayDroppedWhenTimePassed() {
        let now = at(2026, 9, 18, 7, 0)   // after 06:00 → today's is gone, first is tomorrow
        let plan = NitnemReminders.plan(now: now, enabled: [.amritVela: 6 * 60], calendar: cal)
        XCTAssertEqual(plan.count, 14)
        XCTAssertEqual(cal.dateComponents([.day], from: plan[0].date).day, 19)
    }

    func testTodayDroppedWhenSetComplete() {
        let now = at(2026, 9, 18, 5, 0)   // before 06:00, but the band is already done today
        let plan = NitnemReminders.plan(now: now, enabled: [.amritVela: 6 * 60],
                                        completedToday: [.amritVela], calendar: cal)
        XCTAssertEqual(cal.dateComponents([.day], from: plan[0].date).day, 19, "today's nudge dropped")
    }

    func testThreeBandsStayUnder64() {
        let now = at(2026, 9, 18, 1, 0)
        let plan = NitnemReminders.plan(now: now,
                                        enabled: [.amritVela: 360, .evening: 1080, .night: 1290], calendar: cal)
        XCTAssertEqual(plan.count, 42)
        XCTAssertLessThanOrEqual(plan.count, 64)
    }

    func testCopyHasNoDigitsOrGurmukhi() {
        for band in NitnemReminders.bands {
            let (title, body) = NitnemReminders.copy(band)
            XCTAssertFalse((title + body).contains { $0.isNumber }, "no counts in reminder copy")
            XCTAssertFalse((title + body).unicodeScalars.contains { (0x0A00...0x0A7F).contains(Int($0.value)) },
                           "no Gurmukhi on the lock screen")
        }
    }

    // MARK: controller + fake scheduler

    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return d
    }

    func testEnableSchedulesRescheduleReplaces() async {
        let fake = FakeNotificationScheduler()
        let c = NitnemReminderController(scheduler: fake)
        let d = freshDefaults()
        _ = await c.setEnabled(true, band: .evening, defaults: d)
        var pending = await fake.snapshot()
        XCTAssertEqual(pending.count, 14)
        XCTAssertTrue(pending.allSatisfy { $0.band == .evening })
        // re-plan does not double up
        await c.reschedule(defaults: d)
        pending = await fake.snapshot()
        XCTAssertEqual(pending.count, 14, "reschedule clears the prefix first")
    }

    func testDeniedSnapsToggleBack() async {
        let fake = FakeNotificationScheduler(grants: false, status: .denied)
        let c = NitnemReminderController(scheduler: fake)
        let d = freshDefaults()
        let settled = await c.setEnabled(true, band: .night, defaults: d)
        XCTAssertFalse(settled, "denied permission returns off")
        XCTAssertFalse(c.isEnabled(.night, defaults: d))
        let pending = await fake.snapshot()
        XCTAssertTrue(pending.isEmpty, "nothing scheduled when denied")
    }

    /// Builds up to 1.3.0 (7) were granted `.provisional` silently, which never alerts. Turning a
    /// reminder on must upgrade that with a real prompt instead of treating it as good enough.
    func testProvisionalIsUpgradedWithARealPrompt() async {
        let fake = FakeNotificationScheduler(grants: true, status: .provisional)
        let c = NitnemReminderController(scheduler: fake)
        let d = freshDefaults()
        let settled = await c.setEnabled(true, band: .amritVela, defaults: d)
        XCTAssertTrue(settled)
        let (prompts, status, pending) = await (fake.promptCount, fake.status, fake.snapshot())
        XCTAssertEqual(prompts, 1, "provisional must be promoted through the system prompt")
        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(pending.count, 14)
    }

    func testDecliningTheUpgradePromptSnapsToggleBack() async {
        let fake = FakeNotificationScheduler(grants: false, status: .provisional)
        let c = NitnemReminderController(scheduler: fake)
        let d = freshDefaults()
        let settled = await c.setEnabled(true, band: .evening, defaults: d)
        XCTAssertFalse(settled)
        XCTAssertFalse(c.isEnabled(.evening, defaults: d))
        let pending = await fake.snapshot()
        XCTAssertTrue(pending.isEmpty)
    }

    func testAlreadyAuthorizedNeverPromptsAgain() async {
        let fake = FakeNotificationScheduler(grants: true, status: .authorized)
        let c = NitnemReminderController(scheduler: fake)
        _ = await c.setEnabled(true, band: .night, defaults: freshDefaults())
        let prompts = await fake.promptCount
        XCTAssertEqual(prompts, 0)
    }

    func testTurningAReminderOffNeverPrompts() async {
        let fake = FakeNotificationScheduler(grants: true, status: .notDetermined)
        let c = NitnemReminderController(scheduler: fake)
        _ = await c.setEnabled(false, band: .night, defaults: freshDefaults())
        let prompts = await fake.promptCount
        XCTAssertEqual(prompts, 0, "permission is asked only when a reminder is switched ON")
    }

    func testDisableClearsPending() async {
        let fake = FakeNotificationScheduler()
        let c = NitnemReminderController(scheduler: fake)
        let d = freshDefaults()
        _ = await c.setEnabled(true, band: .amritVela, defaults: d)
        _ = await c.setEnabled(false, band: .amritVela, defaults: d)
        let pending = await fake.snapshot()
        XCTAssertTrue(pending.isEmpty)
    }
}
