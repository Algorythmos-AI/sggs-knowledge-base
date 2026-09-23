import XCTest

final class SGGSUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    /// Every test ends with the app terminated so no keyboard/sheet/tab state leaks into the next.
    override func tearDown() {
        // TEST_RUNNER_SGGS_KEEP_APP=1 leaves the app running after a test (manual screenshots)
        if ProcessInfo.processInfo.environment["SGGS_KEEP_APP"] != "1" { XCUIApplication().terminate() }
    }

    /// Launch with the UI-test environment: the app (Debug only) clears per-launch residue
    /// (resume-last-Ang, transliteration toggle) — never the accent, whose persistence is under test.
    /// The app opens on the Nitnem tab; `selectSearch` (the default) then moves to Search so
    /// the search-driven tests start where they always did.
    private func launchApp(selectSearch: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launch()
        if selectSearch { openTab(app, "Search", expectingNavBar: "Search") }
        return app
    }

    /// Poll a static text's label (a value the UI sets a beat after an action, e.g. a scroll landing).
    private func waitLabel(_ element: XCUIElement, hasPrefix prefix: String, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.label.hasPrefix(prefix) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return element.exists && element.label.hasPrefix(prefix)
    }

    /// The Raag Clock lives under Explore: open the hub, then its card.
    private func openClock(_ app: XCUIApplication) {
        openTab(app, "Explore", expectingNavBar: "Explore")
        let card = app.buttons["Raag Clock"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Raag Clock card missing")
        card.tap()
        XCTAssertTrue(app.navigationBars["Raag Clock"].waitForExistence(timeout: 12), "Raag Clock did not open")
    }

    /// Tab button that also resolves on iPadOS 26 (top tab bar may not expose `tabBars`).
    private func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let bar = app.tabBars.buttons[name]
        return bar.waitForExistence(timeout: 2) ? bar : app.buttons[name].firstMatch
    }

    /// Switch tabs and WAIT for the destination to be on screen. The iOS 26 glass tab bar can
    /// swallow a tap while it is minimised/animating (first tap restores it), so verify the
    /// destination's navigation bar and tap once more if it did not arrive.
    private func openTab(_ app: XCUIApplication, _ name: String, expectingNavBar nav: String) {
        for _ in 0..<3 {
            tab(app, name).tap()
            if app.navigationBars[nav].waitForExistence(timeout: 4) { return }
        }
        XCTFail("tab \(name) did not open \(nav)")
    }

    /// Focus the search field and make sure the keyboard is actually up (a tap that lands
    /// during the search-bar layout animation can leave the field unfocused).
    private func focusSearch(_ app: XCUIApplication) -> XCUIElement {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), "search field missing")
        for _ in 0..<3 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { return field }
            // iPad with a hardware keyboard shows no software keyboard — focus is enough
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return field }
        }
        XCTFail("search field never took keyboard focus")
        return field
    }

    /// Long-press a verse row until its context menu shows `action` (a long press that
    /// starts mid-scroll can be dropped; retry rather than fail on a synthetic-input hiccup).
    private func contextAction(_ app: XCUIApplication, on element: XCUIElement, _ action: String) -> XCUIElement {
        for _ in 0..<3 {
            element.press(forDuration: 1.1)
            let b = app.buttons[action].firstMatch
            if b.waitForExistence(timeout: 5) { return b }
            app.tap()                                   // dismiss a half-open menu, then retry
        }
        XCTFail("context action \(action) never appeared")
        return app.buttons[action].firstMatch
    }

    // MARK: Jump-sheet helpers

    /// Enter a new Ang into the (seeded, editable) number field: focus, clear the existing digits,
    /// then type the value. Robust whether or not select-all-on-focus has fired.
    private func enterAng(_ app: XCUIApplication, _ value: String, file: StaticString = #file, line: UInt = #line) {
        let field = app.textFields["angField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), "angField missing", file: file, line: line)
        field.tap()
        field.typeText(String(repeating: "\u{8}", count: 5))   // delete up to 5 seeded digits
        field.typeText(value)
    }

    // MARK: Reader pager helpers

    /// The Reader mounts three pages at once (current ±1), so the same in-page control id exists on
    /// off-screen neighbours too. The *visible* page is identified by the pager's own container id
    /// `angPager-<n>` (from the pager, not the router), suffixed `-h0` under UI test so a self-heal —
    /// which would mean the desync bug re-appeared — makes this assertion fail instead of passing quietly.
    private func assertOnAng(_ app: XCUIApplication, _ n: Int, _ note: String = "",
                             timeout: TimeInterval = 12, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["Ang \(n)"].waitForExistence(timeout: timeout),
                      "title should read Ang \(n) \(note)", file: file, line: line)
        XCTAssertTrue(app.otherElements["angPager-\(n)-h0"].waitForExistence(timeout: timeout),
                      "the visible page should be Ang \(n) with no self-heal \(note)", file: file, line: line)
        // The regression that shipped: title + pager agreed while the page stayed a skeleton. Require
        // the loaded content view (only present when verses rendered, never on the skeleton).
        XCTAssertTrue(app.scrollViews["angContent-\(n)"].waitForExistence(timeout: timeout),
                      "Ang \(n) must render verses, not a skeleton \(note)", file: file, line: line)
    }

    /// Open the Reader on a specific Ang via the deep link (avoids typing into the Jump sheet and
    /// starts every pager test from a known page).
    private func goReader(_ app: XCUIApplication, at n: Int) {
        XCUIDevice.shared.system.open(URL(string: "sggs://ang/\(n)")!)
        openTab(app, "Reader", expectingNavBar: "Ang \(n)")
    }

    /// The first HITTABLE element with this id — the on-screen page's copy, never a neighbour's.
    private func hittable(_ app: XCUIApplication, button id: String, timeout: TimeInterval = 8) -> XCUIElement? {
        _ = app.buttons[id].firstMatch.waitForExistence(timeout: timeout)
        return app.buttons.matching(identifier: id).allElementsBoundByIndex.first { $0.isHittable }
    }

    /// The on-screen page's scroll view (neighbours are mounted but off-screen / not hittable).
    private func readerScroll(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.allElementsBoundByIndex.first { $0.isHittable } ?? app.scrollViews.firstMatch
    }

    /// Scroll the reading area down one screen. `scrollViews.firstMatch` is the current page's
    /// vertical scroll view (the mechanism `testReaderChromeReturnsOnScrollUp` relies on); a
    /// coordinate drag is the fallback if it is not hittable.
    private func dragReaderUp(_ app: XCUIApplication) {
        let sv = app.scrollViews.firstMatch
        if sv.isHittable { sv.swipeUp() ; return }
        let top = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        top.press(forDuration: 0.05, thenDragTo: bottom)
    }

    /// The current page's forward control at the bottom: the "Continues on Ang N+1" hint pill when
    /// the shabad carries over, else the always-present end-of-page "Next · Ang N+1" card.
    private func forwardFooter(_ app: XCUIApplication) -> XCUIElement? {
        hittable(app, button: "continuesOnPill", timeout: 1) ?? hittable(app, button: "endNextAng", timeout: 1)
    }

    /// THE new regression guard for the reported bug: after a jump, swiping several pages must render
    /// verses on EVERY page — not a permanent skeleton (TestFlight 1.3.0 (4), Angs 352 / 918 / 1106).
    /// `assertOnAng` now requires the content view, so a blank page fails here.
    func testSwipeRunAfterJumpRendersContent() {
        let app = launchApp()
        for start in [1100, 348, 915] {
            goReader(app, at: start)
            assertOnAng(app, start)
            for i in 1...8 {                       // swipe forward past the old 3-4 page eviction cliff
                readerScroll(app).swipeLeft()
                assertOnAng(app, start + i, "forward swipe #\(i) from \(start)")
            }
            for i in stride(from: 7, through: 0, by: -1) {
                readerScroll(app).swipeRight()
                assertOnAng(app, start + i, "back swipe to \(start + i)")
            }
        }
    }

    /// The "Ang N" title is a control: tapping it opens Jump with the keypad up, and typing a number
    /// then Go lands on a rendered page.
    func testTitleOpensJumpAndTypedAngRenders() {
        let app = launchApp()
        goReader(app, at: 500)
        assertOnAng(app, 500)
        let title = app.buttons["angTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 12), "the Ang title should be a button")
        title.tap()
        XCTAssertTrue(app.textFields["angField"].firstMatch.waitForExistence(timeout: 8), "title tap should open Jump")
        enterAng(app, "1106")
        app.buttons["goToAng"].tap()
        assertOnAng(app, 1106, "after typing an Ang from the title")
    }

    func testLaunchShowsNitnem() {
        let app = launchApp(selectSearch: false)
        XCTAssertTrue(app.navigationBars["Nitnem"].waitForExistence(timeout: 20), "the app opens on the daily reading")
        XCTAssertTrue(app.buttons["bani_japji"].waitForExistence(timeout: 12), "Japji Sahib row missing")
        XCTAssertTrue(app.buttons["Hukam"].exists, "Hukam card missing")
    }

    func testSearchTabReachable() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 20))
    }

    /// Nitnem → Japji Sahib: the bani reader opens on the verbatim Mool Mantar, the position
    /// bar reads, marking it read completes the ring, and Next leads on to Jaap Sahib.
    func testNitnemOpensJapjiAndCompletes() {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_CLOCK_NOW"] = "300"      // 05:00 → Amrit Vela
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launch()
        XCTAssertTrue(app.navigationBars["Nitnem"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Amrit Vela"].waitForExistence(timeout: 8), "band title missing")
        let row = app.buttons["bani_japji"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        row.tap()
        XCTAssertTrue(app.navigationBars["Japji Sahib"].waitForExistence(timeout: 12), "bani reader did not open")
        let mool = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ")).firstMatch
        XCTAssertTrue(mool.waitForExistence(timeout: 12), "Mool Mantar (verbatim) missing at the top of Japji")
        XCTAssertTrue(app.staticTexts["baniPosition"].firstMatch.waitForExistence(timeout: 8), "position bar missing")
        // jump to the end and mark it read
        app.buttons["End"].firstMatch.tap()
        let mark = app.buttons["baniMarkComplete"].firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 12), "Mark as read missing at the end")
        mark.tap()
        let next = app.buttons["nitnemNext"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 8), "Next bani action missing after completion")
        XCTAssertTrue(next.label.contains("Jaap Sahib"), "next bani should be Jaap Sahib, got \(next.label)")
        next.tap()
        XCTAssertTrue(app.navigationBars["Jaap Sahib"].waitForExistence(timeout: 12), "Next did not open Jaap Sahib")
        // the extra layer is labelled, never cited as an Ang
        // the header is one combined element and each LineRow is one element: query any kind
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Sri Dasam Granth")).firstMatch
            .waitForExistence(timeout: 8), "Dasam source label missing")
    }

    /// The Live Activity opt-in is present in More and defaults off (never on without consent).
    func testLiveActivityToggleDefaultsOff() {
        let app = launchApp(selectSearch: false)
        openTab(app, "More", expectingNavBar: "More")
        let toggle = app.switches["liveActivityToggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 12), "Live Activity toggle missing in More")
        XCTAssertEqual(toggle.value as? String, "0", "Live Activity must default OFF")
    }

    /// My Nitnem: the editor opens from More and shows the set picker, the morning banis and the
    /// "Add a bani" affordance. (Reorder/hide/add persistence is covered by NitnemSetsTests and
    /// validated on-device.)
    func testMyNitnemEditorOpens() {
        let app = launchApp(selectSearch: false)
        openTab(app, "More", expectingNavBar: "More")
        let link = app.buttons["nitnemSetsLink"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 12), "My Nitnem link missing in More")
        link.tap()
        XCTAssertTrue(app.navigationBars["My Nitnem"].waitForExistence(timeout: 8), "My Nitnem did not open")
        XCTAssertTrue(app.buttons["nitnemSetsAdd"].firstMatch.waitForExistence(timeout: 6), "Add a bani missing")
        XCTAssertTrue(app.staticTexts["Japji Sahib"].firstMatch.exists, "morning set not shown")
        // switch to the Sohila set and confirm the header changes
        app.buttons["Sohila"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Kirtan Sohila"].firstMatch.waitForExistence(timeout: 6), "Sohila set not shown")
    }

    /// Reminders: the screen opens from More and shows a toggle for each of the three daily sets
    /// plus the calm, offline footer. (Toggling → scheduling is covered by NitnemRemindersTests
    /// and validated on-device; a SwiftUI Toggle is not reliably tappable from XCUITest here.)
    func testNitnemRemindersScreenOpens() {
        let app = launchApp(selectSearch: false)
        openTab(app, "More", expectingNavBar: "More")
        let link = app.buttons["nitnemRemindersLink"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 12), "Reminders link missing in More")
        link.tap()
        XCTAssertTrue(app.navigationBars["Reminders"].waitForExistence(timeout: 8), "Reminders screen did not open")
        XCTAssertTrue(app.switches["reminder_amritVela"].firstMatch.waitForExistence(timeout: 6), "Amrit Vela toggle missing")
        XCTAssertTrue(app.switches["reminder_evening"].firstMatch.exists, "Rehras toggle missing")
        XCTAssertTrue(app.switches["reminder_night"].firstMatch.exists, "Sohila toggle missing")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "no account, no network")).firstMatch.exists,
            "offline reassurance footer missing")
    }

    /// Privacy Policy is reachable inside the app (Guideline 5.1.1(i)): a row in More opens a
    /// static, offline policy screen that states the "Data Not Collected" stance.
    func testPrivacyPolicyReachableFromMore() {
        let app = launchApp(selectSearch: false)
        openTab(app, "More", expectingNavBar: "More")
        let link = app.buttons["privacyPolicyLink"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 12), "Privacy Policy link missing in More")
        XCTAssertTrue(app.buttons["supportLink"].firstMatch.exists, "Support link missing in More")
        link.tap()
        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 8), "Privacy Policy screen did not open")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Data Not Collected")).firstMatch.exists,
            "Privacy Policy screen does not state the Data Not Collected stance")
        XCTAssertTrue(app.links["privacyWebLink"].firstMatch.exists, "online policy link missing")
    }

    /// Rehras variant is a setting: switching to Taksal persists and retitles the row.
    func testRehrasVariantPersists() {
        let app = launchApp(selectSearch: false)
        openTab(app, "More", expectingNavBar: "More")
        let picker = app.buttons["rehrasVariantPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 12), "Rehras variant picker missing")
        picker.tap()
        let taksal = app.buttons["Damdami Taksal"].firstMatch
        XCTAssertTrue(taksal.waitForExistence(timeout: 8))
        taksal.tap()
        openTab(app, "Nitnem", expectingNavBar: "Nitnem")
        XCTAssertTrue(app.buttons["bani_rehras"].firstMatch.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["bani_rehras"].firstMatch.label.contains("Taksal"), "row should show the Taksal variant")
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        XCTAssertTrue(again.navigationBars["Nitnem"].waitForExistence(timeout: 20))
        XCTAssertTrue(again.buttons["bani_rehras"].firstMatch.waitForExistence(timeout: 12))
        XCTAssertTrue(again.buttons["bani_rehras"].firstMatch.label.contains("Taksal"), "variant must persist across relaunch")
    }

    /// Hands-free auto-scroll advances the reading position and pauses on touch.
    func testAutoScrollAdvancesAndPausesOnTouch() {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launchEnvironment["SGGS_AUTOSCROLL_PPS"] = "320"
        app.launch()
        openTab(app, "Nitnem", expectingNavBar: "Nitnem")
        let row = app.buttons["bani_sohila"].firstMatch
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 12), "Sohila row missing")
        row.tap()
        XCTAssertTrue(app.navigationBars["Kirtan Sohila"].waitForExistence(timeout: 12))
        let play = app.buttons["baniAutoScroll"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 8), "auto-scroll control missing")
        XCTAssertEqual(play.label, "Auto-scroll", "starts in the play state")
        play.tap()
        // it is running now — the control shows the pause label
        XCTAssertTrue(waitLabel(app.buttons["baniAutoScroll"].firstMatch, hasPrefix: "Pause", timeout: 6),
                      "tapping play should start auto-scroll")
        // touching the page pauses it — the control returns to the play label
        app.swipeUp()
        XCTAssertTrue(waitLabel(app.buttons["baniAutoScroll"].firstMatch, hasPrefix: "Auto-scroll", timeout: 6),
                      "a touch should pause auto-scroll")
    }

    /// The reading journey opens from the home and shows the month.
    func testJourneyOpens() {
        let app = launchApp(selectSearch: false)
        let card = app.buttons["nitnemJourney"].firstMatch
        for _ in 0..<4 where !(card.exists && card.isHittable) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 12), "journey card missing")
        card.tap()
        XCTAssertTrue(app.navigationBars["Reading journey"].waitForExistence(timeout: 10), "journey did not open")
        XCTAssertTrue(app.staticTexts["Begin today"].waitForExistence(timeout: 6)
                      || app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "together")).firstMatch.exists,
                      "journey header missing")
    }

    /// Contents jumps to a pauri, and the position bar's stanza caption follows.
    func testBaniContentsJumpsToPauri() {
        let app = launchApp(selectSearch: false)
        let row = app.buttons["bani_japji"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        row.tap()
        XCTAssertTrue(app.navigationBars["Japji Sahib"].waitForExistence(timeout: 12))
        app.buttons["baniOptions"].tap()
        let contents = app.buttons["Contents"].firstMatch
        XCTAssertTrue(contents.waitForExistence(timeout: 8), "Contents item missing")
        contents.tap()
        XCTAssertTrue(app.navigationBars["Contents"].waitForExistence(timeout: 8), "Contents sheet did not open")
        // Pauri 5 may sit below the fold — scroll the sheet's own list (swiping the window can
        // just resize the sheet), then tap it.
        let list = app.collectionViews.firstMatch
        let pauri = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pauri 5")).firstMatch
        for _ in 0..<8 where !(pauri.exists && pauri.isHittable) {
            if list.exists { list.swipeUp() } else { app.swipeUp() }
        }
        XCTAssertTrue(pauri.waitForExistence(timeout: 8), "Pauri 5 row missing")
        pauri.tap()
        let stanza = app.staticTexts["baniStanza"].firstMatch
        XCTAssertTrue(waitLabel(stanza, hasPrefix: "Pauri 5", timeout: 10), "stanza caption did not follow the jump")
    }

    // MARK: Explore → Index → a composition's own reader

    /// Open the Index and push a major composition onto the EXPLORE stack: the reader appears on
    /// top of the Index (tab bar unchanged, back returns to the Index), and the saved position is
    /// the same one the Nitnem surface uses.
    func testIndexOpensCompositionReaderOnTheExploreStack() {
        let app = launchApp(selectSearch: false)
        openIndex(app)

        let card = app.buttons["composition_sukhmani"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Sukhmani card missing from the Index")
        card.tap()
        XCTAssertTrue(app.navigationBars["Sukhmani Sahib"].waitForExistence(timeout: 15),
                      "the composition did not open its own reader")
        XCTAssertFalse(app.navigationBars["Ang 262"].exists, "must NOT drop into the Ang reader")
        XCTAssertTrue(tab(app, "Explore").isSelected, "a composition reads inside Explore")

        // Move the position, then go back: Back must land on the Index, not the Explore hub.
        let pos = app.staticTexts["baniPosition"].firstMatch
        XCTAssertTrue(pos.waitForExistence(timeout: 10), "the reading-position bar is missing")
        app.buttons["Next ashtapadi"].firstMatch.tap()
        app.navigationBars["Sukhmani Sahib"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Index"].waitForExistence(timeout: 10),
                      "Back from a composition must return to the Index")

        // Reopening resumes where it was left.
        app.buttons["composition_sukhmani"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Sukhmani Sahib"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["baniPosition"].firstMatch.waitForExistence(timeout: 8))
    }

    /// The closing chrome of a composition belongs to Explore: "Back to Index", never the Nitnem
    /// band's "Back to Nitnem". Uses Lavan (25 lines) so the end is one tap away.
    func testCompositionEndOffersBackToIndexNotNitnem() {
        let app = launchApp(selectSearch: false)
        openIndex(app)

        let row = app.buttons["composition_lavan"].firstMatch
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Lavan missing from More compositions")
        row.tap()
        XCTAssertTrue(app.navigationBars["Lavan"].waitForExistence(timeout: 15))

        app.buttons["End"].firstMatch.tap()
        let markRead = app.buttons["baniMarkComplete"].firstMatch
        for _ in 0..<8 where !(markRead.exists && markRead.isHittable) { app.swipeUp() }
        XCTAssertTrue(markRead.waitForExistence(timeout: 10), "end-of-bani action missing")
        markRead.tap()

        let back = app.buttons["baniBackToIndex"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), "a composition must close back to the Index")
        XCTAssertFalse(app.buttons["baniBackToNitnem"].exists, "Nitnem chrome must not leak into Explore")
        XCTAssertFalse(app.buttons["nitnemNext"].exists, "the time band must not drive a composition read")
        back.tap()
        XCTAssertTrue(app.navigationBars["Index"].waitForExistence(timeout: 10))
    }

    /// Explore hub → Index, waiting for each step (the glass tab bar can swallow a first tap).
    private func openIndex(_ app: XCUIApplication) {
        openTab(app, "Explore", expectingNavBar: "Explore")
        let index = app.buttons["Index"].firstMatch
        XCTAssertTrue(index.waitForExistence(timeout: 10), "Index card missing from Explore")
        index.tap()
        XCTAssertTrue(app.navigationBars["Index"].waitForExistence(timeout: 10))
    }

    /// A bani reopens where the reader left it (progress file), and Start again returns to the top.
    func testBaniProgressResumes() {
        let app = launchApp(selectSearch: false)
        let row = app.buttons["bani_sukhmani"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        row.tap()
        XCTAssertTrue(app.navigationBars["Sukhmani Sahib"].waitForExistence(timeout: 12))
        // Sukhmani steps by its printed rhythm (24 ashtapadis), not by the three registry groups.
        app.buttons["Next ashtapadi"].firstMatch.tap()
        let stanza = app.staticTexts["baniStanza"].firstMatch
        XCTAssertTrue(stanza.waitForExistence(timeout: 8))
        XCTAssertTrue(waitLabel(stanza, hasPrefix: "Ashtapadi 2"), "expected Ashtapadi 2, got \(stanza.label)")
        app.navigationBars.buttons.element(boundBy: 0).tap()          // back (flushes the save)
        XCTAssertTrue(app.buttons["bani_sukhmani"].firstMatch.waitForExistence(timeout: 12))
        app.buttons["bani_sukhmani"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Sukhmani Sahib"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["baniStanza"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(waitLabel(app.staticTexts["baniStanza"].firstMatch, hasPrefix: "Ashtapadi 2"),
                      "position did not resume")
        app.buttons["baniOptions"].tap()
        app.buttons["Start again"].firstMatch.tap()
        XCTAssertTrue(waitLabel(app.staticTexts["baniStanza"].firstMatch, hasPrefix: "Ashtapadi 1"),
                      "Start again should return to the top")
    }

    func testSearchOpensShabad() {
        let app = launchApp()
        let field = focusSearch(app)
        field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20), "no search results appeared")
        firstCell.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 12), "shabad sheet did not open")
        app.buttons["Done"].tap()
    }

    func testVerifyShowsVerdict() {
        let app = launchApp()
        // Type first (the field is guaranteed at launch), THEN switch mode: the search task is
        // keyed on (query, mode) so it re-runs as Verify. Drag the pill row from an always-
        // visible pill (Roman) — the Verify pill is last and off-screen on narrow widths.
        let field = focusSearch(app)
        field.typeText("pavan guroo paanee pitaa maataa dharat mahat")
        let from = app.buttons["mode_roman"].firstMatch
        XCTAssertTrue(from.waitForExistence(timeout: 5))
        from.press(forDuration: 0.05, thenDragTo: app.buttons["mode_auto"].firstMatch)
        let verifyPill = app.buttons["mode_verify"].firstMatch
        XCTAssertTrue(verifyPill.waitForExistence(timeout: 10))
        verifyPill.tap()
        let verified = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "verified")).firstMatch
        XCTAssertTrue(verified.waitForExistence(timeout: 20), "verdict not shown")
    }

    func testReaderTab() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 10))
    }

    func testTrailFromSearch() {
        let app = launchApp()
        let field = focusSearch(app)
        field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20))
        let explore = contextAction(app, on: firstCell, "Explore related")
        explore.tap()
        XCTAssertTrue(app.navigationBars["Related verses"].waitForExistence(timeout: 12),
                      "Trail did not open")
    }

    func testInsights() {
        let app = launchApp()
        openTab(app, "Explore", expectingNavBar: "Explore")
        let insights = app.buttons["Insights"].firstMatch
        XCTAssertTrue(insights.waitForExistence(timeout: 12))
        insights.tap()
        XCTAssertTrue(app.buttons["Contributors"].waitForExistence(timeout: 12), "Insights did not open")
        _ = app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 6)
    }

    func testConstellation() {
        let app = launchApp()
        openTab(app, "Explore", expectingNavBar: "Explore")
        let cons = app.buttons["Constellation"].firstMatch
        XCTAssertTrue(cons.waitForExistence(timeout: 12))
        cons.tap()
        XCTAssertTrue(app.navigationBars["Constellation"].waitForExistence(timeout: 12), "Constellation did not open")
        _ = app.staticTexts.element(boundBy: 2).waitForExistence(timeout: 8)   // let the map render
    }

    /// English layer (personal profile): the English mode pill exists and returns results,
    /// and the More-tab toggle is present. (The public profile hides both — degradation gate.)
    func testEnglishSearchMode() {
        let app = launchApp()
        // toggle first (before typing raises a keyboard over the tab bar)
        openTab(app, "More", expectingNavBar: "More")
        let toggleLabel = app.staticTexts["Show English translation"]
        XCTAssertTrue(toggleLabel.waitForExistence(timeout: 20), "English toggle missing in More")
        openTab(app, "Search", expectingNavBar: "Search")
        let pill = app.buttons["mode_english"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 20), "English mode pill missing (personal profile)")
        // the 4th pill can be clipped on narrow widths — bring the row into view first
        app.buttons["mode_roman"].firstMatch.press(forDuration: 0.05, thenDragTo: app.buttons["mode_auto"].firstMatch)
        pill.tap()
        let field = focusSearch(app)
        field.typeText("mercy")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "english-mode search returned nothing")
    }

    /// Lineage: timeline renders, a profile opens, compare mode produces the ⇄ sheet.
    /// Vaars: the 22 ballads list to an anatomy with pauri/salok units.
    func testLineageAndVaars() {
        let app = launchApp()
        openTab(app, "Explore", expectingNavBar: "Explore")
        let lineage = app.buttons["Lineage"].firstMatch
        XCTAssertTrue(lineage.waitForExistence(timeout: 15)); lineage.tap()
        XCTAssertTrue(app.staticTexts["30 voices · 12th–17th century"].waitForExistence(timeout: 15),
                      "lineage header missing")
        // open a profile
        let farid = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Baba Sheikh Farid")).firstMatch
        XCTAssertTrue(farid.waitForExistence(timeout: 8)); farid.tap()
        // "lines preserved" stat tile always renders once the profile loads (some voices,
        // like Farid, legitimately have no signature-themes section)
        XCTAssertTrue(app.staticTexts["lines preserved"].waitForExistence(timeout: 12), "profile did not load")
        app.buttons["Done"].tap()
        // compare two voices
        app.buttons["compareVoices"].tap()
        farid.tap()
        // Jaidev sits in the same top century group as Farid (List rows are lazy — a
        // far-scrolled voice wouldn't exist in the hierarchy yet)
        let jaidev = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Jaidev,")).firstMatch
        XCTAssertTrue(jaidev.waitForExistence(timeout: 8)); jaidev.tap()
        XCTAssertTrue(app.staticTexts["Theme emphasis (lift)"].waitForExistence(timeout: 12),
                      "compare sheet missing")
        app.buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to Explore
        // vaars
        let vaars = app.buttons["Vaars"].firstMatch
        XCTAssertTrue(vaars.waitForExistence(timeout: 8)); vaars.tap()
        XCTAssertTrue(app.navigationBars["Vaars"].waitForExistence(timeout: 12))
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Anatomy in reading order"].waitForExistence(timeout: 12),
                      "vaar anatomy missing")
    }

    /// Insights completions: network + resonance + flow views render their content.
    func testInsightsVisualizations() {
        let app = launchApp()
        openTab(app, "Explore", expectingNavBar: "Explore")
        let insights = app.buttons["Insights"].firstMatch
        XCTAssertTrue(insights.waitForExistence(timeout: 15)); insights.tap()
        app.buttons["insights_Network"].tap()
        XCTAssertTrue(app.staticTexts["Strongest pairs"].waitForExistence(timeout: 15), "network list missing")
        app.buttons["insights_Resonance"].tap()
        XCTAssertTrue(app.staticTexts["Strongest resonances"].waitForExistence(timeout: 15), "resonance missing")
        // Flow is the last pill in a horizontal row — on narrow widths it sits off-screen
        // (an off-screen XCUIElement has no hit point). Drag the row left first.
        // (`isHittable` itself throws for an off-screen element, so always drag — harmless
        // when the row already fits.)
        app.buttons["insights_Resonance"].firstMatch
            .press(forDuration: 0.05, thenDragTo: app.buttons["insights_Contributors"].firstMatch)
        let flow = app.buttons["insights_Flow"].firstMatch
        XCTAssertTrue(flow.waitForExistence(timeout: 5))
        flow.tap()
        XCTAssertTrue(app.otherElements["progressionRaagPicker"].firstMatch.waitForExistence(timeout: 15)
                      || app.buttons["progressionRaagPicker"].firstMatch.exists
                      || app.staticTexts["Raag"].firstMatch.waitForExistence(timeout: 5),
                      "progression picker missing")
    }

    /// Reader parity: jump-to-Ang (boundary 1430, next disabled), swipe page-turn back.
    func testReaderJumpAndSwipe() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        let jump = app.buttons["jumpToAng"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 15))
        jump.tap()
        enterAng(app, "1430")
        app.buttons["goToAng"].tap()
        XCTAssertTrue(app.navigationBars["Ang 1430"].waitForExistence(timeout: 12), "jump to 1430 failed")
        XCTAssertFalse(app.buttons["Next Ang"].isEnabled, "next must be disabled at Ang 1430")
        // swipe left-to-right = previous Ang
        readerScroll(app).swipeRight()
        XCTAssertTrue(app.navigationBars["Ang 1429"].waitForExistence(timeout: 12), "swipe page-turn failed")
    }

    /// THE regression for the shipped bug: the bottom bar chevrons must turn the page every time —
    /// not just once — and the visible page must always agree with the title. On TestFlight 1.3.0 (2)
    /// the second `nextAng` tap was swallowed (the pager latched) while the title kept counting up.
    func testChevronsTurnPagesRepeatedly() {
        let app = launchApp()
        goReader(app, at: 1180)
        assertOnAng(app, 1180)
        app.buttons["Next Ang"].tap(); assertOnAng(app, 1181, "after Next ×1")
        app.buttons["Next Ang"].tap(); assertOnAng(app, 1182, "after Next ×2")   // died here on 1.3.0
        app.buttons["Next Ang"].tap(); assertOnAng(app, 1183, "after Next ×3")
        app.buttons["Previous Ang"].tap(); assertOnAng(app, 1182, "after Prev ×1")
        app.buttons["Previous Ang"].tap(); assertOnAng(app, 1181, "after Prev ×2")
    }

    /// The end-of-page forward pill (the other control that died) turns the page and names the right
    /// Ang: on 1181 it reads "Continues on Ang 1182" and lands there; the next page's forward footer
    /// then advances to 1183.
    func testContinuationPillGoesToNextAng() {
        let app = launchApp()
        goReader(app, at: 1181)
        assertOnAng(app, 1181)
        // Ang 1181's shabad continues onto 1182 (verified in the DB), so the forward footer is the
        // "Continues on Ang 1182" pill; reach it by scrolling to the bottom of the page.
        var pill = hittable(app, button: "continuesOnPill", timeout: 1)
        for _ in 0..<12 where pill == nil { dragReaderUp(app); pill = hittable(app, button: "continuesOnPill", timeout: 1) }
        XCTAssertNotNil(pill, "Continues-on pill should be reachable on Ang 1181")
        XCTAssertTrue(pill!.label.contains("1182"), "the pill must name the NEXT Ang, not the current one")
        pill!.tap()
        assertOnAng(app, 1182, "after tapping Continues-on")
        // the forward footer on 1182 (continues or plain "Next ·") advances to 1183
        var fwd = forwardFooter(app)
        for _ in 0..<12 where fwd == nil { dragReaderUp(app); fwd = forwardFooter(app) }
        XCTAssertNotNil(fwd, "every Ang before 1430 must offer a forward control")
        fwd!.tap()
        assertOnAng(app, 1183, "after tapping the forward footer")
    }

    /// Several fast chevron taps must not desync the pager (the title and the visible page still agree,
    /// and no self-heal was needed — `assertOnAng` requires `-h0`).
    func testRapidChevronTapsStayInSync() {
        let app = launchApp()
        goReader(app, at: 700)
        for _ in 0..<5 { app.buttons["Next Ang"].tap() }
        assertOnAng(app, 705, "after 5 rapid Next taps")
    }

    /// Bounds: at Ang 1 Previous is disabled and a swipe-right rubber-bands; at Ang 1430 Next is
    /// disabled and Previous still works.
    func testReaderBoundsAndRubberBand() {
        let app = launchApp()
        goReader(app, at: 1)
        assertOnAng(app, 1)
        XCTAssertFalse(app.buttons["Previous Ang"].isEnabled, "Previous must be disabled at Ang 1")
        readerScroll(app).swipeRight()
        assertOnAng(app, 1, "rubber-band: still on Ang 1 after swiping past the start")
        goReader(app, at: 1430)
        assertOnAng(app, 1430)
        XCTAssertFalse(app.buttons["Next Ang"].isEnabled, "Next must be disabled at Ang 1430")
        app.buttons["Previous Ang"].tap()
        assertOnAng(app, 1429, "Previous still works at the end")
    }

    /// Navigation stays correct around a sheet and after backgrounding: a deep link dismisses a
    /// covering Hukam sheet and lands on the Reader, and a chevron tap survives background→foreground.
    func testReaderNavAroundSheetAndBackground() {
        let app = launchApp()
        goReader(app, at: 300)
        // open Hukam, then deep-link elsewhere — the sheet must not hide the destination
        app.buttons["Hukam"].tap()
        XCTAssertTrue(app.buttons["Done"].firstMatch.waitForExistence(timeout: 12), "Hukam sheet did not open")
        XCUIDevice.shared.system.open(URL(string: "sggs://ang/900")!)
        assertOnAng(app, 900, "deep link must land on the Reader, not behind the Hukam sheet")
        // background and return, then keep navigating
        XCUIDevice.shared.press(.home)
        app.activate()
        assertOnAng(app, 900, "state preserved across background")
        app.buttons["Next Ang"].tap()
        assertOnAng(app, 901, "chevrons work after foregrounding")
    }

    /// Open Reader → jump to an Ang that continues a shabad (164) → the "Shabad starts on Ang N"
    /// pill is a real control that navigates back to the shabad's start (163). Regression guard for
    /// the dead-label bug where this chip did nothing on any Ang.
    func testContinuesFromPillGoesToShabadStart() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        let jump = app.buttons["jumpToAng"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 15)); jump.tap()
        let field = app.textFields["angField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap(); field.typeText("164")
        app.buttons["goToAng"].tap()
        XCTAssertTrue(app.navigationBars["Ang 164"].waitForExistence(timeout: 12), "jump to 164 failed")
        // Query the HITTABLE pill: the neighbour page 165 also mounts a continuesFromPill, so
        // `firstMatch` could hit the wrong one.
        let pill = hittable(app, button: "continuesFromPill")
        XCTAssertNotNil(pill, "Continues-from pill missing on Ang 164")
        pill!.tap()
        XCTAssertTrue(app.navigationBars["Ang 163"].waitForExistence(timeout: 12),
                      "Continues-from pill did not navigate to the shabad's start Ang")
    }

    /// The Jump sheet's fine-tune steppers reach an exact Ang without typing, and the primary
    /// action restates the destination ("Go to Ang 12") and lands there.
    func testJumpSteppersAndGoLabel() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        let jump = app.buttons["jumpToAng"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 15)); jump.tap()
        let go = app.buttons["goToAng"].firstMatch
        XCTAssertTrue(go.waitForExistence(timeout: 8))
        // from Ang 1: +10, +1 → 12
        app.buttons["Forward 10"].firstMatch.tap()
        app.buttons["Forward 1"].firstMatch.tap()
        XCTAssertTrue(waitLabel(go, hasPrefix: "Go to Ang 12", timeout: 6),
                      "Go label should restate the destination, got \(go.label)")
        go.tap()
        XCTAssertTrue(app.navigationBars["Ang 12"].waitForExistence(timeout: 12), "steppers did not land on Ang 12")
    }

    /// At the largest accessibility text size the Jump sheet stays usable: the primary Go action
    /// is present and hittable (nothing truncates it off-screen).
    func testJumpSheetAtAX5() {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 15), "Reader did not open")
        let jump = app.buttons["jumpToAng"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 15)); jump.tap()
        let go = app.buttons["goToAng"].firstMatch
        XCTAssertTrue(go.waitForExistence(timeout: 10), "Go action missing at AX5")
        XCTAssertTrue(go.isHittable, "Go action must stay hittable at the largest text size")
    }

    /// The bottom bar's "Ang N of 1430" progress control is a third, thumb-reachable way into Jump.
    func testReaderProgressOpensJump() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        // the "Ang N of 1430" progress control (a button whose label is the count text)
        let progress = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "of 1430")).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 12), "progress control missing")
        progress.tap()
        XCTAssertTrue(app.textFields["angField"].waitForExistence(timeout: 8), "progress control did not open Jump")
    }

    /// The never-stranded end-of-page footer turns the page from the bottom of the content.
    func testEndOfPageFooterTurnsPage() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        let scroll = app.scrollViews.firstMatch
        let next = app.buttons["endNextAng"].firstMatch
        for _ in 0..<8 where !(next.exists && next.isHittable) { scroll.swipeUp() }
        XCTAssertTrue(next.waitForExistence(timeout: 8), "end-of-page next button missing")
        next.tap()
        XCTAssertTrue(app.navigationBars["Ang 2"].waitForExistence(timeout: 12), "end-of-page footer did not turn the page")
    }

    /// Reading options open a popover with the in-Reader text-size control (A− / A+).
    func testReadingOptionsTextSize() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        app.buttons["readerOptions"].firstMatch.tap()
        let larger = app.buttons["textLarger"].firstMatch
        XCTAssertTrue(larger.waitForExistence(timeout: 8), "text-size control missing in reading options")
        XCTAssertTrue(larger.isHittable)
        larger.tap()                                   // bumps sggs_gurmukhi_size
        XCTAssertTrue(app.buttons["textSmaller"].firstMatch.isHittable, "A− control missing")
    }

    /// Raag Clock: pinned wall clock (16:40 → 4th pahar of day), now card + pahar list +
    /// detail sheet + divergence sheet all reachable.
    func testRaagClock() {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_CLOCK_NOW"] = "1000"     // 16:40 → pahar 4 (3–6 PM)
        app.launchEnvironment["SGGS_CLOCK_MODE"] = "fixed"   // a stored Solar choice must not change the strings
        app.launchEnvironment["SGGS_UITEST"] = "1"
        // the clock renders in the READER'S locale (12/24-h, am/pm casing); pin en_US so the
        // strings below are the same on every developer's simulator, not only CI's
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        openClock(app)
        XCTAssertTrue(app.staticTexts["What raag is it now?"].waitForExistence(timeout: 20), "now card missing")
        XCTAssertTrue(app.staticTexts["4th pahar of day  ·  3–6 PM"].waitForExistence(timeout: 8),
                      "pinned pahar/window line missing")
        // the live local clock in the dial's hollow: the pinned minute (16:40) on the reader's
        // own clock, the watch and the countdown, as one accessibility element
        let readout = app.otherElements["clockNowReadout"].firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 8), "dial readout missing")
        XCTAssertTrue(readout.label.contains("4:40 PM"), "readout should show the pinned local time, got: \(readout.label)")
        XCTAssertTrue(readout.label.contains("4th pahar of day"), "readout should name the current watch")
        XCTAssertTrue(readout.label.contains("Next watch, 1st pahar of night"), "readout should name the next watch")
        // the current watch's raags are a readable list under the clock (never clipped chips)
        let raagRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Raag ")).firstMatch
        XCTAssertTrue(raagRow.waitForExistence(timeout: 8), "\"Sung in this watch\" list missing")
        XCTAssertTrue(raagRow.label.contains("read from Ang"), "raag rows lead into the Granth")
        // the accessible pahar list is the content path — open P7 (deliberately silent)
        let p7 = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "3rd pahar of night")).firstMatch
        XCTAssertTrue(p7.waitForExistence(timeout: 8), "pahar list missing")
        p7.tap()
        XCTAssertTrue(app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Deliberately silent")).firstMatch
            .waitForExistence(timeout: 8), "P7 empty-state missing")
        app.buttons["Done"].tap()
        // divergence sheet
        let div = app.buttons["divergenceLink"].firstMatch
        XCTAssertTrue(div.waitForExistence(timeout: 8))
        div.tap()
        XCTAssertTrue(app.navigationBars["Where traditions disagree"].waitForExistence(timeout: 10),
                      "divergence sheet did not open")
    }

    /// Solar is the default. With no stored location the clock shows the fixed watches and the
    /// one-tap location card — location is never requested on its own.
    func testRaagClockDefaultsToSolarPrompt() {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_CLOCK_NOW"] = "1000"
        app.launchEnvironment["SGGS_CLOCK_MODE"] = "solar"
        app.launchEnvironment["SGGS_CLOCK_NO_COORDS"] = "1"   // DEBUG: ignore any stored location
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        openClock(app)
        XCTAssertTrue(app.buttons["useMyLocation"].waitForExistence(timeout: 20), "one-tap location card missing")
        XCTAssertTrue(app.buttons["enterLocationManually"].exists)
        XCTAssertTrue(app.staticTexts["4th pahar of day  ·  3–6 PM"].waitForExistence(timeout: 8),
                      "with no location the fixed windows are shown")
    }

    /// The Explore hub reaches every browse surface (nav-restructure gate).
    func testExploreHubReachesEverySurface() {
        let app = launchApp()
        openTab(app, "Explore", expectingNavBar: "Explore")
        for (card, marker) in [("Index", "Index"), ("Themes", "Themes"), ("Raag Clock", "Raag Clock")] {
            let btn = app.buttons[card].firstMatch
            XCTAssertTrue(btn.waitForExistence(timeout: 12), "\(card) card missing")
            btn.tap()
            XCTAssertTrue(app.navigationBars[marker].waitForExistence(timeout: 12), "\(card) did not open")
            app.navigationBars.buttons.element(boundBy: 0).tap()   // back
        }
    }

    /// Regression for the consolidated single root sheet: opening a shabad from INSIDE the Trail must
    /// swap the one sheet (not drop it, as two competing `.sheet(item:)` modifiers did).
    func testTrailOpenSwapsToShabad() {
        let app = launchApp()
        let field = focusSearch(app)
        field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20))
        let explore = contextAction(app, on: firstCell, "Explore related")
        explore.tap()
        XCTAssertTrue(app.navigationBars["Related verses"].waitForExistence(timeout: 12))
        let openBtn = app.buttons["Open"].firstMatch
        XCTAssertTrue(openBtn.waitForExistence(timeout: 5), "pinned Open button missing")
        openBtn.tap()                                              // pinned-verse Open → swap to shabad
        // the single sheet must swap to a shabad (nav title "Ang N"), not be dropped
        let shabadBar = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Ang ")).firstMatch
        XCTAssertTrue(shabadBar.waitForExistence(timeout: 12), "Trail→Open did not surface the shabad (dropped sheet)")
    }

    func testSettingsControls() {
        let app = launchApp()
        openTab(app, "More", expectingNavBar: "More")
        XCTAssertTrue(app.switches["translitToggle"].waitForExistence(timeout: 12), "translit toggle missing")
        XCTAssertTrue(app.sliders["gurmukhiSizeSlider"].exists, "size slider missing")
        app.switches["translitToggle"].tap()                       // hide transliteration
        openTab(app, "Search", expectingNavBar: "Search")
        let field = focusSearch(app)
        field.typeText("naam")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "results must still render with translit hidden")
    }

    /// Accent picker (premium pass): switching accents re-tints live via \.palette environment
    /// injection and persists across launches; navigation state must survive the switch.
    func testAccentPickerSwitchesAndPersists() {
        let app = launchApp()
        openTab(app, "More", expectingNavBar: "More")
        let indigo = app.buttons["Indigo accent"]
        if !indigo.waitForExistence(timeout: 8) { app.swipeUp() }
        XCTAssertTrue(indigo.waitForExistence(timeout: 8))
        indigo.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@ AND selected == 1", "Indigo accent"))
                        .firstMatch.waitForExistence(timeout: 4), "swatch must show selected")
        // still on More (no navigation reset), and the app survives a relaunch with the choice
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 4))
        app.terminate(); app.launch()
        openTab(app, "More", expectingNavBar: "More")
        if !app.buttons["Indigo accent"].waitForExistence(timeout: 8) { app.swipeUp() }
        XCTAssertTrue(app.buttons["Indigo accent"].isSelected, "accent choice must persist")
        // restore the default for subsequent tests/captures
        app.buttons["Saffron accent"].tap()
    }

    // MARK: pre-TestFlight hardening (2026-09)

    /// The Search tab must never be a blank pane: idle shows guidance, and the mode pills
    /// change that guidance.
    func testSearchIdleStateShowsExamples() {
        let app = launchApp()
        XCTAssertTrue(app.otherElements["searchIdle"].firstMatch.waitForExistence(timeout: 20)
                      || app.staticTexts["Search the Granth"].waitForExistence(timeout: 5), "idle guidance missing")
        // Roman is the third pill — always on screen (Theme/Verify scroll off on narrow widths)
        app.buttons["mode_roman"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Roman"].firstMatch.waitForExistence(timeout: 5), "mode-specific guidance missing")
    }

    /// Save a verse (context menu) → More → Saved verses lists it → opens its composition →
    /// Done returns to Saved → swipe-delete removes it (SwiftData store round trip).
    func testSavedVerseRoundTrip() {
        let app = launchApp()
        let field = focusSearch(app)
        field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20))
        let save = contextAction(app, on: firstCell, "Save")
        save.tap()
        field.typeText("\n")                                     // keyboard covers the tab bar
        openTab(app, "More", expectingNavBar: "More")
        let saved = app.buttons["Saved verses"].firstMatch
        for _ in 0..<3 where !saved.exists { app.swipeUp() }     // below the Nitnem + Display sections
        XCTAssertTrue(saved.waitForExistence(timeout: 10))
        // the row can sit under the floating tab bar — bring it clear, then verify the push
        for _ in 0..<3 where !app.navigationBars["Saved"].exists {
            app.swipeUp(); saved.tap()
            _ = app.navigationBars["Saved"].waitForExistence(timeout: 4)
        }
        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 6), "Saved did not open")
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "saved verse not listed")
        row.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 12), "composition did not open from Saved")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 8), "Done must return to Saved")
        row.swipeLeft()
        let del = app.buttons["Delete"].firstMatch
        XCTAssertTrue(del.waitForExistence(timeout: 5)); del.tap()
        XCTAssertTrue(app.staticTexts["No saved verses"].waitForExistence(timeout: 8), "delete did not empty the list")
    }

    /// Every composition sheet's Done returns to exactly where the reader was.
    func testShabadDoneReturnsToOrigin() {
        let app = launchApp()
        tab(app, "Reader").tap(); XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12), "Reader did not open")
        let hukam = app.buttons["Hukam"]
        XCTAssertTrue(hukam.waitForExistence(timeout: 15)); hukam.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 12))
        app.buttons["Done"].tap()
        XCTAssertTrue(hukam.waitForExistence(timeout: 8), "Done must return to the Reader")
        // Reader-only chrome proves we are back where we started (not on another tab/sheet)
        XCTAssertTrue(app.buttons["jumpToAng"].firstMatch.waitForExistence(timeout: 8), "Reader toolbar must be back")
        XCTAssertFalse(app.buttons["Done"].waitForExistence(timeout: 2), "the sheet must be gone")
    }

    /// The About screen shows "<CFBundleShortVersionString>+<CFBundleVersion>". The test bundle's
    /// own Info.plist carries the same MARKETING_VERSION / CURRENT_PROJECT_VERSION as the app
    /// (see SGGSUITests `info:` in project.yml), so we assert against what was *built* — including
    /// the per-archive build number — instead of a literal that has to be hand-edited every bump.
    /// Mirrors LaunchIntegrity.bundleVersionString's "short+build" format on purpose: a change to
    /// that format should fail here (the UI-test target can't import the app to share the helper).
    private func expectedVersionLabel() -> String {
        let info = Bundle(for: type(of: self)).infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short)+\(build)"
    }

    /// Testers must be able to report which build they are on.
    func testAboutShowsVersion() {
        let expected = expectedVersionLabel()
        XCTAssertTrue(
            expected.range(of: "^[0-9]+\\.[0-9]+\\.[0-9]+\\+[0-9]+$", options: .regularExpression) != nil,
            "UI-test bundle Info.plist is not carrying MARKETING_VERSION/CURRENT_PROJECT_VERSION "
            + "(got \(expected)) — check the SGGSUITests `info:` block in project.yml"
        )
        let app = launchApp()
        openTab(app, "More", expectingNavBar: "More")
        let about = app.buttons["About & credits"].firstMatch
        for _ in 0..<3 where !about.exists { app.swipeUp() }     // last row: below Nitnem + Display
        XCTAssertTrue(about.waitForExistence(timeout: 12))
        app.swipeUp()                                   // last row can sit under the floating tab bar
        XCTAssertTrue(about.waitForExistence(timeout: 4)); about.tap()
        let v = app.staticTexts["aboutVersion"].firstMatch
        XCTAssertTrue(v.waitForExistence(timeout: 8), "version line missing")
        XCTAssertTrue(v.label.contains(expected), "expected \(expected), got version label: \(v.label)")
    }

    /// A deep link arriving while the app runs must open the Hukam sheet (no production hook:
    /// the system opens the URL exactly as a widget/Siri/Spotlight would).
    func testDeepLinkOpensHukam() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 20))
        XCUIDevice.shared.system.open(URL(string: "sggs://hukam")!)
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Hukam")).firstMatch
                        .waitForExistence(timeout: 15), "sggs://hukam did not open the Hukam sheet")
        app.buttons["Done"].tap()
    }

    // MARK: Reader & Shabad UX pass

    /// Tapping a verse opens its composition scrolled to THAT verse; "Open Ang N in Reader" lands
    /// the Reader on the same verse.
    func testSearchResultOpensShabadAtLine() {
        let app = launchApp()
        let field = focusSearch(app); field.typeText("naam")
        let verses = app.cells.matching(NSPredicate(format: "NOT (label BEGINSWITH %@)", "Related themes"))
        XCTAssertTrue(verses.element(boundBy: 2).waitForExistence(timeout: 20), "need at least 3 results")
        field.typeText("\n")                       // keyboard down: the 3rd row must not sit under it
        let target = verses.element(boundBy: 2)
        // List cells carry no label of their own; the LineRow inside is the labelled element
        // (its label starts with the verbatim Gurmukhi)
        // pick the element whose label is the verbatim Gurmukhi (starts in the Gurmukhi block)
        let gurmukhiLabelled = NSPredicate(format: "label MATCHES %@", "^[\\u0A00-\\u0A7F].*")
        let key = String(target.descendants(matching: .any).matching(gurmukhiLabelled).firstMatch.label.prefix(20))
        XCTAssertFalse(key.isEmpty, "could not read the verse label")
        target.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 12), "sheet did not open")
        let inSheet = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", key)).firstMatch
        XCTAssertTrue(inSheet.waitForExistence(timeout: 8), "tapped verse missing from the sheet")
        XCTAssertTrue(inSheet.isHittable, "tapped verse must be scrolled on screen")
        let openBtn = app.buttons["openInReader"].firstMatch      // fixed footer — no scrolling needed
        XCTAssertTrue(openBtn.waitForExistence(timeout: 5), "Open Ang button missing")
        let angLabel = openBtn.label.replacingOccurrences(of: " in Reader", with: "").replacingOccurrences(of: "Open ", with: "")
        openBtn.tap()
        XCTAssertTrue(app.navigationBars[angLabel].waitForExistence(timeout: 12), "Reader did not open \(angLabel)")
        let inReader = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", key)).firstMatch
        XCTAssertTrue(inReader.waitForExistence(timeout: 8), "Reader did not land on the verse")
        XCTAssertTrue(inReader.isHittable, "landed verse must be on screen")
    }

    /// Ambient chrome: reading downwards hides the navigation bar; scrolling back reveals it.
    /// The bottom reading chrome (Prev · Hukam · Next) fades while reading downward and returns on
    /// scroll-up. With the finger-tracked pager the top navigation bar deliberately PERSISTS (the
    /// Ang number + Go/AA stay for orientation; the nav bar is never toggled from scroll — that
    /// caused the 120 Hz watchdog freeze), so the immersive-reading affordance is the bottom bar.
    func testReaderChromeReturnsOnScrollUp() {
        let app = launchApp()
        tab(app, "Reader").tap()
        let hukam = app.buttons["Hukam"].firstMatch      // lives in the bottom page bar
        XCTAssertTrue(hukam.waitForExistence(timeout: 15))
        XCTAssertTrue(hukam.isHittable, "chrome should start visible")
        let scroll = app.scrollViews.firstMatch
        scroll.swipeUp(); scroll.swipeUp()
        // faded chrome keeps `exists` true (opacity 0) but is not hittable — assert on that.
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == false"), object: hukam)
        XCTAssertEqual(XCTWaiter().wait(for: [hidden], timeout: 5), .completed, "bottom chrome should hide while reading down")
        scroll.swipeDown()
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: hukam)
        XCTAssertEqual(XCTWaiter().wait(for: [shown], timeout: 5), .completed, "chrome must return on scroll up")
    }

    /// A deep link must beat resume-last-Ang even on a launch WITHOUT the test env (which
    /// would itself clear the resume state): control relaunch resumes 1430, linked launch → 7.
    func testDeepLinkAngBeatsResume() {
        let app = launchApp()
        tab(app, "Reader").tap()
        let jump = app.buttons["jumpToAng"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 15)); jump.tap()
        let field = app.textFields["angField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("1430")
        app.buttons["goToAng"].tap()
        XCTAssertTrue(app.navigationBars["Ang 1430"].waitForExistence(timeout: 12))
        app.terminate()
        let plain = XCUIApplication(); plain.launch()          // no SGGS_UITEST: resume is live
        tab(plain, "Reader").tap()
        XCTAssertTrue(plain.navigationBars["Ang 1430"].waitForExistence(timeout: 15), "control: resume must work")
        plain.terminate()
        plain.launch()
        XCUIDevice.shared.system.open(URL(string: "sggs://ang/7")!)
        tab(plain, "Reader").tap()
        XCTAssertTrue(plain.navigationBars["Ang 7"].waitForExistence(timeout: 15), "deep link must beat resume")
        plain.terminate()
    }

    /// Two near-simultaneous verse taps must leave exactly one dismissable sheet and a
    /// re-armed presenter (never a stranded modal state).
    func testRapidTapsNeverStrandSheets() {
        let app = launchApp()
        let field = focusSearch(app); field.typeText("naam")
        let verses = app.cells.matching(NSPredicate(format: "NOT (label BEGINSWITH %@)", "Related themes"))
        XCTAssertTrue(verses.element(boundBy: 1).waitForExistence(timeout: 20))
        field.typeText("\n")                       // keyboard down before coordinate taps
        let a = verses.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let b = verses.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        a.tap(); b.tap()
        XCTAssertTrue(app.buttons["Done"].firstMatch.waitForExistence(timeout: 12), "a sheet must be up")
        XCTAssertEqual(app.buttons.matching(identifier: "Done").count, 1, "exactly one sheet")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertFalse(app.buttons["Done"].waitForExistence(timeout: 3), "sheet must dismiss")
        verses.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 12), "presenting must stay armed")
        app.buttons["Done"].tap()
    }

    /// Captures reference screenshots (not an assertion gate). Written to the simulator's tmp
    /// dir — pull with `xcrun simctl get_app_container` or read the test attachments.
    /// Set SGGS_SHOT_TAG in the runner env to prefix filenames (disambiguates light/dark runs
    /// when harvesting with `find` — identical names across runs/containers mix otherwise).
    func testCaptureScreens() {
        // Simulator processes share the host filesystem: TEST_RUNNER_SGGS_SHOT_DIR points the
        // captures at a host directory (default: the runner's tmp).
        let dir = ProcessInfo.processInfo.environment["SGGS_SHOT_DIR"] ?? NSTemporaryDirectory()
        let tag = ProcessInfo.processInfo.environment["SGGS_SHOT_TAG"].map { "\($0)_" } ?? ""
        let app = launchApp()
        // SGGS_SHOT_LANDSCAPE=1 rotates the running app before capturing (iPad regular-width
        // landscape gate); the orientation is applied to the foreground app, so after launch.
        if ProcessInfo.processInfo.environment["SGGS_SHOT_LANDSCAPE"] == "1" {
            XCUIDevice.shared.orientation = .landscapeLeft
            _ = app.navigationBars["Search"].waitForExistence(timeout: 8)
        }
        func shot(_ name: String) {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(tag)\(name).png"))
        }
        let field = focusSearch(app)
        field.typeText("naam")
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
        shot("search_results")
        // Dismiss the keyboard via the return key — it covers the tab bar (a swipe would
        // dismiss it too, but iOS 26 minimises the floating tab bar during scroll and the
        // Reader tap lands on nothing; both failure modes are silent).
        field.typeText("\n")
        // iPadOS 26 keeps the tab bar hidden while search is active — leave search explicitly
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
        shot("after_search")
        print("[SGGS shots] \(dir)")
        let readerTab = tab(app, "Reader")
        if !readerTab.waitForExistence(timeout: 8) {
            print("[SGGS hierarchy]\n" + String(app.debugDescription.prefix(6000)))
            XCTFail("Reader tab missing after search")
        }
        readerTab.tap()
        if !app.buttons["Hukam"].waitForExistence(timeout: 12) {
            shot("reader_missing_hukam")
            print("[SGGS hierarchy]\n" + String(app.debugDescription.prefix(6000)))
            XCTFail("Reader must actually open before its screenshot")
        }
        _ = app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 8)
        shot("reader")
        openClock(app)
        _ = app.staticTexts["What raag is it now?"].waitForExistence(timeout: 12)
        shot("clock")
        app.navigationBars.buttons.firstMatch.tap()   // back to the hub
        openTab(app, "Nitnem", expectingNavBar: "Nitnem")
        _ = app.buttons["bani_japji"].waitForExistence(timeout: 12)
        shot("nitnem_home")
        app.buttons["bani_japji"].firstMatch.tap()
        _ = app.navigationBars["Japji Sahib"].waitForExistence(timeout: 12)
        _ = app.staticTexts.element(boundBy: 2).waitForExistence(timeout: 8)
        shot("bani_reader")
        app.navigationBars.buttons.firstMatch.tap()   // back to Nitnem
        openTab(app, "Explore", expectingNavBar: "Explore")
        _ = app.staticTexts["Explore the Granth"].waitForExistence(timeout: 8)
        shot("explore_hub")
        let index = app.buttons["Index"].firstMatch
        if index.waitForExistence(timeout: 8) { index.tap() }
        _ = app.navigationBars["Index"].waitForExistence(timeout: 8)
        _ = app.staticTexts["MAJOR COMPOSITIONS"].waitForExistence(timeout: 8)
        shot("index")
        // A major composition opens its own reader on the Explore stack (Index → composition).
        let composition = app.buttons["composition_sukhmani"].firstMatch
        if composition.waitForExistence(timeout: 8) {
            composition.tap()
            _ = app.navigationBars["Sukhmani Sahib"].waitForExistence(timeout: 15)
            _ = app.staticTexts["baniPosition"].firstMatch.waitForExistence(timeout: 8)
            shot("composition_reader")
            app.navigationBars.buttons.firstMatch.tap()   // back to the Index
            _ = app.navigationBars["Index"].waitForExistence(timeout: 8)
        }
        app.navigationBars.buttons.firstMatch.tap()   // back to the hub
        let themes = app.buttons["Themes"].firstMatch
        if themes.waitForExistence(timeout: 8) { themes.tap() }
        _ = app.navigationBars["Themes"].waitForExistence(timeout: 8)
        shot("themes")
        app.navigationBars.buttons.firstMatch.tap()   // back to the hub
        let lineage = app.buttons["Lineage"].firstMatch
        if lineage.waitForExistence(timeout: 8) { lineage.tap() }
        _ = app.staticTexts["30 voices · 12th–17th century"].waitForExistence(timeout: 8)
        shot("lineage")
        openTab(app, "More", expectingNavBar: "More")
        _ = app.staticTexts["Accent"].waitForExistence(timeout: 8)
        shot("more_display")
    }
}
