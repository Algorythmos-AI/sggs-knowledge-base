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
}
