import Foundation

/// One corpus line (the columns verify needs). Sendable value type — never a live DB row.
public struct GurbaniLine: Sendable, Equatable {
    public let id: Int
    public let ang: Int
    public let gurmukhi: String
    public let translit: String
    public let translitNorm: String
    public let raag: String?
    public let author: String?
    public let compId: Int
    public let section: String?

    public init(id: Int, ang: Int, gurmukhi: String, translit: String, translitNorm: String,
                raag: String?, author: String?, compId: Int, section: String?) {
        self.id = id; self.ang = ang; self.gurmukhi = gurmukhi; self.translit = translit
        self.translitNorm = translitNorm; self.raag = raag; self.author = author
        self.compId = compId; self.section = section
    }
}

/// The DB seam: the verify engine is pure and asks a source for FTS candidates + line rows.
/// `GurbaniDB.SQLiteCandidateSource` satisfies this; tests can fake it.
public protocol CandidateSource: Sendable {
    /// `SELECT rowid, rank FROM fts WHERE fts MATCH ? ORDER BY rank LIMIT ?` — rowids in rank order.
    /// Returns [] for an empty match string (mirrors verify._fts_query's empty guard).
    func ftsRowids(_ match: String, limit: Int) throws -> [Int]
    func fetchLine(_ rowid: Int) throws -> GurbaniLine?
}

public struct VerifyResult: Sendable, Equatable {
    public let verdict: String
    public let confidence: Double
    public let matchedLineId: Int?
    public let ang: Int?
    public let gurmukhi: String?
    public let raag: String?
    public let author: String?
    public let compId: Int?
    public let section: String?
    public let bestRatio: Double?
    public let secondRatio: Double?
    public let gap: Double?
    public let candidatesScored: Int?
    public let note: String?
}

/// Byte-identical Swift port of `webapp/verify.py` `verify()` + `_make_verdict` + the
/// gurmukhi/roman 3-stage candidate searches. Pinned by `contract/golden_verify.ndjson`.
public struct VerifyEngine {
    private let source: CandidateSource
    private let candidateLimit = 10          // verify._fts_query default limit

    private let threshExact = 0.95
    private let threshProbable = 0.85
    private let threshAmbig = 0.80
    private let threshGap = 0.05

    public init(source: CandidateSource) { self.source = source }

    public func verify(claim claimIn: String, ang: Int? = nil) throws -> VerifyResult {
        let claim = claimIn.trimmingCharacters(in: .whitespacesAndNewlines)
        let nfc = claim.precomposedStringWithCanonicalMapping     // unicodedata.normalize("NFC", …)
        let isG = GurbaniText.isGurmukhi(nfc)

        let claimClean: String
        let claimTN: String
        let candidates: [Int]
        let exactHit: Int?
        if isG {
            claimClean = GurbaniText.cleanGurmukhi(nfc)
            claimTN = ""
            (candidates, exactHit) = try searchGurmukhi(nfc, claimClean: claimClean)
        } else {
            claimClean = ""
            claimTN = nfc.lowercased()
                .split(whereSeparator: { $0.isWhitespace })
                .map { RomanNorm.fold(String($0)) }
                .joined(separator: " ")
            (candidates, exactHit) = try searchRoman(nfc)
        }

        let v = try makeVerdict(candidates: candidates, exactHit: exactHit,
                                claimClean: claimClean, claimTN: claimTN, isG: isG)

        let actualAng = v.bestRow?.ang
        var verdict = v.verdict
        if v.verdict != "NOT_FOUND", let ang = ang, let actual = actualAng {
            verdict += (ang == actual) ? "+ANG_MATCH" : "+ANG_MISMATCH(actual=\(actual))"
        }

        return VerifyResult(
            verdict: verdict, confidence: v.confidence, matchedLineId: v.matchedLineId,
            ang: actualAng, gurmukhi: v.bestRow?.gurmukhi, raag: v.bestRow?.raag,
            author: v.bestRow?.author, compId: v.bestRow?.compId, section: v.bestRow?.section,
            bestRatio: v.bestRatio, secondRatio: v.secondRatio, gap: v.gap,
            candidatesScored: v.candidatesScored, note: v.note)
    }

    // MARK: verdict

    private struct Inter {
        var verdict: String; var confidence: Double; var matchedLineId: Int?; var bestRow: GurbaniLine?
        var bestRatio: Double?; var secondRatio: Double?; var gap: Double?
        var candidatesScored: Int?; var note: String?
    }

    private func score(_ row: GurbaniLine, claimClean: String, claimTN: String, isG: Bool) -> Double {
        if isG {
            return SequenceMatcher(a: claimClean, b: GurbaniText.cleanGurmukhi(row.gurmukhi)).ratio()
        } else {
            return SequenceMatcher(a: claimTN, b: row.translitNorm).ratio()
        }
    }

