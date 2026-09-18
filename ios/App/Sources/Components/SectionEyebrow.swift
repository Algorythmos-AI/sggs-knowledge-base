import SwiftUI

/// A small-caps accent eyebrow — the app's section-header voice (the widget `Eyebrow` is a
/// fixed 10 pt and hidden from accessibility, so it isn't reused here). Scales to AX5, honours
/// the chosen accent, and reads as a header to VoiceOver.
struct SectionEyebrow: View {
    let text: String
    var symbol: String? = nil
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.semibold))
            }
            Text(text.uppercased()).font(.caption2.weight(.semibold)).tracking(1.2)
        }
        .foregroundStyle(palette.accentText)
        .accessibilityAddTraits(.isHeader)
    }
}
