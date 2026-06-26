import XCTest
import CryptoKit
import GurbaniDB
import GurbaniSearchKit

/// In-app integration: the SHIPPED bundle DB, opened the way the app opens it, must behave like the
/// proven corpus (the kit parity is golden-tested separately; this proves the bundle + path wiring).
final class CorpusIntegrationTests: XCTestCase {

    private func makeSource() throws -> SQLiteCandidateSource {
        guard let path = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite")?.path
            ?? Bundle(for: Self.self).url(forResource: "sggs-ios", withExtension: "sqlite")?.path
        else { throw XCTSkip("bundled DB not found in host app") }
        return try SQLiteCandidateSource(path: path)
    }

    func testAngOneIsMoolMantar() throws {
        let db = try makeSource()
        let page = try db.fetchAng(1)
        XCTAssertEqual(page.ang, 1)
        XCTAssertTrue(page.lines.first?.gurmukhi.hasPrefix("ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ") ?? false)
    }

    func testThemeSearchReturnsLines() throws {
        let engine = SearchEngine(source: try makeSource())
        let out = try engine.search("naam", mode: "theme", limit: 10, offset: 0)
        XCTAssertEqual(out.mode, "theme")
        XCTAssertFalse(out.results.isEmpty)
    }

    func testVerifyExact() throws {
        let engine = VerifyEngine(source: try makeSource())
        let v = try engine.verify(claim: "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", ang: 1)
        XCTAssertTrue(v.verdict.hasPrefix("VERIFIED_EXACT"))
        XCTAssertEqual(v.matchedLineId, 5)
    }

    func testHukamUnitIsComplete() throws {
        let db = try makeSource()
        let u = try db.hukamUnit(seed: 400)   // Maajh Vaar: comps 399–409
        XCTAssertEqual(u.compIds, Array(399...409))
        XCTAssertFalse(u.lines.isEmpty)
    }

    /// Guards the launch-integrity hash: streaming SHA-256 of the ~91 MB DB must stay well within a
    /// launch budget (the hash runs off-main via Task.detached; this catches a perf regression).
    func testDBHashWithinLaunchBudget() throws {
        guard let path = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite")?.path
            ?? Bundle(for: Self.self).url(forResource: "sggs-ios", withExtension: "sqlite")?.path
        else { throw XCTSkip("bundled DB not found") }
        let fh = try XCTUnwrap(FileHandle(forReadingAtPath: path))
        defer { try? fh.close() }
        let start = Date()
        var hasher = SHA256()
        while case let chunk = fh.readData(ofLength: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        _ = hasher.finalize()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0, "DB hash took \(elapsed)s — launch-time budget regression")
    }
}
