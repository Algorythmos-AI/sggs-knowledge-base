import SwiftUI

/// A shareable verse image: verbatim Gurmukhi + translit + English + the Ang citation on the
/// brand ramp. Rendered with ImageRenderer at 3× — text is typeset from the verbatim string,
/// never re-encoded through lossy transforms.
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
                Rectangle().fill(Brand.saffron).frame(width: 28, height: 2)
                Text("Sri Guru Granth Sahib · Ang \(String(ang))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Brand.gold)
            }
        }
        .padding(28)
        .frame(width: 480, alignment: .leading)
        .background(Color(.systemBackground))
    }
}

@MainActor
enum VerseCardRenderer {
    /// nil only if rendering fails (caller falls back to sharing text).
    static func render(gurmukhi: String, translit: String, en: String?, ang: Int) -> UIImage? {
        let renderer = ImageRenderer(content: VerseCardView(
            gurmukhi: gurmukhi, translit: translit, en: en, ang: ang))
        renderer.scale = 3
        return renderer.uiImage
    }
}
