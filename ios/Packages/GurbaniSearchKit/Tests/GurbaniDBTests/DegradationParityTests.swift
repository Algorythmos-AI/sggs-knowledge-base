import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Degradation-parity gate: on the PUBLIC (Gurmukhi-only) DB profile the English layer must
/// no-op exactly the way serve.py degrades on an EN-less DB — `search_en` → [] (mode label
/// unchanged), `attach_translations` → pass-through, every `en` nil. This pins the public
/// profile to today's shipped behavior so activating English can never regress it.
/// Skips (never fails) when the public artifact hasn't been built:
///   python3 pipeline/build_ios_db.py --profile public
final class DegradationParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private func publicDB() throws -> SQLiteCandidateSource {
        let path = repoRoot().appendingPathComponent("ios/Resources/sggs-ios-public.sqlite").path
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("public-profile DB missing — run `python3 pipeline/build_ios_db.py --profile public`")
        }
        return try SQLiteCandidateSource(path: path)
    }

    func testEnglishModeDegradesToEmpty() throws {
        let engine = SearchEngine(source: try publicDB())
        for q in ["mercy", "the true guru", "lotus feet", "compassion"] {
            let out = try engine.search(q, mode: "english", limit: 50, offset: 0)
            XCTAssertEqual(out.mode, "english", "q=\(q)")
            XCTAssertTrue(out.results.isEmpty, "q=\(q): english mode must be empty on the public profile")
        }
    }

    func testAutoWaterfallEnglishTierNoOps() throws {
        // Queries that resolve via the english tier on the personal profile must fall
        // through it silently here — reaching a later tier or empty, never crashing.
        let engine = SearchEngine(source: try publicDB())
        for q in ["lotus feet of the lord", "ocean of peace", "wandering in doubt"] {
            let out = try engine.search(q, mode: "auto", limit: 50, offset: 0)
            XCTAssertNotEqual(out.mode, "english", "q=\(q): auto must not resolve to english here")
            if out.mode == "english-translation" {
                XCTAssertTrue(out.results.isEmpty, "q=\(q): english tier must yield [] on the public profile")
            }
        }
    }

    func testReaderCarriesNoEnglish() throws {
        let db = try publicDB()
        let page = try db.fetchAng(8)
        XCTAssertFalse(page.lines.isEmpty)
        XCTAssertTrue(page.lines.allSatisfy { $0.en == nil }, "ang lines must carry no en on the public profile")
        let shabad = try db.fetchShabad(compId: 682)
        XCTAssertTrue(shabad.lines.allSatisfy { $0.en == nil })
        let nb = try db.neighbors(lineId: 1000, limit: 12)
        XCTAssertTrue(nb.neighbors.allSatisfy { $0.en == nil })
    }

    func testBaniRegistryCarriesNoEnglishOnPublicProfile() throws {
        // The Nitnem registry is bundled on BOTH profiles; on the public one every SGGS line
        // must carry en == nil exactly like /api/bani on an EN-less DB, and extra lines never do.
        let db = try publicDB()
        XCTAssertTrue(db.detectCapabilities().hasBanis)
        XCTAssertTrue(db.fetchBanis().available)
        for key in ["japji", "rehras", "sukhmani"] {
            let bani = try XCTUnwrap(db.fetchBani(key: key), key)
            XCTAssertTrue(bani.lines.allSatisfy { $0.en == nil }, "\(key): en must be nil on the public profile")
        }
    }

    func testScriptureIdenticalAcrossProfiles() throws {
        // The verbatim Gurmukhi must be byte-identical between profiles (the profile switch
        // only adds/removes the translation layer — prime directive).
        let pub = try publicDB()
        let personalPath = repoRoot().appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: personalPath) else { throw XCTSkip("personal DB missing") }
        let per = try SQLiteCandidateSource(path: personalPath)
        for ang in [1, 100, 829, 1430] {
            let a = try pub.fetchAng(ang), b = try per.fetchAng(ang)
            XCTAssertEqual(a.lines.map { $0.gurmukhi }, b.lines.map { $0.gurmukhi }, "ang \(ang)")
            XCTAssertEqual(a.lines.map { $0.id }, b.lines.map { $0.id }, "ang \(ang)")
        }
    }
}
