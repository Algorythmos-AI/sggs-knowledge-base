import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// `AngPage.continuedFromLineId` — the id of the opening line of a composition that spills onto
/// this Ang, so "Shabad starts on Ang N" can land on the shabad's start rather than the top of
/// the Ang. Additive to the (test-pinned) `continuedFrom`; verified against the shipped iOS DB.
final class ContinuedFromLineTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private func openDB() throws -> SQLiteCandidateSource {
        let dbPath = repoRoot().appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run pipeline/build_ios_db.py")
        }
        return try SQLiteCandidateSource(path: dbPath)
    }

    /// Whenever an Ang continues a composition, the start-line id is a real, land-able line that
    /// sits on the start Ang (an Ang can begin mid-way through a *different* composition, so the
    /// shabad's opening line is not necessarily that Ang's first row — only that it is on it).
    func testContinuedFromLineIsLandableOnStartAng() throws {
        let db = try openDB()
        var checked = 0
        for n in 2...1430 {
            let page = try db.fetchAng(n)
            guard let from = page.continuedFrom else {
                XCTAssertNil(page.continuedFromLineId, "ang \(n): no continuedFrom but a line id was set")
                continue
            }
            let lineId = try XCTUnwrap(page.continuedFromLineId, "ang \(n): continues from \(from) but no start-line id")
            let start = try db.fetchAng(from)
            let landing = start.lines.first { $0.id == lineId }
            XCTAssertNotNil(landing, "ang \(n): start-line id \(lineId) is not present on its start Ang \(from)")
            XCTAssertEqual(landing?.ang, from, "ang \(n): start-line \(lineId) is not on Ang \(from)")
            // it must also be the composition this Ang continues (shares the page's first comp_id)
            XCTAssertEqual(landing?.compId, page.lines.first?.compId,
                           "ang \(n): start-line comp \(String(describing: landing?.compId)) ≠ page comp")
            checked += 1
            if checked >= 40 { break }   // enough coverage; keep the DB pass fast
        }
        XCTAssertGreaterThan(checked, 0, "no continuing Angs found — fixture DB may be wrong")
    }

    /// An Ang that opens with a heading run (no spilled-in composition) has no start-line id.
    func testHeaderOpeningAngHasNoContinuedFromLine() throws {
        let db = try openDB()
        let ang1 = try db.fetchAng(1)          // opens with the Mool Mantar heading run
        XCTAssertNil(ang1.continuedFrom)
        XCTAssertNil(ang1.continuedFromLineId)
    }
}
