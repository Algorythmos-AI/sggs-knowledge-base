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
    let sqliteVersion: String
    let checks: [Check]
    /// true when the full streaming hash was skipped because the cached fingerprint matched
    /// (same file size/mtime, same bundle version, same manifest sha as the last full verify).
    let usedCachedHash: Bool
    struct Check: Sendable, Identifiable { let name: String; let passed: Bool; var id: String { name } }
}

/// What the launch cache records after a successful FULL streaming verify. If every field still
/// matches at the next launch, the ~100 MB re-hash is skipped and only the cheap structural
/// checks run. ANY mismatch (fresh install, app update, bundle restored/repaired, manifest
/// change) forces a full re-verify.
///
/// THREAT MODEL: this cache defends scripture fidelity against ACCIDENTS — corruption, a
/// truncated copy, a bad build — not against an attacker: anyone who can rewrite a file inside
/// the signed app bundle can rewrite UserDefaults too. Anti-tamper is the code-signing layer's
/// job; the fail-closed behavior and the manifest chain (db_sha256 + scripture_sha256, certified
/// by pipeline/build_ios_db.py) are unchanged by caching.
struct DBFingerprint: Codable, Equatable, Sendable {
    let dbSha256: String        // the sha the full verify computed (== manifest at store time)
    let fileSize: Int64
    let fileMtimeNs: Int64
    let bundleVersion: String   // CFBundleShortVersionString+CFBundleVersion
    let manifestSha: String     // db_sha256 the bundled manifest claimed at store time
}

enum LaunchIntegrity {
    static let cacheKey = "sggs_db_verified_v1"

    /// Stream-hash the bundled DB (~100 MB) without loading it all into memory.
    /// Uses the throwing `read(upToCount:)` — the legacy `readData(ofLength:)` raises an
    /// uncatchable ObjC exception on an I/O error, which would CRASH the launch check on
    /// exactly the corrupted-bundle case it exists to catch. Any read failure returns nil,
    /// which the caller records as a failed check (fail closed, never fail crashed).
    private static func sha256(ofFileAt path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        var hasher = SHA256()
        do {
            while let chunk = try fh.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
        } catch { return nil }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func expectedSha() -> String? {
        guard let url = Bundle.main.url(forResource: "sggs-ios.manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj["db_sha256"] as? String
    }

    static func bundleVersionString(_ bundle: Bundle = .main) -> String {
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short)+\(build)"
    }

    static func fileFingerprint(path: String) -> (size: Int64, mtimeNs: Int64)? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: path),
              let size = (a[.size] as? NSNumber)?.int64Value,
              let mtime = a[.modificationDate] as? Date else { return nil }
        return (size, Int64((mtime.timeIntervalSince1970 * 1_000_000_000).rounded()))
    }

    /// Pure cache decision, extracted for unit testing: skip the streaming hash iff the stored
    /// fingerprint matches the CURRENT file attrs + bundle version + manifest sha exactly.
    static func cacheHit(stored: DBFingerprint?, expectedSha: String?,
                         fileSize: Int64?, fileMtimeNs: Int64?, bundleVersion: String) -> Bool {
        guard let stored, let expectedSha, let fileSize, let fileMtimeNs else { return false }
        return stored == DBFingerprint(dbSha256: expectedSha, fileSize: fileSize,
                                       fileMtimeNs: fileMtimeNs, bundleVersion: bundleVersion,
                                       manifestSha: expectedSha)
    }

    /// `cacheSuiteName` selects the UserDefaults domain for the fingerprint cache — nil = .standard
    /// (a String parameter, not a UserDefaults, so the call crosses actor boundaries under Swift 6).
    static func run(corpus: CorpusActor, cacheSuiteName: String? = nil) async -> IntegrityReport {
        var checks: [IntegrityReport.Check] = []
        let defaults = cacheSuiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        let path = corpus.dbPath
        let expected = expectedSha()
        let attrs = fileFingerprint(path: path)
        let bundleVersion = bundleVersionString()

        let stored = defaults.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode(DBFingerprint.self, from: $0) }
        let cached = cacheHit(stored: stored, expectedSha: expected,
                              fileSize: attrs?.size, fileMtimeNs: attrs?.mtimeNs, bundleVersion: bundleVersion)

        let sha: String
        if cached {
            sha = expected ?? ""                    // full verify already proved this exact file
        } else {
            // Hash the ~100 MB DB OFF the main thread (this is awaited from a @MainActor caller).
            sha = await Task.detached(priority: .userInitiated) { sha256(ofFileAt: path) ?? "" }.value
        }
        let hashOK = expected != nil && sha == expected
        checks.append(.init(name: "db_sha256 matches manifest", passed: hashOK))
        if hashOK && !cached, let expected, let attrs {
            let fp = DBFingerprint(dbSha256: sha, fileSize: attrs.size, fileMtimeNs: attrs.mtimeNs,
                                   bundleVersion: bundleVersion, manifestSha: expected)
            if let data = try? JSONEncoder().encode(fp) { defaults.set(data, forKey: cacheKey) }
        }
        if !hashOK { defaults.removeObject(forKey: cacheKey) }   // never cache a failure

        // Structural checks run on EVERY launch (cached or not) — cheap defence in depth.
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
                               expectedSha256: expected, sqliteVersion: corpus.sqliteVersion,
                               checks: checks, usedCachedHash: cached)
    }
}
