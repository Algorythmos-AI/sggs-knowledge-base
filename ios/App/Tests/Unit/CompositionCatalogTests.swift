import XCTest
import GurbaniSearchKit
@testable import SGGS

/// The Index's Major-Compositions rail: which registry row a card opens, what the "More
/// compositions" shelf may show, and where "Next" leads. Pure logic — no DB, no SwiftUI.
final class CompositionCatalogTests: XCTestCase {

    private func summary(_ key: String, variant: String = "", isDefault: Bool = true,
                         category: BaniCategory = .popular, order: Int = 100,
                         hasExtra: Bool = false, nLines: Int = 100) -> BaniSummary {
        BaniSummary(key: key, variant: variant, isDefault: isDefault, titleGm: "ਗ",
                    titleEn: key, category: category, orderNo: order, nLines: nLines, nGroups: 1,
                    hasExtra: hasExtra, estimatedMinutes: 10, descriptionEn: nil, sourceLabel: "x")
    }

    /// The real registry shape for Asa Di Vaar: the kirtan form is the default, the printed form
    /// is not. A hero naming "printed" must resolve the printed row, never the default.
    func testResolvePicksTheExactVariantNotTheDefault() {
        let registry = [summary("asa_di_vaar", variant: "kirtan", isDefault: true, nLines: 740),
                        summary("asa_di_vaar", variant: "printed", isDefault: false, nLines: 637)]
        let hero = CompositionCatalog.heroes.first { $0.key == "asa_di_vaar" }!
        XCTAssertEqual(hero.variant, "printed", "the Index card promises the Vaar as printed")
        XCTAssertEqual(CompositionCatalog.resolve(hero, in: registry)?.nLines, 637)
        XCTAssertEqual(hero.id, "asa_di_vaar/printed", "progress identity must match BaniSummary.id")
    }

    /// An empty variant means "whatever the registry marks default", as /api/bani/{key} does.
    func testResolveWithEmptyVariantTakesTheDefaultRow() {
        let registry = [summary("rehras", variant: "sgpc", isDefault: true, nLines: 339),
                        summary("rehras", variant: "taksal", isDefault: false, nLines: 420)]
        let hero = CompositionCatalog.Hero(key: "rehras", variant: "", gm: "ਗ", roman: "Rehras",
                                           ang: 8, raag: "")
        XCTAssertEqual(CompositionCatalog.resolve(hero, in: registry)?.variant, "sgpc")
    }

    /// No registry (older/other DB profile) or an unknown key: the card must fall back, not crash.
    func testResolveReturnsNilWhenTheRegistryCannotAnswer() {
        for hero in CompositionCatalog.heroes {
            XCTAssertNil(CompositionCatalog.resolve(hero, in: []))
        }
        let hero = CompositionCatalog.heroes[0]
        XCTAssertNil(CompositionCatalog.resolve(hero, in: [summary("something_else")]))
    }

    /// The shelf: Popular/Ceremony defaults that aren't heroes, never a bani carrying non-SGGS
    /// text (the Index is a way into Sri Guru Granth Sahib Ji).
    func testMoreExcludesHeroesNonDefaultsAndTheExtraLayer() {
        let registry = [
            summary("sukhmani", nLines: 2047),                                   // hero
            summary("asa_di_vaar", variant: "printed", isDefault: false),        // hero, non-default
            summary("salok_m9", order: 130),
            summary("lavan", category: .ceremony, order: 300),
            summary("ardaas", hasExtra: true),                                   // separate layer
            summary("japji", category: .nitnemMorning, order: 10),               // daily practice
            summary("barah_maha", order: 220),
        ]
        XCTAssertEqual(CompositionCatalog.more(from: registry).map(\.key),
                       ["salok_m9", "barah_maha", "lavan"], "ordered by orderNo")
        XCTAssertTrue(CompositionCatalog.more(from: []).isEmpty)
    }

    /// "Next" walks the curated rail and stops at the end — it never wraps round to the start.
    func testNextHeroWalksTheRailAndStopsAtTheEnd() {
        XCTAssertEqual(CompositionCatalog.nextHero(after: "sukhmani", variant: "")?.key, "asa_di_vaar")
        XCTAssertEqual(CompositionCatalog.nextHero(after: "asa_di_vaar", variant: "printed")?.key, "anand")
        let last = CompositionCatalog.heroes.last!
        XCTAssertNil(CompositionCatalog.nextHero(after: last.key, variant: last.variant))
        XCTAssertNil(CompositionCatalog.nextHero(after: "not_a_bani", variant: ""))
    }

    /// Every hero names a key the API would accept, and the rail has no duplicates.
    @MainActor
    func testHeroKeysAreValidAndUnique() {
        XCTAssertEqual(Set(CompositionCatalog.heroes.map(\.id)).count, CompositionCatalog.heroes.count)
        for hero in CompositionCatalog.heroes {
            XCTAssertTrue(Router.isValidBaniKey(hero.key), hero.key)
            XCTAssertTrue(Router.isValidBaniVariant(hero.variant), hero.variant)
            XCTAssertTrue((1...1430).contains(hero.ang), "\(hero.key) fallback Ang")
        }
    }
}
