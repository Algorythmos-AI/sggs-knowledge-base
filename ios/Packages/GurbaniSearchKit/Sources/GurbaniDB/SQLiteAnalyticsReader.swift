import Foundation
import CSQLite
import GurbaniSearchKit

/// Insight-Engine deep reads over the read-only DB — the exact serve.py SQL/logic for
/// /api/analytics/{author,resonance,progression,vaars,vaar}. Pinned by
/// contract/golden_analytics.ndjson. All degrade to empty when analytics tables are absent.
extension SQLiteCandidateSource {

    private func aText(_ s: OpaquePointer?, _ c: Int32) -> String? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : sqlite3_column_text(s, c).map { String(cString: $0) }
    }
    private func aInt(_ s: OpaquePointer?, _ c: Int32) -> Int? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(s, c))
    }

    /// serve.py:/api/analytics/author?author=X(&full=1) — stylometry + fingerprint + terms.
    public func authorProfile(_ author: String, full: Bool) -> AuthorProfile {
        var stylometry: AuthorStylometry?
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(handle,
            "SELECT author, n_lines, n_shabads, n_raags, n_tokens, mattr_100, hapax_pct, "
            + "avg_words_line, avg_lines_shabad, top_themes, is_reliable "
            + "FROM author_analytics WHERE author=?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, author, -1, Self.transientDtor)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let themesJSON = aText(stmt, 9) ?? "[]"
                let themes = (try? JSONDecoder().decode([TopTheme].self, from: Data(themesJSON.utf8))) ?? []
                stylometry = AuthorStylometry(
                    author: aText(stmt, 0) ?? author,
                    nLines: aInt(stmt, 1) ?? 0, nShabads: aInt(stmt, 2) ?? 0, nRaags: aInt(stmt, 3) ?? 0,
                    nTokens: aInt(stmt, 4) ?? 0, mattr100: sqlite3_column_double(stmt, 5),
                    hapaxPct: sqlite3_column_double(stmt, 6), avgWordsLine: sqlite3_column_double(stmt, 7),
                    avgLinesShabad: sqlite3_column_double(stmt, 8),
                    topThemes: themes, isReliable: (aInt(stmt, 10) ?? 0) != 0)
            }
        }
        sqlite3_finalize(stmt)

        var fp: [FingerprintAxis] = []
        var fs: OpaquePointer?
        let fpLim: Int32 = full ? 60 : 12    // serve.py:901 — full=1 → every concept (radar axes)
        if sqlite3_prepare_v2(handle,
            "SELECT concept, n_tagged, entity_rate, corpus_rate, lift FROM theme_fingerprint "
            + "WHERE entity_type='author' AND entity_id=? ORDER BY lift DESC LIMIT ?", -1, &fs, nil) == SQLITE_OK {
            sqlite3_bind_text(fs, 1, author, -1, Self.transientDtor)
            sqlite3_bind_int(fs, 2, fpLim)
            while sqlite3_step(fs) == SQLITE_ROW {
                fp.append(FingerprintAxis(concept: aText(fs, 0) ?? "", nTagged: aInt(fs, 1) ?? 0,
                                          entityRate: sqlite3_column_double(fs, 2),
                                          corpusRate: sqlite3_column_double(fs, 3),
                                          lift: sqlite3_column_double(fs, 4)))
            }
        }
        sqlite3_finalize(fs)

        var terms: [DistinctiveTerm] = []
        var ts: OpaquePointer?
        if sqlite3_prepare_v2(handle,
            "SELECT term, z_score, rank FROM author_distinctive_terms "
            + "WHERE author=? ORDER BY rank LIMIT 12", -1, &ts, nil) == SQLITE_OK {
            sqlite3_bind_text(ts, 1, author, -1, Self.transientDtor)
            while sqlite3_step(ts) == SQLITE_ROW {
                terms.append(DistinctiveTerm(term: aText(ts, 0) ?? "",
                                             zScore: sqlite3_column_double(ts, 1),
                                             rank: aInt(ts, 2) ?? 0))
            }
        }
        sqlite3_finalize(ts)
        return AuthorProfile(author: author, stylometry: stylometry, fingerprint: fp, distinctiveTerms: terms)
    }

    /// serve.py:/api/analytics/resonance — nodes ≥ minLines, edges filtered to those nodes.
    public func resonance(minLines: Int = 250, minLift: Double = 1.0, minEdges: Int = 8) -> ResonanceGraph {
        var nodes: [ResonanceGraph.Node] = []
        var ns: OpaquePointer?
        guard sqlite3_prepare_v2(handle,
            "SELECT name, n_lines, first_ang FROM authors WHERE n_lines >= ? ORDER BY n_lines DESC",
            -1, &ns, nil) == SQLITE_OK else { return ResonanceGraph(nodes: [], edges: []) }
        sqlite3_bind_int(ns, 1, Int32(max(1, minLines)))
        while sqlite3_step(ns) == SQLITE_ROW {
            nodes.append(.init(author: aText(ns, 0) ?? "", nLines: aInt(ns, 1) ?? 0, firstAng: aInt(ns, 2) ?? 0))
        }
        sqlite3_finalize(ns)
        if nodes.isEmpty { return ResonanceGraph(nodes: [], edges: []) }

        let names = nodes.map { $0.author }
        let ph = Array(repeating: "?", count: names.count).joined(separator: ",")
        let sql = "SELECT src_author, dst_author, edges, mean_score, lift FROM author_resonance "
            + "WHERE src_author <> dst_author AND lift >= ? AND edges >= ? "
            + "AND src_author IN (\(ph)) AND dst_author IN (\(ph)) ORDER BY lift DESC"
        var es: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &es, nil) == SQLITE_OK else {
            return ResonanceGraph(nodes: nodes, edges: [])
        }
        defer { sqlite3_finalize(es) }
        sqlite3_bind_double(es, 1, minLift)
        sqlite3_bind_int(es, 2, Int32(max(1, minEdges)))
        for (i, n) in names.enumerated() {
            sqlite3_bind_text(es, Int32(3 + i), n, -1, Self.transientDtor)
            sqlite3_bind_text(es, Int32(3 + names.count + i), n, -1, Self.transientDtor)
        }
        var edges: [ResonanceGraph.Edge] = []
        while sqlite3_step(es) == SQLITE_ROW {
            edges.append(.init(source: aText(es, 0) ?? "", target: aText(es, 1) ?? "",
                               edges: aInt(es, 2) ?? 0, meanScore: sqlite3_column_double(es, 3),
                               lift: sqlite3_column_double(es, 4)))
        }
        return ResonanceGraph(nodes: nodes, edges: edges)
    }

    /// serve.py:/api/analytics/progression — ported OPERATION-FOR-OPERATION. The binning uses
    /// Python floor division (`pos*bins//M`; Swift Int `/` matches for non-negatives) and the
    /// ang_axis uses `int((b + 0.5) * M / bins)` — the same IEEE-754 double ops in the same
    /// order, truncated toward zero. Do NOT algebraically simplify; the {8,36,80}-bin golden
    /// vectors are the referee.
    public func progression(raag: String, bins binsReq: Int = 36, top topReq: Int = 7) -> Progression? {
        var bins = max(8, min(binsReq, 80))
        let top = max(2, min(topReq, 10))

        var ordered: [(id: Int, ang: Int)] = []
        var os: OpaquePointer?
        guard sqlite3_prepare_v2(handle,
            "SELECT id, ang FROM lines WHERE raag=? ORDER BY ang, id", -1, &os, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(os, 1, raag, -1, Self.transientDtor)
        while sqlite3_step(os) == SQLITE_ROW {
            ordered.append((Int(sqlite3_column_int64(os, 0)), Int(sqlite3_column_int64(os, 1))))
        }
        sqlite3_finalize(os)
        let M = ordered.count
        if M == 0 {
            return Progression(raag: raag, roman: "", nLines: 0, bins: 0, concepts: [],
                               series: [:], linesPerBin: [], angAxis: [])
        }
        bins = min(bins, M)
        var pos: [Int: Int] = [:]
        for (i, r) in ordered.enumerated() { pos[r.id] = i }
        let angs = ordered.map { $0.ang }

        var concepts: [String] = []
        var cs: OpaquePointer?
        if sqlite3_prepare_v2(handle,
            "SELECT cl.concept, COUNT(*) c FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
            + "WHERE l.raag=? GROUP BY cl.concept ORDER BY c DESC LIMIT ?", -1, &cs, nil) == SQLITE_OK {
            sqlite3_bind_text(cs, 1, raag, -1, Self.transientDtor)
            sqlite3_bind_int(cs, 2, Int32(top))
            while sqlite3_step(cs) == SQLITE_ROW { concepts.append(aText(cs, 0) ?? "") }
        }
        sqlite3_finalize(cs)

        var series: [String: [Int]] = [:]
        for c in concepts { series[c] = Array(repeating: 0, count: bins) }
        let cset = Set(concepts)
        var ls: OpaquePointer?
        if sqlite3_prepare_v2(handle,
            "SELECT cl.line_id, cl.concept FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
            + "WHERE l.raag=?", -1, &ls, nil) == SQLITE_OK {
            sqlite3_bind_text(ls, 1, raag, -1, Self.transientDtor)
            while sqlite3_step(ls) == SQLITE_ROW {
                let lid = Int(sqlite3_column_int64(ls, 0))
                let concept = aText(ls, 1) ?? ""
                if cset.contains(concept), let p = pos[lid] {
                    series[concept]![min(bins - 1, p * bins / M)] += 1
                }
            }
        }
        sqlite3_finalize(ls)

        var linesPerBin = Array(repeating: 0, count: bins)
        for i in 0..<M { linesPerBin[min(bins - 1, i * bins / M)] += 1 }
        let angAxis = (0..<bins).map { b in
            angs[min(M - 1, Int((Double(b) + 0.5) * Double(M) / Double(bins)))]
        }

        var roman = ""
        var rs: OpaquePointer?
        if sqlite3_prepare_v2(handle, "SELECT roman FROM raags WHERE name=?", -1, &rs, nil) == SQLITE_OK {
            sqlite3_bind_text(rs, 1, raag, -1, Self.transientDtor)
            if sqlite3_step(rs) == SQLITE_ROW { roman = aText(rs, 0) ?? "" }
        }
        sqlite3_finalize(rs)

        return Progression(raag: raag, roman: roman, nLines: M, bins: bins, concepts: concepts,
                           series: series, linesPerBin: linesPerBin, angAxis: angAxis)
    }

    /// serve.py:/api/analytics/vaars — the 22 Vaar summaries in first_ang order.
    public func vaars() -> [VaarSummary] {
        var out: [VaarSummary] = []
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle,
            "SELECT vaar_id, raag, roman, first_ang, last_ang, n_pauris, n_saloks, "
            + "pauri_author, salok_authors, cross_author, title FROM vaars ORDER BY first_ang",
            -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let salokJSON = aText(stmt, 8) ?? "[]"
            let saloks = (try? JSONDecoder().decode([String].self, from: Data(salokJSON.utf8))) ?? []
            out.append(VaarSummary(
                vaarId: aInt(stmt, 0) ?? 0, raag: aText(stmt, 1), roman: aText(stmt, 2),
                firstAng: aInt(stmt, 3) ?? 0, lastAng: aInt(stmt, 4) ?? 0,
                nPauris: aInt(stmt, 5) ?? 0, nSaloks: aInt(stmt, 6) ?? 0,
                pauriAuthor: aText(stmt, 7), salokAuthors: saloks,
                crossAuthor: (aInt(stmt, 9) ?? 0) != 0, title: aText(stmt, 10)))
        }
        return out
    }

    /// serve.py:/api/analytics/vaar?id=N — salok + pauri anatomy in reading order.
    public func vaar(id: Int) -> VaarAnatomy {
        guard let head = vaars().first(where: { $0.vaarId == id }) else {
            return VaarAnatomy(vaar: nil, units: [])
        }
        var units: [VaarUnit] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(handle,
            "SELECT seq, kind, author, n_lines, pauri_no, first_line_id, ang, theme "
            + "FROM vaar_units WHERE vaar_id=? ORDER BY seq", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            while sqlite3_step(stmt) == SQLITE_ROW {
                units.append(VaarUnit(
                    seq: aInt(stmt, 0) ?? 0, kind: aText(stmt, 1) ?? "", author: aText(stmt, 2),
                    nLines: aInt(stmt, 3) ?? 0, pauriNo: aInt(stmt, 4),
                    firstLineId: aInt(stmt, 5) ?? 0, ang: aInt(stmt, 6) ?? 0, theme: aText(stmt, 7)))
            }
        }
        sqlite3_finalize(stmt)
        return VaarAnatomy(vaar: head, units: units)
    }
}
