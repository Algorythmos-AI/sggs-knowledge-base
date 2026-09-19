import XCTest
@testable import SGGS

/// The pure decision core of the Reader's pager. These are the regression tests for the TestFlight
/// 1.3.0 (2) bug: an animated programmatic page turn latched a flag so every later chevron /
/// "Continues on Ang N" tap was swallowed while the title kept advancing. The core rule under test:
/// an idle external request ALWAYS yields a `.show`, never a silent park.
final class PagerSyncTests: XCTestCase {
    private func sync() -> PagerSync { PagerSync(bounds: 1...1430) }
    private let idle = (scrollBusy: false, reduceMotion: false, inWindow: true)

    private func request(_ s: inout PagerSync, _ desired: Int, visible: Int?, now: TimeInterval = 100,
                         scrollBusy: Bool = false, reduceMotion: Bool = false, inWindow: Bool = true) -> [PagerSync.Effect] {
        s.request(desired: desired, visible: visible, scrollBusy: scrollBusy,
                  reduceMotion: reduceMotion, inWindow: inWindow, now: now)
    }

    // MARK: the regression

    /// Three consecutive adjacent requests must each move the page — the exact sequence (Next ×3)
    /// that died on the shipped build.
    func testConsecutiveAdjacentRequestsAllShow() {
        var s = sync()
        XCTAssertEqual(request(&s, 1181, visible: 1180, now: 1), [.show(1181, .slide(forward: true))])
        XCTAssertEqual(request(&s, 1182, visible: 1181, now: 2), [.show(1182, .slide(forward: true))])
        XCTAssertEqual(request(&s, 1183, visible: 1182, now: 3), [.show(1183, .slide(forward: true))])
    }

    /// The "Continues on Ang N+1" tap: from a page showing N with the router already at N+1.
    func testContinuesOnPillShows() {
        var s = sync()
        XCTAssertEqual(request(&s, 1182, visible: 1181, now: 5), [.show(1182, .slide(forward: true))])
    }

    // MARK: transitions

    func testFirstMountShowsWithoutAnimation() {
        var s = sync()
        XCTAssertEqual(request(&s, 700, visible: nil), [.show(700, PagerSync.Transition.none)])
    }

    func testNoOpWhenAlreadyThere() {
        var s = sync()
        XCTAssertEqual(request(&s, 500, visible: 500), [])
    }

    func testFarJumpFades() {
        var s = sync()
        XCTAssertEqual(request(&s, 900, visible: 500, now: 10), [.show(900, .fade)])
    }

    func testReverseAdjacentSlidesBackward() {
        var s = sync()
        XCTAssertEqual(request(&s, 1180, visible: 1181, now: 10), [.show(1180, .slide(forward: false))])
    }

    func testReduceMotionFadesEvenWhenAdjacent() {
        var s = sync()
        XCTAssertEqual(request(&s, 1181, visible: 1180, now: 10, reduceMotion: true), [.show(1181, .fade)])
    }

    func testOffWindowShowsWithoutTransition() {
        var s = sync()
        XCTAssertEqual(request(&s, 1181, visible: 1180, now: 10, inWindow: false), [.show(1181, PagerSync.Transition.none)])
    }

    func testRapidTapsSkipAnimationAfterTheFirst() {
        var s = sync()
        XCTAssertEqual(request(&s, 1181, visible: 1180, now: 10.00), [.show(1181, .slide(forward: true))])
        // < 0.30 s later: no animation (avoids a queue of overlapping CATransitions)
        XCTAssertEqual(request(&s, 1182, visible: 1181, now: 10.10), [.show(1182, PagerSync.Transition.none)])
        XCTAssertEqual(request(&s, 1183, visible: 1182, now: 10.20), [.show(1183, PagerSync.Transition.none)])
    }

    func testBoundsAreClamped() {
        var s = sync()
        XCTAssertEqual(request(&s, 0, visible: 2, now: 10), [.show(1, .slide(forward: false))])
        var s2 = sync()
        XCTAssertEqual(request(&s2, 5000, visible: 1429, now: 10), [.show(1430, .slide(forward: true))])
    }

    // MARK: gestures

    func testRequestDuringGestureIsParkedThenApplied() {
        var s = sync()
        s.gestureBegan()
        XCTAssertEqual(request(&s, 1185, visible: 1180), [.armWatchdog])
        XCTAssertEqual(s.pending, 1185)
        // swipe settles on 1181, but the external request (1185) wins
        let fx = s.gestureEnded(completed: true, visible: 1181, scrollBusy: false,
                                reduceMotion: false, inWindow: true, now: 20)
        XCTAssertEqual(fx, [.show(1185, .fade)])
        XCTAssertNil(s.pending)
    }

    func testRequestDuringGestureThatMatchesLandingIsANoOp() {
        var s = sync()
        s.gestureBegan()
        _ = request(&s, 1181, visible: 1180)
        let fx = s.gestureEnded(completed: true, visible: 1181, scrollBusy: false,
                                reduceMotion: false, inWindow: true, now: 20)
        XCTAssertEqual(fx, [])   // pending == where the swipe landed
    }

