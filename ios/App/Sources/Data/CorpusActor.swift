import Foundation
import GurbaniSearchKit
import GurbaniDB

/// Serializes all access to the read-only corpus DB + the search/verify engines, returning only
/// Sendable value types. The single boundary where SQLite is touched (the handle is not
/// thread-safe; the actor makes it correct under Swift 6 strict concurrency).
actor CorpusActor {
    private let db: SQLiteCandidateSource
    private let searchEngine: SearchEngine
    private let verifyEngine: VerifyEngine
    /// Bundle path of the corpus DB (read-only; safe to read off the actor for the integrity hash).
    nonisolated let dbPath: String
    /// The linked (pinned) SQLite version — provenance, safe to read off-actor.
    nonisolated var sqliteVersion: String { SQLiteCandidateSource.sqliteVersion }

    enum CorpusError: LocalizedError {
        case databaseMissing
        var errorDescription: String? { "Scripture database not found in the app bundle." }
    }

    init() throws {
        guard let url = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite") else {
            throw CorpusError.databaseMissing
        }
        self.dbPath = url.path
        self.db = try SQLiteCandidateSource(path: url.path)
        self.searchEngine = SearchEngine(source: db)
        self.verifyEngine = VerifyEngine(source: db)
    }

    func search(_ q: String, mode: String, limit: Int = 50, offset: Int = 0) throws -> SearchOutput {
        try searchEngine.search(q, mode: mode, limit: limit, offset: offset)
    }
    func verify(_ claim: String, ang: Int?) throws -> VerifyResult { try verifyEngine.verify(claim: claim, ang: ang) }
    func ang(_ n: Int) throws -> AngPage { try db.fetchAng(n) }
    func shabad(compId: Int) throws -> Shabad { try db.fetchShabad(compId: compId) }
    func randomHukam() throws -> HukamUnit { try db.hukamUnit(seed: db.randomSeedCompId()) }
    func meta() throws -> CorpusMeta { try db.fetchMeta() }
    func neighbors(lineId: Int, limit: Int = 12) throws -> NeighborsResult { try db.neighbors(lineId: lineId, limit: limit) }
    func authorAnalytics() throws -> [AuthorStat] { try db.authorAnalytics() }
    func raagAnalytics() throws -> [RaagStat] { try db.raagAnalytics() }
    func themeNetwork(minPPMI: Double = 0.7, limit: Int = 40) throws -> [ThemeEdge] { try db.themeNetwork(minPPMI: minPPMI, limit: limit) }
    func constellation(concept: String, author: String? = nil, raag: String? = nil) throws -> ConstellationResult {
        try db.constellation(concept: concept, author: author, raag: raag)
    }
    func theme(_ name: String) throws -> ThemeSearchResult { try db.themeSearch(name, limit: 200, offset: 0) }
}
