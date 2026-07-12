import SwiftUI

// The ONLY sanctioned animation entry points — both are Reduce-Motion-aware, and the
// certification grep gate enforces that no screen calls `withAnimation`/.animation directly.
// Curves come from Motion (DesignTokens.swift); everything stays ≤0.3 s so XCUITest
// waitForExistence never races an animation.

extension View {
    /// Declarative: animate changes of `value` with an app curve, unless Reduce Motion is on.
    func appAnimation<V: Equatable>(_ animation: Animation = Motion.spring, value: V) -> some View {
        modifier(MotionAwareAnimation(animation: animation, value: value))
    }
}

private struct MotionAwareAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Imperative gate for state changes that want an animated transaction.
enum MotionGate {
    @MainActor
    static func run(_ animation: Animation = Motion.spring, _ body: () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            body()
        } else {
            withAnimation(animation, body)
        }
    }
}
