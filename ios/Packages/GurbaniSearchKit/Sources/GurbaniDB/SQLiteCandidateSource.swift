import Foundation
import SQLite3
import GurbaniSearchKit

/// Read-only SQLite implementation of `CandidateSource`, querying the bundled corpus DB exactly
/// as `webapp/serve.py` does: opened `mode=ro&immutable=1` with `query_only=ON`, FTS rowids in
/// rank order, line rows by id. (In the iOS app this is wrapped by GRDB with a pinned SQLite; for
/// the parity test the macOS system SQLite is 3.51.0 — the same version as the web reference.)
public final class SQLiteCandidateSource: CandidateSource, @unchecked Sendable {

    private let db: OpaquePointer
    // SQLite wants the bound text to persist for the call; SQLITE_TRANSIENT makes it copy.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public enum DBError: Error { case open(String), prepare(String) }

    public init(path: String) throws {
        var handle: OpaquePointer?
        let uri = "file:\(path)?mode=ro&immutable=1"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        guard sqlite3_open_v2(uri, &handle, flags, nil) == SQLITE_OK, let h = handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let handle { sqlite3_close(handle) }
            throw DBError.open(msg)
        }
        self.db = h
        sqlite3_exec(h, "PRAGMA query_only=ON", nil, nil, nil)
    }

    deinit { sqlite3_close(db) }

    public func ftsRowids(_ match: String, limit: Int) throws -> [Int] {
        if match.isEmpty { return [] }   // verify._fts_query guard: never MATCH ''
        var stmt: OpaquePointer?
        let sql = "SELECT rowid, rank FROM fts WHERE fts MATCH ? ORDER BY rank LIMIT ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, match, -1, Self.transient)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var out: [Int] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(Int(sqlite3_column_int64(stmt, 0)))
        }
        return out
    }

    public func fetchLine(_ rowid: Int) throws -> GurbaniLine? {
        var stmt: OpaquePointer?
        let sql = """
        SELECT id, ang, gurmukhi, translit, translit_norm, raag, author, comp_id, section
        FROM lines WHERE id = ?
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(rowid))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        func text(_ col: Int32) -> String {
            sqlite3_column_text(stmt, col).map { String(cString: $0) } ?? ""
        }
        func optText(_ col: Int32) -> String? {
            sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : text(col)
        }
        return GurbaniLine(
            id: Int(sqlite3_column_int64(stmt, 0)),
            ang: Int(sqlite3_column_int64(stmt, 1)),
            gurmukhi: text(2), translit: text(3), translitNorm: text(4),
            raag: optText(5), author: optText(6),
            compId: Int(sqlite3_column_int64(stmt, 7)), section: optText(8)
        )
    }
}
