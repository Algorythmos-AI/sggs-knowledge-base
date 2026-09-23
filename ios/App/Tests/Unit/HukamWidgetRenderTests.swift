import XCTest
import SwiftUI
import WidgetKit
import GurbaniDB
import GurbaniSearchKit
@testable import SGGS

/// Renders the Hukam widget (systemMedium + systemLarge, light + dark) through `ImageRenderer`,
/// modelled on `WidgetRenderTests`: a gate that each layout composes, and — when
/// `SGGS_WIDGET_SNAPSHOT_DIR` is set — a PNG per family for visual review.
///
/// `HukamView` itself lives in the widget-extension target (Widgets/SGGSWidgets.swift), which a
/// unit-test bundle hosted by the app cannot import, so `HukamWidgetBody` below mirrors its body
/// line for line using the same shared components (Eyebrow, Mark, Citation, WidgetType,
/// PaperGround). Keep the two in step. The verse is NOT a fixture: it is drawn the way the app
/// draws the snapshot — `hukamUnit(seed:)` on the bundled DB, first non-header line, verbatim.
@MainActor
final class HukamWidgetRenderTests: XCTestCase {

    /// Dhanasari M1, "Aarti" (Ang 13) — the composition used for the marketing Hukam shots.
    private let seedCompId = 29

    /// Japji (Ang 1), the Aarti (Ang 13) and the Granth's closing composition (a 4-digit Ang —
    /// the widest citation) for the truncation gate.
    private let probeSeeds = [2, 29, 5376]

    private let families: [(WidgetFamily, CGSize, String)] = [
        (.systemMedium, CGSize(width: 338, height: 158), "medium"),
        (.systemLarge, CGSize(width: 338, height: 354), "large"),
    ]

    private let typeSizes: [DynamicTypeSize] = [.large, .xxxLarge, .accessibility1, .accessibility2]
    private let inset: CGFloat = 14

    private func makeSource() throws -> SQLiteCandidateSource {
        guard let path = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite")?.path
            ?? Bundle(for: Self.self).url(forResource: "sggs-ios", withExtension: "sqlite")?.path
        else { throw XCTSkip("bundled DB not found in host app") }
        return try SQLiteCandidateSource(path: path)
    }

    private func verse(seed: Int, in source: SQLiteCandidateSource) throws -> ReaderLine {
        let unit = try source.hukamUnit(seed: seed)
        return try XCTUnwrap(unit.lines.first(where: { !$0.isHeader }), "hukam unit \(seed) has no verse")
    }

    private func widget(_ verse: ReaderLine, family: WidgetFamily, size: CGSize, dark: Bool,
                        typeSize: DynamicTypeSize) -> some View {
        ZStack {
            PaperGround()
            HukamWidgetBody(gurmukhi: verse.gurmukhi, translit: verse.translit, ang: verse.ang,
                            large: family == .systemLarge)
                .padding(inset)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.colorScheme, dark ? .dark : .light)
        .environment(\.dynamicTypeSize, typeSize)
    }

    private func render(_ verse: ReaderLine, family: WidgetFamily, size: CGSize, dark: Bool,
                        typeSize: DynamicTypeSize = .large) -> UIImage? {
        let r = ImageRenderer(content: widget(verse, family: family, size: size, dark: dark, typeSize: typeSize))
        r.scale = 3
        return r.uiImage
    }

