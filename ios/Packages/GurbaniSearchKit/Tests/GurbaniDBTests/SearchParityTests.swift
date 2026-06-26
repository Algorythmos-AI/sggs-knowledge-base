import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Integration parity gate for the explicit-mode search core: the Swift SearchEngine, running
/// against the shipped iOS DB, must reproduce Python do_search's resolved mode + ORDERED result
/// line-ids (incl. the BM25 `…, lines.id` tie-break) + concept + related_themes, byte-for-byte.
/// Pinned by contract/golden_search.ndjson.
final class SearchParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private struct SVector: Decodable {
        let query: String
        let mode: String
        let used: String?
        let result_ids: [Int]
        let concept: String?
        let related_themes: [String]?
    }

    // All tiers are now ported (incl. passage_search). Nothing is deferred.
    private static func isDeferred(_ usedMode: String?) -> Bool { false }

    func testSearchParity() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run `python3 pipeline/build_ios_db.py`")
        }
        let goldenURL = root.appendingPathComponent("contract/golden_search.ndjson")
        let rows = try String(contentsOf: goldenURL, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        let engine = SearchEngine(source: try SQLiteCandidateSource(path: dbPath))
        let dec = JSONDecoder()
        var failures: [String] = []
        var asserted = 0

        for row in rows {
            let v = try dec.decode(SVector.self, from: Data(row.utf8))
            if Self.isDeferred(v.used) { continue }   // passage_search: later phase
            asserted += 1
            let out = try engine.search(v.query, mode: v.mode, limit: 50, offset: 0)
            let tag = "q=\(v.query.debugDescription) mode=\(v.mode)"
            if out.mode != v.used {
                failures.append("\(tag): used want=\(String(describing: v.used)) got=\(out.mode)")
            }
            let gotIds = out.results.map { $0.id }
            if gotIds != v.result_ids {
                failures.append("\(tag): ids want=\(v.result_ids.prefix(8))… got=\(gotIds.prefix(8))…")
            }
            if out.concept?.name != v.concept {
                failures.append("\(tag): concept want=\(String(describing: v.concept)) got=\(String(describing: out.concept?.name))")
            }
            if out.relatedThemes ?? [] != v.related_themes ?? [] {
                failures.append("\(tag): related want=\(String(describing: v.related_themes)) got=\(String(describing: out.relatedThemes))")
            }
        }

        XCTAssertGreaterThan(asserted, 10, "expected to assert the explicit-mode vectors")
        if !failures.isEmpty {
            XCTFail("search parity failures: \(failures.count)/\(asserted)\n" + failures.prefix(20).joined(separator: "\n"))
        }
    }

    /// Mirrors serve.py do_search's `len(q) > 300 → ValueError`: the engine must reject (not process)
    /// an over-long query. A 300-char query is allowed.
    func testOverLongQueryRejected() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else { throw XCTSkip("DB missing") }
        let engine = SearchEngine(source: try SQLiteCandidateSource(path: dbPath))
        XCTAssertThrowsError(try engine.search(String(repeating: "a", count: 301), mode: "roman"))
        XCTAssertNoThrow(try engine.search(String(repeating: "a", count: 300), mode: "roman"))
    }
}
