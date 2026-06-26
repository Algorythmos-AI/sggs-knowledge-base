import Foundation
import CSQLite
import GurbaniSearchKit

/// SearchSource over the read-only corpus DB — the exact serve.py SQL (BM25 weights,
/// `ORDER BY m.rk, lines.id` tie-break, the FTS column allowlist, theme + related-theme lookups).
extension SQLiteCandidateSource: SearchSource {

    private static let ftsCols: Set<String> = ["text", "translit", "translit_norm", "fl_g", "fl_r", "skeleton"]
    private static let lineCols = "id, ang, gurmukhi, translit, raag, section, author, comp_id, is_rahao, is_header"

    private func mapLine(_ stmt: OpaquePointer?) -> SearchLine {
        func text(_ c: Int32) -> String { sqlite3_column_text(stmt, c).map { String(cString: $0) } ?? "" }
        func optText(_ c: Int32) -> String? { sqlite3_column_type(stmt, c) == SQLITE_NULL ? nil : text(c) }
        return SearchLine(
            id: Int(sqlite3_column_int64(stmt, 0)), ang: Int(sqlite3_column_int64(stmt, 1)),
            gurmukhi: text(2), translit: text(3), raag: optText(4), section: optText(5),
            author: optText(6), compId: Int(sqlite3_column_int64(stmt, 7)),
            isRahao: sqlite3_column_int64(stmt, 8) != 0, isHeader: sqlite3_column_int64(stmt, 9) != 0)
    }

    public func ftsSearch(column: String, match: String, excludeHeaders: Bool, limit: Int, offset: Int) throws -> [SearchLine] {
        guard Self.ftsCols.contains(column) else { throw DBError.prepare("invalid column: \(column)") }
        if match.isEmpty { return [] }
        let wh = excludeHeaders ? " WHERE lines.is_header = 0" : ""
        let sql = """
        SELECT \(Self.lineCols) FROM lines JOIN
          (SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk
           FROM fts WHERE \(column) MATCH ?) m ON lines.id = m.rowid\(wh)
        ORDER BY m.rk, lines.id LIMIT ? OFFSET ?
        """
        return try query(sql, text: [(1, match)], ints: [(2, limit), (3, offset)])
    }

    public func ftsSearchExpr(match: String, excludeHeaders: Bool, limit: Int, offset: Int) throws -> [SearchLine] {
        if match.isEmpty { return [] }
        let wh = excludeHeaders ? " WHERE lines.is_header = 0" : ""
        let sql = """
        SELECT \(Self.lineCols) FROM lines JOIN
          (SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk
           FROM fts WHERE fts MATCH ?) m ON lines.id = m.rowid\(wh)
        ORDER BY m.rk, lines.id LIMIT ? OFFSET ?
        """
        return try query(sql, text: [(1, match)], ints: [(2, limit), (3, offset)])
    }

