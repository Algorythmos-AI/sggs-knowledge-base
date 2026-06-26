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
    public let mode: String              // resolved 'used' mode
    public let results: [SearchLine]
    public let concept: ThemeConcept?
    public let relatedThemes: [String]?
}

/// The DB seam for search (separate from verify's CandidateSource). The DB target satisfies it.
public protocol SearchSource: Sendable {
    func ftsSearch(column: String, match: String, excludeHeaders: Bool, limit: Int, offset: Int) throws -> [SearchLine]
    func likeSearch(column: String, pattern: String, limit: Int, offset: Int) throws -> [SearchLine]
    func conceptExactExists(_ name: String) throws -> Bool
    func themeSearch(_ q: String, limit: Int, offset: Int) throws -> ThemeSearchResult
    func termConcepts(_ tokens: [String]) throws -> [String]
}

public enum SearchError: Error { case queryTooLong, modeNotPortedYet(String) }

/// Byte-identical Swift port of the EXPLICIT-mode paths of `webapp/serve.py:do_search`
/// (gurmukhi / roman / first / theme). The auto-mode mixed-script + exotic fallback tiers
/// (variant / lexicon / passage / blob / honorific) are ported in a later phase.
/// Pinned by `contract/golden_search.ndjson`.
public struct SearchEngine {
    private let source: SearchSource

    // PUNCT_RE = [॥।.,;:!?"'()\[\]{}|/\\-]+  (separators)
    private static let punct: Set<UInt32> = Set("॥।.,;:!?\"'()[]{}|/\\-".unicodeScalars.map { $0.value })
    // do_search's matra strip for the skeleton fallback (a SUBSET of the full matra set).
    private static let skelMatras: Set<UInt32> = Set("ਾਿੀੁੂੇੈੋੌੰਂ੍".unicodeScalars.map { $0.value })

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

        var res: [SearchLine] = []
        var used = ""

        switch mode {
        case "gurmukhi":
            res = try run("text"); used = "gurmukhi"
            if res.isEmpty {
                let stripped = Self.stripSkelMatras(q)
                res = try source.likeSearch(column: "skeleton", pattern: Self.likePattern(stripped),
                                            limit: limit, offset: offset)
                used = "gurmukhi-skeleton"
            }

        case "roman":
            res = try run("translit"); used = "roman"
            if res.isEmpty {
                let strong = RomanNorm.fold(q).split(separator: " ").map(String.init)
                    .filter { $0.unicodeScalars.count >= 2 }
                if !strong.isEmpty, let m = Self.ftsMatch(strong, phrase: false) {
                    res = try source.ftsSearch(column: "translit_norm", match: m, excludeHeaders: true,
                                               limit: limit, offset: offset)
                    used = "roman-spelling-tolerant"
                }
            }

        case "first":
            res = try run(isG ? "fl_g" : "fl_r", phrase: true); used = "first-letters"

        case "theme":
            let t = try source.themeSearch(q, limit: limit, offset: offset)
            return SearchOutput(mode: "theme", results: t.lines, concept: t.concept, relatedThemes: nil)

        default:
            throw SearchError.modeNotPortedYet(mode)   // auto + exotic tiers: later phase
        }

        var related: [String]? = nil
        if isG {
            let rel = try source.termConcepts(toks)
            if !rel.isEmpty { related = Array(rel.prefix(3)) }
        }
        return SearchOutput(mode: used, results: res, concept: nil, relatedThemes: related)
    }

    // MARK: preprocessing helpers (Unicode-scalar exact)

    static func preprocess(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        let space = Unicode.Scalar(" ")
        for u in s.unicodeScalars { v.append(punct.contains(u.value) ? space : u) }
        return String(v).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func containsGurmukhi(_ s: String) -> Bool {
        for u in s.unicodeScalars where (0x0A00...0x0A7F).contains(u.value) { return true }
        return false
    }

    static func stripSkelMatras(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        for u in s.unicodeScalars where !skelMatras.contains(u.value) { v.append(u) }
        return String(v)
    }

    static func likePattern(_ stripped: String) -> String {
        let toks = stripped.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return "%" + toks.joined(separator: "%") + "%"
    }

    /// fts_query (search variant — NO column prefix; the column is bound in the SQL).
    static func ftsMatch(_ tokens: [String], phrase: Bool) -> String? {
        let toks = tokens.map { FTSQuery.clean($0) }.filter { !$0.isEmpty }
        if toks.isEmpty { return nil }
        if phrase { return "\"" + toks.joined(separator: " ") + "\"" }
        return toks.map { "\"\($0)\"" }.joined(separator: " AND ")
    }
}
