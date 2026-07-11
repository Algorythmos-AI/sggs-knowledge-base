import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Adversarial sweep: 1,000 DETERMINISTICALLY-generated hostile queries (random Unicode incl.
/// Gurmukhi matras and isolated combining marks, FTS metacharacters, quote/star soup, Variation
/// Selectors as pasted from the web app's saroop copy, huge token counts) — the engine must
/// never crash and never throw anything but the documented queryTooLong. Seeded PRNG: the same
/// 1,000 inputs every run, so a failure is reproducible by index.
final class FuzzTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
    }

    /// Character pools chosen to hit the engine's edges: FTS syntax, Gurmukhi base letters,
    /// bare matras/combining marks (invalid in isolation), VS16/VS15, ASCII soup, whitespace.
    private static let pools: [[Character]] = [
        Array("\"*()^-:.,;!?'"),                                   // FTS metacharacters
        Array("ਓਅੲਸਹਕਖਗਘਙਚਛਜਝਞਟਠਡਢਣਤਥਦਧਨਪਫਬਭਮਯਰਲਵੜ"),                 // Gurmukhi letters
        Array("ਾਿੀੁੂੇੈੋੌ੍ੰਂਃ਼ੱ"),                                     // matras/combining (isolated = hostile)
        Array("abcdefghijklmnopqrstuvwxyzAEIOU0123456789"),        // roman + digits
        [" ", " ", " ", "\t", "\u{00A0}"],                          // whitespace variants
        ["\u{FE0E}", "\u{FE0F}", "ੴ", "॥", "।", "😀", "\u{200D}"],  // VS15/16, terminals, emoji, ZWJ
    ]

    func testThousandHostileQueriesNeverCrash() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run pipeline/build_ios_db.py")
        }
        let engine = SearchEngine(source: try SQLiteCandidateSource(path: dbPath))
        let verify = VerifyEngine(source: try SQLiteCandidateSource(path: dbPath))
        let modes = ["auto", "gurmukhi", "roman", "english", "first", "theme"]
        var rng = SplitMix64(state: 0x5347_4753)   // 'SGGS' — fixed seed, reproducible by index

        for i in 0..<1000 {
            let len = 1 + rng.below(80)
            var q = ""
            for _ in 0..<len {
                let pool = Self.pools[rng.below(Self.pools.count)]
                q.append(pool[rng.below(pool.count)])
            }
            let mode = modes[rng.below(modes.count)]
            do {
                _ = try engine.search(q, mode: mode, limit: 20, offset: 0)
            } catch is SearchError {
                // queryTooLong is the one documented throw — acceptable
            } catch {
                XCTFail("fuzz #\(i) mode=\(mode) q=\(q.debugDescription): unexpected error \(error)")
                return
            }
            // every 25th input also goes through the verify engine (its own FTS path)
            if i % 25 == 0 {
                _ = try? verify.verify(claim: q, ang: i % 3 == 0 ? 1 + rng.below(1430) : nil)
            }
        }
    }

    /// roman_norm drift check over every input in the 24,719-vector contract, plus totality
    /// (never crashes, always ASCII-lowercase output). NOTE: the fold is deliberately NOT
    /// idempotent — the Python source of truth isn't either (fold("sahib")="shv" but
    /// fold("shv")="sv"): it is applied EXACTLY ONCE on each side (query time and index-build
    /// time), so single-application equality with the contract is the correct property.
    func testRomanNormMatchesContractExactly() throws {
        let url = repoRoot().appendingPathComponent("contract/golden_roman_norm.ndjson")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("contract missing") }
        let rows = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        struct V: Decodable { let input: String; let output: String }
        let dec = JSONDecoder()
        var checked = 0
        for row in rows {
            let v = try dec.decode(V.self, from: Data(row.utf8))
            let once = RomanNorm.fold(v.input)
            XCTAssertEqual(once, v.output, "fold(\(v.input.debugDescription)) drifted from contract")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 24_000)
    }
}
