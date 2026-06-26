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
        XCTAssertTrue(app.buttons["Verify"].waitForExistence(timeout: 20))
        app.buttons["Verify"].tap()
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
        let dir = "/private/tmp/claude-501/-Users-samkalaliya-ppt-universe-SGGS-KnowledgeBase/27b4d30a-a6e1-40cf-9daa-9a74b9b8b00a/scratchpad"
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["More"].tap()
        let insights = app.buttons["Insights"]
        XCTAssertTrue(insights.waitForExistence(timeout: 12))
        insights.tap()
        XCTAssertTrue(app.buttons["Contributors"].waitForExistence(timeout: 12), "Insights did not open")
        _ = app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 6)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/v11_insights.png"))
    }

    func testConstellation() {
        let dir = "/private/tmp/claude-501/-Users-samkalaliya-ppt-universe-SGGS-KnowledgeBase/27b4d30a-a6e1-40cf-9daa-9a74b9b8b00a/scratchpad"
        let app = XCUIApplication(); app.launch()
        app.tabBars.buttons["More"].tap()
        let cons = app.buttons["Concept Constellation"]
        XCTAssertTrue(cons.waitForExistence(timeout: 12))
        cons.tap()
        XCTAssertTrue(app.navigationBars["Constellation"].waitForExistence(timeout: 12), "Constellation did not open")
        _ = app.staticTexts.element(boundBy: 2).waitForExistence(timeout: 8)   // let the map render
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/v11_constellation.png"))
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

    /// Captures reference screenshots to the scratchpad (not an assertion gate).
    func testCaptureScreens() {
        let dir = "/private/tmp/claude-501/-Users-samkalaliya-ppt-universe-SGGS-KnowledgeBase/27b4d30a-a6e1-40cf-9daa-9a74b9b8b00a/scratchpad"
        let app = XCUIApplication(); app.launch()
        func shot(_ name: String) {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
        let field = app.searchFields.firstMatch
        if field.waitForExistence(timeout: 20) { field.tap(); field.typeText("naam") }
        _ = app.cells.firstMatch.waitForExistence(timeout: 20)
        shot("v11_search_results")
        app.tabBars.buttons["Reader"].tap()
        _ = app.buttons["Hukam"].waitForExistence(timeout: 12)
        _ = app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 8)
        shot("v11_reader_ang1")
        app.tabBars.buttons["Themes"].tap()
        _ = app.navigationBars["Themes"].waitForExistence(timeout: 8)
        shot("v11_themes")
    }
}