    func testPlainSwipeSettles() {
        var s = sync()
        s.gestureBegan()
        let fx = s.gestureEnded(completed: true, visible: 1181, scrollBusy: false,
                                reduceMotion: false, inWindow: true, now: 20)
        XCTAssertEqual(fx, [.settle(1181)])
    }

    func testCancelledSwipeDoesNothing() {
        var s = sync()
        s.gestureBegan()
        let fx = s.gestureEnded(completed: false, visible: 1180, scrollBusy: false,
                                reduceMotion: false, inWindow: true, now: 20)
        XCTAssertEqual(fx, [])
    }

    func testSecondSwipeKeepsGestureActive() {
        var s = sync()
        s.gestureBegan()
        _ = s.gestureEnded(completed: true, visible: 1181, scrollBusy: true /* another swipe live */,
                           reduceMotion: false, inWindow: true, now: 20)
        XCTAssertTrue(s.gestureActive)
    }

    // MARK: watchdog (lost delegate callback → self-heal)

    func testWatchdogHealsAfterLostCallback() {
        var s = sync()
        s.gestureBegan()
        _ = request(&s, 1185, visible: 1180)      // parked
        // didFinishAnimating never arrives; the page is stuck on 1180
        let fx = s.watchdog(desired: 1185, visible: 1180, scrollBusy: false)
        XCTAssertEqual(fx, [.log("watchdog-heal"), .show(1185, PagerSync.Transition.none)])
        XCTAssertFalse(s.gestureActive)
        XCTAssertNil(s.pending)
    }

    func testWatchdogReArmsWhileScrollBusy() {
        var s = sync()
        s.gestureBegan()
        _ = request(&s, 1185, visible: 1180)
        XCTAssertEqual(s.watchdog(desired: 1185, visible: 1180, scrollBusy: true), [.armWatchdog])
    }

    func testWatchdogNoOpWhenNothingPending() {
        var s = sync()
        XCTAssertEqual(s.watchdog(desired: 5, visible: 5, scrollBusy: false), [])
    }

    // MARK: fuzz — the visible index always converges to the desired index

    /// Replays 5,000 random event sequences through the model + a tiny simulator of the coordinator's
    /// effects, and asserts that whenever the system is quiescent (no gesture, no parked request), the
    /// simulated visible index equals the last desired index. This is the machine-checked statement of
    /// invariant I1 — the property the shipped build violated.
    func testFuzzConvergence() {
        var rng = SplitMix64(seed: 0xC0FFEE_D00D)   // deterministic → reproducible, never flaky in CI
        for _ in 0..<5000 {
            var s = sync()
            var visible: Int? = Int.random(in: 1...1430, using: &rng)
            var desired = visible ?? 1
            var now: TimeInterval = 0
            var gestureOpen = false

            func apply(_ effects: [PagerSync.Effect]) {
                for e in effects {
                    switch e {
                    case .show(let i, _): visible = i
                    case .settle(let i): visible = i; desired = i
                    case .armWatchdog, .log: break
                    }
                }
            }

            for _ in 0..<Int.random(in: 1...12, using: &rng) {
                now += Double.random(in: 0...0.6, using: &rng)
                switch Int.random(in: 0...3, using: &rng) {
                case 0:                                   // external request
                    desired = Int.random(in: -3...1435, using: &rng)
                    apply(s.request(desired: desired, visible: visible, scrollBusy: gestureOpen,
                                    reduceMotion: Bool.random(using: &rng), inWindow: true, now: now))
                case 1:                                   // gesture begins
                    if !gestureOpen { s.gestureBegan(); gestureOpen = true }
                case 2 where gestureOpen:                 // gesture ends on a neighbour
                    let landed = min(max(1, (visible ?? 1) + [-1, 1].randomElement(using: &rng)!), 1430)
                    apply(s.gestureEnded(completed: Bool.random(using: &rng), visible: landed, scrollBusy: false,
                                         reduceMotion: false, inWindow: true, now: now))
                    gestureOpen = false
                case 3:                                   // watchdog tick
                    apply(s.watchdog(desired: desired, visible: visible, scrollBusy: gestureOpen))
                default: break
                }
            }

            // Drain to quiescence exactly as the real system does: end any live gesture, then let the
            // watchdog heal a parked request and let reconcile() (which SwiftUI runs on every
            // updateUIViewController after any state change) drive the visible page to `desired`.
            if gestureOpen {
                apply(s.gestureEnded(completed: true, visible: visible, scrollBusy: false,
                                     reduceMotion: false, inWindow: true, now: now))
                gestureOpen = false
            }
            var guardCount = 0
            while guardCount < 10 {
                let before = visible
                apply(s.watchdog(desired: desired, visible: visible, scrollBusy: false))
                apply(s.request(desired: desired, visible: visible, scrollBusy: false,
                                reduceMotion: false, inWindow: true, now: now + Double(guardCount)))
                if visible == before && s.pending == nil { break }
                guardCount += 1
            }
            let clampedDesired = min(max(1, desired), 1430)
            XCTAssertEqual(visible, clampedDesired, "did not converge: desired \(desired) visible \(String(describing: visible))")
        }
    }
}

/// A tiny deterministic PRNG so the convergence fuzz is reproducible (a seeded sequence catches the
/// same edge cases on every run and in CI, instead of flaking with the system RNG).
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
