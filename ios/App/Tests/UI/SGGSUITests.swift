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
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launch()
        return app
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

    func testLaunchShowsSearch() {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 20))
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
        let field = app.textFields["angField"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap(); field.typeText("1430")
        app.buttons["goToAng"].tap()
        XCTAssertTrue(app.navigationBars["Ang 1430"].waitForExistence(timeout: 12), "jump to 1430 failed")
        XCTAssertFalse(app.buttons["Next Ang"].isEnabled, "next must be disabled at Ang 1430")
        // swipe left-to-right = previous Ang
        app.scrollViews.firstMatch.swipeRight()
        XCTAssertTrue(app.navigationBars["Ang 1429"].waitForExistence(timeout: 12), "swipe page-turn failed")
    }

    /// Raag Clock: pinned wall clock (16:40 → 4th pahar of day), now card + pahar list +
    /// detail sheet + divergence sheet all reachable.
    func testRaagClock() {
        let app = XCUIApplication()
        app.launchEnvironment["SGGS_CLOCK_NOW"] = "1000"     // 16:40 → pahar 4 (3–6 PM)
        app.launchEnvironment["SGGS_UITEST"] = "1"
        app.launch()
        openTab(app, "Clock", expectingNavBar: "Raag Clock")
        XCTAssertTrue(app.staticTexts["What raag is it now?"].waitForExistence(timeout: 20), "now card missing")
        XCTAssertTrue(app.staticTexts["4th pahar of day  ·  3–6 PM"].waitForExistence(timeout: 8),
                      "pinned pahar/window line missing")
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

    /// The Explore hub reaches every browse surface (nav-restructure gate).
    func testExploreHubReachesEverySurface() {
        let app = launchApp()
        openTab(app, "Explore", expectingNavBar: "Explore")
        for (card, marker) in [("Index", "Index"), ("Themes", "Themes")] {
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

    /// Testers must be able to report which build they are on.
    func testAboutShowsVersion() {
        let app = launchApp()
        openTab(app, "More", expectingNavBar: "More")
        let about = app.buttons["About & credits"].firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 12))
        app.swipeUp()                                   // last row can sit under the floating tab bar
        XCTAssertTrue(about.waitForExistence(timeout: 4)); about.tap()
        let v = app.staticTexts["aboutVersion"].firstMatch
        XCTAssertTrue(v.waitForExistence(timeout: 8), "version line missing")
        XCTAssertTrue(v.label.contains("1.1.3+1"), "unexpected version label: \(v.label)")
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
    func testReaderChromeReturnsOnScrollUp() {
        let app = launchApp()
        tab(app, "Reader").tap()
        let jump = app.buttons["jumpToAng"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout: 15))
        let scroll = app.scrollViews.firstMatch
        scroll.swipeUp(); scroll.swipeUp()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == 0"), object: jump)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "chrome should hide while reading down")
        scroll.swipeDown()
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "chrome must return on scroll up")
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
        openTab(app, "Clock", expectingNavBar: "Raag Clock")
        _ = app.staticTexts["What raag is it now?"].waitForExistence(timeout: 12)
        shot("clock")
        openTab(app, "Explore", expectingNavBar: "Explore")
        _ = app.staticTexts["Explore the Granth"].waitForExistence(timeout: 8)
        shot("explore_hub")
        let index = app.buttons["Index"].firstMatch
        if index.waitForExistence(timeout: 8) { index.tap() }
        _ = app.navigationBars["Index"].waitForExistence(timeout: 8)
        _ = app.staticTexts["MAJOR COMPOSITIONS — QUICK ACCESS"].waitForExistence(timeout: 8)
        shot("index")
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