    public func ftsSearchExprWithNorm(match: String, limit: Int) throws -> [VariantRow] {
        if match.isEmpty { return [] }
        // NOTE: serve.py's all-but-one fallback uses ORDER BY m.rk (no lines.id tiebreak), LIMIT 150.
        let sql = """
        SELECT \(Self.lineCols), translit_norm FROM lines JOIN
          (SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk
           FROM fts WHERE fts MATCH ?) m ON lines.id = m.rowid
        ORDER BY m.rk LIMIT ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, match, -1, Self.transientDtor)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var out: [VariantRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let line = mapLine(stmt)
            let tn = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""  // translit_norm follows lineCols
            out.append(VariantRow(line: line, translit: line.translit, translitNorm: tn))
        }
        return out
    }

    public func variantsLookup(_ token: String) throws -> [String] {
        var stmt: OpaquePointer?
        let sql = "SELECT DISTINCT translit FROM variants WHERE variant = ? ORDER BY freq * score DESC LIMIT 3"
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, token, -1, Self.transientDtor)
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "")
        }
        return out
    }

    public func ftsShabad(match: String, limit: Int) throws -> [ShabadCand] {
        if match.isEmpty { return [] }
        var stmt: OpaquePointer?
        let sql = "SELECT comp_id, tnorm, rank FROM fts_shabad WHERE fts_shabad MATCH ? ORDER BY rank LIMIT ?"
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, match, -1, Self.transientDtor)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var out: [ShabadCand] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(ShabadCand(compId: Int(sqlite3_column_int64(stmt, 0)),
                                  tnorm: sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "",
                                  rank: sqlite3_column_double(stmt, 2)))
        }
        return out
    }

    public func shabadLineNorms(compIds: [Int]) throws -> [Int: [String]] {
        if compIds.isEmpty { return [:] }
        let ph = Array(repeating: "?", count: compIds.count).joined(separator: ",")
        let sql = "SELECT comp_id, translit_norm FROM lines WHERE comp_id IN (\(ph)) AND is_header = 0"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, cid) in compIds.enumerated() { sqlite3_bind_int(stmt, Int32(i + 1), Int32(cid)) }
        var out: [Int: [String]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let cid = Int(sqlite3_column_int64(stmt, 0))
            let tn = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            out[cid, default: []].append(tn)
        }
        return out
    }

    public func compLines(compId: Int) throws -> [VariantRow] {
        let sql = "SELECT \(Self.lineCols), translit_norm FROM lines WHERE comp_id = ? AND is_header = 0 ORDER BY id"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(compId))
        var out: [VariantRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let line = mapLine(stmt)
            let tn = sqlite3_column_text(stmt, 10).map { String(cString: $0) } ?? ""
            out.append(VariantRow(line: line, translit: line.translit, translitNorm: tn))
        }
        return out
    }

    public func isCanon(_ token: String) throws -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT 1 FROM canon_tokens WHERE token = ?", -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, token, -1, Self.transientDtor)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    public func likeSearch(column: String, pattern: String, limit: Int, offset: Int) throws -> [SearchLine] {
        guard Self.ftsCols.contains(column) else { throw DBError.prepare("invalid column: \(column)") }
        let sql = "SELECT \(Self.lineCols) FROM lines WHERE \(column) LIKE ? ORDER BY id LIMIT ? OFFSET ?"
        return try query(sql, text: [(1, pattern)], ints: [(2, limit), (3, offset)])
    }

    public func conceptExactExists(_ name: String) throws -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT 1 FROM concepts WHERE concept = ? LIMIT 1", -1, &stmt, nil) == SQLITE_OK
        else { throw DBError.prepare(String(cString: sqlite3_errmsg(handle))) }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, name, -1, Self.transientDtor)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    public func themeSearch(_ q: String, limit: Int, offset: Int) throws -> ThemeSearchResult {
        let ql = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // exact concept, else LIKE on concept/description
        var name: String?, termsJSON = "", desc = ""
        if let row = try conceptRow("SELECT concept, gurmukhi_terms, description FROM concepts WHERE concept = ?", ql) {
            (name, termsJSON, desc) = row
        } else if let row = try conceptRow(
            "SELECT concept, gurmukhi_terms, description FROM concepts WHERE concept LIKE ? OR description LIKE ?",
            "%\(ql)%", second: "%\(ql)%") {
            (name, termsJSON, desc) = row
        }
        guard let concept = name else { return ThemeSearchResult(concept: nil, lines: []) }

        let sql = """
        SELECT \(Self.lineCols) FROM concept_lines cl JOIN lines ON lines.id = cl.line_id
        WHERE cl.concept = ? ORDER BY lines.id LIMIT ? OFFSET ?
        """
        let lines = try query(sql, text: [(1, concept)], ints: [(2, limit), (3, offset)])
        let total = try count("SELECT count(*) FROM concept_lines WHERE concept = ?", concept)
        let terms = (try? JSONDecoder().decode([String].self, from: Data(termsJSON.utf8))) ?? []
        return ThemeSearchResult(concept: ThemeConcept(name: concept, terms: terms, description: desc, total: total),
                                 lines: lines)
    }

    public func termConcepts(_ tokens: [String]) throws -> [String] {
        let index = try termIndex()
        var hits: [String] = []
        for t in tokens {
            for c in index[t] ?? [] where !hits.contains(c) { hits.append(c) }
        }
        return hits
    }

    // MARK: helpers

    private func query(_ sql: String, text: [(Int32, String)], ints: [(Int32, Int)]) throws -> [SearchLine] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, s) in text { sqlite3_bind_text(stmt, i, s, -1, Self.transientDtor) }
        for (i, n) in ints { sqlite3_bind_int(stmt, i, Int32(n)) }
        var out: [SearchLine] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(mapLine(stmt)) }
        return out
    }

    private func conceptRow(_ sql: String, _ a: String, second: String? = nil) throws -> (String, String, String)? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, a, -1, Self.transientDtor)
        if let b = second { sqlite3_bind_text(stmt, 2, b, -1, Self.transientDtor) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        func text(_ c: Int32) -> String { sqlite3_column_text(stmt, c).map { String(cString: $0) } ?? "" }
        return (text(0), text(1), text(2))
    }

    private func count(_ sql: String, _ a: String) throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, a, -1, Self.transientDtor)
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int64(stmt, 0)) : 0
    }
}
