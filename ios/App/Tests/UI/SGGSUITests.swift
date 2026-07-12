import XCTest

final class SGGSUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunchShowsSearch() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 20))
    }

    func testSearchOpensShabad() {
        let app = XCUIApplication(); app.launch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap(); field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20), "no search results appeared")
        firstCell.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 12), "shabad sheet did not open")
        app.buttons["Done"].tap()
    }

    func testVerifyShowsVerdict() {
        let app = XCUIApplication(); app.launch()
        let verifyPill = app.buttons["mode_verify"].firstMatch
        XCTAssertTrue(verifyPill.waitForExistence(timeout: 20))
        // the Verify pill is last in the horizontal mode row — scroll the row, then tap
        let from = app.buttons["mode_first"].firstMatch
        if from.exists { from.press(forDuration: 0.05, thenDragTo: app.buttons["mode_auto"].firstMatch) }
        verifyPill.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText("pavan guroo paanee pitaa maataa dharat mahat")
        let verified = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "verified")).firstMatch
        XCTAssertTrue(verified.waitForExistence(timeout: 20), "verdict not shown")
    }

    func testReaderTab() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Reader"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 10))
    }

    func testTrailFromSearch() {
        let app = XCUIApplication(); app.launch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap(); field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20))
        firstCell.press(forDuration: 1.1)                 // long-press → context menu
        let explore = app.buttons["Explore related"]
        XCTAssertTrue(explore.waitForExistence(timeout: 8))
        explore.tap()
        XCTAssertTrue(app.navigationBars["Related verses"].waitForExistence(timeout: 12),
                      "Trail did not open")
    }

    func testInsights() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Explore"].tap()
        let insights = app.buttons["Insights"].firstMatch
        XCTAssertTrue(insights.waitForExistence(timeout: 12))
        insights.tap()
        XCTAssertTrue(app.buttons["Contributors"].waitForExistence(timeout: 12), "Insights did not open")
        _ = app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 6)
    }

    func testConstellation() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Explore"].tap()
        let cons = app.buttons["Constellation"].firstMatch
        XCTAssertTrue(cons.waitForExistence(timeout: 12))
        cons.tap()
        XCTAssertTrue(app.navigationBars["Constellation"].waitForExistence(timeout: 12), "Constellation did not open")
        _ = app.staticTexts.element(boundBy: 2).waitForExistence(timeout: 8)   // let the map render
    }

    /// English layer (personal profile): the English mode pill exists and returns results,
    /// and the More-tab toggle is present. (The public profile hides both — degradation gate.)
    func testEnglishSearchMode() {
        let app = XCUIApplication(); app.launch()
        // toggle first (before typing raises a keyboard over the tab bar)
        app.tabBars.buttons["More"].tap()
        let toggleLabel = app.staticTexts["Show English translation"]
        XCTAssertTrue(toggleLabel.waitForExistence(timeout: 20), "English toggle missing in More")
        app.tabBars.buttons["Search"].tap()
        let pill = app.buttons["mode_english"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 20), "English mode pill missing (personal profile)")
        pill.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText("mercy")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "english-mode search returned nothing")
    }

    /// Lineage: timeline renders, a profile opens, compare mode produces the ⇄ sheet.
    /// Vaars: the 22 ballads list to an anatomy with pauri/salok units.
    func testLineageAndVaars() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Explore"].tap()
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
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Explore"].tap()
        let insights = app.buttons["Insights"].firstMatch
        XCTAssertTrue(insights.waitForExistence(timeout: 15)); insights.tap()
        app.buttons["insights_Network"].tap()
        XCTAssertTrue(app.staticTexts["Strongest pairs"].waitForExistence(timeout: 15), "network list missing")
        app.buttons["insights_Resonance"].tap()
        XCTAssertTrue(app.staticTexts["Strongest resonances"].waitForExistence(timeout: 15), "resonance missing")
        app.buttons["insights_Flow"].tap()
        XCTAssertTrue(app.otherElements["progressionRaagPicker"].firstMatch.waitForExistence(timeout: 15)
                      || app.buttons["progressionRaagPicker"].firstMatch.exists
                      || app.staticTexts["Raag"].firstMatch.waitForExistence(timeout: 5),
                      "progression picker missing")
    }

    /// Reader parity: jump-to-Ang (boundary 1430, next disabled), swipe page-turn back.
    func testReaderJumpAndSwipe() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Reader"].tap()
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
        app.launch()
        app.tabBars.buttons["Clock"].tap()
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
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["Explore"].tap()
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
        let app = XCUIApplication(); app.launch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap(); field.typeText("naam")
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20))
        firstCell.press(forDuration: 1.1)
        let explore = app.buttons["Explore related"]
        XCTAssertTrue(explore.waitForExistence(timeout: 8)); explore.tap()
        XCTAssertTrue(app.navigationBars["Related verses"].waitForExistence(timeout: 12))
        let openBtn = app.buttons["Open"].firstMatch
        XCTAssertTrue(openBtn.waitForExistence(timeout: 5), "pinned Open button missing")
        openBtn.tap()                                              // pinned-verse Open → swap to shabad
        // the single sheet must swap to a shabad (nav title "Ang N"), not be dropped
        let shabadBar = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Ang ")).firstMatch
        XCTAssertTrue(shabadBar.waitForExistence(timeout: 12), "Trail→Open did not surface the shabad (dropped sheet)")
    }

    func testSettingsControls() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.switches["translitToggle"].waitForExistence(timeout: 12), "translit toggle missing")
        XCTAssertTrue(app.sliders["gurmukhiSizeSlider"].exists, "size slider missing")
        app.switches["translitToggle"].tap()                       // hide transliteration
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 12)); field.tap(); field.typeText("naam")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "results must still render with translit hidden")
    }

    /// Accent picker (premium pass): switching accents re-tints live via \.palette environment
    /// injection and persists across launches; navigation state must survive the switch.
    func testAccentPickerSwitchesAndPersists() {
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["More"].tap()
        let indigo = app.buttons["Indigo accent"]
        if !indigo.waitForExistence(timeout: 8) { app.swipeUp() }
        XCTAssertTrue(indigo.waitForExistence(timeout: 8))
        indigo.tap()
        XCTAssertTrue(indigo.isSelected || indigo.exists)   // selected trait set by the swatch
        // still on More (no navigation reset), and the app survives a relaunch with the choice
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 4))
        app.terminate(); app.launch()
        app.tabBars.buttons["More"].tap()
        if !app.buttons["Indigo accent"].waitForExistence(timeout: 8) { app.swipeUp() }
        XCTAssertTrue(app.buttons["Indigo accent"].isSelected, "accent choice must persist")
        // restore the default for subsequent tests/captures
        app.buttons["Saffron accent"].tap()
    }

    /// Captures reference screenshots (not an assertion gate). Written to the simulator's tmp
    /// dir — pull with `xcrun simctl get_app_container` or read the test attachments.
    /// Set SGGS_SHOT_TAG in the runner env to prefix filenames (disambiguates light/dark runs
    /// when harvesting with `find` — identical names across runs/containers mix otherwise).
    func testCaptureScreens() {
        let dir = NSTemporaryDirectory()
        let tag = ProcessInfo.processInfo.environment["SGGS_SHOT_TAG"].map { "\($0)_" } ?? ""
        let app = XCUIApplication(); app.launch()
        func shot(_ name: String) {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(tag)\(name).png"))
        }
        let field = app.searchFields.firstMatch
        if field.waitForExistence(timeout: 20) { field.tap(); field.typeText("naam") }
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
        shot("search_results")
        // Dismiss the keyboard via the return key — it covers the tab bar (a swipe would
        // dismiss it too, but iOS 26 minimises the floating tab bar during scroll and the
        // Reader tap lands on nothing; both failure modes are silent).
        field.typeText("\n")
        let readerTab = app.tabBars.buttons["Reader"]
        XCTAssertTrue(readerTab.waitForExistence(timeout: 8))
        readerTab.tap()
        XCTAssertTrue(app.buttons["Hukam"].waitForExistence(timeout: 12),
                      "Reader must actually open before its screenshot")
        _ = app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 8)
        shot("reader")
        app.tabBars.buttons["Clock"].tap()
        _ = app.staticTexts["What raag is it now?"].waitForExistence(timeout: 12)
        shot("clock")
        app.tabBars.buttons["Explore"].tap()
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
        app.tabBars.buttons["More"].tap()
        _ = app.staticTexts["Accent"].waitForExistence(timeout: 8)
        shot("more_display")
    }
}
