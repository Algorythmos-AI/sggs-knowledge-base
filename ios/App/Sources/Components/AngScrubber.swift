import SwiftUI
import UIKit

/// A large, finger-friendly scrubber for picking an Ang across the whole Granth. Unlike a stock
/// `Slider` (a ~4 pt track where 1,430 values sit ~0.2 pt apart), the WHOLE 60 pt row is the drag
/// target — touch or drag anywhere and the thumb jumps under your finger — with a 36 pt thumb and
/// faint tick marks at raag boundaries that give a light selection tick as you cross them. Built
/// for elders and one-handed use. VoiceOver sees a real adjustable `Slider` via
/// `accessibilityRepresentation`, so the custom drawing never costs accessibility.
struct AngScrubber: View {
    @Binding var value: Int
    var bounds: ClosedRange<Int> = 1...1430
    /// Angs at which to draw a faint tick (raag boundaries).
    var ticks: [Int] = []
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Last value we fired a boundary-cross haptic for (avoids repeat ticks while paused on one).
    @State private var lastHapticValue: Int?

    private var span: CGFloat { CGFloat(max(1, bounds.upperBound - bounds.lowerBound)) }
    private func frac(_ v: Int) -> CGFloat {
        CGFloat(min(max(v, bounds.lowerBound), bounds.upperBound) - bounds.lowerBound) / span
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2
            let f = frac(value)
            let thumbX = min(max(18, f * w), w - 18)
            ZStack {
                // rail
                Capsule().fill(Ink.hairline)
                    .frame(width: w, height: 10).position(x: w / 2, y: midY)
                // raag-boundary ticks
                ForEach(ticks, id: \.self) { t in
                    Rectangle().fill(Ink.hairline)
                        .frame(width: 1.5, height: 18)
                        .position(x: frac(t) * w, y: midY)
                        .accessibilityHidden(true)
                }
                // filled portion
                Capsule().fill(palette.accent)
                    .frame(width: max(10, f * w), height: 10)
                    .position(x: max(10, f * w) / 2, y: midY)
                // thumb
                Circle().fill(Ink.raised)
                    .overlay(Circle().strokeBorder(palette.accent, lineWidth: 2.5))
                    .frame(width: 36, height: 36)
                    .shadow(color: Elevation.cardShadowColor, radius: 3, y: 1)
                    .position(x: thumbX, y: midY)
            }
            .frame(width: w, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let f = min(max(0, g.location.x / w), 1)
                        let v = bounds.lowerBound + Int((f * span).rounded())
                        setValue(v)
                    }
            )
        }
        .frame(height: 60)
        .accessibilityElement()
        .accessibilityRepresentation {
            Slider(
                value: Binding(get: { Double(value) },
                               set: { value = min(max(bounds.lowerBound, Int($0.rounded())), bounds.upperBound) }),
                in: Double(bounds.lowerBound)...Double(bounds.upperBound), step: 1
            )
            .accessibilityIdentifier("angSlider")
        }
    }

    private func setValue(_ v: Int) {
        let clamped = min(max(bounds.lowerBound, v), bounds.upperBound)
        guard clamped != value else { return }
        let old = value
        value = clamped
        // Selection tick only when a raag boundary is crossed (not every step) — restrained.
        if ticks.contains(where: { crossed($0, old, clamped) }), lastHapticValue != clamped {
            lastHapticValue = clamped
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func crossed(_ tick: Int, _ a: Int, _ b: Int) -> Bool {
        (min(a, b)...max(a, b)).contains(tick)
    }
}
