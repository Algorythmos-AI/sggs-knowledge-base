import XCTest
@testable import SGGS

/// The launch-hash cache: the full ~100 MB streaming verify runs once per (file, bundle version,
/// manifest); later launches skip it on a fingerprint match and still run the structural checks.
/// Fail-closed is untouched: any mismatch or garbage cache forces the full verify, and a failed
/// verify clears the cache.
final class LaunchCacheTests: XCTestCase {

    /// Wipes and returns the name of an isolated UserDefaults suite (run() takes the NAME —
    /// a Sendable String — because UserDefaults itself can't cross actor boundaries in Swift 6).
    private func freshSuite(_ name: String) -> String {
        UserDefaults(suiteName: name)!.removePersistentDomain(forName: name)
        return name
    }

    // MARK: pure decision logic

    func testCacheHitRequiresEveryFieldToMatch() {
        let fp = DBFingerprint(dbSha256: "abc", fileSize: 100, fileMtimeNs: 5, bundleVersion: "1.0.0+1", manifestSha: "abc")
        func hit(sha: String? = "abc", size: Int64? = 100, mtime: Int64? = 5, bundle: String = "1.0.0+1") -> Bool {
            LaunchIntegrity.cacheHit(stored: fp, expectedSha: sha, fileSize: size, fileMtimeNs: mtime, bundleVersion: bundle)
        }
        XCTAssertTrue(hit())
        XCTAssertFalse(hit(sha: "different"))          // manifest changed → full verify
        XCTAssertFalse(hit(sha: nil))                  // manifest unreadable → full verify (fails closed later)
        XCTAssertFalse(hit(size: 101))                 // file grew/shrank → full verify
        XCTAssertFalse(hit(size: nil))                 // attrs unreadable → full verify
        XCTAssertFalse(hit(mtime: 6))                  // file touched → full verify
        XCTAssertFalse(hit(bundle: "1.0.1+2"))         // app updated → full verify
        XCTAssertFalse(LaunchIntegrity.cacheHit(stored: nil, expectedSha: "abc", fileSize: 100,
                                                fileMtimeNs: 5, bundleVersion: "1.0.0+1"))   // first launch
    }

    // MARK: end-to-end against the real bundle DB

    @MainActor
    func testFirstRunStreamsSecondRunUsesCache() async throws {
        guard let corpus = try? CorpusActor() else { throw XCTSkip("bundled DB not found in host app") }
        let suite = freshSuite("sggs-launch-cache-test-a")
        let first = await LaunchIntegrity.run(corpus: corpus, cacheSuiteName: suite)
        XCTAssertTrue(first.ok, "first (streamed) verify must pass: \(first.checks.filter { !$0.passed }.map(\.name))")
        XCTAssertFalse(first.usedCachedHash, "first run must stream the full hash")
        let second = await LaunchIntegrity.run(corpus: corpus, cacheSuiteName: suite)
        XCTAssertTrue(second.ok)
        XCTAssertTrue(second.usedCachedHash, "second run must skip the streaming hash")
        XCTAssertEqual(second.dbSha256, first.dbSha256)
        // structural checks still ran on the cached path
        XCTAssertEqual(second.checks.count, first.checks.count)
    }

    @MainActor
    func testGarbageCacheForcesFullVerify() async throws {
        guard let corpus = try? CorpusActor() else { throw XCTSkip("bundled DB not found in host app") }
        let suite = freshSuite("sggs-launch-cache-test-b")
        UserDefaults(suiteName: suite)!.set(Data("not a fingerprint".utf8), forKey: LaunchIntegrity.cacheKey)
        let report = await LaunchIntegrity.run(corpus: corpus, cacheSuiteName: suite)
        XCTAssertTrue(report.ok)
        XCTAssertFalse(report.usedCachedHash, "garbage cache data must fall back to the full verify")
    }
}
