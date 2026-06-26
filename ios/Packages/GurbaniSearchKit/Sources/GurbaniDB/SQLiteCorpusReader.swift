import Foundation
import SQLite3
import GurbaniSearchKit

/// Plain corpus-read endpoints over the read-only DB — the exact serve.py SQL/logic for
/// /api/ang, /shabad, /random (hukam_package), /meta. No fuzzy logic.
extension SQLiteCandidateSource: CorpusReader {

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
        let rs = try readerRows("SELECT \(Self.readerCols) FROM lines WHERE ang = ? ORDER BY id") {
            sqlite3_bind_int($0, 1, Int32(ang))
        }
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
        let rs = try readerRows("SELECT \(Self.readerCols) FROM lines WHERE comp_id = ? ORDER BY id") {
            sqlite3_bind_int($0, 1, Int32(compId))
        }
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
