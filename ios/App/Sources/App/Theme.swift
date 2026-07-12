import SwiftUI

/// Brand tokens (the web's saffron/gold identity, tuned per scheme) + the Sant Lipi
/// scripture font. These are the FIXED brand colors (launch, About, integrity screens);
/// accent-aware components read @Environment(\.palette) instead — see DesignTokens.swift.
/// The light saffron is #E06E09 (2% deeper than the web's #E8730C) so it clears 3:1 on
/// the paper surfaces; the AccentColor asset is pinned to these values by ThemeContrastTests.
enum Brand {
    static let saffron = AccentPalette.saffron.accent
    static let gold = AccentPalette.gold.accent

    /// The bundled Gurmukhi scripture font (variable; default instance). Scales with Dynamic Type.
    static func gurmukhi(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("SantLipi-ExtraLight", size: size, relativeTo: style)
    }
}

/// Semantic design tokens — the single vocabulary every screen draws from (mirrors the web's
/// token discipline). Add here, use everywhere; never hard-code a spacing/radius/band constant
/// in a screen.
enum Theme {
    static let accent = Brand.saffron
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
