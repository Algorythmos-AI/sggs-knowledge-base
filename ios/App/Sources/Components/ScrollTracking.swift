import SwiftUI

/// Scroll tracking with the modern API where available (iOS 18+: exact offset + content and
/// container sizes from the scroll view itself) and the zero-height GeometryReader probe +
/// preference keys as the iOS 17.0 fallback. Shared by the Ang Reader and the Bani reader so
/// both hide and restore their chrome with exactly the same feel.
struct ReaderScrollTracking: ViewModifier {
    let onScroll: (CGFloat, CGFloat, CGFloat) -> Void
    let onContentHeight: (CGFloat) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollSnapshot.self) { g in
                ScrollSnapshot(y: g.contentOffset.y + g.contentInsets.top,
                               content: g.contentSize.height, viewport: g.containerSize.height)
            } action: { _, s in onScroll(s.y, s.content, s.viewport) }
        } else {
            content
                .onPreferenceChange(ReaderScrollOffsetKey.self) { y in onScroll(y, 0, 0) }
                .onPreferenceChange(ReaderContentHeightKey.self) { h in onContentHeight(h) }
        }
    }
}
struct ScrollSnapshot: Equatable { let y: CGFloat; let content: CGFloat; let viewport: CGFloat }

struct ReaderScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
struct ReaderContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// The ambient-chrome rule both readers share. Hide only when the reader is clearly reading
/// downwards (> 24 pt run, past 80 pt, on a page taller than the viewport + 120 so short pages
/// never flicker); restore on ≥ 8 pt upwards or at the top. Never for VoiceOver / Switch
/// Control users — the chrome is their navigation. Reduce Motion: MotionGate makes it instant.
struct AmbientChrome {
    var hidden = false
    private var lastOffset: CGFloat = 0
    private var downRun: CGFloat = 0
    private var upRun: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    /// True during a programmatic landing scroll (must never count as "reading down").
    var landingInProgress = false
    /// True while hands-free auto-scroll runs (the programmatic pace must not toggle chrome).
    var autoScrolling = false

    /// Returns the new `hidden` value when it should change, nil otherwise.
    @MainActor mutating func scrolled(to offset: CGFloat) -> Bool? {
        let delta = offset - lastOffset
        lastOffset = offset
        if landingInProgress || autoScrolling { downRun = 0; upRun = 0; return nil }
        if UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning { return hidden ? false : nil }
        if delta > 0 { downRun += delta; upRun = 0 } else if delta < 0 { upRun += -delta; downRun = 0 }
        if !hidden, downRun > 24, offset > 80, contentHeight > viewportHeight + 120 { return true }
        if hidden, upRun >= 8 || offset <= 0 { return false }
        return nil
    }

    mutating func reset() { downRun = 0; upRun = 0 }
}
