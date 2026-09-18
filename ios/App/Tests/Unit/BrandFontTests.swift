import XCTest
import UIKit
@testable import SGGS

/// A missing or renamed font file fails SILENTLY at runtime (UIKit falls back to the system
/// face), so bundle registration is pinned here rather than noticed in a screenshot.
final class BrandFontTests: XCTestCase {

    func testHeadingSerifIsBundledAndRegistered() {
        XCTAssertNotNil(UIFont(name: Brand.headingFontName, size: 17),
                        "\(Brand.headingFontName) not registered — check UIAppFonts + Resources/SourceSerif4.ttf")
    }

    func testGurmukhiFaceIsStillRegistered() {
        XCTAssertNotNil(UIFont(name: "SantLipi-ExtraLight", size: 17), "Sant Lipi must stay bundled")
    }

    func testHeadingUsesTheSerifNotTheFallback() {
        XCTAssertTrue(Brand.headingUIFont(.headline).familyName.contains("Source Serif"),
                      "heading resolved to \(Brand.headingUIFont(.headline).familyName)")
    }

    func testHeadingScalesWithDynamicType() {
        let small = UITraitCollection(preferredContentSizeCategory: .large)
        let huge = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let metrics = UIFontMetrics(forTextStyle: .headline)
        let base = Brand.headingUIFont(.headline)
        XCTAssertGreaterThan(metrics.scaledValue(for: base.pointSize, compatibleWith: huge),
                             metrics.scaledValue(for: base.pointSize, compatibleWith: small))
    }
}
