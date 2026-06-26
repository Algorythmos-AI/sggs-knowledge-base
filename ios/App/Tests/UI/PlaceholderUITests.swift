import XCTest
final class PlaceholderUITests: XCTestCase {
    func testLaunchShowsSearch() {
        let app = XCUIApplication(); app.launch()
        // Search tab is selected by default; its mode picker should appear.
        XCTAssertTrue(app.descendants(matching: .any)["searchModePicker"].waitForExistence(timeout: 20)
                      || app.navigationBars["Search"].waitForExistence(timeout: 20))
    }
}
