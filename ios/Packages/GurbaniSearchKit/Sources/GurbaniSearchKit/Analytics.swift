import Foundation

/// Insight-Engine read models (serve.py /api/analytics/*, /api/themes/network). All precomputed,
/// descriptive — NEVER a ranking or judgement of scripture.

public struct AuthorStat: Sendable, Equatable, Identifiable {
    public let author: String
    public let nLines: Int
    public let nShabads: Int
    public let nRaags: Int
    public let mattr100: Double      // moving-average type-token ratio (lexical diversity)
    public let avgWordsLine: Double
    public let isReliable: Bool
    public var id: String { author }
    public init(author: String, nLines: Int, nShabads: Int, nRaags: Int, mattr100: Double,
                avgWordsLine: Double, isReliable: Bool) {
        self.author = author; self.nLines = nLines; self.nShabads = nShabads; self.nRaags = nRaags
        self.mattr100 = mattr100; self.avgWordsLine = avgWordsLine; self.isReliable = isReliable
    }
}

public struct RaagStat: Sendable, Equatable, Identifiable {
    public let raag: String
    public let nLines: Int
    public let nShabads: Int
    public let nAuthors: Int
    public let dominantAuthor: String?
    public let dominantAuthorPct: Double
    public let nThemes: Int
    public var id: String { raag }
    public init(raag: String, nLines: Int, nShabads: Int, nAuthors: Int, dominantAuthor: String?,
                dominantAuthorPct: Double, nThemes: Int) {
        self.raag = raag; self.nLines = nLines; self.nShabads = nShabads; self.nAuthors = nAuthors
        self.dominantAuthor = dominantAuthor; self.dominantAuthorPct = dominantAuthorPct; self.nThemes = nThemes
    }
}

public struct ThemeEdge: Sendable, Equatable, Identifiable {
    public let source: String
    public let target: String
    public let shabadCount: Int
    public let ppmi: Double
    public let jaccard: Double
    public var id: String { "\(source)~\(target)" }
    public init(source: String, target: String, shabadCount: Int, ppmi: Double, jaccard: Double) {
        self.source = source; self.target = target; self.shabadCount = shabadCount
        self.ppmi = ppmi; self.jaccard = jaccard
    }
}

public protocol AnalyticsSource: Sendable {
    /// `SELECT author,n_lines,n_shabads,n_raags,mattr_100,avg_words_line,is_reliable FROM author_analytics ORDER BY n_lines DESC`.
    func authorAnalytics() throws -> [AuthorStat]
    /// `SELECT … FROM raag_analytics ORDER BY n_lines DESC`.
    func raagAnalytics() throws -> [RaagStat]
    /// `SELECT source,target,shabad_count,ppmi,jaccard FROM theme_network WHERE source<target AND ppmi>=? ORDER BY ppmi DESC LIMIT ?`.
    func themeNetwork(minPPMI: Double, limit: Int) throws -> [ThemeEdge]
}
