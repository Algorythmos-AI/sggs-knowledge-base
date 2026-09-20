import XCTest
import CSQLite
@testable import GurbaniDB

/// `stepRow` is the single row-iteration primitive. These tests pin the property the app depends
/// on: a step that ends with anything other than ROW / DONE is an ERROR, never "no more rows" —
/// because "no more rows" on a damaged page is a silently truncated Ang.
/// Self-contained: tiny throwaway databases, no corpus needed.
final class StepErrorTests: XCTestCase {

    private func open(_ path: String = ":memory:", flags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) throws -> OpaquePointer {
        var h: OpaquePointer?
        guard sqlite3_open_v2(path, &h, flags, nil) == SQLITE_OK, let h else { throw XCTSkip("cannot open sqlite") }
        return h
    }

    private func prepare(_ db: OpaquePointer, _ sql: String) throws -> OpaquePointer {
        var s: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &s, nil), SQLITE_OK, String(cString: sqlite3_errmsg(db)))
        return try XCTUnwrap(s)
    }

    func testRowsThenDone() throws {
        let db = try open(); defer { sqlite3_close(db) }
        let s = try prepare(db, "SELECT 1 UNION ALL SELECT 2"); defer { sqlite3_finalize(s) }
        XCTAssertTrue(try stepRow(s))
        XCTAssertTrue(try stepRow(s))
        XCTAssertFalse(try stepRow(s), "SQLITE_DONE is the only clean end")
    }

    /// One good row, then a step-time failure. The old `while sqlite3_step(s) == SQLITE_ROW` loop
    /// would have returned that one row as if it were the whole result.
    func testErrorAfterARowThrowsInsteadOfTruncating() throws {
        let db = try open(); defer { sqlite3_close(db) }
        let s = try prepare(db, "SELECT 1 UNION ALL SELECT abs(-9223372036854775808)"); defer { sqlite3_finalize(s) }
        var rows = 0
        XCTAssertThrowsError(try { while try stepRow(s) { rows += 1 } }()) { error in
            guard case SQLiteCandidateSource.DBError.step(let code, let message) = error else {
                return XCTFail("expected DBError.step, got \(error)")
            }
            XCTAssertEqual(code & 0xFF, SQLITE_ERROR)
            XCTAssertFalse(message.isEmpty)
        }
        XCTAssertEqual(rows, 1, "the partial row count is exactly what must never be returned as complete")
    }

    func testNonThrowingVariantReportsFailure() throws {
        let db = try open(); defer { sqlite3_close(db) }
        let s = try prepare(db, "SELECT 1 UNION ALL SELECT abs(-9223372036854775808)"); defer { sqlite3_finalize(s) }
        var failed = false
        var rows = 0
        while stepRow(s, failed: &failed) { rows += 1 }
        XCTAssertTrue(failed, "callers discard their partial rows when this is set")
        XCTAssertEqual(rows, 1)
    }

    func testNonThrowingVariantCleanEnd() throws {
        let db = try open(); defer { sqlite3_close(db) }
        let s = try prepare(db, "SELECT 1"); defer { sqlite3_finalize(s) }
        var failed = false
        XCTAssertTrue(stepRow(s, failed: &failed))
        XCTAssertFalse(stepRow(s, failed: &failed))
        XCTAssertFalse(failed)
    }

    /// End to end on a genuinely damaged file, opened the way the app opens the corpus
    /// (read-only + immutable): a full scan must throw SQLITE_CORRUPT, not stop early.
    func testCorruptedDatabaseFileThrowsOnScan() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("step-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let db = try open(url.path); defer { sqlite3_close(db) }
            XCTAssertEqual(sqlite3_exec(db, """
                PRAGMA page_size=1024; PRAGMA journal_mode=OFF;
                CREATE TABLE lines(id INTEGER PRIMARY KEY, t TEXT);
                WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<4000)
                INSERT INTO lines SELECT i, printf('%0200d', i) FROM n;
                """, nil, nil, nil), SQLITE_OK)
        }
        // Overwrite a run of interior/leaf pages past the header and schema page.
        let handle = try FileHandle(forUpdating: url)
        let size = try handle.seekToEnd()
        XCTAssertGreaterThan(size, 64 * 1024)
        try handle.seek(toOffset: 8 * 1024)
        handle.write(Data(repeating: 0xFF, count: 24 * 1024))
        try handle.close()

        let db = try open("file:\(url.path)?mode=ro&immutable=1", flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI)
        defer { sqlite3_close(db) }
        let s = try prepare(db, "SELECT id, t FROM lines ORDER BY id"); defer { sqlite3_finalize(s) }
        var rows = 0
        XCTAssertThrowsError(try { while try stepRow(s) { rows += 1 } }()) { error in
            guard case SQLiteCandidateSource.DBError.step(let code, _) = error else {
                return XCTFail("expected DBError.step, got \(error)")
            }
            XCTAssertEqual(code & 0xFF, SQLITE_CORRUPT)
        }
        XCTAssertLessThan(rows, 4000, "the scan cannot have completed")
    }
}