    private func makeVerdict(candidates: [Int], exactHit: Int?, claimClean: String,
                             claimTN: String, isG: Bool) throws -> Inter {
        if candidates.isEmpty {
            return Inter(verdict: "NOT_FOUND", confidence: 0.0, matchedLineId: nil, bestRow: nil,
                         bestRatio: nil, secondRatio: nil, gap: nil, candidatesScored: nil,
                         note: "no FTS hits")
        }
        var scored: [(ratio: Double, rid: Int, row: GurbaniLine)] = []
        for rid in candidates {
            guard let row = try source.fetchLine(rid) else { continue }
            scored.append((score(row, claimClean: claimClean, claimTN: claimTN, isG: isG), rid, row))
        }
        if scored.isEmpty {
            return Inter(verdict: "NOT_FOUND", confidence: 0.0, matchedLineId: nil, bestRow: nil,
                         bestRatio: nil, secondRatio: nil, gap: nil, candidatesScored: nil,
                         note: "scoring yielded no rows")
        }
        // Python's list.sort(key=-ratio) is STABLE — ties keep candidate (rank) order.
        let stable = scored.enumerated().sorted {
            $0.element.ratio != $1.element.ratio ? $0.element.ratio > $1.element.ratio
                                                 : $0.offset < $1.offset
        }.map { $0.element }

        let bestRatio = stable[0].ratio
        let secondRatio = stable.count > 1 ? stable[1].ratio : 0.0
        let gap = bestRatio - secondRatio

        // Containment / fragment tier: claim is a clean fragment of a canonical line.
        if exactHit == nil && (!claimClean.isEmpty || !claimTN.isEmpty) {
            let needle = isG ? claimClean : claimTN
            if !needle.isEmpty && (GurbaniText.scalarCount(needle) >= 12 || GurbaniText.wordCount(needle) >= 3) {
                for s in stable {
                    let hay = isG ? GurbaniText.cleanGurmukhi(s.row.gurmukhi) : s.row.translitNorm
                    if hay != needle && " \(hay) ".contains(" \(needle) ") {   // whole line ≠ fragment
                        // Python's VERIFIED_PARTIAL distance_details carries only {note, fragment_len}
                        // — no best/second/gap/candidates_scored — so those stay nil here.
                        return Inter(verdict: "VERIFIED_PARTIAL", confidence: 0.95,
                                     matchedLineId: s.rid, bestRow: s.row, bestRatio: nil,
                                     secondRatio: nil, gap: nil, candidatesScored: nil,
                                     note: "claim is a fragment of this full line")
                    }
                }
            }
        }

        let verdict: String
        let confidence: Double
        if exactHit != nil {
            verdict = "VERIFIED_EXACT"; confidence = 1.0
        } else if bestRatio >= threshExact {
            verdict = "VERIFIED"; confidence = bestRatio
        } else if bestRatio >= threshProbable {
            verdict = (secondRatio >= threshAmbig && gap < threshGap) ? "AMBIGUOUS" : "PROBABLE"
            confidence = bestRatio
        } else {
            verdict = "NOT_FOUND"; confidence = 0.0
        }

        let isNF = verdict == "NOT_FOUND"
        return Inter(verdict: verdict, confidence: confidence,
                     matchedLineId: isNF ? nil : stable[0].rid, bestRow: isNF ? nil : stable[0].row,
                     bestRatio: bestRatio, secondRatio: secondRatio, gap: gap,
                     candidatesScored: stable.count, note: nil)
    }

    // MARK: candidate search (3-stage cascades)

    private func searchGurmukhi(_ nfc: String, claimClean: String) throws -> ([Int], Int?) {
        let tokens = nfc.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // Stage 1: NFC text phrase + exact byte-match detection
        var rows = try source.ftsRowids(FTSQuery.phrase(tokens, column: "text"), limit: candidateLimit)
        var exact: Int? = nil
        for rid in rows {
            if let row = try source.fetchLine(rid), GurbaniText.cleanGurmukhi(row.gurmukhi) == claimClean {
                exact = rid; break
            }
        }
        if !rows.isEmpty { return (rows, exact) }
        // Stage 2: skeleton phrase
        let sk = GurbaniText.skeletonize(nfc).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if !sk.isEmpty {
            rows = try source.ftsRowids(FTSQuery.phrase(sk, column: "skeleton"), limit: candidateLimit)
            if !rows.isEmpty { return (rows, nil) }
        }
        // Stage 3: skeleton OR
        if !sk.isEmpty {
            rows = try source.ftsRowids(FTSQuery.or(sk, column: "skeleton"), limit: candidateLimit)
            if !rows.isEmpty { return (rows, nil) }
        }
        return ([], nil)
    }

    private func searchRoman(_ claim: String) throws -> ([Int], Int?) {
        let claimLower = claim.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = claimLower.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // Stage 1: translit phrase + exact spelling detection
        var rows = try source.ftsRowids(FTSQuery.phrase(tokens, column: "translit"), limit: candidateLimit)
        var exact: Int? = nil
        for rid in rows {
            if let row = try source.fetchLine(rid),
               row.translit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == claimLower {
                exact = rid; break
            }
        }
        if !rows.isEmpty { return (rows, exact) }
        // Stage 2: translit_norm phrase
        let tn = tokens.map { RomanNorm.fold($0) }
        rows = try source.ftsRowids(FTSQuery.phrase(tn, column: "translit_norm"), limit: candidateLimit)
        if !rows.isEmpty { return (rows, nil) }
        // Stage 3: translit_norm OR
        rows = try source.ftsRowids(FTSQuery.or(tn, column: "translit_norm"), limit: candidateLimit)
        return (rows, nil)
    }
}
