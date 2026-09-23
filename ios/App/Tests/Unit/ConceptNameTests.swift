import XCTest
import GurbaniDB
@testable import SGGS

/// Concept slugs (`concepts.concept`) are keys, not labels: every theme surface — Themes,
/// Constellation, Theme Network, raag progression — shows them through `ConceptName.display`,
/// so `dukh_sukh` reads "Dukh Sukh", never the "Dukh_Sukh" that `String.capitalized` leaked.
final class ConceptNameTests: XCTestCase {

    func testSlugsBecomeTitleCasedWords() {
        XCTAssertEqual(ConceptName.display("naam"), "Naam")
        XCTAssertEqual(ConceptName.display("dukh_sukh"), "Dukh Sukh")
        XCTAssertEqual(ConceptName.display("maran_jeevan"), "Maran Jeevan")
        XCTAssertEqual(ConceptName.display("karam_nadar"), "Karam Nadar")
        XCTAssertEqual(ConceptName.display("ik_onkar"), "Ik Onkar")
        XCTAssertNotEqual(ConceptName.display("dukh_sukh"), "dukh_sukh".capitalized)
    }

    func testDegenerateSlugsDoNotCrash() {
        XCTAssertEqual(ConceptName.display(""), "")
        XCTAssertEqual(ConceptName.display("_a__b_"), "A B")
    }

    /// Every concept in the SHIPPED DB gets an underscore-free label, and no two concepts
    /// collapse to the same label (the progression chart keys its series by label).
    func testEveryBundledConceptHasADistinctCleanLabel() throws {
        guard let path = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite")?.path
            ?? Bundle(for: Self.self).url(forResource: "sggs-ios", withExtension: "sqlite")?.path
        else { throw XCTSkip("bundled DB not found in host app") }
        let concepts = try SQLiteCandidateSource(path: path).fetchMeta().concepts.map(\.concept)
        XCTAssertFalse(concepts.isEmpty)
        XCTAssertTrue(concepts.contains { $0.contains("_") }, "fixture lost its multi-word slugs")
        let labels = concepts.map(ConceptName.display)
        for (slug, label) in zip(concepts, labels) {
            XCTAssertFalse(label.contains("_"), "\(slug) → \(label)")
            XCTAssertFalse(label.isEmpty, slug)
        }
        XCTAssertEqual(Set(labels).count, labels.count, "two concepts share a display label")
    }
}
