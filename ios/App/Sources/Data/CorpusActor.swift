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
    /// Which optional layers this DB build carries (English/timing) — detected from
    /// sqlite_master at init, immutable, Sendable → safe to read off-actor. UI surfaces gate
    /// on these bits so the public (Gurmukhi-only) profile degrades to today's behavior.
    nonisolated let capabilities: CorpusCapabilities

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
        self.capabilities = db.detectCapabilities()
    }

    func search(_ q: String, mode: String, limit: Int = 50, offset: Int = 0) throws -> SearchOutput {
        let out = try searchEngine.search(q, mode: mode, limit: limit, offset: offset)
        // serve.py:798 — en attaches to EVERY search mode's results (no-op on the public profile)
        return SearchOutput(mode: out.mode, results: db.attachTranslations(out.results),
                            concept: out.concept, relatedThemes: out.relatedThemes)
    }
    func verify(_ claim: String, ang: Int?) throws -> VerifyResult { try verifyEngine.verify(claim: claim, ang: ang) }
    /// English of one line (display layer — e.g. under the verify verdict's canonical line).
    func english(forLine id: Int) throws -> String? { db.english(forLine: id) }
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
    // Insight-Engine deep reads (Lineage profiles, chord, streamgraph, vaar anatomy).
    func authorProfile(_ author: String, full: Bool = false) -> AuthorProfile { db.authorProfile(author, full: full) }
    func resonance(minLines: Int = 250, minLift: Double = 1.0, minEdges: Int = 8) -> ResonanceGraph {
        db.resonance(minLines: minLines, minLift: minLift, minEdges: minEdges)
    }
    func progression(raag: String, bins: Int = 36, top: Int = 7) -> Progression? {
        db.progression(raag: raag, bins: bins, top: top)
    }
    func vaars() -> [VaarSummary] { db.vaars() }
    func vaar(id: Int) -> VaarAnatomy { db.vaar(id: id) }

    // Raag-Timing layer (v2.12.0) — attributed claims with citations, never facts.
    func timingClock() -> TimingClock { db.timingClock() }
    func timingRaag(name: String) -> RaagTiming { db.timingRaag(name: name) }
    func timingDivergence() -> TimingDivergence { db.timingDivergence() }
    func forms(compId: Int) -> ShabadForms { db.forms(compId: compId) }

    // Nitnem / Gutka registry (v1.2.0, ADR-0006) — pointers into the verbatim corpus plus a
    // separate labelled non-SGGS layer. Gated by `capabilities.hasBanis`.
    func banis() -> BaniList { db.fetchBanis() }
    func bani(key: String, variant: String = "") -> Bani? { db.fetchBani(key: key, variant: variant) }

    func theme(_ name: String) throws -> ThemeSearchResult {
        let t = try db.themeSearch(name, limit: 200, offset: 0)
        return ThemeSearchResult(concept: t.concept, lines: db.attachTranslations(t.lines))
    }
}
