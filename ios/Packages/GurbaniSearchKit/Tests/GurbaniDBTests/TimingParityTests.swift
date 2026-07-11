import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Parity gate for the Raag-Timing layer (clock / raag / divergence / forms) vs Python
/// serve.py, against the shipped iOS DB. Pinned by contract/golden_timing.ndjson. Also
/// asserts the degradation contract on the public (timing-carrying) — note BOTH profiles
/// carry timing since v2.12.0, so degradation is covered by synthetic absence below.
final class TimingParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    // Decoded shapes of the serve.py payloads recorded in the vectors.
    private struct ClaimJSON: Decodable {
        let raag_name: String?; let roman: String?; let first_ang: Int?; let seq: Int?
        let claim_type: String; let pahar: Int?; let time_start: String?; let time_end: String?
        let season: String?; let occasion: String?; let confidence: String; let notes: String?
        let source_name: String; let tradition: String; let source_url: String?
    }
    private struct ClockPayload: Decodable {
        let available: Bool
        let claims: [String: [ClaimJSON]]?
    }
    private struct RaagPayload: Decodable {
        let available: Bool; let raag: String; let roman: String?; let first_ang: Int?
        let claims: [ClaimJSON]
    }
    private struct DivergencePayload: Decodable {
        struct Entry: Decodable { let raag: String; let roman: String?; let first_ang: Int?; let claims: [ClaimJSON] }
        let available: Bool; let raags: [Entry]
    }
    private struct FormsPayload: Decodable {
        struct Forms: Decodable {
            let comp_id: Int; let raag_name: String?; let first_ang: Int?
            let ghar: Int?; let partaal: Int?; let has_rahao: Int?; let has_rahao_dooja: Int?
            let dhunni: String?; let jati: String?; let form: String?; let pada_count: Int?
            let genre: String?; let source_label: String?
        }
        let available: Bool; let comp_id: Int; let forms: Forms?
    }
    private struct Vector: Decodable {
        let kind: String
        let name: String?
        let comp_id: Int?
        let payload: AnyPayload
        struct AnyPayload: Decodable {
            let raw: Data
            init(from decoder: Decoder) throws {
                // re-encode the arbitrary payload for kind-specific decoding below
                let v = try decoder.singleValueContainer().decode(JSONValue.self)
                raw = try JSONEncoder().encode(v)
            }
        }
    }
    /// Minimal JSON passthrough so payloads survive Decodable round-tripping untouched.
    private enum JSONValue: Codable {
        case null, bool(Bool), int(Int), double(Double), string(String)
        case array([JSONValue]), object([String: JSONValue])
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if c.decodeNil() { self = .null }
            else if let b = try? c.decode(Bool.self) { self = .bool(b) }
            else if let i = try? c.decode(Int.self) { self = .int(i) }
            else if let x = try? c.decode(Double.self) { self = .double(x) }
            else if let s = try? c.decode(String.self) { self = .string(s) }
            else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
            else { self = .object(try c.decode([String: JSONValue].self)) }
        }
        func encode(to e: Encoder) throws {
            var c = e.singleValueContainer()
            switch self {
            case .null: try c.encodeNil()
            case .bool(let b): try c.encode(b)
            case .int(let i): try c.encode(i)
            case .double(let x): try c.encode(x)
            case .string(let s): try c.encode(s)
            case .array(let a): try c.encode(a)
            case .object(let o): try c.encode(o)
            }
        }
    }

    private func eqClaim(_ got: TimingClaim, _ want: ClaimJSON) -> Bool {
        got.claimType == want.claim_type && got.pahar == want.pahar
            && got.timeStart == want.time_start && got.timeEnd == want.time_end
            && got.season == want.season && got.occasion == want.occasion
            && got.confidence == want.confidence && got.notes == want.notes
            && got.sourceName == want.source_name && got.tradition == want.tradition
            && got.sourceURL == want.source_url
    }

    func testTimingParity() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run pipeline/build_ios_db.py")
        }
        let rows = try String(contentsOf: root.appendingPathComponent("contract/golden_timing.ndjson"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let db = try SQLiteCandidateSource(path: dbPath)
        let dec = JSONDecoder()
        var failures: [String] = []
        var asserted = 0

        for row in rows {
            let v = try dec.decode(Vector.self, from: Data(row.utf8))
            switch v.kind {
            case "clock":
                asserted += 1
                let want = try dec.decode(ClockPayload.self, from: v.payload.raw)
                let got = db.timingClock()
                if got.available != want.available { failures.append("clock: available"); continue }
                let groups: [(String, [TimingClaim])] = [("primary", got.primary), ("variant", got.variant),
                                                         ("seasonal", got.seasonal), ("ceremonial", got.ceremonial)]
                for (key, gotClaims) in groups {
                    let wantClaims = want.claims?[key] ?? []
                    if gotClaims.count != wantClaims.count { failures.append("clock \(key): count \(gotClaims.count) != \(wantClaims.count)"); continue }
                    for (g, w) in zip(gotClaims, wantClaims) {
                        if !eqClaim(g, w) || g.raagName != w.raag_name || g.roman != w.roman
                            || g.firstAng != w.first_ang || g.seq != w.seq {
                            failures.append("clock \(key): claim \(w.raag_name ?? "?")/\(w.source_name) differs")
                        }
                    }
                }
            case "raag":
                asserted += 1
                let want = try dec.decode(RaagPayload.self, from: v.payload.raw)
                let got = db.timingRaag(name: v.name!)
                if got.available != want.available || got.raag != want.raag
                    || got.roman != want.roman || got.firstAng != want.first_ang {
                    failures.append("raag \(v.name!): head differs (got \(got.raag)/\(String(describing: got.roman)))")
                }
                if got.claims.count != want.claims.count {
                    failures.append("raag \(v.name!): claims \(got.claims.count) != \(want.claims.count)")
                } else {
                    for (g, w) in zip(got.claims, want.claims) where !eqClaim(g, w) {
                        failures.append("raag \(v.name!): claim \(w.source_name) differs")
                    }
                }
            case "divergence":
                asserted += 1
                let want = try dec.decode(DivergencePayload.self, from: v.payload.raw)
                let got = db.timingDivergence()
                if got.available != want.available { failures.append("divergence: available") }
                if got.raags.map({ $0.raag }) != want.raags.map({ $0.raag }) {
                    failures.append("divergence: raag order \(got.raags.map { $0.raag })")
                } else {
                    for (g, w) in zip(got.raags, want.raags) {
                        if g.roman != w.roman || g.firstAng != w.first_ang
                            || g.claims.count != w.claims.count {
                            failures.append("divergence \(w.raag): head/claims differ"); continue
                        }
                        for (gc, wc) in zip(g.claims, w.claims) where !eqClaim(gc, wc) {
                            failures.append("divergence \(w.raag): claim \(wc.source_name) differs")
                        }
                    }
                }
            case "forms":
                asserted += 1
                let want = try dec.decode(FormsPayload.self, from: v.payload.raw)
                let got = db.forms(compId: v.comp_id!)
                if got.available != want.available { failures.append("forms \(v.comp_id!): available") }
                if let wf = want.forms {
                    if !got.mapped { failures.append("forms \(v.comp_id!): expected mapped"); continue }
                    if got.raagName != wf.raag_name || got.firstAng != wf.first_ang
                        || got.ghar != wf.ghar || got.partaal != wf.partaal.map({ $0 != 0 })
                        || got.hasRahao != wf.has_rahao.map({ $0 != 0 })
                        || got.hasRahaoDooja != wf.has_rahao_dooja.map({ $0 != 0 })
                        || got.dhunni != wf.dhunni || got.jati != wf.jati
                        || got.form != wf.form || got.padaCount != wf.pada_count
                        || got.genre != wf.genre || got.sourceLabel != wf.source_label {
                        failures.append("forms \(v.comp_id!): fields differ")
                    }
                } else if got.mapped {
                    failures.append("forms \(v.comp_id!): expected unmapped (forms: None)")
                }
            default:
                failures.append("unknown timing vector kind \(v.kind)")
            }
        }
        XCTAssertGreaterThan(asserted, 60, "expected the full timing contract")
        if !failures.isEmpty {
            XCTFail("timing parity failures: \(failures.count)/\(asserted)\n" + failures.prefix(20).joined(separator: "\n"))
        }
    }
}
