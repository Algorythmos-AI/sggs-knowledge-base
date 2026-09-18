import SwiftUI

/// The quiet seal shown when a bani is marked read: a gold ring closes and a checkmark settles.
/// A checkmark, never the ੴ mark (the brand book forbids decorating the mark). Driven through
/// `appAnimation(Motion.gentle)`, so it is ≤0.3 s and instant under Reduce Motion.
struct CompletionSeal: View {
    /// Set true on completion; false while unread.
    let sealed: Bool
    var size: CGFloat = 44
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle().strokeBorder(Ink.hairline, lineWidth: 3)
            Circle()
                .trim(from: 0, to: sealed ? 1 : 0)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.5)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(palette.accent)
                .opacity(sealed ? 1 : 0)
                .scaleEffect(sealed ? 1 : 0.6)
        }
        .frame(width: size, height: size)
        .appAnimation(Motion.gentle, value: sealed)
        .accessibilityHidden(true)
    }
}
