import SwiftUI

/// A shareable verse image: verbatim Gurmukhi + translit + English + the Ang citation on the
/// brand ramp. Rendered with ImageRenderer at 3× — text is typeset from the verbatim string,
/// never re-encoded through lossy transforms.
///
/// FIXED-SIZE by design: the card renders at 480 pt for a share image; Dynamic Type must not
/// reflow it (the recipient's accessibility settings apply in their own viewer).
struct VerseCardView: View {
    let gurmukhi: String
    let translit: String
    let en: String?
    let ang: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ੴ").font(Brand.gurmukhi(30)).foregroundStyle(Brand.saffron)
            Text(gurmukhi)
                .font(Brand.gurmukhi(30))
                .lineSpacing(16)
                .foregroundStyle(.primary)
            if !translit.isEmpty {
                Text(translit).font(.system(size: 15)).foregroundStyle(.secondary)
            }
            if let en, !en.isEmpty {
                Text(en).font(.system(size: 15, design: .serif)).foregroundStyle(.secondary)
            }
            HStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(AccentPalette.saffron.heroGradient)
                    .frame(width: 44, height: 2.5)
                Text("Sri Guru Granth Sahib Ji · Ang \(String(ang))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AccentPalette.gold.accentText)
            }
        }
        .padding(28)
        .frame(width: 480, alignment: .leading)
        .background(Ink.paper)
    }
}

@MainActor
enum VerseCardRenderer {
    /// nil only if rendering fails (caller falls back to sharing text).
    /// `scheme` must be passed explicitly: the card's colors are dynamic providers, and
    /// ImageRenderer resolves them against ITS environment, not the presenting window's —
    /// without this the shared image could silently flip scheme.
    static func render(gurmukhi: String, translit: String, en: String?, ang: Int,
                       scheme: ColorScheme) -> UIImage? {
        let renderer = ImageRenderer(content: VerseCardView(
            gurmukhi: gurmukhi, translit: translit, en: en, ang: ang)
            .environment(\.colorScheme, scheme))
        renderer.scale = 3
        return renderer.uiImage
    }
}
