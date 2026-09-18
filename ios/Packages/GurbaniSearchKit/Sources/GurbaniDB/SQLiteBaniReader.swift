import Foundation
import CSQLite
import GurbaniSearchKit

/// Nitnem / Gutka bani registry over the read-only DB — the exact serve.py SQL for
/// /api/banis and /api/bani/{key}?variant=. Pinned by contract/golden_banis.ndjson.
/// Degrades to `available: false` / nil when the registry tables are absent (older DB
/// builds) — a failed prepare is that degradation, not an error.
extension SQLiteCandidateSource {

    private func colText(_ s: OpaquePointer?, _ c: Int32) -> String { sqlite3_column_text(s, c).map { String(cString: $0) } ?? "" }
    private func colOptText(_ s: OpaquePointer?, _ c: Int32) -> String? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : colText(s, c)
    }
    private func colOptInt(_ s: OpaquePointer?, _ c: Int32) -> Int? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(s, c))
    }

    private static let summaryCols =
        "key, variant, is_default, title_gm, title_en, category, order_no, n_lines, n_groups, " +
        "has_extra, estimated_minutes, description_en, source_label, bani_id"

    private func mapSummary(_ s: OpaquePointer?) -> BaniSummary {
        BaniSummary(
            key: colText(s, 0), variant: colText(s, 1), isDefault: sqlite3_column_int64(s, 2) != 0,
            titleGm: colText(s, 3), titleEn: colText(s, 4),
            category: BaniCategory(rawValue: colText(s, 5)) ?? .popular,
            orderNo: Int(sqlite3_column_int64(s, 6)), nLines: Int(sqlite3_column_int64(s, 7)),
            nGroups: Int(sqlite3_column_int64(s, 8)), hasExtra: sqlite3_column_int64(s, 9) != 0,
            estimatedMinutes: colOptInt(s, 10), descriptionEn: colOptText(s, 11), sourceLabel: colText(s, 12))
    }

    /// serve.py /api/banis — ORDER BY order_no, variant.
    public func fetchBanis() -> BaniList {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT \(Self.summaryCols) FROM banis ORDER BY order_no, variant",
                                 -1, &stmt, nil) == SQLITE_OK else {
            return BaniList(available: false, banis: [])
        }
        defer { sqlite3_finalize(stmt) }
        var out: [BaniSummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(mapSummary(stmt)) }
        return BaniList(available: true, banis: out)
    }

    /// serve.py /api/bani/{key}?variant= — nil when the key (or key+variant) does not exist.
    /// An empty `variant` resolves the default variant for the key.
    public func fetchBani(key: String, variant: String = "") -> Bani? {
        var stmt: OpaquePointer?
        let sql = variant.isEmpty
            ? "SELECT \(Self.summaryCols) FROM banis WHERE key=? AND is_default=1"
            : "SELECT \(Self.summaryCols) FROM banis WHERE key=? AND variant=?"
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, Self.transientDtor)
        if !variant.isEmpty { sqlite3_bind_text(stmt, 2, variant, -1, Self.transientDtor) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { sqlite3_finalize(stmt); return nil }
        let summary = mapSummary(stmt)
        let baniId = Int(sqlite3_column_int64(stmt, 13))
        sqlite3_finalize(stmt)

        var variants: [String] = []
        var vs: OpaquePointer?
        if sqlite3_prepare_v2(handle, "SELECT variant FROM banis WHERE key=? ORDER BY is_default DESC, variant",
                              -1, &vs, nil) == SQLITE_OK {
            sqlite3_bind_text(vs, 1, key, -1, Self.transientDtor)
            while sqlite3_step(vs) == SQLITE_ROW { variants.append(colText(vs, 0)) }
        }
        sqlite3_finalize(vs)

        let lineSQL = """
        SELECT bl.seq, bl.line_group, bl.line_id, bl.extra_id,
               l.ang, l.comp_id, l.is_rahao, l.is_header, l.gurmukhi, l.translit, l.markers,
               e.source, e.panna, e.gurmukhi, e.translit, e.is_header
        FROM bani_lines bl
        LEFT JOIN lines l ON l.id = bl.line_id
        LEFT JOIN extra_lines e ON e.extra_id = bl.extra_id
        WHERE bl.bani_id = ? ORDER BY bl.seq
        """
        var ls: OpaquePointer?
        guard sqlite3_prepare_v2(handle, lineSQL, -1, &ls, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(ls) }
        sqlite3_bind_int64(ls, 1, Int64(baniId))
        var lines: [BaniLine] = []
        var sggsIds: [Int] = []
        var angs: [Int] = []
        while sqlite3_step(ls) == SQLITE_ROW {
            let seq = Int(sqlite3_column_int64(ls, 0))
            let group = Int(sqlite3_column_int64(ls, 1))
            if let lineId = colOptInt(ls, 2) {
                let ang = Int(sqlite3_column_int64(ls, 4))
                let markersJSON = colOptText(ls, 10) ?? "[]"
                let markers = (try? JSONDecoder().decode([String].self, from: Data(markersJSON.utf8))) ?? []
                lines.append(BaniLine(
                    seq: seq, lineGroup: group, gurmukhi: colText(ls, 8), translit: colText(ls, 9),
                    isHeader: sqlite3_column_int64(ls, 7) != 0, isRahao: sqlite3_column_int64(ls, 6) != 0,
                    markers: markers,
                    citation: .sggs(ang: ang, lineId: lineId, compId: Int(sqlite3_column_int64(ls, 5)))))
                sggsIds.append(lineId)
                angs.append(ang)
            } else {
                let extraId = Int(sqlite3_column_int64(ls, 3))
                let source = colText(ls, 11)
                let citation: BaniCitation = source == "dasam"
                    ? .dasam(panna: colOptInt(ls, 12), extraId: extraId)
                    : .ardaas(extraId: extraId)
                lines.append(BaniLine(
                    seq: seq, lineGroup: group, gurmukhi: colText(ls, 13), translit: colText(ls, 14),
                    isHeader: sqlite3_column_int64(ls, 15) != 0, isRahao: false, markers: [],
                    citation: citation))
            }
        }
        // serve.py attach_translations — SGGS rows only; no-op on the public profile.
        let en = baniEnMap(ids: sggsIds)
        if !en.isEmpty {
            lines = lines.map { l in
                guard let lid = l.citation.lineId, let t = en[lid] else { return l }
                return BaniLine(seq: l.seq, lineGroup: l.lineGroup, gurmukhi: l.gurmukhi, translit: l.translit,
                                isHeader: l.isHeader, isRahao: l.isRahao, markers: l.markers,
                                citation: l.citation, en: t)
            }
        }
        return Bani(summary: summary, variants: variants, angFirst: angs.min(), angLast: angs.max(), lines: lines)
    }

    private func baniEnMap(ids: [Int]) -> [Int: String] {
        guard !ids.isEmpty else { return [:] }
        var out: [Int: String] = [:]
        // chunked: Sukhmani has 2,047 ids — stay well under SQLite's default bound-parameter limit.
        for chunk in stride(from: 0, to: ids.count, by: 500) {
            let part = Array(ids[chunk..<min(chunk + 500, ids.count)])
            let ph = Array(repeating: "?", count: part.count).joined(separator: ",")
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle, "SELECT line_id, text FROM translations WHERE lang='en' AND line_id IN (\(ph))",
                                     -1, &stmt, nil) == SQLITE_OK else { return [:] }
            for (i, lid) in part.enumerated() { sqlite3_bind_int64(stmt, Int32(i + 1), Int64(lid)) }
            while sqlite3_step(stmt) == SQLITE_ROW { out[Int(sqlite3_column_int64(stmt, 0))] = colText(stmt, 1) }
            sqlite3_finalize(stmt)
        }
        return out
    }
}
