import Foundation

/// Insight-Engine deep models (serve.py /api/analytics/{author,resonance,progression,vaars,vaar}).
/// All precomputed or deterministically derived, descriptive — NEVER a ranking or judgement of
/// scripture. Pinned by contract/golden_analytics.ndjson.

/// A signature theme of an author (top_themes JSON: concept + lift vs corpus baseline).
public struct TopTheme: Sendable, Equatable, Codable, Identifiable {
    public let concept: String
    public let lift: Double
    public var id: String { concept }
    public init(concept: String, lift: Double) { self.concept = concept; self.lift = lift }
}

/// One author's full stylometry row (author_analytics; stylometry computed on the English
/// translation — descriptive only).
public struct AuthorStylometry: Sendable, Equatable {
    public let author: String
    public let nLines: Int
    public let nShabads: Int
    public let nRaags: Int
    public let nTokens: Int
    public let mattr100: Double
    public let hapaxPct: Double
    public let avgWordsLine: Double
    public let avgLinesShabad: Double
    public let topThemes: [TopTheme]
    public let isReliable: Bool
    public init(author: String, nLines: Int, nShabads: Int, nRaags: Int, nTokens: Int,
                mattr100: Double, hapaxPct: Double, avgWordsLine: Double, avgLinesShabad: Double,
                topThemes: [TopTheme], isReliable: Bool) {
        self.author = author; self.nLines = nLines; self.nShabads = nShabads; self.nRaags = nRaags
        self.nTokens = nTokens; self.mattr100 = mattr100; self.hapaxPct = hapaxPct
        self.avgWordsLine = avgWordsLine; self.avgLinesShabad = avgLinesShabad
        self.topThemes = topThemes; self.isReliable = isReliable
    }
}

/// One theme-fingerprint axis (lift vs the corpus baseline) — the radar's spokes.
public struct FingerprintAxis: Sendable, Equatable, Identifiable {
    public let concept: String
    public let nTagged: Int
    public let entityRate: Double
    public let corpusRate: Double
    public let lift: Double
    public var id: String { concept }
    public init(concept: String, nTagged: Int, entityRate: Double, corpusRate: Double, lift: Double) {
        self.concept = concept; self.nTagged = nTagged; self.entityRate = entityRate
        self.corpusRate = corpusRate; self.lift = lift
    }
}

public struct DistinctiveTerm: Sendable, Equatable, Identifiable {
    public let term: String
    public let zScore: Double
    public let rank: Int
    public var id: String { term }
    public init(term: String, zScore: Double, rank: Int) {
        self.term = term; self.zScore = zScore; self.rank = rank
    }
}

/// /api/analytics/author?author=X(&full=1) — profile for Lineage + the radar.
public struct AuthorProfile: Sendable, Equatable {
    public let author: String
    public let stylometry: AuthorStylometry?
    public let fingerprint: [FingerprintAxis]     // 12 axes, or up to 60 with full
    public let distinctiveTerms: [DistinctiveTerm]
    public init(author: String, stylometry: AuthorStylometry?, fingerprint: [FingerprintAxis],
                distinctiveTerms: [DistinctiveTerm]) {
        self.author = author; self.stylometry = stylometry
        self.fingerprint = fingerprint; self.distinctiveTerms = distinctiveTerms
    }
}

/// /api/analytics/resonance — cross-contributor semantic-neighbour graph (the chord).
public struct ResonanceGraph: Sendable, Equatable {
    public struct Node: Sendable, Equatable, Identifiable {
        public let author: String
        public let nLines: Int
        public let firstAng: Int
        public var id: String { author }
        public init(author: String, nLines: Int, firstAng: Int) {
            self.author = author; self.nLines = nLines; self.firstAng = firstAng
        }
    }
    public struct Edge: Sendable, Equatable {
        public let source: String
        public let target: String
        public let edges: Int
        public let meanScore: Double
        public let lift: Double
        public init(source: String, target: String, edges: Int, meanScore: Double, lift: Double) {
            self.source = source; self.target = target; self.edges = edges
            self.meanScore = meanScore; self.lift = lift
        }
    }
    public let nodes: [Node]
    public let edges: [Edge]
    public init(nodes: [Node], edges: [Edge]) { self.nodes = nodes; self.edges = edges }
}

/// /api/analytics/progression — concept-tag density along a raag in reading order
/// (computed on the fly; the float/int port is pinned by bins {8,36,80} golden vectors).
public struct Progression: Sendable, Equatable {
    public let raag: String
    public let roman: String
    public let nLines: Int
    public let bins: Int
    public let concepts: [String]
    public let series: [String: [Int]]
    public let linesPerBin: [Int]
    public let angAxis: [Int]
    public init(raag: String, roman: String, nLines: Int, bins: Int, concepts: [String],
                series: [String: [Int]], linesPerBin: [Int], angAxis: [Int]) {
        self.raag = raag; self.roman = roman; self.nLines = nLines; self.bins = bins
        self.concepts = concepts; self.series = series; self.linesPerBin = linesPerBin
        self.angAxis = angAxis
    }
}

/// /api/analytics/vaars — the 22 Vaars. Pauris take the Vaar's author even when interleaved
/// saloks carry other Gurus' ਮਃ headers (the famous cross-voice editorial structure) — always
/// displayed verbatim from the tables, never re-derived.
public struct VaarSummary: Sendable, Equatable, Identifiable {
    public let vaarId: Int
    public let raag: String?
    public let roman: String?
    public let firstAng: Int
    public let lastAng: Int
    public let nPauris: Int
    public let nSaloks: Int
    public let pauriAuthor: String?
    public let salokAuthors: [String]
    public let crossAuthor: Bool
    public let title: String?
    public var id: Int { vaarId }
    public init(vaarId: Int, raag: String?, roman: String?, firstAng: Int, lastAng: Int,
                nPauris: Int, nSaloks: Int, pauriAuthor: String?, salokAuthors: [String],
                crossAuthor: Bool, title: String?) {
        self.vaarId = vaarId; self.raag = raag; self.roman = roman; self.firstAng = firstAng
        self.lastAng = lastAng; self.nPauris = nPauris; self.nSaloks = nSaloks
        self.pauriAuthor = pauriAuthor; self.salokAuthors = salokAuthors
        self.crossAuthor = crossAuthor; self.title = title
    }
}

/// One salok/pauri unit of a Vaar's anatomy, in reading order.
public struct VaarUnit: Sendable, Equatable {
    public let seq: Int
    public let kind: String          // salok | pauri
    public let author: String?
    public let nLines: Int
    public let pauriNo: Int?
    public let firstLineId: Int
    public let ang: Int
    public let theme: String?
    public init(seq: Int, kind: String, author: String?, nLines: Int, pauriNo: Int?,
                firstLineId: Int, ang: Int, theme: String?) {
        self.seq = seq; self.kind = kind; self.author = author; self.nLines = nLines
        self.pauriNo = pauriNo; self.firstLineId = firstLineId; self.ang = ang; self.theme = theme
    }
}

public struct VaarAnatomy: Sendable, Equatable {
    public let vaar: VaarSummary?
    public let units: [VaarUnit]
    public init(vaar: VaarSummary?, units: [VaarUnit]) { self.vaar = vaar; self.units = units }
}
