import Foundation

/// A corpus line as the Reader/Shabad/Hukam surfaces render it (LINE_COLS + markers). Sendable.
public struct ReaderLine: Sendable, Equatable {
    public let id: Int
    public let ang: Int
    public let raag: String?
    public let section: String?
    public let author: String?
    public let compType: String?
    public let compId: Int
    public let lineNo: Int?
    public let isRahao: Bool
    public let isHeader: Bool
    public let gurmukhi: String
    public let translit: String
    public let markers: [String]      // parsed from the markers JSON column (Hukam-unit logic)
    /// Labelled English translation (Khalsa layer; serve.py `attach_translations` on /api/ang
    /// and /api/shabad — NOT /api/random, which the web serves without en). nil on the public
    /// DB profile and for the 2,619 lines with no en row — absence renders as nothing.
    public let en: String?
    public init(id: Int, ang: Int, raag: String?, section: String?, author: String?, compType: String?,
                compId: Int, lineNo: Int?, isRahao: Bool, isHeader: Bool, gurmukhi: String,
                translit: String, markers: [String], en: String? = nil) {
        self.id = id; self.ang = ang; self.raag = raag; self.section = section; self.author = author
        self.compType = compType; self.compId = compId; self.lineNo = lineNo; self.isRahao = isRahao
        self.isHeader = isHeader; self.gurmukhi = gurmukhi; self.translit = translit; self.markers = markers
        self.en = en
    }

    /// Same line with the translation attached (models are immutable value types).
    public func withEn(_ en: String?) -> ReaderLine {
        ReaderLine(id: id, ang: ang, raag: raag, section: section, author: author, compType: compType,
                   compId: compId, lineNo: lineNo, isRahao: isRahao, isHeader: isHeader,
                   gurmukhi: gurmukhi, translit: translit, markers: markers, en: en)
    }
}

public struct AngPage: Sendable, Equatable {
    public let ang: Int
    public let lines: [ReaderLine]
    public let continuedFrom: Int?
    /// The id of the FIRST line of the composition that continues onto this Ang (its heading /
    /// opening verse, on Ang `continuedFrom`). Lets "Continues from Ang N" land on the shabad's
    /// start, not the top of Ang N. nil when the Ang does not continue a composition. Additive.
    public let continuedFromLineId: Int?
    public let raag: String?
    public let section: String?
    public let authors: [String]
    public init(ang: Int, lines: [ReaderLine], continuedFrom: Int?, continuedFromLineId: Int? = nil,
                raag: String?, section: String?, authors: [String]) {
        self.ang = ang; self.lines = lines; self.continuedFrom = continuedFrom
        self.continuedFromLineId = continuedFromLineId
        self.raag = raag; self.section = section; self.authors = authors
    }
}

public struct Shabad: Sendable, Equatable {
    public let compId: Int
    public let lines: [ReaderLine]
    public init(compId: Int, lines: [ReaderLine]) { self.compId = compId; self.lines = lines }
}

public struct HukamUnit: Sendable, Equatable {
    public let compId: Int
    public let compIds: [Int]
    public let lines: [ReaderLine]
    public init(compId: Int, compIds: [Int], lines: [ReaderLine]) {
        self.compId = compId; self.compIds = compIds; self.lines = lines
    }
}

public struct RaagRow: Sendable, Equatable, Identifiable {
    public let name: String; public let roman: String?; public let firstAng: Int; public let lastAng: Int
    public let nLines: Int; public let nShabads: Int; public let seq: Int
    public var id: String { name }
    public init(name: String, roman: String?, firstAng: Int, lastAng: Int, nLines: Int, nShabads: Int, seq: Int) {
        self.name = name; self.roman = roman; self.firstAng = firstAng; self.lastAng = lastAng
        self.nLines = nLines; self.nShabads = nShabads; self.seq = seq
    }
}
public struct SectionRow: Sendable, Equatable, Identifiable {
    public let name: String; public let firstAng: Int; public let lastAng: Int; public let nLines: Int
    public var id: String { name }
    public init(name: String, firstAng: Int, lastAng: Int, nLines: Int) {
        self.name = name; self.firstAng = firstAng; self.lastAng = lastAng; self.nLines = nLines
    }
}
public struct AuthorRow: Sendable, Equatable, Identifiable {
    public let name: String; public let firstAng: Int; public let lastAng: Int; public let nLines: Int
    public var id: String { name }
    public init(name: String, firstAng: Int, lastAng: Int, nLines: Int) {
        self.name = name; self.firstAng = firstAng; self.lastAng = lastAng; self.nLines = nLines
    }
}
public struct ConceptRow: Sendable, Equatable, Identifiable {
    public let concept: String; public let description: String; public let nLines: Int
    public var id: String { concept }
    public init(concept: String, description: String, nLines: Int) {
        self.concept = concept; self.description = description; self.nLines = nLines
    }
}
public struct CorpusMeta: Sendable, Equatable {
    public let raags: [RaagRow]; public let sections: [SectionRow]
    public let authors: [AuthorRow]; public let concepts: [ConceptRow]
    public init(raags: [RaagRow], sections: [SectionRow], authors: [AuthorRow], concepts: [ConceptRow]) {
        self.raags = raags; self.sections = sections; self.authors = authors; self.concepts = concepts
    }
}

