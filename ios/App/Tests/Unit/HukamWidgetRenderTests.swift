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

    private let families: [(WidgetFamily, CGSize, String)] = [
        (.systemMedium, CGSize(width: 338, height: 158), "medium"),
        (.systemLarge, CGSize(width: 338, height: 354), "large"),
    ]

    private func makeSource() throws -> SQLiteCandidateSource {
        guard let path = Bundle.main.url(forResource: "sggs-ios", withExtension: "sqlite")?.path
            ?? Bundle(for: Self.self).url(forResource: "sggs-ios", withExtension: "sqlite")?.path
        else { throw XCTSkip("bundled DB not found in host app") }
        return try SQLiteCandidateSource(path: path)
    }

    private func render(_ verse: ReaderLine, family: WidgetFamily, size: CGSize, dark: Bool) -> UIImage? {
        let view = ZStack {
            PaperGround()
            HukamWidgetBody(gurmukhi: verse.gurmukhi, translit: verse.translit, ang: verse.ang,
                            large: family == .systemLarge)
                .padding(14)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.colorScheme, dark ? .dark : .light)
        let r = ImageRenderer(content: view)
        r.scale = 3
        return r.uiImage
    }

    func testHukamRendersMediumAndLarge() throws {
        let out = ProcessInfo.processInfo.environment["SGGS_WIDGET_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("sggs-widget-snapshots")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        print("SGGS_WIDGET_SNAPSHOT_DIR=\(out.path)")
        let unit = try makeSource().hukamUnit(seed: seedCompId)
        let verse = try XCTUnwrap(unit.lines.first(where: { !$0.isHeader }), "hukam unit has no verse")
        for (family, size, name) in families {
            for dark in [false, true] {
                let img = try XCTUnwrap(render(verse, family: family, size: size, dark: dark),
                                        "hukam \(name) \(dark ? "dark" : "light") failed to render")
                XCTAssertGreaterThan(img.size.width, 0)
                if let png = img.pngData() {
                    try png.write(to: out.appendingPathComponent("hukam-\(name)-\(dark ? "dark" : "light").png"))
                }
            }
        }
    }
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
    }
}
