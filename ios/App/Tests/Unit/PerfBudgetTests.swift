import XCTest
import GurbaniDB
import GurbaniSearchKit
@testable import SGGS

/// Performance budgets as hard asserts (generous enough not to flake on CI hardware, tight
/// enough to catch a regression that would feel slow in the hand). Wall-clock medians over
/// several iterations; the launch-hash budget lives in CorpusIntegrationTests.
final class PerfBudgetTests: XCTestCase {

    private func makeSource() throws -> SQLiteCandidateSource {
        guard let path = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite")?.path
            ?? Bundle(for: Self.self).url(forResource: "sggs-ios", withExtension: "sqlite")?.path
        else { throw XCTSkip("bundled DB not found in host app") }
        return try SQLiteCandidateSource(path: path)
    }

    private func median(of times: [TimeInterval]) -> TimeInterval { times.sorted()[times.count / 2] }

    func testSearchBudget() throws {
        let engine = SearchEngine(source: try makeSource())
        _ = try engine.search("naam", mode: "auto", limit: 50, offset: 0)   // warm
        var times: [TimeInterval] = []
        for q in ["naam", "waheguru", "satgur kirpa", "ਸਤਿ ਨਾਮੁ", "mercy", "dh dh r g", "hukam"] {
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try engine.search(q, mode: "auto", limit: 50, offset: 0)
            times.append(CFAbsoluteTimeGetCurrent() - t0)
        }
        XCTAssertLessThan(median(of: times), 0.5, "auto-search median exceeded 500 ms: \(times)")
    }

    func testAngRenderDataBudget() throws {
        let db = try makeSource()
        var times: [TimeInterval] = []
        for ang in [1, 100, 500, 917, 1430] {          // 917 is among the densest Angs
            let t0 = CFAbsoluteTimeGetCurrent()
            _ = try db.fetchAng(ang)
            times.append(CFAbsoluteTimeGetCurrent() - t0)
        }
        XCTAssertLessThan(median(of: times), 0.2, "ang fetch median exceeded 200 ms: \(times)")
    }

    func testProgressionBudget() throws {
        let db = try makeSource()
        let t0 = CFAbsoluteTimeGetCurrent()
        _ = db.progression(raag: "ਗਉੜੀ", bins: 80, top: 10)   // largest raag, max params
        let dt = CFAbsoluteTimeGetCurrent() - t0
        XCTAssertLessThan(dt, 1.5, "worst-case progression exceeded 1.5 s: \(dt)")
    }

    func testForceLayoutSettleBudget() throws {
        let db = try makeSource()
        let edges = try db.themeNetwork(minPPMI: 0.0, limit: 1500)   // full edge set
        let names = Array(Set(edges.flatMap { [$0.source, $0.target] })).sorted()
        let index = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })
        let links = edges.compactMap { e -> (Int, Int, Double)? in
            guard let i = index[e.source], let j = index[e.target] else { return nil }
            return (i, j, e.ppmi)
        }
        let t0 = CFAbsoluteTimeGetCurrent()
        let pts = ForceLayout.layout(nodeCount: names.count, edges: links)
        let dt = CFAbsoluteTimeGetCurrent() - t0
        XCTAssertEqual(pts.count, names.count)
        XCTAssertLessThan(dt, 2.0, "network layout settle exceeded 2 s for \(links.count) edges: \(dt)")
        // determinism: same seed → identical layout
        XCTAssertEqual(pts, ForceLayout.layout(nodeCount: names.count, edges: links),
                       "force layout must be deterministic")
    }
}
