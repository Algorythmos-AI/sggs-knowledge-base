import XCTest
@testable import GurbaniDB
@testable import GurbaniSearchKit

/// The pauri / ashtapadi / salok outline is derived only from the verbatim text, so it is
/// pinned against the real bundled DB (counts) and proven never to touch scripture (fidelity).
final class BaniOutlineTests: XCTestCase {

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

    private func bani(_ key: String, variant: String = "") throws -> Bani {
        try XCTUnwrap(try db().fetchBani(key: key, variant: variant), key)
    }

    // MARK: real-DB counts

    func testJapji() throws {
        let s = BaniOutline.sections(for: try bani("japji"))
        XCTAssertEqual(s.filter { $0.kind == .pauri }.count, 38)
        XCTAssertEqual(s.filter { $0.kind == .salok }.count, 2)
        XCTAssertEqual(s.first?.kind, .salok)
        XCTAssertEqual(s.last?.kind, .salok)
        // pauris are 1…38 in order, and each starts after the previous section
        let pauris = s.filter { $0.kind == .pauri }
        XCTAssertEqual(pauris.map(\.number), Array(1...38))
        for section in s { XCTAssertLessThanOrEqual(section.startSeq, section.endSeq) }
        // jumping to pauri 1 lands after the opening salok
        XCTAssertEqual(pauris.first?.startSeq, s.first!.endSeq + 1)
    }

    func testAnand() throws {
        let s = BaniOutline.sections(for: try bani("anand"))
        XCTAssertEqual(s.count, 40)
        XCTAssertEqual(s.map(\.number), Array(1...40))
        XCTAssertTrue(s.allSatisfy { $0.kind == .pauri })
    }

    func testSukhmani() throws {
        let s = BaniOutline.sections(for: try bani("sukhmani"))
        XCTAssertEqual(s.count, 24)
        XCTAssertEqual(s.map(\.number), Array(1...24))
        XCTAssertTrue(s.allSatisfy { $0.kind == .ashtapadi })
        // each ashtapadi opens on the ਸਲੋਕੁ header (start < end)
        XCTAssertTrue(s.allSatisfy { $0.startSeq < $0.endSeq })
    }

    func testAsaDiVaar() throws {
        let s = BaniOutline.sections(for: try bani("asa_di_vaar", variant: "kirtan"))
        XCTAssertEqual(s.filter { $0.kind == .pauri }.count, 24)
        XCTAssertEqual(s.filter { $0.kind == .pauri }.map(\.number), Array(1...24))
    }

    func testJaapVerses() throws {
        let s = BaniOutline.sections(for: try bani("jaap"))
        XCTAssertGreaterThanOrEqual(s.count, 190)
        XCTAssertTrue(s.allSatisfy { $0.kind == .verse && $0.derivedFromText })
        XCTAssertEqual(s.first?.number, 1)
    }

    func testChaupaiKeepsPrintedNumbers() throws {
        let s = BaniOutline.sections(for: try bani("chaupai"))
        // Chaupai carries the source's own numbering (starts at ੩੭੭), never renumbered to 1
        XCTAssertGreaterThanOrEqual(s.first?.number ?? 0, 300)
        XCTAssertTrue(s.allSatisfy { $0.kind == .verse })
        // strictly consecutive from the first
        for (i, sec) in s.enumerated() { XCTAssertEqual(sec.number, s[0].number + i) }
    }

    func testRehrasFallsBackToParts() throws {
        let s = BaniOutline.sections(for: try bani("rehras", variant: "sgpc"))
        XCTAssertFalse(s.isEmpty, "a multi-part bani should navigate by parts")
        XCTAssertTrue(s.allSatisfy { $0.kind == .part })
    }

    /// The registry stays byte-identical: outline building reads text, never rewrites it.
    func testFidelityEveryBani() throws {
        let src = try db()
        for summary in src.fetchBanis().banis {
            let b = try XCTUnwrap(src.fetchBani(key: summary.key, variant: summary.variant), summary.id)
            let before = b.lines.map(\.gurmukhi)
            _ = BaniOutline.sections(for: b)
            XCTAssertEqual(b.lines.map(\.gurmukhi), before, "\(summary.id): scripture changed")
        }
    }

    /// Every SGGS bani either has no outline or a sane one — no crash, no out-of-range seq.
    func testEveryBaniOutlineIsWellFormed() throws {
        let src = try db()
        for summary in src.fetchBanis().banis {
            let b = try XCTUnwrap(src.fetchBani(key: summary.key, variant: summary.variant))
            let s = BaniOutline.sections(for: b)
            let seqs = Set(b.lines.map(\.seq))
            for section in s {
                XCTAssertTrue(seqs.contains(section.startSeq), "\(summary.id) start \(section.startSeq)")
                XCTAssertLessThanOrEqual(section.startSeq, section.endSeq, summary.id)
            }
            // sections are ordered and non-overlapping
            for (a, c) in zip(s, s.dropFirst()) { XCTAssertLessThan(a.endSeq, c.startSeq, summary.id) }
        }
    }

    // MARK: pure gate + parsing

    func testValidityGateRejectsAHole() {
        // a Japji-shaped fixture whose middle markers skip a number → no outline
        func line(_ seq: Int, _ marker: String?, header: Bool = false) -> BaniLine {
            BaniLine(seq: seq, lineGroup: 1, gurmukhi: "x", translit: "", isHeader: header,
                     isRahao: false, markers: marker.map { [$0] } ?? [],
                     citation: .sggs(ang: 1, lineId: seq, compId: 1))
        }
        let good = fixture([line(1, "੧"), line(2, "੧"), line(3, "੨"), line(4, "੩"), line(5, "੧")], key: "japji")
        XCTAssertFalse(BaniOutline.sections(for: good).isEmpty)
        let holed = fixture([line(1, "੧"), line(2, "੧"), line(3, "੩"), line(4, "੪"), line(5, "੧")], key: "japji")
        XCTAssertTrue(BaniOutline.sections(for: holed).isEmpty, "a skipped number must yield no outline")
    }

    func testNumberParsing() {
        XCTAssertEqual(BaniOutline.gurmukhiNumber("੧"), 1)
        XCTAssertEqual(BaniOutline.gurmukhiNumber("੨੪"), 24)
        XCTAssertNil(BaniOutline.gurmukhiNumber("ਰਹਾਉ"))
        XCTAssertNil(BaniOutline.gurmukhiNumber(""))
        XCTAssertEqual(BaniOutline.trailingNumbers(inExtraText: "ਕ੍ਰਿਪਾਲੰ ਸਰੂਪੇ ॥੧॥"), ["੧"])
        XCTAssertEqual(BaniOutline.trailingNumbers(inExtraText: "ਸ੍ਵੈਯਾ ॥੧॥੨੧॥"), ["੧", "੨੧"])
        XCTAssertEqual(BaniOutline.trailingNumbers(inExtraText: "no danda here"), [])
    }

    private func fixture(_ lines: [BaniLine], key: String) -> Bani {
        Bani(summary: BaniSummary(key: key, variant: "", isDefault: true, titleGm: "x", titleEn: "x",
                                  category: .nitnemMorning, orderNo: 1, nLines: lines.count, nGroups: 1,
                                  hasExtra: false, estimatedMinutes: nil, descriptionEn: nil, sourceLabel: ""),
             variants: [], angFirst: 1, angLast: 1, lines: lines)
    }
}