/// One semantic neighbour (serve.py:/api/neighbors). `score` is a descriptive TF-IDF cosine, surfaced
/// as a relatedness band — NEVER a ranking of scripture.
public struct Neighbor: Sendable, Equatable, Identifiable {
    public let id: Int          // neighbour line id (line level) or comp_id (composition level)
    public let score: Double
    public let ang: Int
    public let raag: String?
    public let author: String?
    public let compId: Int
    public let gurmukhi: String
    public let translit: String
    /// Labelled English translation of the neighbour line (serve.py attaches en on /api/neighbors).
    public let en: String?
    public init(id: Int, score: Double, ang: Int, raag: String?, author: String?, compId: Int,
                gurmukhi: String, translit: String, en: String? = nil) {
        self.id = id; self.score = score; self.ang = ang; self.raag = raag; self.author = author
        self.compId = compId; self.gurmukhi = gurmukhi; self.translit = translit; self.en = en
    }

    /// Same neighbour with the translation attached.
    public func withEn(_ en: String?) -> Neighbor {
        Neighbor(id: id, score: score, ang: ang, raag: raag, author: author, compId: compId,
                 gurmukhi: gurmukhi, translit: translit, en: en)
    }
}

public struct NeighborsResult: Sendable, Equatable {
    public let lineId: Int
    public let level: String     // "line" | "composition" | "none"
    public let source: String?
    public let neighbors: [Neighbor]
    public init(lineId: Int, level: String, source: String?, neighbors: [Neighbor]) {
        self.lineId = lineId; self.level = level; self.source = source; self.neighbors = neighbors
    }
}

/// What optional layers this DB build carries — detected from sqlite_master at open, never from
/// compile flags: one binary degrades correctly on either profile (personal = +English, public =
/// Gurmukhi-only), and any FUTURE additive layer (audio, commentary, …) is a new bit here + a
/// capability-gated surface, no code fork.
public struct CorpusCapabilities: Sendable, Equatable {
    /// translations + fts_en present (the Khalsa English layer; personal profile only).
    public let hasEnglish: Bool
    /// The v2.12.0 raag-timing layer (timing_sources/raag_timing_claims/shabd_* form tables).
    public let hasTiming: Bool
    /// The v1.2.0 Nitnem bani registry (banis/bani_lines/extra_lines) — gates the Nitnem tab.
    public let hasBanis: Bool
    public init(hasEnglish: Bool, hasTiming: Bool, hasBanis: Bool = false) {
        self.hasEnglish = hasEnglish; self.hasTiming = hasTiming; self.hasBanis = hasBanis
    }
}

/// Plain read endpoints (mirror serve.py's /api/ang, /shabad, /random, /meta, /neighbors). No fuzzy logic.
public protocol CorpusReader: Sendable {
    func fetchAng(_ n: Int) throws -> AngPage
    func fetchShabad(compId: Int) throws -> Shabad
    /// The complete Hukam unit for a seed comp_id (serve.py:hukam_package; deterministic).
    func hukamUnit(seed: Int) throws -> HukamUnit
    /// A random seed comp_id (non-header line), for the Hukam draw.
    func randomSeedCompId() throws -> Int
    func fetchMeta() throws -> CorpusMeta
    /// Semantic neighbours of a line (line_neighbors → shabad_neighbors fallback). Trail surface.
    func neighbors(lineId: Int, limit: Int) throws -> NeighborsResult
}
