import Foundation
import CryptoKit

/// The iOS analogue of /api/health: a fail-closed launch self-test. The SHA-256 match against the
/// certified manifest is the strongest guarantee — if it holds, the DB is bit-identical to the
/// proven corpus, so all invariants hold by construction. A couple of cheap structural checks add
/// defence in depth. If anything fails, the app refuses to present scripture.
struct IntegrityReport: Sendable {
    let ok: Bool
    let dbSha256: String
    let expectedSha256: String?
    let checks: [Check]
    struct Check: Sendable, Identifiable { let name: String; let passed: Bool; var id: String { name } }
}

enum LaunchIntegrity {
    /// Stream-hash the bundled DB (91 MB) without loading it all into memory.
    private static func sha256(ofFileAt path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        var hasher = SHA256()
        while case let chunk = fh.readData(ofLength: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func expectedSha() -> String? {
        guard let url = Bundle.main.url(forResource: "sggs-ios.manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj["db_sha256"] as? String
    }

    static func run(corpus: CorpusActor) async -> IntegrityReport {
        var checks: [IntegrityReport.Check] = []
        let sha = sha256(ofFileAt: corpus.dbPath) ?? ""
        let expected = expectedSha()
        checks.append(.init(name: "db_sha256 matches manifest", passed: expected != nil && sha == expected))

        // Mool Mantar prefix on Ang 1
        let mool = (try? await corpus.ang(1).lines.first?.gurmukhi)?
            .hasPrefix("ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ") ?? false
        checks.append(.init(name: "Mool Mantar present", passed: mool))

        // FTS works
        let fts = ((try? await corpus.search("ਨਾਮੁ", mode: "gurmukhi", limit: 1, offset: 0))?.results.isEmpty == false)
        checks.append(.init(name: "FTS search works", passed: fts))

        // verify engine self-test → VERIFIED_EXACT (matched line id 5)
        let verdict = (try? await corpus.verify("ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ", ang: 1))?.verdict ?? ""
        checks.append(.init(name: "Verify engine sane", passed: verdict.hasPrefix("VERIFIED_EXACT")))

        return IntegrityReport(ok: checks.allSatisfy { $0.passed }, dbSha256: sha,
                               expectedSha256: expected, checks: checks)
    }
}
