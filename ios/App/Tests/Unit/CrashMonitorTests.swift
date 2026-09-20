import XCTest
@testable import SGGS

/// The local diagnostics folder is scratch evidence: bounded, ordered, and deletable by the reader.
final class CrashMonitorTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("diag-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    private func write(_ names: [String]) throws {
        for n in names { try Data("{}".utf8).write(to: folder.appendingPathComponent(n)) }
    }

    func testFilesAreFilteredAndOldestFirst() throws {
        try write(["diagnostic-2026-09-20T10-00-00Z.json", "diagnostic-2026-09-18T10-00-00Z.json", "notes.txt"])
        XCTAssertEqual(CrashMonitor.files(in: folder).map(\.lastPathComponent),
                       ["diagnostic-2026-09-18T10-00-00Z.json", "diagnostic-2026-09-20T10-00-00Z.json"])
    }

    func testPruneKeepsOnlyTheNewest() throws {
        try write((1...9).map { "diagnostic-2026-09-0\($0)T00-00-00Z.json" } + ["keep-me.txt"])
        CrashMonitor.prune(in: folder, keep: 3)
        XCTAssertEqual(CrashMonitor.files(in: folder).map(\.lastPathComponent),
                       ["diagnostic-2026-09-07T00-00-00Z.json", "diagnostic-2026-09-08T00-00-00Z.json",
                        "diagnostic-2026-09-09T00-00-00Z.json"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("keep-me.txt").path),
                      "only diagnostic-* files are ever removed")
    }

    func testPruneUnderTheCapRemovesNothing() throws {
        try write(["diagnostic-a.json", "diagnostic-b.json"])
        CrashMonitor.prune(in: folder, keep: CrashMonitor.keep)
        XCTAssertEqual(CrashMonitor.files(in: folder).count, 2)
    }

    func testDeleteAll() throws {
        try write(["diagnostic-a.json", "diagnostic-b.json", "other.txt"])
        CrashMonitor.deleteAll(in: folder)
        XCTAssertTrue(CrashMonitor.files(in: folder).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("other.txt").path))
    }

    func testMissingFolderIsEmptyNotACrash() {
        XCTAssertTrue(CrashMonitor.files(in: folder.appendingPathComponent("nope")).isEmpty)
        CrashMonitor.deleteAll(in: folder.appendingPathComponent("nope"))
    }
}
