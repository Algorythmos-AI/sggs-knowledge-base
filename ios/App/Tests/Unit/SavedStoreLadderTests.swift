import XCTest
import SwiftData
@testable import SGGS

/// The bookmarks-store fallback ladder must never delete a reader's saved verses on a
/// one-off open failure: first failure → session-only in-memory store (nothing lost);
/// only a second consecutive failure destroys and recreates the file.
final class SavedStoreLadderTests: XCTestCase {
    private func garbageStore() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sggs-ladder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("saved.store")
        try Data(repeating: 0x5A, count: 4096).write(to: url)   // not a SQLite file
        return url
    }

    /// Upgrade gate: the host app's real default store (created by earlier, un-versioned
    /// builds on this simulator) must open through the versioned schema WITHOUT hitting any
    /// fallback rung — otherwise an app update would silently reset readers' bookmarks.
    @MainActor
    func testExistingDefaultStoreOpensWithoutDegradation() {
        let c = AppContainer()
        XCTAssertNotNil(c.modelContainer)
        XCTAssertFalse(c.savedStoreDegraded, "default store must open cleanly on upgrade")
        XCTAssertFalse(c.savedStoreDestroyed)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppContainer.savedStoreFailKey), 0)
    }

    @MainActor
    func testHealthyStoreOpensPersistently() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sggs-ladder-ok-\(UUID().uuidString).store")
        let r = AppContainer.openSavedStore(url: url, priorFailures: 0)
        XCTAssertNotNil(r.container)
        XCTAssertFalse(r.degraded); XCTAssertFalse(r.destroyed)
    }

    @MainActor
    func testFirstFailureFallsBackToMemoryWithoutDeleting() throws {
        let url = try garbageStore()
        let before = try Data(contentsOf: url)
        let r = AppContainer.openSavedStore(url: url, priorFailures: 0)
        XCTAssertNotNil(r.container, "in-memory fallback must still give a usable store")
        XCTAssertTrue(r.degraded)
        XCTAssertFalse(r.destroyed, "a first failure must never destroy the file")
        XCTAssertEqual(try Data(contentsOf: url), before, "the store file must be untouched")
    }

    @MainActor
    func testSecondConsecutiveFailureRecreates() throws {
        let url = try garbageStore()
        let r = AppContainer.openSavedStore(url: url, priorFailures: 1)
        XCTAssertNotNil(r.container)
        XCTAssertTrue(r.degraded); XCTAssertTrue(r.destroyed)
        // the recreated store is a real persistent one: it opens cleanly next time
        let again = AppContainer.openSavedStore(url: url, priorFailures: 0)
        XCTAssertFalse(again.degraded)
    }
}
