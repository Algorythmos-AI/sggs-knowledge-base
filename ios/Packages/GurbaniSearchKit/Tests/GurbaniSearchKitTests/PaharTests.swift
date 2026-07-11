import XCTest
@testable import GurbaniSearchKit

/// Cross-language pahar contract: every vector in contract/golden_pahar.ndjson (emitted from
/// the REAL pahar.js under TZ=UTC by frontend/scripts/gen-pahar-vectors.mjs) must reproduce
/// exactly — fixed clock for every minute of the day, windows/labels/ranges/fmt12, NOAA
/// suntimes incl. DST/southern-hemisphere/polar tuples, solar sweeps, boundary countdowns.
/// Plus property tests the vectors can't express: totality and no-gap/no-overlap tiling.
final class PaharTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("contract/_meta.json").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
    }

    private struct Vector: Decodable {
        let kind: String
        let m: Int?
        let pahar: Int?
        let p: Int?
        let start: Int?
        let end: Int?
        let label: String?
        let range: String?
        let `in`: String?
        let out: String?
        let y: Int?
        let mo: Int?
        let d: Int?
        let lat: Double?
        let lon: Double?
        let tz: Int?
        let sunrise: Int?
        let sunset: Int?
        let polar: Bool?
        let mode: String?
        let nextPahar: Int?
        let minutes: Int?
    }

    func testGoldenPaharVectors() throws {
        let url = repoRoot().appendingPathComponent("contract/golden_pahar.ndjson")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("golden_pahar.ndjson missing — run `TZ=UTC node frontend/scripts/gen-pahar-vectors.mjs`")
        }
        let rows = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let dec = JSONDecoder()
        var failures: [String] = []
        var counts: [String: Int] = [:]

        for row in rows {
            let v = try dec.decode(Vector.self, from: Data(row.utf8))
            counts[v.kind, default: 0] += 1
            switch v.kind {
            case "fixed":
                if Pahar.paharFromMinutes(v.m!) != v.pahar! {
                    failures.append("fixed m=\(v.m!): got \(Pahar.paharFromMinutes(v.m!)) want \(v.pahar!)")
                }
            case "window":
                let w = Pahar.window(v.p!)
                if w.start != v.start! || w.end != v.end! { failures.append("window p=\(v.p!)") }
            case "label":
                if Pahar.label(v.p!) != v.label! { failures.append("label p=\(v.p!)") }
            case "range":
                if Pahar.range(v.p!) != v.range! {
                    failures.append("range p=\(v.p!): got \(Pahar.range(v.p!)) want \(v.range!)")
                }
            case "fmt12":
                if Pahar.fmt12(v.in!) != v.out! {
                    failures.append("fmt12 \(v.in!): got \(Pahar.fmt12(v.in!)) want \(v.out!)")
                }
            case "suntimes":
                let s = Pahar.sunTimes(year: v.y!, month: v.mo!, day: v.d!,
                                       lat: v.lat!, lon: v.lon!, tzOffsetMin: v.tz!)
                if s.polar != v.polar! || s.sunrise != v.sunrise || s.sunset != v.sunset {
                    failures.append("suntimes \(v.y!)-\(v.mo!)-\(v.d!) lat=\(v.lat!): got (\(String(describing: s.sunrise)),\(String(describing: s.sunset)),\(s.polar)) want (\(String(describing: v.sunrise)),\(String(describing: v.sunset)),\(v.polar!))")
                }
            case "solar":
                if Pahar.paharSolar(v.m!, sunrise: v.sunrise!, sunset: v.sunset!) != v.pahar! {
                    failures.append("solar m=\(v.m!) sr=\(v.sunrise!) ss=\(v.sunset!)")
                }
            case "solar_window":
                let w = Pahar.solarWindow(v.p!, sunrise: v.sunrise!, sunset: v.sunset!)
                if w.start != v.start! || w.end != v.end! {
                    failures.append("solar_window p=\(v.p!): got (\(w.start),\(w.end)) want (\(v.start!),\(v.end!))")
                }
            case "boundary":
                let b = Pahar.nextBoundary(v.m!, mode: v.mode!, sunrise: v.sunrise ?? 0, sunset: v.sunset ?? 0)
                if b.nextPahar != v.nextPahar! || b.minutes != v.minutes! {
                    failures.append("boundary mode=\(v.mode!) m=\(v.m!): got (\(b.nextPahar),\(b.minutes)) want (\(v.nextPahar!),\(v.minutes!))")
                }
            default:
                failures.append("unknown vector kind \(v.kind)")
            }
        }
        XCTAssertGreaterThan(rows.count, 2000, "expected the full pahar contract")
        if !failures.isEmpty {
            XCTFail("pahar parity failures: \(failures.count)/\(rows.count) — kinds \(counts)\n"
                    + failures.prefix(20).joined(separator: "\n"))
        }
    }

    /// Property: the fixed clock is TOTAL — every minute of the day belongs to exactly one
    /// pahar, and the windows tile [0, 1440) with no gap or overlap.
    func testFixedClockTotalityAndTiling() {
        for m in 0..<1440 {
            let p = Pahar.paharFromMinutes(m)
            XCTAssertTrue((1...8).contains(p), "minute \(m) → pahar \(p) out of range")
            let w = Pahar.window(p)
            let inWindow = w.start < w.end ? (m >= w.start && m < w.end) : (m >= w.start || m < w.end)
            XCTAssertTrue(inWindow, "minute \(m) not inside its own pahar's window")
        }
        let total = (1...8).map { p -> Int in
            let w = Pahar.window(p); return ((w.end - w.start) % 1440 + 1440) % 1440
        }.reduce(0, +)
        XCTAssertEqual(total, 1440, "fixed windows must tile the day exactly")
    }

    /// Property: solar pahars are also total for any plausible sunrise/sunset pair.
    func testSolarTotality() {
        for (sr, ss) in [(322, 1166), (429, 1041), (378, 1098), (100, 200), (1400, 300)] {
            for m in 0..<1440 {
                let p = Pahar.paharSolar(m, sunrise: sr, sunset: ss)
                XCTAssertTrue((1...8).contains(p), "solar minute \(m) (sr \(sr) ss \(ss)) → \(p)")
            }
        }
    }
}
