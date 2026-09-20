import Foundation
import CSQLite
import GurbaniSearchKit

/// Read-only SQLite implementation of the verify `CandidateSource` (and, via an extension,
/// the `SearchSource`), querying the bundled corpus DB exactly as `webapp/serve.py` does:
/// opened `mode=ro&immutable=1` with `query_only=ON`, FTS rowids in rank order, line rows by id.
/// Links the VENDORED SQLite (CSQLite target, amalgamation 3.51.0 with FTS5) — the exact engine that
/// built the corpus index + the golden vectors — so unicode61 tokenization + bm25 ordering are
/// byte-identical on every device, not subject to the host iOS's system SQLite version.
public final class SQLiteCandidateSource: CandidateSource, @unchecked Sendable {

    let handle: OpaquePointer
    // SQLite wants bound text to persist for the call; SQLITE_TRANSIENT makes it copy.
    static let transientDtor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// The linked (pinned) SQLite version — provenance for the integrity/About surface.
    public static var sqliteVersion: String { String(cString: sqlite3_libversion()) }

    private let lock = NSLock()
    private var _termIndex: [String: [String]]?

    public enum DBError: Error {
        case open(String), prepare(String)
        /// `sqlite3_step` ended with something other than ROW/DONE (corrupt page, I/O error, …).
        case step(code: Int32, message: String)
    }

    public init(path: String) throws {
        var h: OpaquePointer?
        let uri = "file:\(path)?mode=ro&immutable=1"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        guard sqlite3_open_v2(uri, &h, flags, nil) == SQLITE_OK, let opened = h else {
            let msg = h.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let h { sqlite3_close(h) }
            throw DBError.open(msg)
        }
        self.handle = opened
        sqlite3_exec(opened, "PRAGMA query_only=ON", nil, nil, nil)
    }

    deinit { sqlite3_close(handle) }

    public func ftsRowids(_ match: String, limit: Int) throws -> [Int] {
        if match.isEmpty { return [] }   // verify._fts_query guard: never MATCH ''
        var stmt: OpaquePointer?
        let sql = "SELECT rowid, rank FROM fts WHERE fts MATCH ? ORDER BY rank LIMIT ?"
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, match, -1, Self.transientDtor)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var out: [Int] = []
        while try stepRow(stmt) { out.append(Int(sqlite3_column_int64(stmt, 0))) }
        return out
    }

    public func fetchLine(_ rowid: Int) throws -> GurbaniLine? {
        var stmt: OpaquePointer?
        let sql = """
        SELECT id, ang, gurmukhi, translit, translit_norm, raag, author, comp_id, section
        FROM lines WHERE id = ?
        """
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(rowid))
        guard try stepRow(stmt) else { return nil }

        func text(_ col: Int32) -> String { sqlite3_column_text(stmt, col).map { String(cString: $0) } ?? "" }
        func optText(_ col: Int32) -> String? { sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : text(col) }
        return GurbaniLine(
            id: Int(sqlite3_column_int64(stmt, 0)), ang: Int(sqlite3_column_int64(stmt, 1)),
            gurmukhi: text(2), translit: text(3), translitNorm: text(4),
            raag: optText(5), author: optText(6),
            compId: Int(sqlite3_column_int64(stmt, 7)), section: optText(8))
    }

    /// term → [concept] index from `concepts.gurmukhi_terms`, built once (mirrors term_concepts).
    func termIndex() throws -> [String: [String]] {
        lock.lock(); defer { lock.unlock() }
        if let idx = _termIndex { return idx }
        var idx: [String: [String]] = [:]
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT concept, gurmukhi_terms FROM concepts", -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        while try stepRow(stmt) {
            let concept = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
            let json = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "[]"
            let terms = (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
            for t in terms { idx[t, default: []].append(concept) }
        }
        _termIndex = idx
        return idx
    }
}
