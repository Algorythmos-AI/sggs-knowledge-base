import Foundation

/// A search result line (the subset of LINE_COLS the app renders). Sendable value type.
public struct SearchLine: Sendable, Equatable {
    public let id: Int
    public let ang: Int
    public let gurmukhi: String
    public let translit: String
    public let raag: String?
    public let section: String?
    public let author: String?
    public let compId: Int
    public let isRahao: Bool
    public let isHeader: Bool
    public init(id: Int, ang: Int, gurmukhi: String, translit: String, raag: String?,
                section: String?, author: String?, compId: Int, isRahao: Bool, isHeader: Bool) {
        self.id = id; self.ang = ang; self.gurmukhi = gurmukhi; self.translit = translit
        self.raag = raag; self.section = section; self.author = author; self.compId = compId
        self.isRahao = isRahao; self.isHeader = isHeader
    }
}

/// A search line plus its translit / translit_norm (for the variant all-but-one fallback scoring).
public struct VariantRow: Sendable {
    public let line: SearchLine
    public let translit: String
    public let translitNorm: String
    public init(line: SearchLine, translit: String, translitNorm: String) {
        self.line = line; self.translit = translit; self.translitNorm = translitNorm
    }
}

public struct ThemeConcept: Sendable, Equatable {
    public let name: String
    public let terms: [String]
    public let description: String
    public let total: Int
    public init(name: String, terms: [String], description: String, total: Int) {
        self.name = name; self.terms = terms; self.description = description; self.total = total
    }
}

public struct ThemeSearchResult: Sendable {
    public let concept: ThemeConcept?
    public let lines: [SearchLine]
    public init(concept: ThemeConcept?, lines: [SearchLine]) { self.concept = concept; self.lines = lines }
}

public struct SearchOutput: Sendable, Equatable {
    public let mode: String
    public let results: [SearchLine]
    public let concept: ThemeConcept?
    public let relatedThemes: [String]?
    public init(mode: String, results: [SearchLine], concept: ThemeConcept?, relatedThemes: [String]?) {
        self.mode = mode; self.results = results; self.concept = concept; self.relatedThemes = relatedThemes
    }
}

/// The DB seam for search. The DB target satisfies it.
public protocol SearchSource: Sendable {
    /// `… WHERE <column> MATCH ? …` BM25-ranked, `ORDER BY m.rk, lines.id`.
    func ftsSearch(column: String, match: String, excludeHeaders: Bool, limit: Int, offset: Int) throws -> [SearchLine]
    /// `… WHERE fts MATCH ? …` (the match expression carries its own `col: "…"` prefixes).
    func ftsSearchExpr(match: String, excludeHeaders: Bool, limit: Int, offset: Int) throws -> [SearchLine]
    /// `… WHERE fts MATCH ? ORDER BY m.rk LIMIT ?` returning translit + translit_norm (variant fallback).
    func ftsSearchExprWithNorm(match: String, limit: Int) throws -> [VariantRow]
    func likeSearch(column: String, pattern: String, limit: Int, offset: Int) throws -> [SearchLine]
    func conceptExactExists(_ name: String) throws -> Bool
    func themeSearch(_ q: String, limit: Int, offset: Int) throws -> ThemeSearchResult
    func termConcepts(_ tokens: [String]) throws -> [String]
    /// `SELECT DISTINCT translit FROM variants WHERE variant=? ORDER BY freq*score DESC LIMIT 3`.
    func variantsLookup(_ token: String) throws -> [String]
    /// `SELECT 1 FROM canon_tokens WHERE token=?`.
    func isCanon(_ token: String) throws -> Bool
    /// `SELECT comp_id, tnorm, rank FROM fts_shabad WHERE fts_shabad MATCH ? ORDER BY rank LIMIT ?`.
    func ftsShabad(match: String, limit: Int) throws -> [ShabadCand]
    /// translit_norm of each non-header line, grouped by comp_id (passage span scoring).
    func shabadLineNorms(compIds: [Int]) throws -> [Int: [String]]
    /// non-header lines of a comp_id (ORDER BY id) with their translit_norm (passage bubbling).
    func compLines(compId: Int) throws -> [VariantRow]
}

/// A shabad-level FTS candidate (passage tier).
public struct ShabadCand: Sendable { public let compId: Int; public let tnorm: String; public let rank: Double
    public init(compId: Int, tnorm: String, rank: Double) { self.compId = compId; self.tnorm = tnorm; self.rank = rank } }

