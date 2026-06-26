import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Parity gate for the plain corpus-reader endpoints (ang / hukam unit) vs Python serve.py,
/// against the shipped iOS DB. Pinned by contract/golden_reader.ndjson.
final class ReaderParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private struct RVector: Decodable {
        let kind: String
        let n: Int?
        let line_ids: [Int]?
        let continued_from: Int?
        let raag: String?
        let section: String?
        let authors: [String]?
        let seed: Int?
        let comp_id: Int?
        let comp_ids: [Int]?
        let level: String?
        let source: String?
        let line_id: Int?
        let neighbor_ids: [Int]?
        let scores: [Double]?
        let names: [String]?
        let n_lines: [Int]?
        let mattr: [Double]?
        let pairs: [String]?
        let ppmi: [Double]?
    }

    private func eqDoubles(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && !zip(a, b).contains { abs($0 - $1) > 1e-4 }
    }

    func testReaderParity() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run pipeline/build_ios_db.py")
        }
        let rows = try String(contentsOf: root.appendingPathComponent("contract/golden_reader.ndjson"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let db = try SQLiteCandidateSource(path: dbPath)
        let dec = JSONDecoder()
        var failures: [String] = []
        var asserted = 0

        for row in rows {
            let v = try dec.decode(RVector.self, from: Data(row.utf8))
            if v.kind == "ang", let n = v.n {
                asserted += 1
                let page = try db.fetchAng(n)
                if page.lines.map({ $0.id }) != (v.line_ids ?? []) { failures.append("ang \(n): line ids differ") }
                if page.continuedFrom != v.continued_from { failures.append("ang \(n): continuedFrom \(String(describing: page.continuedFrom)) != \(String(describing: v.continued_from))") }
                if page.raag != v.raag { failures.append("ang \(n): raag \(String(describing: page.raag)) != \(String(describing: v.raag))") }
                if page.section != v.section { failures.append("ang \(n): section differs") }
                if page.authors != (v.authors ?? []) { failures.append("ang \(n): authors \(page.authors) != \(String(describing: v.authors))") }
            } else if v.kind == "neighbors", let lid = v.line_id {
                asserted += 1
                let r = try db.neighbors(lineId: lid, limit: 12)
                if r.level != v.level { failures.append("neighbors \(lid): level \(r.level) != \(v.level ?? "?")") }
                if r.source != v.source { failures.append("neighbors \(lid): source differs") }
                if r.neighbors.map({ $0.id }) != (v.neighbor_ids ?? []) { failures.append("neighbors \(lid): ids differ") }
                let gotScores = r.neighbors.map { ($0.score * 1e6).rounded() / 1e6 }
                if zip(gotScores, v.scores ?? []).contains(where: { abs($0 - $1) > 1e-5 }) || gotScores.count != (v.scores?.count ?? -1) {
                    failures.append("neighbors \(lid): scores differ")
                }
            } else if v.kind == "authors" {
                asserted += 1
                let a = try db.authorAnalytics()
                if a.map({ $0.author }) != (v.names ?? []) { failures.append("authors: names differ") }
                if a.map({ $0.nLines }) != (v.n_lines ?? []) { failures.append("authors: n_lines differ") }
                if !eqDoubles(a.map { ($0.mattr100 * 1e4).rounded() / 1e4 }, v.mattr ?? []) { failures.append("authors: mattr differ") }
            } else if v.kind == "raags" {
                asserted += 1
                let r = try db.raagAnalytics()
                if r.map({ $0.raag }) != (v.names ?? []) { failures.append("raags: names differ") }
                if r.map({ $0.nLines }) != (v.n_lines ?? []) { failures.append("raags: n_lines differ") }
            } else if v.kind == "theme_net" {
                asserted += 1
                let e = try db.themeNetwork(minPPMI: 0.7, limit: 40)
                if e.map({ "\($0.source)~\($0.target)" }) != (v.pairs ?? []) { failures.append("theme_net: pairs differ") }
                if !eqDoubles(e.map { ($0.ppmi * 1e6).rounded() / 1e6 }, v.ppmi ?? []) { failures.append("theme_net: ppmi differ") }
            } else if v.kind == "hukam", let seed = v.seed {
                asserted += 1
                let u = try db.hukamUnit(seed: seed)
                if u.compId != v.comp_id { failures.append("hukam \(seed): comp_id differs") }
                if u.compIds != (v.comp_ids ?? []) { failures.append("hukam \(seed): comp_ids \(u.compIds) != \(String(describing: v.comp_ids))") }
                if u.lines.map({ $0.id }) != (v.line_ids ?? []) { failures.append("hukam \(seed): line ids differ (\(u.lines.count) vs \(v.line_ids?.count ?? 0))") }
            }
        }
        XCTAssertGreaterThan(asserted, 8)
        if !failures.isEmpty { XCTFail("reader parity failures: \(failures.count)\n" + failures.prefix(20).joined(separator: "\n")) }
    }
}
