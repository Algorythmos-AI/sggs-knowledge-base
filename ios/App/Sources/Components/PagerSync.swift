import Foundation

/// The pure, UIKit-free decision core for `AngPager`.
///
/// It exists because `UIPageViewController`'s `setViewControllers(animated: true)` completion and its
/// `didFinishAnimating` delegate callback are *not* reliably delivered for programmatic transitions
/// (they fire for gesture-driven ones). The previous coordinator latched a single `isTransitioning`
/// flag on an animated programmatic turn and never cleared it — so after the first chevron / "Continues
/// on Ang N" tap every later external navigation was silently parked forever while the router's Ang kept
/// advancing (title said "Ang 1182", the page still showed 1181). See `PagerSyncTests`.
///
/// This type decides *what* the coordinator should do and never depends on any completion callback for
/// correctness: programmatic turns are always applied with a synchronous, non-animated
/// `setViewControllers` (wrapped in a `CATransition` for the visual), and a watchdog heals any request
/// that had to be parked because a finger was on the glass.
///
/// Invariants it guarantees (with the coordinator's `verifySoon`/`reconcile`):
///  - I1: after any transition ends, the visible index converges to `desired` within one runloop.
///  - I2: a programmatic set is never issued while a touch is tracking/dragging/decelerating.
///  - I3: no correctness depends on a UIKit callback arriving (a lost one is bounded by the watchdog).
///  - I5: the latest external intent wins — a request made during a swipe overrides where it lands.
struct PagerSync {
    enum Transition: Equatable { case none, slide(forward: Bool), fade }

    enum Effect: Equatable {
        /// Set the visible page to this index (non-animated set + the given `CATransition`).
        case show(Int, Transition)
        /// A finger swipe settled here → write it back to the router (the only write-back).
        case settle(Int)
        /// A request is parked behind a live gesture; re-check after a short delay.
        case armWatchdog
        /// Diagnostics only (a self-heal fired — a UIKit callback was lost).
        case log(String)
    }

    /// Turns closer together than this are applied without animation (rapid taps must not queue).
    static let rapidWindow: TimeInterval = 0.30

    let bounds: ClosedRange<Int>
    private(set) var gestureActive = false
    private(set) var pending: Int?
    private var lastShowAt: TimeInterval = -1

    init(bounds: ClosedRange<Int>) { self.bounds = bounds }

    private func clamp(_ i: Int) -> Int { min(max(bounds.lowerBound, i), bounds.upperBound) }

    /// An external index change (chevron, pill, Jump, deep link, resume, self-heal). `visible` is the
    /// truth read from the pager right now (nil = no page mounted yet).
    mutating func request(desired: Int, visible: Int?, scrollBusy: Bool,
                          reduceMotion: Bool, inWindow: Bool, now: TimeInterval) -> [Effect] {
        let d = clamp(desired)
        guard let v = visible else { return [.show(d, .none)] }      // first mount
        if v == d { pending = nil; return [] }
        if gestureActive || scrollBusy { pending = d; return [.armWatchdog] }   // I2: never set under a finger
        pending = nil
        return [.show(d, transition(from: v, to: d, reduceMotion: reduceMotion, inWindow: inWindow, now: now))]
    }

    mutating func gestureBegan() { gestureActive = true }

    /// A finger swipe finished. `visible` is the page it settled on.
    mutating func gestureEnded(completed: Bool, visible: Int?, scrollBusy: Bool,
                               reduceMotion: Bool, inWindow: Bool, now: TimeInterval) -> [Effect] {
        gestureActive = scrollBusy      // a second swipe may already be decelerating
        if let p = pending {            // I5: an external request arrived mid-swipe; it wins
            if scrollBusy { return [.armWatchdog] }
            pending = nil
            let d = clamp(p)
            if d == visible { return [] }
            lastShowAt = now
            return [.show(d, (reduceMotion || !inWindow) ? .none : .fade)]
        }
        if completed, let v = visible { return [.settle(clamp(v))] }
        return []
    }

    /// A parked request timed out — a delegate callback was probably lost. Re-check and heal.
    mutating func watchdog(desired: Int, visible: Int?, scrollBusy: Bool) -> [Effect] {
        guard pending != nil else { return [] }
        if scrollBusy { return [.armWatchdog] }
        gestureActive = false
        pending = nil
        let d = clamp(desired)
        if d == visible { return [] }
        return [.log("watchdog-heal"), .show(d, .none)]
    }

    private mutating func transition(from v: Int, to d: Int, reduceMotion: Bool,
                                     inWindow: Bool, now: TimeInterval) -> Transition {
        let rapid = now - lastShowAt < Self.rapidWindow
        lastShowAt = now
        if !inWindow || rapid { return .none }
        if reduceMotion { return .fade }
        return abs(v - d) == 1 ? .slide(forward: d > v) : .fade
    }
}
