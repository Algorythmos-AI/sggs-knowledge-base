import XCTest
import SwiftUI
import WidgetKit
@testable import SGGS

/// Renders the Nitnem widget in every family (light + dark) through `ImageRenderer` — a gate
/// that each layout composes without trapping, and (with `SGGS_WIDGET_SNAPSHOT_DIR`) a PNG per
/// family for visual review.
@MainActor
final class NitnemWidgetRenderTests: XCTestCase {
    private let families: [(WidgetFamily, CGSize, String)] = [
        (.systemSmall, CGSize(width: 158, height: 158), "small"),
        (.systemMedium, CGSize(width: 338, height: 158), "medium"),
        (.accessoryCircular, CGSize(width: 72, height: 72), "circular"),
        (.accessoryRectangular, CGSize(width: 172, height: 76), "rectangular"),
        (.accessoryInline, CGSize(width: 260, height: 24), "inline"),
    ]

    private func entry(next: Bool, hasNitnem: Bool = true) -> NitnemEntry {
        let banis = [
            NitnemWidgetData.Bani(id: "japji", key: "japji", titleEn: "Japji Sahib", titleGm: "ਜਪੁਜੀ ਸਾਹਿਬ", minutes: 20, nLines: 385),
            NitnemWidgetData.Bani(id: "jaap", key: "jaap", titleEn: "Jaap Sahib", titleGm: "ਜਾਪੁ ਸਾਹਿਬ", minutes: 25, nLines: 801),
        ]
        let completed = next ? ["japji": true] : ["japji": true, "jaap": true]
        return NitnemEntry(date: .now, band: .amritVela, banis: hasNitnem ? banis : [],
                           completed: completed, fractions: [:], hasNitnem: hasNitnem)
    }

    private func render(_ e: NitnemEntry, family: WidgetFamily, size: CGSize, dark: Bool) -> UIImage? {
        let accessory = [.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(family)
        let view = ZStack {
            if accessory { Color.black } else { PaperGround() }
            NitnemWidgetView(entry: e, familyOverride: family).padding(accessory ? 4 : 14)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, dark ? .dark : .light)
        let r = ImageRenderer(content: view); r.scale = 3
        return r.uiImage
    }

    func testRendersEveryFamily() {
        let dir = ProcessInfo.processInfo.environment["SGGS_WIDGET_SNAPSHOT_DIR"]
        for (family, size, name) in families {
            for (e, tag) in [(entry(next: true), "next"), (entry(next: false), "done")] {
                for dark in [false, true] {
                    let img = render(e, family: family, size: size, dark: dark)
                    XCTAssertNotNil(img, "\(name) \(tag) dark=\(dark) failed to render")
                    if let dir, let png = img?.pngData() {
                        try? png.write(to: URL(fileURLWithPath: "\(dir)/nitnem_\(name)_\(tag)_\(dark ? "dark" : "light").png"))
                    }
                }
            }
        }
    }
}