    func testHukamRendersMediumAndLarge() throws {
        let out = ProcessInfo.processInfo.environment["SGGS_WIDGET_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("sggs-widget-snapshots")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        print("SGGS_WIDGET_SNAPSHOT_DIR=\(out.path)")
        let verse = try verse(seed: seedCompId, in: makeSource())
        for (family, size, name) in families {
            for dark in [false, true] {
                let img = try XCTUnwrap(render(verse, family: family, size: size, dark: dark),
                                        "hukam \(name) \(dark ? "dark" : "light") failed to render")
                XCTAssertGreaterThan(img.size.width, 0)
                if let png = img.pngData() {
                    try png.write(to: out.appendingPathComponent("hukam-\(name)-\(dark ? "dark" : "light").png"))
                }
                // the largest type size the citation gate covers, for visual review
                if let png = render(verse, family: family, size: size, dark: dark, typeSize: .accessibility2)?.pngData() {
                    try png.write(to: out.appendingPathComponent("hukam-\(name)-ax2-\(dark ? "dark" : "light").png"))
                }
            }
        }
    }

    /// The citation must always read in full — "Sri Guru Granth Sahib Ji · Ang N", never
    /// truncated, never clipped (docs/engineering/invariants.md) — in every family, at every type size up to AX2.
    /// The widget is laid out in a real window; `Citation` reports its text's frame, and the
    /// gate checks (1) the frame lies inside the widget's content area and (2) the text, laid
    /// out unconstrained at the width it was given, needs no more height than it got — i.e. no
    /// line was cut off with an ellipsis.
    func testCitationIsNeverTruncated() throws {
        XCTAssertEqual(Citation.text(ang: 13), "Sri Guru Granth Sahib Ji · Ang 13")
        let source = try makeSource()
        for seed in probeSeeds {
            let verse = try verse(seed: seed, in: source)
            for (family, size, name) in families {
                for typeSize in typeSizes {
                    let label = "hukam \(name) seed \(seed) (Ang \(verse.ang)) \(typeSize)"
                    let probe = Probe()
                    let host = UIHostingController(rootView:
                        widget(verse, family: family, size: size, dark: false, typeSize: typeSize)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.root = $0 }
                            .onPreferenceChange(CitationFrameKey.self) { probe.citation = $0 })
                    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
                    window.rootViewController = host
                    window.isHidden = false
                    host.view.layoutIfNeeded()
                    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                    window.isHidden = true

                    let cite = probe.citation, root = probe.root
                    XCTAssertFalse(cite.isNull || root.isNull, "\(label): no citation frame reported")
                    if cite.isNull || root.isNull { continue }
                    let content = root.insetBy(dx: inset - 0.5, dy: inset - 0.5)
                    XCTAssertTrue(content.contains(cite),
                                  "\(label): citation \(cite) is clipped outside the widget content \(content)")
                    // measured at the size the widget actually draws (it clamps at xxxLarge)
                    let needed = UIHostingController(rootView:
                        Text(Citation.displayText(ang: verse.ang)).font(WidgetType.serif(12))
                            .environment(\.dynamicTypeSize, min(typeSize, .xxxLarge)))
                        .sizeThatFits(in: CGSize(width: cite.width + 0.5, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(needed.height, cite.height + 1,
                                             "\(label): citation truncated — needs \(needed.height)pt, got \(cite.height)pt at \(cite.width)pt wide")
                }
            }
        }
    }
}

/// Collects the frames reported during layout (main thread only).
private final class Probe: @unchecked Sendable {
    var root: CGRect = .null
    var citation: CGRect = .null
}

/// Mirror of `HukamView.body` (Widgets/SGGSWidgets.swift) for the snapshot-present state.
private struct HukamWidgetBody: View {
    let gurmukhi: String
    let translit: String
    let ang: Int
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Eyebrow(text: "HUKAM")
                Spacer()
                Mark(size: large ? 22 : 16)
            }
            Spacer(minLength: large ? 14 : 8)
            Text(gurmukhi)
                .font(WidgetType.gurmukhi(large ? 26 : 21))
                .lineSpacing(large ? 8 : 5)
                .minimumScaleFactor(0.7)
                .lineLimit(large ? 5 : 3)
                .foregroundStyle(.primary)
            if !translit.isEmpty {
                Text(translit)
                    .font(.system(size: large ? 13 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(large ? 3 : 1)
                    .padding(.top, large ? 10 : 6)
            }
            Spacer(minLength: large ? 14 : 8)
            Citation(ang: ang, action: large ? "Tap to read the shabad" : "Tap to read")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
