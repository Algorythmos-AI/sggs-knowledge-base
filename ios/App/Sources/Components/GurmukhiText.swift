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

    private var effective: CGFloat { size * CGFloat(userBase) / 24 }

    var body: some View {
        Text(saroop ? Saroop.toTraditional(verbatim) : verbatim)
            .font(Brand.gurmukhi(effective, relativeTo: .body).weight(weight))
            .lineSpacing(effective * 0.55)                  // headroom for stacked matras
            // Never let a self-sizing List cell truncate scripture: at accessibility text sizes
            // the cell under-measures a custom-font Text with large lineSpacing and shows "…".
            // Vertical fixedSize makes the Text claim its full wrapped height (verified AX3).
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(punjabiLabel))
    }

    private var punjabiLabel: AttributedString {
        var a = AttributedString(verbatim)
        a.languageIdentifier = "pa"
        return a
    }
}
