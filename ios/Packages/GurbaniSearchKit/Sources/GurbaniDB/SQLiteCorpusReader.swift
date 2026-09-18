import Foundation
import CSQLite
import GurbaniSearchKit

/// Plain corpus-read endpoints over the read-only DB — the exact serve.py SQL/logic for
/// /api/ang, /shabad, /random (hukam_package), /meta. No fuzzy logic.
extension SQLiteCandidateSource: CorpusReader, AnalyticsSource {

    // id, ang, raag, section, author, comp_type, comp_id, line_no, is_rahao, is_header, gurmukhi, translit, markers
    private static let readerCols =
        "id, ang, raag, section, author, comp_type, comp_id, line_no, is_rahao, is_header, gurmukhi, translit, markers"

    private func mapReader(_ stmt: OpaquePointer?) -> ReaderLine {
        func text(_ c: Int32) -> String { sqlite3_column_text(stmt, c).map { String(cString: $0) } ?? "" }
        func optText(_ c: Int32) -> String? { sqlite3_column_type(stmt, c) == SQLITE_NULL ? nil : text(c) }
        func optInt(_ c: Int32) -> Int? { sqlite3_column_type(stmt, c) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, c)) }
        let markersJSON = optText(12) ?? "[]"
        let markers = (try? JSONDecoder().decode([String].self, from: Data(markersJSON.utf8))) ?? []
        return ReaderLine(
            id: Int(sqlite3_column_int64(stmt, 0)), ang: Int(sqlite3_column_int64(stmt, 1)),
            raag: optText(2), section: optText(3), author: optText(4), compType: optText(5),
            compId: Int(sqlite3_column_int64(stmt, 6)), lineNo: optInt(7),
            isRahao: sqlite3_column_int64(stmt, 8) != 0, isHeader: sqlite3_column_int64(stmt, 9) != 0,
            gurmukhi: text(10), translit: text(11), markers: markers)
    }

    /// serve.py `attach_translations`: labelled English for a set of line ids, merged into
    /// result models. Returns [:] when the DB has no `translations` table (public profile) —
    /// that degradation is the parity contract (serve.py catches OperationalError → pass).
    private func enMap(ids: [Int]) -> [Int: String] {
        guard !ids.isEmpty else { return [:] }
        let ph = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let sql = "SELECT line_id, text FROM translations WHERE lang='en' AND line_id IN (\(ph))"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        for (i, lid) in ids.enumerated() { sqlite3_bind_int64(stmt, Int32(i + 1), Int64(lid)) }
        var out: [Int: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            out[Int(sqlite3_column_int64(stmt, 0))] = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
        }
        return out
    }

    private func attachEn(_ lines: [ReaderLine]) -> [ReaderLine] {
        let m = enMap(ids: lines.map { $0.id })
        if m.isEmpty { return lines }
        return lines.map { m[$0.id] != nil ? $0.withEn(m[$0.id]) : $0 }
    }

    /// English for search results — serve.py attaches en to EVERY search mode's results (:798).
    /// Called by the app's CorpusActor after SearchEngine.search.
    public func attachTranslations(_ lines: [SearchLine]) -> [SearchLine] {
        let m = enMap(ids: lines.map { $0.id })
        if m.isEmpty { return lines }
        return lines.map { $0.en == nil && m[$0.id] != nil ? $0.withEn(m[$0.id]) : $0 }
    }

    /// The labelled English translation of one line (display layer, e.g. under a verify verdict).
    public func english(forLine id: Int) -> String? { enMap(ids: [id])[id] }

    /// Which optional layers this DB build carries (see CorpusCapabilities). One sqlite_master
    /// probe at open; capability bits gate UI surfaces so a public/Gurmukhi-only DB degrades
    /// to exactly today's behavior.
    public func detectCapabilities() -> CorpusCapabilities {
        func has(_ table: String) -> Bool {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(handle,
                "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ?",
                -1, &stmt, nil) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, table, -1, Self.transientDtor)
            return sqlite3_step(stmt) == SQLITE_ROW
        }
        return CorpusCapabilities(
            hasEnglish: has("translations") && has("fts_en"),
            hasTiming: has("raag_timing_claims") && has("timing_sources"),
            hasBanis: has("banis") && has("bani_lines") && has("extra_lines"))
    }

    private func readerRows(_ sql: String, bind: (OpaquePointer?) -> Void) throws -> [ReaderLine] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        var out: [ReaderLine] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(mapReader(stmt)) }
        return out
    }

    public func fetchAng(_ n: Int) throws -> AngPage {
        let ang = max(1, min(1430, n))
        let rs = attachEn(try readerRows("SELECT \(Self.readerCols) FROM lines WHERE ang = ? ORDER BY id") {
            sqlite3_bind_int($0, 1, Int32(ang))
        })
        var continuedFrom: Int? = nil
        if let first = rs.first, !first.isHeader {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(handle, "SELECT min(ang) FROM lines WHERE comp_id = ?", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(first.compId))
                if sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_type(stmt, 0) != SQLITE_NULL {
                    let m = Int(sqlite3_column_int64(stmt, 0)); if m < ang { continuedFrom = m }
                }
                sqlite3_finalize(stmt)
            }
        }
        func majority(_ pick: (ReaderLine) -> String?) -> String? {
            var counts: [String: Int] = [:]; var order: [String] = []
            for l in rs { if let v = pick(l) { if counts[v] == nil { order.append(v) }; counts[v, default: 0] += 1 } }
            return order.max(by: { counts[$0]! != counts[$1]! ? counts[$0]! < counts[$1]! : false })
        }
        let authors = Set(rs.compactMap { $0.author }).sorted()
        return AngPage(ang: ang, lines: rs, continuedFrom: continuedFrom,
                       raag: majority { $0.raag }, section: majority { $0.section }, authors: authors)
    }

    public func fetchShabad(compId: Int) throws -> Shabad {
        let rs = attachEn(try readerRows("SELECT \(Self.readerCols) FROM lines WHERE comp_id = ? ORDER BY id") {
            sqlite3_bind_int($0, 1, Int32(compId))
        })
        return Shabad(compId: compId, lines: rs)
    }

    public func randomSeedCompId() throws -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, "SELECT comp_id FROM lines WHERE is_header=0 ORDER BY RANDOM() LIMIT 1", -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw DBError.prepare("corpus is empty") }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Port of serve.py:hukam_package(seed) — expand a seed comp_id to its full structural unit.
    public func hukamUnit(seed: Int) throws -> HukamUnit {
        let SAL: Set<String> = ["ਸਲੋਕ", "ਸਲੋਕੁ"]; let PAU = "ਪਉੜੀ"
        let win = try readerRows("SELECT \(Self.readerCols) FROM lines WHERE comp_id BETWEEN ? AND ? ORDER BY id") {
            sqlite3_bind_int($0, 1, Int32(seed - 15)); sqlite3_bind_int($0, 2, Int32(seed + 15))
        }
        // group by comp_id preserving first-appearance order
        var comps: [Int: [ReaderLine]] = [:]; var order: [Int] = []
        for l in win { if comps[l.compId] == nil { order.append(l.compId) }; comps[l.compId, default: []].append(l) }

        func dtype(_ ls: [ReaderLine]) -> String {
            let body = ls.contains { !$0.isHeader } ? ls.filter { !$0.isHeader } : ls
            var counts: [String: Int] = [:]; var seen: [String] = []
            for x in body { let t = x.compType ?? ""; if counts[t] == nil { seen.append(t) }; counts[t, default: 0] += 1 }
            return seen.max(by: { counts[$0]! != counts[$1]! ? counts[$0]! < counts[$1]! : false }) ?? ""
        }
        func multiEnd(_ ls: [ReaderLine]) -> Bool {
            let body = ls.filter { !$0.isHeader }
            guard let last = body.last else { return false }
            let digitTokens = last.markers.filter { !$0.isEmpty && $0.unicodeScalars.allSatisfy { (0x0A66...0x0A6F).contains($0.value) } }
            return digitTokens.count >= 2
        }
        guard order.contains(seed), comps[seed] != nil else {                    // defensive fallback
            let rs = try fetchShabad(compId: seed).lines
            return HukamUnit(compId: seed, compIds: [seed], lines: rs)
        }
        var typ: [Int: String] = [:]; var mend: [Int: Bool] = [:]
        for (cid, ls) in comps { typ[cid] = dtype(ls); mend[cid] = multiEnd(ls) }

        let i = order.firstIndex(of: seed)!
        var end: Int
        if SAL.contains(typ[seed] ?? "") {
            var j = i
            while j + 1 < order.count, SAL.contains(typ[order[j]] ?? ""), !(mend[order[j]] ?? false),
                  SAL.contains(typ[order[j + 1]] ?? "") { j += 1 }
            end = (j + 1 < order.count && typ[order[j + 1]] == PAU) ? j + 1 : i
        } else {
            end = i
        }
        var start: Int
        if typ[order[end]] == PAU {
            var s = end
            while s - 1 >= 0, SAL.contains(typ[order[s - 1]] ?? "") { s -= 1 }
            start = s
        } else {
            start = i
        }
        let unit = Set(order[start...end])
        let lines = win.filter { unit.contains($0.compId) }     // already id-ordered
        return HukamUnit(compId: seed, compIds: unit.sorted(), lines: lines)
    }

    public func neighbors(lineId: Int, limit: Int) throws -> NeighborsResult {
        let lim = max(1, min(limit, 50))
        // Tier 1: line-level embedding neighbours (line_neighbors), exact TF-IDF cosine.
        var line: [Neighbor] = []
        _ = try? prepareEach(
            "SELECT n.neighbor_id, n.score, l.ang, l.raag, l.author, l.comp_id, l.gurmukhi, l.translit "
            + "FROM line_neighbors n JOIN lines l ON l.id = n.neighbor_id "
            + "WHERE n.line_id = \(lineId) ORDER BY n.score DESC LIMIT \(lim)") { s in
            line.append(Neighbor(
                id: int(s, 0), score: sqlite3_column_double(s, 1), ang: int(s, 2),
                raag: col(s, 3), author: col(s, 4), compId: int(s, 5),
                gurmukhi: col(s, 6) ?? "", translit: col(s, 7) ?? ""))
        }
        if !line.isEmpty {
            var source: String? = nil
            _ = try? prepareEach("SELECT value FROM analytics_meta WHERE key='line_neighbors_source'") { s in
                source = col(s, 0)
            }
            let m = enMap(ids: line.map { $0.id })   // serve.py attaches en on /api/neighbors
            if !m.isEmpty { line = line.map { m[$0.id] != nil ? $0.withEn(m[$0.id]) : $0 } }
            return NeighborsResult(lineId: lineId, level: "line", source: source, neighbors: line)
        }
        // Tier 2: composition-level theme profile (shabad_neighbors).
        var compId: Int? = nil
        _ = try? prepareEach("SELECT comp_id FROM lines WHERE id=\(lineId)") { s in compId = int(s, 0) }
        guard let cid = compId else { return NeighborsResult(lineId: lineId, level: "none", source: nil, neighbors: []) }
        var comp: [Neighbor] = []
        _ = try? prepareEach(
            "SELECT n.neighbor_comp_id, n.score, "
            + "(SELECT ang FROM lines WHERE comp_id=n.neighbor_comp_id ORDER BY id LIMIT 1), "
            + "(SELECT raag FROM lines WHERE comp_id=n.neighbor_comp_id AND raag IS NOT NULL LIMIT 1), "
            + "(SELECT gurmukhi FROM lines WHERE comp_id=n.neighbor_comp_id AND is_header=0 ORDER BY id LIMIT 1) "
            + "FROM shabad_neighbors n WHERE n.comp_id=\(cid) ORDER BY n.rank LIMIT \(lim)") { s in
            comp.append(Neighbor(
                id: int(s, 0), score: sqlite3_column_double(s, 1), ang: int(s, 2),
                raag: col(s, 3), author: nil, compId: int(s, 0),
                gurmukhi: col(s, 4) ?? "", translit: ""))
        }
        return NeighborsResult(lineId: lineId, level: comp.isEmpty ? "none" : "composition",
                               source: comp.isEmpty ? nil : "shabad-theme-profile", neighbors: comp)
    }

    public func fetchMeta() throws -> CorpusMeta {
        var raags: [RaagRow] = []
        _ = try? prepareEach("SELECT name, roman, first_ang, last_ang, n_lines, n_shabads, seq FROM raags ORDER BY seq") { s in
            raags.append(RaagRow(
                name: col(s, 0) ?? "", roman: col(s, 1), firstAng: int(s, 2), lastAng: int(s, 3),
                nLines: int(s, 4), nShabads: int(s, 5), seq: int(s, 6)))
        }
        var sections: [SectionRow] = []
        _ = try? prepareEach("SELECT name, first_ang, last_ang, n_lines FROM sections ORDER BY first_ang") { s in
            sections.append(SectionRow(name: col(s, 0) ?? "", firstAng: int(s, 1), lastAng: int(s, 2), nLines: int(s, 3)))
        }
        var authors: [AuthorRow] = []
        _ = try? prepareEach("SELECT name, first_ang, last_ang, n_lines FROM authors ORDER BY n_lines DESC") { s in
            authors.append(AuthorRow(name: col(s, 0) ?? "", firstAng: int(s, 1), lastAng: int(s, 2), nLines: int(s, 3)))
        }
        var concepts: [ConceptRow] = []
        _ = try? prepareEach("SELECT c.concept, c.description, COUNT(cl.line_id) AS n FROM concepts c LEFT JOIN concept_lines cl ON cl.concept = c.concept GROUP BY c.concept, c.description ORDER BY c.concept") { s in
            concepts.append(ConceptRow(concept: col(s, 0) ?? "", description: col(s, 1) ?? "", nLines: int(s, 2)))
        }
        return CorpusMeta(raags: raags, sections: sections, authors: authors, concepts: concepts)
    }

    public func authorAnalytics() throws -> [AuthorStat] {
        var out: [AuthorStat] = []
        try prepareEach("SELECT author, n_lines, n_shabads, n_raags, mattr_100, avg_words_line, is_reliable "
                        + "FROM author_analytics ORDER BY n_lines DESC") { s in
            out.append(AuthorStat(author: col(s, 0) ?? "", nLines: int(s, 1), nShabads: int(s, 2),
                                  nRaags: int(s, 3), mattr100: sqlite3_column_double(s, 4),
                                  avgWordsLine: sqlite3_column_double(s, 5), isReliable: int(s, 6) != 0))
        }
        return out
    }

    public func raagAnalytics() throws -> [RaagStat] {
        var out: [RaagStat] = []
        try prepareEach("SELECT raag, n_lines, n_shabads, n_authors, dominant_author, dominant_author_pct, n_themes "
                        + "FROM raag_analytics ORDER BY n_lines DESC") { s in
            out.append(RaagStat(raag: col(s, 0) ?? "", nLines: int(s, 1), nShabads: int(s, 2),
                                nAuthors: int(s, 3), dominantAuthor: col(s, 4),
                                dominantAuthorPct: sqlite3_column_double(s, 5), nThemes: int(s, 6)))
        }
        return out
    }

    public func themeNetwork(minPPMI: Double, limit: Int) throws -> [ThemeEdge] {
        let lim = max(1, min(limit, 2000))
        let mp = max(0.0, min(1.0, minPPMI.isFinite ? minPPMI : 0.0))
        var stmt: OpaquePointer?
        let sql = "SELECT source, target, shabad_count, ppmi, jaccard FROM theme_network "
            + "WHERE source < target AND ppmi >= ? ORDER BY ppmi DESC LIMIT ?"
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, mp); sqlite3_bind_int(stmt, 2, Int32(lim))
        var out: [ThemeEdge] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(ThemeEdge(source: col(stmt, 0) ?? "", target: col(stmt, 1) ?? "",
                                 shabadCount: int(stmt, 2), ppmi: sqlite3_column_double(stmt, 3),
                                 jaccard: sqlite3_column_double(stmt, 4)))
        }
        return out
    }

    public func constellation(concept: String, author: String?, raag: String?) throws -> ConstellationResult {
        let au = (author?.isEmpty == false) ? author : nil
        let rg = (raag?.isEmpty == false) ? raag : nil
        var whereClause = "cl.concept=?"
        var binds: [String] = [concept]
        if let au { whereClause += " AND l.author=?"; binds.append(au) }
        if let rg { whereClause += " AND l.raag=?"; binds.append(rg) }
        func bindAll(_ s: OpaquePointer?) { for (i, b) in binds.enumerated() {
            sqlite3_bind_text(s, Int32(i + 1), b, -1, SQLiteCandidateSource.transientDtor) } }

        var total = 0
        var st: OpaquePointer?
        if sqlite3_prepare_v2(handle, "SELECT COUNT(DISTINCT cl.line_id) FROM concept_lines cl "
            + "JOIN lines l ON l.id=cl.line_id WHERE \(whereClause)", -1, &st, nil) == SQLITE_OK {
            bindAll(st)
            if sqlite3_step(st) == SQLITE_ROW { total = Int(sqlite3_column_int64(st, 0)) }
        }
        sqlite3_finalize(st)
        if total == 0 { return ConstellationResult(concept: concept, total: 0, clusters: []) }

        let rowsSQL = "SELECT co.concept, l.id, l.ang, l.comp_id, l.gurmukhi "
            + "FROM concept_lines cl JOIN concept_lines co ON co.line_id=cl.line_id AND co.concept<>cl.concept "
            + "JOIN lines l ON l.id=cl.line_id WHERE \(whereClause) ORDER BY co.concept, l.id"
        var st2: OpaquePointer?
        guard sqlite3_prepare_v2(handle, rowsSQL, -1, &st2, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(st2) }
        bindAll(st2)
        var order: [String] = []                         // co insertion order (= alphabetical co)
        var buckets: [String: [ConstellationVerse]] = [:]
        while sqlite3_step(st2) == SQLITE_ROW {
            let co = col(st2, 0) ?? ""
            if buckets[co] == nil { order.append(co) }
            buckets[co, default: []].append(ConstellationVerse(
                id: int(st2, 1), ang: int(st2, 2), compId: int(st2, 3), gurmukhi: col(st2, 4) ?? ""))
        }
        // top-9 by n, stable on insertion order (Python sorted(reverse=True) is stable); verses[:40]
        let top = order.enumerated().sorted { a, b in
            let na = buckets[a.element]!.count, nb = buckets[b.element]!.count
            return na != nb ? na > nb : a.offset < b.offset
        }.prefix(9)
        let clusters = top.map { ConstellationCluster(
            co: $0.element, n: buckets[$0.element]!.count, verses: Array(buckets[$0.element]!.prefix(40))) }
        return ConstellationResult(concept: concept, total: total, clusters: clusters)
    }

    // small helpers
    private func col(_ s: OpaquePointer?, _ c: Int32) -> String? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : (sqlite3_column_text(s, c).map { String(cString: $0) })
    }
    private func int(_ s: OpaquePointer?, _ c: Int32) -> Int { Int(sqlite3_column_int64(s, c)) }
    private func prepareEach(_ sql: String, _ body: (OpaquePointer?) -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW { body(stmt) }
    }
}
