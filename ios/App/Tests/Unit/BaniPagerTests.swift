import XCTest
import GurbaniSearchKit
@testable import SGGS

/// Stepping a long composition by its printed rhythm (pauris / ashtapadis).
final class BaniPagerTests: XCTestCase {

    private func section(_ kind: BaniSectionKind, _ n: Int, _ start: Int, _ end: Int) -> BaniSection {
        BaniSection(kind: kind, number: n, numberGm: "", startSeq: start, endSeq: end, derivedFromText: false)
    }

    /// Sukhmani's shape: three registry groups, but twenty-four ashtapadis worth stepping.
    private var ashtapadis: [BaniSection] {
        (1...24).map { section(.ashtapadi, $0, ($0 - 1) * 80 + 11, $0 * 80 + 10) }
    }

    func testStepsNeedMoreThanOneNumberedSection() {
        XCTAssertEqual(BaniPager.steps(in: ashtapadis).count, 24)
        XCTAssertTrue(BaniPager.steps(in: [section(.ashtapadi, 1, 1, 80)]).isEmpty, "one section is not a rhythm")
        XCTAssertTrue(BaniPager.steps(in: []).isEmpty)
        XCTAssertTrue(BaniPager.steps(in: [section(.part, 1, 1, 5), section(.part, 2, 6, 9)]).isEmpty,
                      "printed line-groups keep the existing part bar")
        XCTAssertEqual(BaniPager.steps(in: [section(.salok, 0, 1, 10)] + ashtapadis).count, 24,
                       "an unnumbered opening salok is not a step")
    }

    func testForwardAndBackWalkTheSections() {
        let s = ashtapadis
        XCTAssertEqual(BaniPager.neighbour(of: 11, in: s, direction: 1), s[1].startSeq)
        XCTAssertEqual(BaniPager.neighbour(of: s[1].startSeq, in: s, direction: -1), s[0].startSeq)
        XCTAssertNil(BaniPager.neighbour(of: 11, in: s, direction: -1), "no step before the first")
        XCTAssertNil(BaniPager.neighbour(of: s[23].startSeq, in: s, direction: 1), "no step after the last")
        XCTAssertFalse(BaniPager.canStep(from: s[23].startSeq, in: s, direction: 1))
        XCTAssertTrue(BaniPager.canStep(from: s[23].startSeq, in: s, direction: -1))
    }

    /// Halfway through a pauri, "previous" means the start of the one being read.
    func testBackFromMidSectionReturnsToItsStart() {
        let s = ashtapadis
        let mid = s[5].startSeq + 20
        XCTAssertEqual(BaniPager.neighbour(of: mid, in: s, direction: -1), s[5].startSeq)
        XCTAssertEqual(BaniPager.neighbour(of: mid, in: s, direction: 1), s[6].startSeq)
    }

    /// A heading run before the first numbered section still reads as "in the first".
    func testPositionBeforeTheFirstSection() {
        let s = ashtapadis
        XCTAssertEqual(BaniPager.index(of: 1, in: s), 0)
        XCTAssertEqual(BaniPager.neighbour(of: 1, in: s, direction: 1), s[1].startSeq)
        XCTAssertNil(BaniPager.index(of: 1, in: []))
    }
}
