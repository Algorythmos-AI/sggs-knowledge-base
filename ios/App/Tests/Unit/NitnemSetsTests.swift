import XCTest
import GurbaniSearchKit
@testable import SGGS

@MainActor
final class NitnemSetsTests: XCTestCase {
    private func bani(_ key: String, _ cat: BaniCategory, order: Int, variant: String = "", isDefault: Bool = true) -> BaniSummary {
        BaniSummary(key: key, variant: variant, isDefault: isDefault, titleGm: key, titleEn: key.capitalized,
                    category: cat, orderNo: order, nLines: 10, nGroups: 1, hasExtra: false,
                    estimatedMinutes: 5, descriptionEn: nil, sourceLabel: "SGGS")
    }
    private var registry: [BaniSummary] {
        [ bani("japji", .nitnemMorning, order: 1), bani("jaap", .nitnemMorning, order: 2),
          bani("tav_prasad_savaiye", .nitnemMorning, order: 3),
          bani("rehras", .nitnemEvening, order: 1, variant: "sgpc", isDefault: true),
          bani("rehras", .nitnemEvening, order: 1, variant: "taksal", isDefault: false),
          bani("sohila", .nitnemNight, order: 1),
          bani("sukhmani", .popular, order: 1) ]
    }

    func testEmptyPlanFallsBackToDefaults() {
        let r = NitnemSets.resolved(category: .nitnemMorning, plan: [], registry: registry, rehrasVariant: "sgpc")
        XCTAssertEqual(r.map(\.key), ["japji", "jaap", "tav_prasad_savaiye"])
    }

    func testReorderRespected() {
        let plan = [NitnemSetEntry(key: "jaap"), NitnemSetEntry(key: "japji"), NitnemSetEntry(key: "tav_prasad_savaiye")]
        let r = NitnemSets.resolved(category: .nitnemMorning, plan: plan, registry: registry, rehrasVariant: "sgpc")
        XCTAssertEqual(r.map(\.key), ["jaap", "japji", "tav_prasad_savaiye"])
    }

    func testHiddenExcluded() {
        let plan = [NitnemSetEntry(key: "japji"), NitnemSetEntry(key: "jaap", hidden: true), NitnemSetEntry(key: "tav_prasad_savaiye")]
        let r = NitnemSets.resolved(category: .nitnemMorning, plan: plan, registry: registry, rehrasVariant: "sgpc")
        XCTAssertEqual(r.map(\.key), ["japji", "tav_prasad_savaiye"])
    }

    func testAddedCrossCategoryBaniAppears() {
        let plan = [NitnemSetEntry(key: "japji"), NitnemSetEntry(key: "sukhmani")]
        let r = NitnemSets.resolved(category: .nitnemMorning, plan: plan, registry: registry, rehrasVariant: "sgpc")
        // sukhmani (a Popular bani) added to the morning set, then the untouched defaults append
        XCTAssertEqual(r.map(\.key).prefix(2).map { $0 }, ["japji", "sukhmani"])
        XCTAssertTrue(r.map(\.key).contains("jaap"), "defaults not in the plan still append")
    }

    func testUnknownKeyDropped() {
        let plan = [NitnemSetEntry(key: "japji"), NitnemSetEntry(key: "removed_bani")]
        let r = NitnemSets.resolved(category: .nitnemMorning, plan: plan, registry: registry, rehrasVariant: "sgpc")
        XCTAssertFalse(r.map(\.key).contains("removed_bani"))
        XCTAssertTrue(r.map(\.key).contains("japji"))
    }

    func testNewDefaultAppendedForCustomisedSet() {
        // reader customised morning to just [japji]; a later app version adds "jaap" as a default
        let plan = [NitnemSetEntry(key: "japji")]
        let r = NitnemSets.resolved(category: .nitnemMorning, plan: plan, registry: registry, rehrasVariant: "sgpc")
        XCTAssertEqual(r.first?.key, "japji")
        XCTAssertTrue(r.map(\.key).contains("jaap"), "a new registry default appends")
    }

    func testRehrasVariantHonoured() {
        let plan = [NitnemSetEntry(key: "rehras")]
        let sgpc = NitnemSets.resolved(category: .nitnemEvening, plan: plan, registry: registry, rehrasVariant: "sgpc")
        XCTAssertEqual(sgpc.first?.variant, "sgpc")
        let taksal = NitnemSets.resolved(category: .nitnemEvening, plan: plan, registry: registry, rehrasVariant: "taksal")
        XCTAssertEqual(taksal.first?.variant, "taksal")
    }

    func testAddableExcludesPresent() {
        let plan = [NitnemSetEntry(key: "japji"), NitnemSetEntry(key: "jaap"), NitnemSetEntry(key: "tav_prasad_savaiye")]
        let add = NitnemSets.addable(to: .nitnemMorning, plan: plan, registry: registry, rehrasVariant: "sgpc")
        XCTAssertFalse(add.map(\.key).contains("japji"))
        XCTAssertTrue(add.map(\.key).contains("sukhmani"), "a library bani can be added")
    }

    // MARK: plan store

    func testStoreRoundTripAndReset() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plan-\(UUID()).json")
        let store = NitnemPlanStore(url: url)
        store.setEntries([NitnemSetEntry(key: "jaap"), NitnemSetEntry(key: "japji")], for: .nitnemMorning)
        let reopened = NitnemPlanStore(url: url)
        XCTAssertEqual(reopened.entries(for: .nitnemMorning).map(\.key), ["jaap", "japji"])
        XCTAssertTrue(reopened.isCustomised(.nitnemMorning))
        reopened.reset(.nitnemMorning)
        XCTAssertFalse(reopened.isCustomised(.nitnemMorning))
        try? FileManager.default.removeItem(at: url)
    }

    func testCorruptFileIsEmptyNotCrash() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plan-\(UUID()).json")
        try? "not json".data(using: .utf8)!.write(to: url)
        let store = NitnemPlanStore(url: url)
        XCTAssertTrue(store.entries(for: .nitnemMorning).isEmpty)
        XCTAssertFalse(store.isReadOnly)
        try? FileManager.default.removeItem(at: url)
    }

    func testNewerVersionReadOnly() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plan-\(UUID()).json")
        let future = "{\"version\":99,\"sets\":{\"nitnem_morning\":[{\"key\":\"jaap\",\"hidden\":false}]}}"
        try? future.data(using: .utf8)!.write(to: url)
        let store = NitnemPlanStore(url: url)
        XCTAssertTrue(store.isReadOnly, "a newer file is never overwritten")
        store.setEntries([NitnemSetEntry(key: "japji")], for: .nitnemMorning)   // must be a no-op on disk
        let reopened = NitnemPlanStore(url: url)
        XCTAssertEqual(reopened.entries(for: .nitnemMorning).map(\.key), ["jaap"], "newer file preserved")
        try? FileManager.default.removeItem(at: url)
    }
}
