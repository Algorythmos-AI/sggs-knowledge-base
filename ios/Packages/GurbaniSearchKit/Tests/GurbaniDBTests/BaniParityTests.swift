import XCTest
import CryptoKit
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// Parity gate for the Nitnem bani registry vs Python serve.py (/api/banis, /api/bani),
/// against the bundled iOS DB. Pinned by contract/golden_banis.ndjson: every bani+variant's
/// line sequence (seq, group, pointer, header, source) and a SHA-256 of its concatenated
/// Gurmukhi — so any drift in the registry OR in the non-SGGS text fails here, never on a
/// user's phone. Also pins the invariants the app relies on (Japji == lines 1…385, English
/// never on an extra line, citation strings).
final class BaniParityTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private func db() throws -> SQLiteCandidateSource {
        let path = repoRoot().appendingPathComponent("ios/Resources/sggs-ios.sqlite").path
        guard FileManager.default.fileExists(atPath: path) else { throw XCTSkip("iOS DB missing (git lfs pull)") }
        return try SQLiteCandidateSource(path: path)
    }

    private struct ListRow: Decodable {
        let key: String; let variant: String; let is_default: Int; let title_gm: String; let title_en: String
        let category: String; let order_no: Int; let n_lines: Int; let n_groups: Int; let has_extra: Int
        let estimated_minutes: Int?; let description_en: String?; let source_label: String
    }
    private struct ListPayload: Decodable { let available: Bool; let banis: [ListRow] }
    private struct Row: Decodable {
        let seq: Int; let group: Int; let lineId: Int?; let extraId: Int?; let isHeader: Int; let source: String
        init(from d: Decoder) throws {
            var c = try d.unkeyedContainer()
            seq = try c.decode(Int.self); group = try c.decode(Int.self)
            lineId = try c.decodeIfPresent(Int.self); extraId = try c.decodeIfPresent(Int.self)
            isHeader = try c.decode(Int.self); source = try c.decode(String.self)
        }
    }
    private struct Vector: Decodable {
        let kind: String
        let key: String?; let variant: String?; let resolved_variant: String?; let variants: [String]?
        let n_lines: Int?; let ang_first: Int?; let ang_last: Int?; let gurmukhi_sha256: String?
        let rows: [Row]?; let status: Int?
        let payload: ListPayload?
    }

    private func vectors() throws -> [Vector] {
        let url = repoRoot().appendingPathComponent("contract/golden_banis.ndjson")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("golden_banis.ndjson missing") }
        let dec = JSONDecoder()
        return try String(decoding: data, as: UTF8.self).split(separator: "\n").map { try dec.decode(Vector.self, from: Data($0.utf8)) }
    }

    func testCapabilityBit() throws {
        XCTAssertTrue(try db().detectCapabilities().hasBanis)
    }

    func testListParity() throws {
        let src = try db()
        guard let v = try vectors().first(where: { $0.kind == "list" }), let payload = v.payload else { return XCTFail("no list vector") }
        let list = src.fetchBanis()
        XCTAssertEqual(list.available, payload.available)
        XCTAssertEqual(list.banis.count, payload.banis.count)
        for (mine, theirs) in zip(list.banis, payload.banis) {
            XCTAssertEqual(mine.key, theirs.key); XCTAssertEqual(mine.variant, theirs.variant)
            XCTAssertEqual(mine.isDefault, theirs.is_default != 0)
            XCTAssertEqual(mine.titleGm, theirs.title_gm); XCTAssertEqual(mine.titleEn, theirs.title_en)
            XCTAssertEqual(mine.category.rawValue, theirs.category)
            XCTAssertEqual(mine.nLines, theirs.n_lines); XCTAssertEqual(mine.nGroups, theirs.n_groups)
            XCTAssertEqual(mine.hasExtra, theirs.has_extra != 0)
            XCTAssertEqual(mine.estimatedMinutes, theirs.estimated_minutes)
            XCTAssertEqual(mine.sourceLabel, theirs.source_label)
        }
    }

    func testEveryBaniParity() throws {
        let src = try db()
        var checked = 0
        for v in try vectors() where v.kind == "bani" {
            guard let key = v.key, let rows = v.rows else { continue }
            guard let bani = src.fetchBani(key: key, variant: v.variant ?? "") else {
                XCTFail("\(key)/\(v.variant ?? "") not found"); continue
            }
            XCTAssertEqual(bani.summary.variant, v.resolved_variant, key)
            XCTAssertEqual(bani.variants, v.variants ?? [], key)
            XCTAssertEqual(bani.lines.count, v.n_lines, key)
            XCTAssertEqual(bani.angFirst, v.ang_first, key); XCTAssertEqual(bani.angLast, v.ang_last, key)
            var h = SHA256()
            for (mine, theirs) in zip(bani.lines, rows) {
                XCTAssertEqual(mine.seq, theirs.seq, key); XCTAssertEqual(mine.lineGroup, theirs.group, key)
                XCTAssertEqual(mine.isHeader, theirs.isHeader != 0, "\(key) seq \(mine.seq)")
                XCTAssertEqual(mine.citation.source, theirs.source, "\(key) seq \(mine.seq)")
                switch mine.citation {
                case .sggs(_, let lineId, _): XCTAssertEqual(lineId, theirs.lineId, "\(key) seq \(mine.seq)")
                case .dasam(_, let extraId), .ardaas(let extraId): XCTAssertEqual(extraId, theirs.extraId, "\(key) seq \(mine.seq)")
                }
                h.update(data: Data(mine.gurmukhi.utf8)); h.update(data: Data("\n".utf8))
            }
            let digest = h.finalize().map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(digest, v.gurmukhi_sha256, "\(key): Gurmukhi drifted from the contract")
            checked += 1
        }
        XCTAssertGreaterThanOrEqual(checked, 22)
    }

    func testMissesMatchServer() throws {
        let src = try db()
        for v in try vectors() where v.kind == "miss" {
            let found = src.fetchBani(key: v.key ?? "", variant: v.variant ?? "") != nil
            XCTAssertEqual(found, v.status == 200, "\(v.key ?? "")/\(v.variant ?? "")")
        }
    }

    func testInvariantsTheAppReliesOn() throws {
        let src = try db()
        let japji = try XCTUnwrap(src.fetchBani(key: "japji"))
        XCTAssertEqual(japji.lines.compactMap { $0.citation.lineId }, Array(1...385))
        XCTAssertTrue(japji.lines[0].gurmukhi.hasPrefix("ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ"))
        XCTAssertEqual(japji.citationRange, "Sri Guru Granth Sahib Ji · Ang 1–8")
        XCTAssertEqual(japji.lines[0].citation.citation, "Sri Guru Granth Sahib Ji · Ang 1")

        let rehras = try XCTUnwrap(src.fetchBani(key: "rehras"))
        XCTAssertEqual(rehras.summary.variant, "sgpc")
        let extra = rehras.lines.filter { !$0.citation.isSGGS }
        XCTAssertFalse(extra.isEmpty)
        XCTAssertTrue(extra.allSatisfy { $0.en == nil && $0.citation.lineId == nil })
        XCTAssertTrue(extra.allSatisfy { $0.citation.citation.hasPrefix("Sri Dasam Granth") || $0.citation.citation == "Ardaas" })
        let taksal = try XCTUnwrap(src.fetchBani(key: "rehras", variant: "taksal"))
        XCTAssertGreaterThan(taksal.lines.count, rehras.lines.count)

        let jaap = try XCTUnwrap(src.fetchBani(key: "jaap"))
        XCTAssertNil(jaap.angFirst)
        XCTAssertEqual(jaap.citationRange, "Sri Dasam Granth · separate layer")
        XCTAssertNil(src.fetchBani(key: "japji", variant: "taksal"))
        XCTAssertNil(src.fetchBani(key: "no_such_bani"))
    }
}
