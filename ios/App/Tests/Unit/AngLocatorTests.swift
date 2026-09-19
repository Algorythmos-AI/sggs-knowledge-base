import XCTest
import GurbaniSearchKit
@testable import SGGS

/// `AngLocator` maps an Ang to the raag / bani span it sits in (raag first, then post-1353
/// sections), and lists raag boundaries for the scrubber ticks. Pure logic over a fixture meta.
final class AngLocatorTests: XCTestCase {

    private func meta() -> CorpusMeta {
        CorpusMeta(
            raags: [
                RaagRow(name: "ਸਿਰੀਰਾਗੁ", roman: "Siree Raag", firstAng: 14, lastAng: 93, nLines: 0, nShabads: 0, seq: 1),
                RaagRow(name: "ਗਉੜੀ", roman: "Gauri", firstAng: 151, lastAng: 346, nLines: 0, nShabads: 0, seq: 3),
            ],
            sections: [
                SectionRow(name: "Japji", firstAng: 1, lastAng: 8, nLines: 0),
                SectionRow(name: "Salok Sehskritee", firstAng: 1353, lastAng: 1360, nLines: 0),
            ],
            authors: [], concepts: [])
    }

    func testRaagSpanWins() {
        let loc = AngLocator.location(for: 164, meta: meta())
        XCTAssertEqual(loc?.gurmukhi, "ਗਉੜੀ")
        XCTAssertEqual(loc?.roman, "Gauri")
        XCTAssertEqual(loc?.rangeLabel, "Angs 151–346")
    }

    func testSectionAnswersAfterRaagFramework() {
        let loc = AngLocator.location(for: 1354, meta: meta())
        XCTAssertNil(loc?.gurmukhi, "post-1353 section spans have no raag")
        XCTAssertEqual(loc?.roman, "Salok Sehskritee")
    }

    func testAngOneResolvesToJapjiSection() {
        // Ang 1 is inside no raag span → falls through to the Japji section.
        let loc = AngLocator.location(for: 1, meta: meta())
        XCTAssertEqual(loc?.roman, "Japji")
    }

    func testUnmatchedAngIsNil() {
        XCTAssertNil(AngLocator.location(for: 120, meta: meta()), "Ang 120 is in no fixture span")
        XCTAssertNil(AngLocator.location(for: 500, meta: nil), "nil meta yields nil")
    }

    func testRaagBoundariesSortedAndDeduped() {
        XCTAssertEqual(AngLocator.raagBoundaries(meta: meta()), [14, 151])
        XCTAssertEqual(AngLocator.raagBoundaries(meta: nil), [])
    }
}