public enum SearchError: Error { case queryTooLong }

/// Byte-identical Swift port of `webapp/serve.py:do_search`. Covers the explicit modes
/// (gurmukhi/roman/first/theme) and the full auto-mode waterfall — mixed-script, the curated
/// seeker lexicon, the precomputed variant index (incl. the graceful all-but-one fallback), the
/// phonetic-fold tier, single-token theme, and both honorific-drop passes. The English tier is a
/// no-op on the Gurmukhi-only iOS DB (no fts_en), `blob_search` is a no-op (no norm_blob), and
/// `passage_search` is deferred (returns nil) — a later phase. Pinned by contract/golden_search.ndjson.
public struct SearchEngine {
    private let source: SearchSource

    private static let punct: Set<UInt32> = Set("॥।.,;:!?\"'()[]{}|/\\-".unicodeScalars.map { $0.value })
    private static let skelMatras: Set<UInt32> = Set("ਾਿੀੁੂੇੈੋੌੰਂ੍".unicodeScalars.map { $0.value })
    // The early + late honorific sets are equal (same elements).
    private static let honorifics: Set<String> = [
        "ji", "jee", "jeo", "jio", "sahib", "maharaj", "maharaaj", "shri", "shree",
        "sri", "baba", "guru", "dev", "waale", "wale",
    ]

    public init(source: SearchSource) { self.source = source }

