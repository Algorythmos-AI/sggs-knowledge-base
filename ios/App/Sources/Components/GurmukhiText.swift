import SwiftUI

/// Renders verbatim Gurmukhi in Sant Lipi, applying the display-only saroop transform when enabled.
/// VoiceOver reads the VERBATIM string (never the VS-marked display form), tagged Punjabi.
struct GurmukhiText: View {
    let verbatim: String
    /// Design size at the default base (24). The user's Gurmukhi-size preference scales it
    /// proportionally, and `relativeTo: .body` then scales with Dynamic Type on top.
    var size: CGFloat = 24
    var weight: Font.Weight = .regular
    @AppStorage("sggs_saroop") private var saroop = true
    @AppStorage("sggs_gurmukhi_size") private var userBase = 24.0
    /// Reader line-spacing multiple (floored at 0.4 in the environment setter); other screens
    /// leave it at the default 0.4.
    @Environment(\.gurmukhiLeading) private var leading

    private var effective: CGFloat { size * CGFloat(userBase) / 24 }

    var body: some View {
        Text(displayed)
            .font(Brand.gurmukhi(effective, relativeTo: .body).weight(weight))
            // Wrapped lines of ONE verse sit closer than two verses do (rows are spaced by the
            // caller), so a long line reads as a unit. 0.4 still clears stacked matras/pairin
            // in Sant Lipi (checked at the 32-pt maximum and AX sizes).
            .lineSpacing(effective * leading)
            // Never let a self-sizing List cell truncate scripture: at accessibility text sizes
            // the cell under-measures a custom-font Text with large lineSpacing and shows "…".
            // Vertical fixedSize makes the Text claim its full wrapped height (verified AX3).
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(punjabiLabel))
    }

    /// The rendered string: saroop painter + no-break binding of the closing marker. Display
    /// only — everything else in the app reads `verbatim`.
    private var displayed: String {
        VerseTypography.bindingClosingMarkers(saroop ? Saroop.toTraditional(verbatim) : verbatim)
    }

    private var punjabiLabel: AttributedString {
        var a = AttributedString(verbatim)
        a.languageIdentifier = "pa"
        return a
    }
}
