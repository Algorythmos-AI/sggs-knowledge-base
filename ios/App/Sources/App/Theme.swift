import SwiftUI
import UIKit
import CoreText

/// Brand tokens (the web's saffron/gold identity, tuned per scheme) + the Sant Lipi
/// scripture font. These are the FIXED brand colors (launch, About, integrity screens);
/// accent-aware components read @Environment(\.palette) instead — see DesignTokens.swift.
/// The light saffron is #E06E09 (2% deeper than the web's #E8730C) so it clears 3:1 on
/// the paper surfaces; the AccentColor asset is pinned to these values by ThemeContrastTests.
enum Brand {
    /// The fixed brand colour (tint/icon/stroke weight, ≥3:1) and its prominent-fill partner.
    static let primary = AccentPalette.brandDefault.accent
    static let primaryFill = AccentPalette.brandDefault.accentFill
    static let saffron = AccentPalette.saffron.accent
    static let gold = AccentPalette.gold.accent

    /// The bundled Gurmukhi scripture font (variable; default instance). Scales with Dynamic Type.
    static func gurmukhi(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("SantLipi-ExtraLight", size: size, relativeTo: style)
    }

    // MARK: heading serif (Source Serif 4, SIL OFL — Resources/OFL-SourceSerif4.txt)
    //
    // HEADINGS ONLY (brand book §4): navigation titles and a few hero lines. Body, buttons,
    // lists and tabs stay San Francisco; Gurmukhi stays Sant Lipi. The file is a variable
    // font, so weight is set on the `wght` axis; sizes come from the text style's own
    // preferred size and scale with Dynamic Type through UIFontMetrics.

    static let headingFontName = "SourceSerif4Variable-Roman"

    /// UIKit heading font for a text style. Falls back to the system serif design if the
    /// bundled face is ever missing, so a heading can never disappear.
    static func headingUIFont(_ style: UIFont.TextStyle, weight: CGFloat = 600) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let size = base.pointSize
        guard let face = UIFont(name: headingFontName, size: size) else {
            let d = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: d, size: size))
        }
        let wghtAxis = 0x77676874   // 'wght'
        let descriptor = face.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight],
        ])
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }

    /// SwiftUI heading font. Call from `body` so a Dynamic Type change re-resolves it.
    static func heading(_ style: UIFont.TextStyle = .headline, weight: CGFloat = 600) -> Font {
        Font(headingUIFont(style, weight: weight))
    }

    /// Navigation-bar titles in the heading serif. Sets only the title text attributes, so
    /// the system bar background/material is left exactly as the OS draws it.
    @MainActor static func applyNavigationTitleFonts() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: headingUIFont(.largeTitle, weight: 700)]
        bar.titleTextAttributes = [.font: headingUIFont(.headline)]
    }
}

/// Semantic design tokens — the single vocabulary every screen draws from (mirrors the web's
/// token discipline). Add here, use everywhere; never hard-code a spacing/radius/band constant
/// in a screen.
enum Theme {
    static let accent = Brand.primary
    static let gold = Brand.gold

    /// Spacing scale (pt). Matches the 4-pt web rhythm.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Corner radii.
    enum Radius {
        static let card: CGFloat = 12
        static let chip: CGFloat = 8
    }

    // MARK: relatedness (echo) bands — web parity

    /// Calibrated relatedness band for a semantic-neighbour cosine score. Thresholds are the
    /// web's `core.ts relBand` — ≥0.65 "Strong echo", ≥0.45 "Related", else "Faint echo" —
    /// surfaced as a BAND, never a raw ranking of scripture. `pct` = round(score*100), the
    /// web's display convention.
    static func echoBand(_ score: Double) -> (label: String, color: Color) {
        switch score {
        case 0.65...: return ("Strong echo", Ink.positive)
        case 0.45..<0.65: return ("Related", AccentPalette.gold.accentText)
        default: return ("Faint echo", .secondary)
        }
    }

    static func echoPct(_ score: Double) -> Int { Int((score * 100).rounded()) }
}

/// The standard content card (Explore hub, Lineage profiles, Insights panels).
/// Elevation is scheme-appropriate: a soft resting shadow in light; a hairline border in
/// dark (shadows die on warm ink — the border does the layering there).
struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.l)
            .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(scheme == .dark ? Ink.hairline : Color.clear))
            .shadow(color: scheme == .dark ? .clear : Elevation.cardShadowColor,
                    radius: Elevation.cardShadowRadius, y: Elevation.cardShadowY)
    }
}

/// A compact stat (value + caption), used in grids on Lineage/Insights.
struct StatTile: View {
    let value: String
    let caption: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Ink.hairline))
    }
}