    public func search(_ rawQuery: String, mode: String, limit: Int = 50, offset: Int = 0) throws -> SearchOutput {
        if rawQuery.unicodeScalars.count > 300 { throw SearchError.queryTooLong }
        let q = Self.preprocess(rawQuery)
        if q.isEmpty { return SearchOutput(mode: mode, results: [], concept: nil, relatedThemes: nil) }
        let toks = q.split(separator: " ").map(String.init)
        let isG = Self.containsGurmukhi(q)

        func run(_ col: String, phrase: Bool = false) throws -> [SearchLine] {
            guard let m = Self.ftsMatch(toks, phrase: phrase) else { return [] }
            return try source.ftsSearch(column: col, match: m, excludeHeaders: false, limit: limit, offset: offset)
        }

        // mixed-script (auto + Gurmukhi + latin)
        let latinPresent = q.unicodeScalars.contains { (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value) }
        if mode == "auto" && isG && latinPresent {
            if let ms = try mixedSearch(q, limit: limit, offset: offset) {
                return SearchOutput(mode: "mixed-script", results: ms, concept: nil, relatedThemes: nil)
            }
            let qLat = toks.filter { !Self.containsGurmukhi($0) }.joined(separator: " ")
            if !qLat.isEmpty {
                let sub = try search(qLat, mode: "auto", limit: limit, offset: offset)
                if !sub.results.isEmpty {
                    return SearchOutput(mode: "mixed-script (latin part: \(sub.mode))",
                                        results: sub.results, concept: sub.concept, relatedThemes: sub.relatedThemes)
                }
            }
        }

        var res: [SearchLine] = []
        var used = ""

        switch mode {
        case "gurmukhi":
            res = try run("text"); used = "gurmukhi"
            if res.isEmpty {
                res = try source.likeSearch(column: "skeleton", pattern: Self.likePattern(Self.stripSkelMatras(q)),
                                            limit: limit, offset: offset)
                used = "gurmukhi-skeleton"
            }
        case "roman":
            res = try run("translit"); used = "roman"
            if res.isEmpty { (res, used) = try romanFoldTier(q, limit: limit, offset: offset, fallback: used) }
        case "first":
            res = try run(isG ? "fl_g" : "fl_r", phrase: true); used = "first-letters"
        case "theme":
            let t = try source.themeSearch(q, limit: limit, offset: offset)
            return SearchOutput(mode: "theme", results: t.lines, concept: t.concept, relatedThemes: nil)
        default:  // auto
            if isG {
                let singleLetters = toks.allSatisfy { $0.unicodeScalars.count == 1 } && toks.count >= 2
                if singleLetters {
                    res = try run("fl_g", phrase: true); used = "first-letters"
                } else {
                    res = try run("text"); used = "gurmukhi"
                    if res.isEmpty {
                        res = try source.likeSearch(column: "skeleton", pattern: Self.likePattern(Self.stripSkelMatras(q)),
                                                    limit: limit, offset: offset)
                        used = "gurmukhi-skeleton"
                    }
                }
            } else {
                let ql = q.lowercased()
                if try source.conceptExactExists(ql) {
                    let t = try source.themeSearch(ql, limit: limit, offset: offset)
                    return SearchOutput(mode: "theme", results: t.lines, concept: t.concept, relatedThemes: nil)
                }
                if toks.allSatisfy({ $0.unicodeScalars.count <= 3 }) && toks.count >= 2 {
                    res = try run("fl_r", phrase: true); used = "first-letters"
                    if res.isEmpty { res = try run("translit"); used = "roman" }
                } else {
                    res = try run("translit"); used = "roman"
                }
                if res.isEmpty, let lx = try lexiconSearch(q, limit: limit, offset: offset) { return lx }
                if res.isEmpty, let vr = try variantSearch(q, limit: limit, offset: offset), !vr.isEmpty {
                    return SearchOutput(mode: "variant-match", results: vr, concept: nil, relatedThemes: nil)
                }
                if res.isEmpty { used = "english-translation" }   // search_en: [] on the EN-less iOS DB
                if res.isEmpty {                                   // early honorific retry
                    let kept = toks.filter { !Self.honorifics.contains($0.lowercased()) }
                    if kept.count >= 2 && kept.count < toks.count {
                        let sub = try search(kept.joined(separator: " "), mode: "auto", limit: limit, offset: offset)
                        if !sub.results.isEmpty {
                            return SearchOutput(mode: "\(sub.mode) (honorifics dropped)",
                                                results: sub.results, concept: sub.concept, relatedThemes: sub.relatedThemes)
                        }
                    }
                }
                if res.isEmpty && toks.count >= 3 {
                    if let ps = try passageSearch(q, limit: limit, offset: offset) {
                        return SearchOutput(mode: "passage-match (quote spans lines)", results: ps,
                                            concept: nil, relatedThemes: nil)
                    }
                }
                if res.isEmpty { (res, used) = try romanFoldTier(q, limit: limit, offset: offset, fallback: used) }
                // blob tier: no norm_blob -> no-op
                if res.isEmpty && toks.count == 1 {
                    let t = try source.themeSearch(q, limit: limit, offset: offset)
                    if !t.lines.isEmpty {
                        return SearchOutput(mode: "theme", results: t.lines, concept: t.concept, relatedThemes: nil)
                    }
                }
            }
        }

        // late honorific post-pass (auto, when fewer than 3 hits)
        if res.count < 3 && mode == "auto" {
            let kept = toks.filter { !Self.honorifics.contains($0.lowercased()) }
            if kept.count >= 2 && kept.count < toks.count {
                let sub = try search(kept.joined(separator: " "), mode: "auto", limit: limit, offset: offset)
                if !sub.results.isEmpty {
                    let seen = Set(res.map { $0.id })
                    let merged = sub.results.filter { !seen.contains($0.id) }
                    if res.isEmpty {
                        return SearchOutput(mode: "\(sub.mode) (honorifics dropped)",
                                            results: sub.results, concept: sub.concept, relatedThemes: sub.relatedThemes)
                    }
                    res = Array((res + merged).prefix(limit))
                    used += " + honorific-dropped"
                }
            }
        }

        var related: [String]? = nil
        if isG {
            let rel = try source.termConcepts(toks)
            if !rel.isEmpty { related = Array(rel.prefix(3)) }
        }
        return SearchOutput(mode: used, results: res, concept: nil, relatedThemes: related)
    }

    // MARK: tiers

    /// translit_norm phonetic-fold tier (no_headers). Returns (results, usedMode).
    private func romanFoldTier(_ q: String, limit: Int, offset: Int, fallback: String) throws -> ([SearchLine], String) {
        let strong = RomanNorm.fold(q).split(separator: " ").map(String.init).filter { $0.unicodeScalars.count >= 2 }
        if !strong.isEmpty, let m = Self.ftsMatch(strong, phrase: false) {
            let res = try source.ftsSearch(column: "translit_norm", match: m, excludeHeaders: true, limit: limit, offset: offset)
            return (res, "roman-spelling-tolerant")
        }
        return ([], fallback)
    }

