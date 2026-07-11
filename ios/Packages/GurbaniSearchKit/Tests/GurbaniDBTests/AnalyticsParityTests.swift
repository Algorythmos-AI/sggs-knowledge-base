import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Parity gate for the Insight-Engine deep reads (author profile / resonance / progression /
/// vaars) vs Python serve.py, against the shipped iOS DB. Pinned by
/// contract/golden_analytics.ndjson — the progression vectors (bins {8,36,80} × top {2,7})
/// exist specifically to catch float/int divergence in the on-the-fly binning port.
final class AnalyticsParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private struct ProgressionPayload: Decodable {
        let raag: String; let roman: String?; let n_lines: Int?; let bins: Int
        let concepts: [String]; let series: [String: [Int]]?
        let lines_per_bin: [Int]?; let ang_axis: [Int]?
    }
    private struct TopThemeJSON: Decodable { let concept: String; let lift: Double }
    private struct StylometryJSON: Decodable {
        let author: String; let n_lines: Int; let n_shabads: Int; let n_raags: Int
        let n_tokens: Int; let mattr_100: Double; let hapax_pct: Double
        let avg_words_line: Double; let avg_lines_shabad: Double
        let top_themes: [TopThemeJSON]?; let is_reliable: Int
    }
    private struct AxisJSON: Decodable {
        let concept: String; let n_tagged: Int; let entity_rate: Double
        let corpus_rate: Double; let lift: Double
    }
    private struct TermJSON: Decodable { let term: String; let z_score: Double; let rank: Int }
    private struct AuthorPayload: Decodable {
        let author: String; let stylometry: StylometryJSON?
        let theme_fingerprint: [AxisJSON]; let distinctive_terms: [TermJSON]
    }
    private struct ResonancePayload: Decodable {
        struct Node: Decodable { let author: String; let n_lines: Int; let first_ang: Int }
        struct Edge: Decodable { let source: String; let target: String; let edges: Int
            let mean_score: Double; let lift: Double }
        let nodes: [Node]; let edges: [Edge]
    }
    private struct VaarsPayload: Decodable {
        struct V: Decodable {
            let vaar_id: Int; let raag: String?; let roman: String?; let first_ang: Int
            let last_ang: Int; let n_pauris: Int; let n_saloks: Int
            let pauri_author: String?; let salok_authors: [String]; let cross_author: Int
            let title: String?
        }
        let vaars: [V]
    }
    private struct VaarPayload: Decodable {
        struct U: Decodable { let seq: Int; let kind: String; let author: String?
            let n_lines: Int; let pauri_no: Int?; let first_line_id: Int; let ang: Int
            let theme: String? }
        let vaar: VaarsPayload.V?
        let units: [U]
    }
    private struct Vector: Decodable {
        let kind: String
        let raag: String?
        let bins_req: Int?
        let top_req: Int?
        let author: String?
        let id: Int?
        let min_ppmi: String?
        let limit: String?
        let pairs: [String]?
        let ppmi: [Double]?
        let jaccard: [Double]?
        let shabad_count: [Int]?
        let payload: TimingJSONBox?
    }
    /// Round-trips the arbitrary payload for kind-specific decoding.
    private struct TimingJSONBox: Decodable {
        let raw: Data
        init(from decoder: Decoder) throws {
            let v = try decoder.singleValueContainer().decode(JSONAny.self)
            raw = try JSONEncoder().encode(v)
        }
    }
    private enum JSONAny: Codable {
        case null, bool(Bool), int(Int), double(Double), string(String)
        case array([JSONAny]), object([String: JSONAny])
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if c.decodeNil() { self = .null }
            else if let b = try? c.decode(Bool.self) { self = .bool(b) }
            else if let i = try? c.decode(Int.self) { self = .int(i) }
            else if let x = try? c.decode(Double.self) { self = .double(x) }
            else if let s = try? c.decode(String.self) { self = .string(s) }
            else if let a = try? c.decode([JSONAny].self) { self = .array(a) }
            else { self = .object(try c.decode([String: JSONAny].self)) }
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

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= max(1e-9, abs(b) * 1e-9) }

    func testAnalyticsParity() throws {
        let root = repoRoot()
        let dbPath = root.appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw XCTSkip("ios/Resources/sggs-ios.sqlite missing — run pipeline/build_ios_db.py")
        }
        let rows = try String(contentsOf: root.appendingPathComponent("contract/golden_analytics.ndjson"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let db = try SQLiteCandidateSource(path: dbPath)
        let dec = JSONDecoder()
        var failures: [String] = []
        var asserted = 0

        for row in rows {
            let v = try dec.decode(Vector.self, from: Data(row.utf8))
            switch v.kind {
            case "progression":
                asserted += 1
                let want = try dec.decode(ProgressionPayload.self, from: v.payload!.raw)
                guard let got = db.progression(raag: v.raag!, bins: v.bins_req!, top: v.top_req!) else {
                    failures.append("progression \(v.raag!): nil"); continue
                }
                let tag = "progression \(want.roman ?? want.raag) bins=\(v.bins_req!) top=\(v.top_req!)"
                if got.bins != want.bins || got.nLines != (want.n_lines ?? 0) { failures.append("\(tag): shape") }
                if got.concepts != want.concepts { failures.append("\(tag): concepts \(got.concepts) != \(want.concepts)") }
                if got.series != (want.series ?? [:]) { failures.append("\(tag): series differ") }
                if got.linesPerBin != (want.lines_per_bin ?? []) { failures.append("\(tag): lines_per_bin") }
                if got.angAxis != (want.ang_axis ?? []) { failures.append("\(tag): ang_axis \(got.angAxis.prefix(6)) != \((want.ang_axis ?? []).prefix(6))") }
            case "author", "author12":
                asserted += 1
                let want = try dec.decode(AuthorPayload.self, from: v.payload!.raw)
                let got = db.authorProfile(v.author!, full: v.kind == "author")
                let tag = "\(v.kind) \(v.author!)"
                if let ws = want.stylometry {
                    guard let gs = got.stylometry else { failures.append("\(tag): stylometry nil"); continue }
                    if gs.nLines != ws.n_lines || gs.nTokens != ws.n_tokens
                        || !close(gs.mattr100, ws.mattr_100) || !close(gs.hapaxPct, ws.hapax_pct)
                        || !close(gs.avgWordsLine, ws.avg_words_line)
                        || !close(gs.avgLinesShabad, ws.avg_lines_shabad)
                        || gs.topThemes.map({ $0.concept }) != (ws.top_themes ?? []).map({ $0.concept })
                        || zip(gs.topThemes, ws.top_themes ?? []).contains(where: { !close($0.lift, $1.lift) })
                        || gs.isReliable != (ws.is_reliable != 0) {
                        failures.append("\(tag): stylometry differs")
                    }
                }
                if got.fingerprint.count != want.theme_fingerprint.count {
                    failures.append("\(tag): fp count \(got.fingerprint.count) != \(want.theme_fingerprint.count)")
                } else {
                    for (g, w) in zip(got.fingerprint, want.theme_fingerprint)
                    where g.concept != w.concept || g.nTagged != w.n_tagged
                        || !close(g.entityRate, w.entity_rate) || !close(g.corpusRate, w.corpus_rate)
                        || !close(g.lift, w.lift) {
                        failures.append("\(tag): axis \(w.concept) differs")
                    }
                }
                if got.distinctiveTerms.map({ $0.term }) != want.distinctive_terms.map({ $0.term }) {
                    failures.append("\(tag): terms differ")
                }
            case "resonance":
                asserted += 1
                let want = try dec.decode(ResonancePayload.self, from: v.payload!.raw)
                // both recorded calls: defaults and (500, 1.5, 12) — infer from node threshold
                let tight = want.nodes.allSatisfy { $0.n_lines >= 500 }
                let got = tight ? db.resonance(minLines: 500, minLift: 1.5, minEdges: 12) : db.resonance()
                if got.nodes.map({ $0.author }) != want.nodes.map({ $0.author }) {
                    failures.append("resonance: nodes differ")
                }
                if got.edges.count != want.edges.count {
                    failures.append("resonance: edge count \(got.edges.count) != \(want.edges.count)")
                } else {
                    for (g, w) in zip(got.edges, want.edges)
                    where g.source != w.source || g.target != w.target || g.edges != w.edges
                        || !close(g.meanScore, w.mean_score) || !close(g.lift, w.lift) {
                        failures.append("resonance: edge \(w.source)→\(w.target) differs")
                    }
                }
            case "vaars":
                asserted += 1
                let want = try dec.decode(VaarsPayload.self, from: v.payload!.raw)
                let got = db.vaars()
                if got.count != want.vaars.count { failures.append("vaars: count"); continue }
                for (g, w) in zip(got, want.vaars)
                where g.vaarId != w.vaar_id || g.raag != w.raag || g.roman != w.roman
                    || g.firstAng != w.first_ang || g.lastAng != w.last_ang
                    || g.nPauris != w.n_pauris || g.nSaloks != w.n_saloks
                    || g.pauriAuthor != w.pauri_author || g.salokAuthors != w.salok_authors
                    || g.crossAuthor != (w.cross_author != 0) || g.title != w.title {
                    failures.append("vaars: vaar \(w.vaar_id) differs")
                }
            case "vaar":
                asserted += 1
                let want = try dec.decode(VaarPayload.self, from: v.payload!.raw)
                let got = db.vaar(id: v.id!)
                if (got.vaar == nil) != (want.vaar == nil) { failures.append("vaar \(v.id!): head presence") }
                if got.units.count != want.units.count {
                    failures.append("vaar \(v.id!): units \(got.units.count) != \(want.units.count)")
                } else {
                    for (g, w) in zip(got.units, want.units)
                    where g.seq != w.seq || g.kind != w.kind || g.author != w.author
                        || g.nLines != w.n_lines || g.pauriNo != w.pauri_no
                        || g.firstLineId != w.first_line_id || g.ang != w.ang || g.theme != w.theme {
                        failures.append("vaar \(v.id!): unit seq \(w.seq) differs")
                    }
                }
            case "theme_network":
                asserted += 1
                let lim = Int(v.limit ?? "40") ?? 40
                let mp = Double(v.min_ppmi ?? "0.7") ?? 0.7
                let got = (try? db.themeNetwork(minPPMI: mp, limit: lim)) ?? []
                if got.map({ "\($0.source)~\($0.target)" }) != (v.pairs ?? []) {
                    failures.append("theme_network(\(mp),\(lim)): pairs differ (\(got.count) vs \(v.pairs?.count ?? -1))")
                }
                let gp = got.map { ($0.ppmi * 1e6).rounded() / 1e6 }
                if zip(gp, v.ppmi ?? []).contains(where: { abs($0 - $1) > 1e-5 }) { failures.append("theme_network: ppmi") }
                let gj = got.map { ($0.jaccard * 1e6).rounded() / 1e6 }
                if zip(gj, v.jaccard ?? []).contains(where: { abs($0 - $1) > 1e-5 }) { failures.append("theme_network: jaccard") }
                if got.map({ $0.shabadCount }) != (v.shabad_count ?? []) { failures.append("theme_network: shabad_count") }
            case "authors_list":
                asserted += 1   // covered field-wise by ReaderParityTests' authors vector; presence only
            default:
                failures.append("unknown analytics vector kind \(v.kind)")
            }
        }
        XCTAssertGreaterThan(asserted, 50, "expected the full analytics contract")
        if !failures.isEmpty {
            XCTFail("analytics parity failures: \(failures.count)/\(asserted)\n" + failures.prefix(20).joined(separator: "\n"))
        }
    }
}
