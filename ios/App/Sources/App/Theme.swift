import SwiftUI

/// Brand tokens (mirrors the web's saffron/gold identity) + the Sant Lipi scripture font.
enum Brand {
    static let saffron = Color(red: 0xE8 / 255, green: 0x73 / 255, blue: 0x0C / 255)
    static let gold = Color(red: 0xB0 / 255, green: 0x7D / 255, blue: 0x12 / 255)

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
        case 0.65...: return ("Strong echo", .green)
        case 0.45..<0.65: return ("Related", Brand.gold)
        default: return ("Faint echo", .secondary)
        }
    }

    static func echoPct(_ score: Double) -> Int { Int((score * 100).rounded()) }
}

/// The standard content card (Explore hub, Lineage profiles, Insights panels).
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.l)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card))
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
        .background(Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
    }
}
