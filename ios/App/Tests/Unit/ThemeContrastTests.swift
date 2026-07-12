import XCTest
import SwiftUI
@testable import SGGS

/// WCAG contrast is a REGRESSION TEST here, not a one-time design claim: every text and
/// status token is checked against its paired surfaces across 4 accents × {light, dark} ×
/// {normal, Increase Contrast}. Change a hex in DesignTokens.swift and this tells you
/// immediately whether the system still passes AA (≥4.5:1 text, ≥3:1 UI fills).
final class ThemeContrastTests: XCTestCase {

    // MARK: WCAG math

    private struct Leg: CustomStringConvertible {
        let style: UIUserInterfaceStyle
        let contrast: UIAccessibilityContrast
        var traits: UITraitCollection {
            UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(accessibilityContrast: contrast),
            ])
        }
        var description: String {
            "\(style == .dark ? "dark" : "light")\(contrast == .high ? "+HC" : "")"
        }
    }

    private let legs: [Leg] = [
        .init(style: .light, contrast: .normal), .init(style: .light, contrast: .high),
        .init(style: .dark, contrast: .normal), .init(style: .dark, contrast: .high),
    ]

    private func luminance(_ color: Color, _ leg: Leg) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: leg.traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func ratio(_ fg: Color, on bg: Color, _ leg: Leg) -> CGFloat {
        let l1 = luminance(fg, leg), l2 = luminance(bg, leg)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func assertRatio(_ fg: Color, on bg: Color, atLeast floor: CGFloat,
                             _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        for leg in legs {
            let r = ratio(fg, on: bg, leg)
            XCTAssertGreaterThanOrEqual(
                r, floor,
                "\(what) [\(leg)] = \(String(format: "%.2f", r)):1, needs ≥\(floor):1",
                file: file, line: line)
        }
    }

    // MARK: accent palettes

    func testAccentTextReadsOnEverySurface() {
        for p in AccentPalette.allCases {
            assertRatio(p.accentText, on: Ink.canvas, atLeast: 4.5, "\(p.rawValue).accentText on canvas")
            assertRatio(p.accentText, on: Ink.card, atLeast: 4.5, "\(p.rawValue).accentText on card")
            assertRatio(p.accentText, on: Ink.paper, atLeast: 4.5, "\(p.rawValue).accentText on paper")
        }
    }

    func testOnAccentLabelsReadOnTheirFill() {
        for p in AccentPalette.allCases {
            assertRatio(p.onAccent, on: p.accent, atLeast: 4.5, "\(p.rawValue).onAccent on accent fill")
        }
    }

    func testAccentFillsAreDistinguishableFromSurfaces() {
        for p in AccentPalette.allCases {
            assertRatio(p.accent, on: Ink.card, atLeast: 3.0, "\(p.rawValue).accent fill on card")
            assertRatio(p.accent, on: Ink.paper, atLeast: 3.0, "\(p.rawValue).accent fill on paper")
        }
    }

    // MARK: status tokens

    func testStatusTokensReadAsTextOnContentSurfaces() {
        let statuses: [(String, Color)] = [
            ("positive", Ink.positive), ("negative", Ink.negative),
            ("info", Ink.info), ("special", Ink.special),
        ]
        for (name, c) in statuses {
            assertRatio(c, on: Ink.canvas, atLeast: 4.5, "Ink.\(name) on canvas")
            assertRatio(c, on: Ink.card, atLeast: 4.5, "Ink.\(name) on card")
            assertRatio(c, on: Ink.paper, atLeast: 4.5, "Ink.\(name) on paper")
        }
    }

    // MARK: surfaces stay layered (dark ink ramp must remain distinguishable)

    func testDarkSurfaceRampIsOrderedAndWarm() {
        let dark = Leg(style: .dark, contrast: .normal)
        let canvas = luminance(Ink.canvas, dark)
        let card = luminance(Ink.card, dark)
        let raised = luminance(Ink.raised, dark)
        XCTAssertLessThan(canvas, card, "canvas must sit below card in the dark ramp")
        XCTAssertLessThan(card, raised, "card must sit below raised in the dark ramp")
        XCTAssertGreaterThan(canvas, 0, "warm ink, never pure black")
    }

    // MARK: asset-catalog ↔ code parity (kills silent drift)

    /// AccentColor.colorset is what the OS reads for system chrome before any code runs;
    /// it must resolve to exactly the code palette's saffron in both schemes.
    func testAccentColorAssetMatchesCodeSaffron() throws {
        let asset = try XCTUnwrap(UIColor(named: "AccentColor"), "AccentColor missing from catalog")
        for leg in [Leg(style: .light, contrast: .normal), Leg(style: .dark, contrast: .normal)] {
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            asset.resolvedColor(with: leg.traits).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
            UIColor(AccentPalette.saffron.accent).resolvedColor(with: leg.traits)
                .getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            XCTAssertEqual(ar, cr, accuracy: 0.005, "AccentColor asset drifted from code saffron (red, \(leg))")
            XCTAssertEqual(ag, cg, accuracy: 0.005, "AccentColor asset drifted from code saffron (green, \(leg))")
            XCTAssertEqual(ab, cb, accuracy: 0.005, "AccentColor asset drifted from code saffron (blue, \(leg))")
        }
    }
}
