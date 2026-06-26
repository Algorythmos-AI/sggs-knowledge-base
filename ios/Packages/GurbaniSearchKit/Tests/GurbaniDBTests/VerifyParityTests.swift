import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Integration parity gate: the Swift VerifyEngine, running against the SHIPPED iOS DB via
/// SQLite, must reproduce the Python verify() verdicts byte-for-byte. Asserts against
/// contract/golden_verify.ndjson (generated from webapp/verify.py over the same DB).
final class VerifyParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private struct VVector: Decodable {
        let claim: String
        let ang: Int?
        let verdict: String
        let confidence: String
        let matched_line_id: Int?
        let candidates_scored: Int?
        let note: String?
    }

    /// Round a Double to 4 decimals the way the Python golden (round(x,4)) records it.
    private func round4(_ x: Double) -> Double { (x * 10000).rounded(.toNearestOrEven) / 10000 }

    func testVerifyParity() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run `python3 pipeline/build_ios_db.py`")
        }
        let goldenURL = root.appendingPathComponent("contract/golden_verify.ndjson")
        let rows = try String(contentsOf: goldenURL, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        XCTAssertGreaterThan(rows.count, 5)

        let engine = VerifyEngine(source: try SQLiteCandidateSource(path: dbPath))
        let dec = JSONDecoder()
        var failures: [String] = []

        for row in rows {
            let v = try dec.decode(VVector.self, from: Data(row.utf8))
            let got = try engine.verify(claim: v.claim, ang: v.ang)

            if got.verdict != v.verdict {
                failures.append("claim=\(v.claim.debugDescription) verdict want=\(v.verdict) got=\(got.verdict)")
            }
            if got.matchedLineId != v.matched_line_id {
                failures.append("claim=\(v.claim.debugDescription) matchedLineId want=\(String(describing: v.matched_line_id)) got=\(String(describing: got.matchedLineId))")
            }
            if got.candidatesScored != v.candidates_scored {
                failures.append("claim=\(v.claim.debugDescription) candidatesScored want=\(String(describing: v.candidates_scored)) got=\(String(describing: got.candidatesScored))")
            }
            if got.note != v.note {
                failures.append("claim=\(v.claim.debugDescription) note want=\(String(describing: v.note)) got=\(String(describing: got.note))")
            }
            if let want = Double(v.confidence) {
                if abs(round4(got.confidence) - want) > 1e-7 {
                    failures.append("claim=\(v.claim.debugDescription) confidence want=\(want) got=\(round4(got.confidence))")
                }
            }
        }

        if !failures.isEmpty {
            XCTFail("verify parity failures: \(failures.count)\n" + failures.prefix(20).joined(separator: "\n"))
        }
    }
}
