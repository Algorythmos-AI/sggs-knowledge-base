import SwiftUI

/// Press feedback for card-shaped tap targets (Explore hub cards, hero cards, pahar rows):
/// a 2% settle + slight dim, on the gentle curve, suppressed under Reduce Motion.
struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : Motion.gentle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
}

/// The prominent brand action (Hukam, Verify again): accent fill, AA-checked onAccent
/// label, capsule silhouette, press settle.
struct ProminentPillStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, 10)
            .background(Capsule().fill(palette.accent))
            .foregroundStyle(palette.onAccent)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : Motion.gentle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ProminentPillStyle {
    static var prominentPill: ProminentPillStyle { ProminentPillStyle() }
}