    private func lexiconSearch(_ q: String, limit: Int, offset: Int) throws -> SearchOutput? {
        guard let entry = SeekerLexicon.table[q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] else { return nil }
        switch entry {
        case .theme(let name):
            let t = try source.themeSearch(name, limit: limit, offset: offset)
            return t.lines.isEmpty ? nil : SearchOutput(mode: "theme", results: t.lines, concept: t.concept, relatedThemes: nil)
        case .translit(let terms):
            for term in terms {
                guard let m = Self.ftsMatch(term.split(separator: " ").map(String.init), phrase: false) else { continue }
                let res = try source.ftsSearch(column: "translit", match: m, excludeHeaders: false, limit: limit, offset: offset)
                if !res.isEmpty { return SearchOutput(mode: "seeker-lexicon (\(term))", results: res, concept: nil, relatedThemes: nil) }
            }
            return nil
        }
    }

    private func mixedSearch(_ q: String, limit: Int, offset: Int) throws -> [SearchLine]? {
        let toks = q.split(separator: " ").map(String.init)
        if toks.count > 10 { return nil }
        var groups: [String] = []
        for t0 in toks {
            if Self.containsGurmukhi(t0) {
                groups.append("(text: \"\(t0.replacingOccurrences(of: "\"", with: ""))\")"); continue
            }
            let t = t0.lowercased()
            if !Self.isAlnum(t) { continue }
            var alts: [String] = []
            for r in try source.variantsLookup(t) { alts.append("translit: \"\(FTSQuery.clean(r))\"") }
            if try source.isCanon(t) { alts.append("translit: \"\(t)\"") }
            if case .translit(let terms)? = SeekerLexicon.table[t] { for term in terms.prefix(2) { alts.append("translit: \"\(term)\"") } }
            alts += Self.foldMatchAlts(RomanNorm.fold(t))
            if !alts.isEmpty { groups.append("(" + alts.joined(separator: " OR ") + ")") }
        }
        if groups.count < 2 { return nil }
        let res = try source.ftsSearchExpr(match: groups.joined(separator: " AND "), excludeHeaders: false, limit: limit, offset: offset)
        return res.isEmpty ? nil : res
    }

    private func variantSearch(_ q: String, limit: Int, offset: Int) throws -> [SearchLine]? {
        let toks = q.lowercased().split(separator: " ").map(String.init).filter { Self.isAlnum($0) }
        if toks.isEmpty || toks.count > 10 { return nil }
        var groups: [String] = []
        var weakSkipped = 0
        for t in toks {
            var alts: [String] = []
            let lastCh = t.last
            var rs = try source.variantsLookup(t)
            if rs.isEmpty, t.count > 3, let l = lastCh, "aeiou".contains(l) { rs = try source.variantsLookup(String(t.dropLast())) }
            if rs.isEmpty, t.count > 3, let l = lastCh, "nm".contains(l), Self.secondLastIsVowel(t) { rs = try source.variantsLookup(String(t.dropLast())) }
            var baseSfx: String? = nil
            if rs.isEmpty {
                for suf in ["ing", "ed", "es", "er", "s"] where t.hasSuffix(suf) && t.count > suf.count + 2 {
                    baseSfx = String(t.dropLast(suf.count))
                    rs = try source.variantsLookup(baseSfx!)
                    if !rs.isEmpty { break }
                }
            }
            for r in rs { alts.append("translit: \"\(FTSQuery.clean(r))\"") }
            let trimCand: String? = (t.count > 3 && lastCh != nil && "aeiounm".contains(lastCh!)) ? String(t.dropLast()) : nil
            for cand in [t, trimCand, baseSfx] {
                if let c = cand, try source.isCanon(c) { alts.append("translit: \"\(c)\"") }
            }
            if let l = lastCh, "aiu".contains(l) {
                let longV = String(t.dropLast()) + ["a": "aa", "i": "ee", "u": "oo"][String(l)]!
                if try source.isCanon(longV) { alts.append("translit: \"\(longV)\"") }
            }
            if case .translit(let terms)? = SeekerLexicon.table[t] { for term in terms.prefix(2) { alts.append("translit: \"\(term)\"") } }
            let fn = RomanNorm.fold(t)
            alts += Self.foldMatchAlts(fn)
            if !alts.isEmpty { groups.append("(" + alts.joined(separator: " OR ") + ")") }
            else if !fn.isEmpty { weakSkipped += 1 }
            else { return nil }
        }
        var seenG = Set<String>(); var uniqG: [String] = []
        for g in groups where !seenG.contains(g) { seenG.insert(g); uniqG.append(g) }
        let hadRepeat = uniqG.count < groups.count
        groups = uniqG
        if groups.isEmpty || (weakSkipped > 0 && groups.count < 2) { return nil }

        let res = try source.ftsSearchExpr(match: groups.joined(separator: " AND "), excludeHeaders: false, limit: limit, offset: offset)
        if !res.isEmpty { return res }

        // graceful all-but-one fallback
        if groups.count >= 3 || (hadRepeat && groups.count >= 2) {
            let rows = try source.ftsSearchExprWithNorm(match: groups.joined(separator: " OR "), limit: 150)
            let gterms = groups.map { Self.parseGroupTerms($0) }
            let need = groups.count - 1
            var scored: [(hits: Int, line: SearchLine)] = []
            for row in rows {
                let tw = Set(row.translit.split(separator: " ").map(String.init))
                let nw = Set(row.translitNorm.split(separator: " ").map(String.init))
                var hits = 0
                for terms in gterms {
                    let matched = terms.contains { (col, term) in
                        col == "translit" ? term.split(separator: " ").allSatisfy { tw.contains(String($0)) } : nw.contains(term)
                    }
                    if matched { hits += 1 }
                }
                if hits >= need { scored.append((hits, row.line)) }
            }
            if !scored.isEmpty {
                let sorted = scored.enumerated()
                    .sorted { $0.element.hits != $1.element.hits ? $0.element.hits > $1.element.hits : $0.offset < $1.offset }
                    .map { $0.element.line }
                let lo = min(offset, sorted.count), hi = min(offset + limit, sorted.count)
                let sliced = Array(sorted[lo..<hi])
                return sliced.isEmpty ? nil : sliced
            }
        }
        return nil
    }

    /// Cross-line passage tier (serve.py:passage_search). Folds tokens, matches at shabad level,
    /// ranks by the tightest in-order SPAN, then bubbles the matched line(s) to the top.
    /// The span regex runs over ASCII translit_norm, so NSRegularExpression (ICU) ≈ Python `re`.
    private func passageSearch(_ q: String, limit: Int, offset: Int) throws -> [SearchLine]? {
        var toks = q.lowercased().split(separator: " ").map(String.init)
            .filter { Self.isAlnum($0) }.map { RomanNorm.fold($0) }
        toks = toks.filter { $0.unicodeScalars.count >= 2 }
        if toks.count < 3 { return nil }

        let m = toks.map { "\"\($0)\"" }.joined(separator: " AND ")
        let cand = try source.ftsShabad(match: m, limit: 60)
        if cand.isEmpty { return nil }

        // seq = \b t1 \w*\b.*?\b t2 \w*\b.*?\b t3 \w*   (re.escape is identity on [a-z] folds)
        let pattern = "\\b" + toks.joined(separator: "\\w*\\b.*?\\b") + "\\w*"
        guard let seq = try? NSRegularExpression(pattern: pattern) else { return nil }
        func span(_ s: String) -> Int? {
            let r = NSRange(s.startIndex..., in: s)
            guard let mt = seq.firstMatch(in: s, range: r) else { return nil }
            return mt.range.length     // UTF-16 == code-point length on ASCII translit_norm
        }
        func matches(_ s: String) -> Bool {
            seq.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        let lineNorms = try source.shabadLineNorms(compIds: cand.map { $0.compId })
        // (span, rank, compId), stable on cand (rank) order
        var scored: [(span: Int, rank: Double, cid: Int)] = []
        for c in cand {
            var best: Int? = nil
            for ln in lineNorms[c.compId] ?? [] {
                if let s = span(ln), best == nil || s < best! { best = s }
            }
            if best == nil, let s = span(c.tnorm) { best = s }
            if let b = best { scored.append((b, c.rank, c.compId)) }
        }
        if scored.isEmpty { return nil }
        let order = scored.enumerated().sorted {
            $0.element.span != $1.element.span ? $0.element.span < $1.element.span
                : ($0.element.rank != $1.element.rank ? $0.element.rank < $1.element.rank : $0.offset < $1.offset)
        }.map { $0.element }
        let cids = order.prefix(3).map { $0.cid }
        let foldSet = Set(toks)

        var out: [SearchLine] = []
        for cid in cids {
            let lines = try source.compLines(compId: cid)
            let annotated = lines.map { row -> (line: SearchLine, hits: Int, seq: Int) in
                let words = row.translitNorm.split(separator: " ").map(String.init)
                let hits = words.reduce(0) { $0 + (foldSet.contains($1) ? 1 : 0) }
                return (row.line, hits, matches(row.translitNorm) ? 1 : 0)
            }
            let matched = annotated.filter { $0.hits > 0 }
                .sorted { a, b in
                    if a.seq != b.seq { return a.seq > b.seq }
                    if a.hits != b.hits { return a.hits > b.hits }
                    return a.line.id < b.line.id
                }.map { $0.line }
            let context = annotated.filter { $0.hits == 0 }.map { $0.line }.sorted { $0.id < $1.id }
            let perComp = max(2, limit / max(cids.count, 1))
            out += Array((matched + context).prefix(perComp))
        }
        let lo = min(offset, out.count), hi = min(offset + limit, out.count)
        let sliced = Array(out[lo..<hi])
        return sliced.isEmpty ? nil : sliced
    }

    // MARK: preprocessing + helpers (Unicode-scalar exact)

    static func preprocess(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        let space = Unicode.Scalar(" ")
        for u in s.unicodeScalars { v.append(punct.contains(u.value) ? space : u) }
        return String(v).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    static func containsGurmukhi(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0A00...0x0A7F).contains($0.value) }
    }
    static func stripSkelMatras(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        for u in s.unicodeScalars where !skelMatras.contains(u.value) { v.append(u) }
        return String(v)
    }
    static func likePattern(_ stripped: String) -> String {
        "%" + stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init).joined(separator: "%") + "%"
    }
    /// fts_query (search variant — NO column prefix).
    static func ftsMatch(_ tokens: [String], phrase: Bool) -> String? {
        let toks = tokens.map { FTSQuery.clean($0) }.filter { !$0.isEmpty }
        if toks.isEmpty { return nil }
        if phrase { return "\"" + toks.joined(separator: " ") + "\"" }
        return toks.map { "\"\($0)\"" }.joined(separator: " AND ")
    }
    static func isAlnum(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
    }
    static func secondLastIsVowel(_ t: String) -> Bool {
        let a = Array(t); return a.count >= 2 && "aeiou".contains(a[a.count - 2])
    }

    /// fold_match_alts: exact-fold twins (initial-vowel swap + subjoined-h reinsertion), ≤5.
    static func foldMatchAlts(_ fn: String) -> [String] {
        if fn.unicodeScalars.count < 2 { return [] }
        let chars = Array(fn)
        var variants = [fn]
        if let sw = ["o": "u", "u": "o", "e": "i", "i": "e"][String(chars[0])] {
            variants.append(sw + String(chars[1...]))
        }
        for i in chars.indices where "mnl".contains(chars[i]) && (i + 1 >= chars.count || chars[i + 1] != "h") {
            variants.append(String(chars[0...i]) + "h" + String(chars[(i + 1)...]))
        }
        var seen = Set<String>(); var uniq: [String] = []
        for v in variants where !seen.contains(v) { seen.insert(v); uniq.append(v) }
        return uniq.prefix(5).map { "translit_norm: \"\($0)\"" }
    }

    /// Python `re.findall(r'(\w+): "([^"]+)"', group)` — parse an OR-group into (column, term) pairs.
    static func parseGroupTerms(_ group: String) -> [(String, String)] {
        var out: [(String, String)] = []
        let scalars = Array(group.unicodeScalars)
        var i = 0
        while i < scalars.count {
            // a column word
            var col = ""
            while i < scalars.count, isWordScalar(scalars[i]) { col.unicodeScalars.append(scalars[i]); i += 1 }
            // expect `: "`
            if !col.isEmpty, i + 1 < scalars.count, scalars[i].value == 0x3A {  // ':'
                var j = i + 1
                while j < scalars.count, scalars[j].value == 0x20 { j += 1 }     // spaces
                if j < scalars.count, scalars[j].value == 0x22 {                 // '"'
                    j += 1
                    var term = ""
                    while j < scalars.count, scalars[j].value != 0x22 { term.unicodeScalars.append(scalars[j]); j += 1 }
                    out.append((col, term))
                    i = j + 1
                    continue
                }
            }
            i += 1
        }
        return out
    }
    private static func isWordScalar(_ u: Unicode.Scalar) -> Bool {
        (0x30...0x39).contains(u.value) || (0x41...0x5A).contains(u.value) ||
        (0x61...0x7A).contains(u.value) || u.value == 0x5F   // [0-9A-Za-z_]
    }
}
