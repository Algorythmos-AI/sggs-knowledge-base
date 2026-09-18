import XCTest
@testable import SGGS

/// The typographic layer is DISPLAY-ONLY: these tests pin that it can never change a character
/// of scripture — only where a line is allowed to break and how a flagged line is styled.
final class VerseTypographyTests: XCTestCase {
    private let nbsp = VerseTypography.unbreakableSpace

    private let samples = [
        "ਹੈ ਭੀ ਸਚੁ ਨਾਨਕ ਹੋਸੀ ਭੀ ਸਚੁ ॥੧॥",
        "ਪ੍ਰਗਟਿਆ ਸਭ ਮਹਿ ਲਿਖਿਆ ਧੁਰ ਕਾ ॥ ਰਹਾਉ ॥",
        "ਗੁਰੁ ਨਾਨਕੁ ਤੁਠਾ ਕੀਨੀ ਦਾਤਿ ॥੪॥੭॥੧੦੧॥",
        "॥ ਜਪੁ ॥",
        "ਆਸਾ ਮਹਲਾ ੫ ॥",
        "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ ॥",
    ]

    func testBindingIsReversibleToTheVerbatimLine() {
        for s in samples {
            let shown = VerseTypography.bindingClosingMarkers(s)
            XCTAssertEqual(shown.replacingOccurrences(of: "\u{2060}", with: ""), s, "display form altered scripture")
        }
    }

    func testClosingMarkerCannotBeOrphaned() {
        let shown = VerseTypography.bindingClosingMarkers("ਹੈ ਭੀ ਸਚੁ ਨਾਨਕ ਹੋਸੀ ਭੀ ਸਚੁ ॥੧॥")
        XCTAssertTrue(shown.hasSuffix("ਸਚੁ\(nbsp)॥੧॥"))
        let rahao = VerseTypography.bindingClosingMarkers("ਪ੍ਰਗਟਿਆ ਸਭ ਮਹਿ ਲਿਖਿਆ ਧੁਰ ਕਾ ॥ ਰਹਾਉ ॥")
        XCTAssertTrue(rahao.hasSuffix("ਕਾ\(nbsp)॥\(nbsp)ਰਹਾਉ\(nbsp)॥"))
    }

    func testAllMarkerLineIsLeftAlone() {
        XCTAssertEqual(VerseTypography.bindingClosingMarkers("॥ ਜਪੁ ॥"), "॥ ਜਪੁ\(nbsp)॥")
        XCTAssertEqual(VerseTypography.bindingClosingMarkers("॥"), "॥")
    }

    func testMisflaggedVersesAreNotDrawnAsHeadings() {
        XCTAssertFalse(VerseTypography.rendersAsHeading("ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ ॥", flaggedHeader: true))
        XCTAssertFalse(VerseTypography.rendersAsHeading("ਮਿਟਿਆ ਸੋਗੁ ਮਹਾ ਅਨੰਦੁ ਥੀਆ ॥", flaggedHeader: true))
        XCTAssertFalse(VerseTypography.rendersAsHeading("ਗੁਰਬਾਣੀ ਸਖੀ ਅਨੰਦੁ ਗਾਵੈ ॥", flaggedHeader: true))
        XCTAssertFalse(VerseTypography.rendersAsHeading("ਬਸੰਤ ਰੁਤਿ ਆਈ ॥", flaggedHeader: true))
    }

    func testRealHeadingsStayHeadings() {
        for h in ["ਆਸਾ ਮਹਲਾ ੫ ॥", "॥ ਜਪੁ ॥", "ਪਉੜੀ ॥", "ਆਸਾ ਘਰੁ ੮ ਕਾਫੀ ਮਹਲਾ ੫", "ਗਉੜੀ ਕਬੀਰ ਜੀ ਦੁਪਦੇ ॥", "ਸਲੋਕ ਵਾਰਾਂ ਤੇ ਵਧੀਕ ॥",
                  "ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀਉ ਕੇ", "ਗਉੜੀ ਬੈਰਾਗਣਿ ਰਵਿਦਾਸ ਜੀਉ ॥", "ਗਉੜੀ ਭੀ ਸੋਰਠਿ ਭੀ ॥",
                  "ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ ਅਜੂਨੀ ਸੈਭੰ ਗੁਰ ਪ੍ਰਸਾਦਿ ॥"] {
            XCTAssertTrue(VerseTypography.rendersAsHeading(h, flaggedHeader: true), h)
        }
        XCTAssertFalse(VerseTypography.rendersAsHeading("ਆਸਾ ਮਹਲਾ ੫ ॥", flaggedHeader: false))
    }
}
