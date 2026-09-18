import SwiftUI

/// A calm placeholder for the Nitnem home while the registry loads. Static blocks on
/// `Ink.raised` (no shimmer loop — a repeating animation keeps XCUITest from idling and is
/// noise under Reduce Motion); shown only after a short grace so a fast local load never
/// flashes it. One gentle fade-in.
struct NitnemSkeleton: View {
    @State private var shown = false
    var body: some View {
        Group {
            if shown {
                VStack(spacing: Theme.Space.l) {
                    block(height: 150)                    // hero
                    block(height: 64)                     // hukam
                    VStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { _ in block(height: 60) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    Spacer(minLength: 0)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
                .transition(.opacity)
                .appAnimation(Motion.gentle, value: shown)
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            shown = true
        }
    }

    private func block(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card)
            .fill(Ink.raised)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}
