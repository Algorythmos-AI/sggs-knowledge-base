import Foundation
import CSQLite
import GurbaniSearchKit

/// Raag-Timing knowledge layer over the read-only DB — the exact serve.py SQL for
/// /api/timing/clock, /api/timing/raag, /api/timing/divergence and /api/forms.
/// Pinned by contract/golden_timing.ndjson. Every method degrades to `available: false`
/// when the timing tables are absent (public/older DB builds) — serve.py catches
/// sqlite3.OperationalError; here a failed prepare is that same degradation, not an error.
extension SQLiteCandidateSource {

    private func optText(_ s: OpaquePointer?, _ c: Int32) -> String? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : sqlite3_column_text(s, c).map { String(cString: $0) }
    }
    private func optInt(_ s: OpaquePointer?, _ c: Int32) -> Int? {
        sqlite3_column_type(s, c) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(s, c))
    }

    /// serve.py:/api/timing/clock — every claim joined to its source + raag, ORDER BY
    /// r.seq, c.claim_type, c.pahar; grouped by claim_type.
    public func timingClock() -> TimingClock {
        let sql = """
        SELECT c.raag_name, r.roman, r.first_ang, r.seq, c.claim_type, c.pahar,
               c.time_start, c.time_end, c.season, c.occasion, c.confidence, c.notes,
               s.name AS source_name, s.tradition, s.url AS source_url
        FROM raag_timing_claims c
        JOIN timing_sources s ON s.id = c.source_id
        JOIN raags r ON r.name = c.raag_name
        ORDER BY r.seq, c.claim_type, c.pahar
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            return TimingClock(available: false)
        }
        defer { sqlite3_finalize(stmt) }
        var groups: [String: [TimingClaim]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let claim = TimingClaim(
                raagName: optText(stmt, 0), roman: optText(stmt, 1), firstAng: optInt(stmt, 2),
                seq: optInt(stmt, 3), claimType: optText(stmt, 4) ?? "", pahar: optInt(stmt, 5),
                timeStart: optText(stmt, 6), timeEnd: optText(stmt, 7), season: optText(stmt, 8),
                occasion: optText(stmt, 9), confidence: optText(stmt, 10) ?? "",
                notes: optText(stmt, 11), sourceName: optText(stmt, 12) ?? "",
                tradition: optText(stmt, 13) ?? "", sourceURL: optText(stmt, 14))
            groups[claim.claimType, default: []].append(claim)
        }
        return TimingClock(available: true,
                           primary: groups["primary"] ?? [], variant: groups["variant"] ?? [],
                           seasonal: groups["seasonal"] ?? [], ceremonial: groups["ceremonial"] ?? [])
    }

    /// One raag's claims by gurmukhi name or roman (serve.py lowercases the roman probe).
    public func timingRaag(name: String) -> RaagTiming {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle,
            "SELECT name, roman, first_ang FROM raags WHERE name=? OR roman=?", -1, &stmt, nil) == SQLITE_OK else {
            return RaagTiming(available: false, raag: name, roman: nil, firstAng: nil, claims: [])
        }
        sqlite3_bind_text(stmt, 1, name, -1, Self.transientDtor)
        sqlite3_bind_text(stmt, 2, name.lowercased(), -1, Self.transientDtor)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            sqlite3_finalize(stmt)
            // raags table exists but no such raag — mirror serve.py ('no such raag', available true)
            // vs the layer being absent entirely (prepare on claims below decides availability)
            var probe: OpaquePointer?
            let hasLayer = sqlite3_prepare_v2(handle, "SELECT 1 FROM raag_timing_claims LIMIT 1", -1, &probe, nil) == SQLITE_OK
            sqlite3_finalize(probe)
            return RaagTiming(available: hasLayer, raag: name, roman: nil, firstAng: nil, claims: [])
        }
        let raagName = optText(stmt, 0) ?? name
        let roman = optText(stmt, 1)
        let firstAng = optInt(stmt, 2)
        sqlite3_finalize(stmt)

        let claimsSQL = """
        SELECT c.claim_type, c.pahar, c.time_start, c.time_end, c.season,
               c.occasion, c.confidence, c.notes, s.name AS source_name,
               s.tradition, s.url AS source_url
        FROM raag_timing_claims c JOIN timing_sources s ON s.id = c.source_id
        WHERE c.raag_name = ? ORDER BY c.claim_type, c.pahar
        """
        var cs: OpaquePointer?
        guard sqlite3_prepare_v2(handle, claimsSQL, -1, &cs, nil) == SQLITE_OK else {
            return RaagTiming(available: false, raag: name, roman: nil, firstAng: nil, claims: [])
        }
        defer { sqlite3_finalize(cs) }
        sqlite3_bind_text(cs, 1, raagName, -1, Self.transientDtor)
        var claims: [TimingClaim] = []
        while sqlite3_step(cs) == SQLITE_ROW {
            claims.append(TimingClaim(
                raagName: nil, roman: nil, firstAng: nil, seq: nil,
                claimType: optText(cs, 0) ?? "", pahar: optInt(cs, 1),
                timeStart: optText(cs, 2), timeEnd: optText(cs, 3), season: optText(cs, 4),
                occasion: optText(cs, 5), confidence: optText(cs, 6) ?? "",
                notes: optText(cs, 7), sourceName: optText(cs, 8) ?? "",
                tradition: optText(cs, 9) ?? "", sourceURL: optText(cs, 10)))
        }
        return RaagTiming(available: true, raag: raagName, roman: roman, firstAng: firstAng, claims: claims)
    }

    /// Raags where traditions disagree (variant claims, or multiple pahars from multiple
    /// sources — a same-source multi-pahar row is an extension, not a dispute).
    public func timingDivergence() -> TimingDivergence {
        let namesSQL = """
        SELECT raag_name FROM raag_timing_claims
        WHERE claim_type IN ('primary','variant')
        GROUP BY raag_name
        HAVING SUM(claim_type = 'variant') > 0
            OR (COUNT(DISTINCT COALESCE(pahar, -1)) > 1
                AND COUNT(DISTINCT source_id) > 1)
        ORDER BY MIN((SELECT seq FROM raags WHERE name = raag_name))
        """
        var ns: OpaquePointer?
        guard sqlite3_prepare_v2(handle, namesSQL, -1, &ns, nil) == SQLITE_OK else {
            return TimingDivergence(available: false, raags: [])
        }
        var names: [String] = []
        while sqlite3_step(ns) == SQLITE_ROW { if let n = optText(ns, 0) { names.append(n) } }
        sqlite3_finalize(ns)

        var entries: [TimingDivergence.Entry] = []
        for n in names {
            let claimsSQL = """
            SELECT c.claim_type, c.pahar, c.time_start, c.time_end, c.occasion,
                   c.confidence, c.notes, s.name AS source_name, s.tradition,
                   s.url AS source_url
            FROM raag_timing_claims c JOIN timing_sources s ON s.id = c.source_id
            WHERE c.raag_name = ? AND c.claim_type IN ('primary','variant')
            ORDER BY c.claim_type, c.pahar
            """
            var cs: OpaquePointer?
            guard sqlite3_prepare_v2(handle, claimsSQL, -1, &cs, nil) == SQLITE_OK else { continue }
            sqlite3_bind_text(cs, 1, n, -1, Self.transientDtor)
            var claims: [TimingClaim] = []
            while sqlite3_step(cs) == SQLITE_ROW {
                claims.append(TimingClaim(
                    raagName: nil, roman: nil, firstAng: nil, seq: nil,
                    claimType: optText(cs, 0) ?? "", pahar: optInt(cs, 1),
                    timeStart: optText(cs, 2), timeEnd: optText(cs, 3), season: nil,
                    occasion: optText(cs, 4), confidence: optText(cs, 5) ?? "",
                    notes: optText(cs, 6), sourceName: optText(cs, 7) ?? "",
                    tradition: optText(cs, 8) ?? "", sourceURL: optText(cs, 9)))
            }
            sqlite3_finalize(cs)
            var rs: OpaquePointer?
            var roman: String? = nil; var firstAng: Int? = nil
            if sqlite3_prepare_v2(handle, "SELECT roman, first_ang, seq FROM raags WHERE name=?",
                                  -1, &rs, nil) == SQLITE_OK {
                sqlite3_bind_text(rs, 1, n, -1, Self.transientDtor)
                if sqlite3_step(rs) == SQLITE_ROW { roman = optText(rs, 0); firstAng = optInt(rs, 1) }
            }
            sqlite3_finalize(rs)
            entries.append(.init(raag: n, roman: roman, firstAng: firstAng, claims: claims))
        }
        return TimingDivergence(available: true, raags: entries)
    }

    /// A composition's musical/structural metadata (serve.py:/api/forms?comp_id=N).
    public func forms(compId: Int) -> ShabadForms {
        let sql = """
        SELECT m.comp_id, m.raag_name, m.first_ang,
               mm.ghar, mm.partaal, mm.has_rahao, mm.has_rahao_dooja,
               mm.dhunni, mm.jati,
               sf.form, sf.pada_count, pg.genre, mm.source_label
        FROM shabd_raag_map m
        LEFT JOIN shabd_musical_markers mm ON mm.comp_id = m.comp_id
        LEFT JOIN shabd_structural_form sf ON sf.comp_id = m.comp_id
        LEFT JOIN shabd_poetic_genre pg ON pg.comp_id = m.comp_id
        WHERE m.comp_id = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            return ShabadForms(available: false, compId: compId)
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(compId))
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return ShabadForms(available: true, compId: compId, mapped: false)
        }
        func optBool(_ c: Int32) -> Bool? { optInt(stmt, c).map { $0 != 0 } }
        return ShabadForms(
            available: true, compId: compId,
            raagName: optText(stmt, 1), firstAng: optInt(stmt, 2),
            ghar: optInt(stmt, 3), partaal: optBool(4), hasRahao: optBool(5),
            hasRahaoDooja: optBool(6), dhunni: optText(stmt, 7), jati: optText(stmt, 8),
            form: optText(stmt, 9), padaCount: optInt(stmt, 10), genre: optText(stmt, 11),
            sourceLabel: optText(stmt, 12), mapped: true)
    }
}
