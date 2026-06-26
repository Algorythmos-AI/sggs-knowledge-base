import SwiftUI

/// Renders verbatim Gurmukhi in Sant Lipi, applying the display-only saroop transform when enabled.
/// VoiceOver reads the VERBATIM string (never the VS-marked display form), tagged Punjabi.
struct GurmukhiText: View {
    let verbatim: String
    var size: CGFloat = 24
    var weight: Font.Weight = .regular
    @AppStorage("sggs_saroop") private var saroop = true

    var body: some View {
        Text(saroop ? Saroop.toTraditional(verbatim) : verbatim)
            .font(Brand.gurmukhi(size, relativeTo: .body).weight(weight))
            .lineSpacing(size * 0.55)                       // headroom for stacked matras
            .accessibilityLabel(Text(punjabiLabel))
    }

    private var punjabiLabel: AttributedString {
        var a = AttributedString(verbatim)
        a.languageIdentifier = "pa"
        return a
    }
}
