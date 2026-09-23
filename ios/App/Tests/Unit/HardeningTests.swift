import XCTest
@testable import SGGS

/// Regression tests for the Phase-1 correctness hardening (premium overhaul, 2026-07):
/// the single-root-sheet swap race and the deep-link/resume interaction.
final class HardeningTests: XCTestCase {

    // MARK: single root sheet — present/flush protocol

    /// Simple case: presenting with no sheet up shows immediately.
    @MainActor
    func testPresentShowsImmediatelyWhenIdle() {
        let c = AppContainer()
        c.sheetHostDidAppear()                // the TabView (sheet host) is mounted
        c.present(.hukam)
        XCTAssertNotNil(c.presentation)
        XCTAssertNil(c.pendingPresentation)
    }

    /// Swap case (the Trail→Shabad path the UI test covers): a second present queues,
    /// dismisses the first, and the onDismiss flush shows the queued one.
    @MainActor
    func testPresentSwapQueuesUntilDismissCompletes() {
        let c = AppContainer()
        c.sheetHostDidAppear()                // the TabView (sheet host) is mounted
        c.present(.hukam)
        c.present(.shabad(compId: 42))
        XCTAssertNil(c.presentation, "current sheet must start dismissing")
        XCTAssertNotNil(c.pendingPresentation)
        c.flushPendingPresentation()   // RootView's sheet onDismiss
        guard case .shabad(let id, _)? = c.presentation else {
            return XCTFail("queued modal must present after the dismiss completes")
        }
        XCTAssertEqual(id, 42)
        XCTAssertNil(c.pendingPresentation)
    }

    /// The race this hardening fixes: a THIRD present arriving while the swap-dismiss is
    /// still animating. Before the fix it assigned `presentation` mid-dismiss (dropped by
    /// SwiftUI) and the subsequent flush discarded the queue — a stranded, sheetless state.
    /// Now: latest intent wins, and it presents exactly once the dismiss completes.
    @MainActor
    func testRapidTriplePresentNeverStrandsTheQueue() {
        let c = AppContainer()
        c.sheetHostDidAppear()                // the TabView (sheet host) is mounted
        c.present(.hukam)                     // sheet A up
        c.present(.shabad(compId: 1))         // queue B, dismiss A
        c.present(.shabad(compId: 2))         // mid-dismiss: must REPLACE the queue, not present
        XCTAssertNil(c.presentation, "nothing may present while the dismiss is in flight")
        c.flushPendingPresentation()          // A's dismiss completes
        guard case .shabad(let id, _)? = c.presentation else {
            return XCTFail("the latest modal must present after the dismiss")
        }
        XCTAssertEqual(id, 2, "latest intent wins")
        XCTAssertNil(c.pendingPresentation)
        // and the protocol is re-armed: a later plain present works
        c.flushPendingPresentation()
        XCTAssertNotNil(c.presentation)
    }

    /// A user-initiated dismiss (drag down, Done) must re-arm presenting immediately.
    @MainActor
    func testUserDismissReArmsPresenting() {
        let c = AppContainer()
        c.sheetHostDidAppear()                // the TabView (sheet host) is mounted
        c.present(.hukam)
        c.presentation = nil                  // .sheet(item:) binding writes nil on user dismiss
        c.flushPendingPresentation()          // onDismiss with nothing queued
        c.present(.shabad(compId: 7))
        XCTAssertNotNil(c.presentation, "present must not stay blocked after a normal dismiss")
    }

    /// A present that arrives BEFORE the TabView mounts (cold launch from a widget /
    /// Spotlight / sggs:// link while the integrity check runs) has nothing to dismiss.
    /// Before the fix a second such present set `dismissInFlight` with no onDismiss ever
    /// coming → every later present queued forever (no modal for the rest of the session).
    @MainActor
    func testPresentBeforeSheetHostNeverLatches() {
        let c = AppContainer()
        XCTAssertFalse(c.sheetHosted)
        c.present(.hukam)
        c.present(.shabad(compId: 1))         // latest intent wins, nothing to wait for
        guard case .shabad(let id, _)? = c.presentation else { return XCTFail("must present directly") }
        XCTAssertEqual(id, 1)
        XCTAssertNil(c.pendingPresentation)
        c.sheetHostDidAppear()                // TabView mounts: the pending item shows as-is
        guard case .shabad(let id2, _)? = c.presentation else { return XCTFail("host mount must keep it") }
        XCTAssertEqual(id2, 1)
        // and the normal swap protocol works from here on
        c.present(.hukam)
        XCTAssertNil(c.presentation, "swap: current sheet dismisses first")
        c.flushPendingPresentation()
        guard case .hukam? = c.presentation else { return XCTFail("queued modal must present") }
    }

    /// Integrity re-verify unmounts the TabView under an open sheet: the host-disappear
    /// hook must re-arm presenting (no onDismiss will come for that sheet).
    @MainActor
    func testHostDisappearReArmsPresenting() {
        let c = AppContainer()
        c.sheetHostDidAppear()
        c.present(.hukam)
        c.present(.shabad(compId: 3))         // dismiss in flight…
        c.sheetHostDidDisappear()             // …but the host vanished (re-verify)
        c.present(.shabad(compId: 4))
        guard case .shabad(let id, _)? = c.presentation else { return XCTFail("must not latch") }
        XCTAssertEqual(id, 4)
        // host comes back (re-verify passed): the pending item shows, and presenting keeps working
        c.sheetHostDidAppear()
        guard case .shabad(let id2, _)? = c.presentation else { return XCTFail("host mount must keep it") }
        XCTAssertEqual(id2, 4)
        c.present(.hukam)                     // swap protocol re-armed
        XCTAssertNil(c.presentation)
        c.flushPendingPresentation()
        guard case .hukam? = c.presentation else { return XCTFail("queued modal must present") }
    }

    /// The scene-active watchdog must NEVER assign `presentation` while a swap-dismiss is in
    /// flight (SwiftUI would drop it and the later onDismiss would find nothing queued —
    /// the modal would vanish). It may only act when the protocol is genuinely idle.
    @MainActor
    func testWatchdogNeverPresentsMidDismiss() {
        let c = AppContainer()
        c.sheetHostDidAppear()
        c.present(.hukam)
        c.present(.shabad(compId: 9))         // dismiss in flight, B queued
        c.flushIfIdle()                       // scene became active mid-dismiss
        XCTAssertNil(c.presentation, "watchdog must not present mid-dismiss")
        XCTAssertNotNil(c.pendingPresentation, "queue must survive the watchdog")
        c.flushPendingPresentation()          // the real onDismiss
        guard case .shabad(let id, _)? = c.presentation else { return XCTFail("queued modal must present") }
        XCTAssertEqual(id, 9)
        // genuinely idle with something queued: the watchdog may flush
        c.presentation = nil; c.flushPendingPresentation()
        c.pendingPresentation = .hukam
        c.flushIfIdle()
        guard case .hukam? = c.presentation else { return XCTFail("idle watchdog must flush") }
    }

    // MARK: precision routing (line-level deep links)

    /// `?line=` lands the Reader on a verse; malformed/negative values are dropped, and a later
    /// `openAng` without a line clears any stale pending id.
    @MainActor
    func testAngDeepLinkCarriesLineAndClears() {
        let c = AppContainer(); let r = Router()
        r.handle(URL(string: "sggs://ang/500?line=123")!, container: c)
        XCTAssertEqual(r.readerAng, 500); XCTAssertEqual(r.pendingReaderLineId, 123)
        r.handle(URL(string: "sggs://ang/501?line=abc")!, container: c)
        XCTAssertEqual(r.readerAng, 501); XCTAssertNil(r.pendingReaderLineId)
        r.openAng(7, lineId: 9); XCTAssertEqual(r.pendingReaderLineId, 9)
        r.handle(URL(string: "sggs://ang/8?line=-1")!, container: c)
        XCTAssertEqual(r.readerAng, 8); XCTAssertNil(r.pendingReaderLineId, "negative line must clear, not linger")
        r.openAng(9); XCTAssertNil(r.pendingReaderLineId)
    }

    @MainActor
    func testShabadDeepLinkCarriesLine() {
        let c = AppContainer(); c.sheetHostDidAppear(); let r = Router()
        r.handle(URL(string: "sggs://shabad/12?line=99")!, container: c)
        guard case .shabad(let comp, let line)? = c.presentation else { return XCTFail("shabad not presented") }
        XCTAssertEqual(comp, 12); XCTAssertEqual(line, 99)
        XCTAssertEqual(c.presentation?.id, "shabad-12", "focus line must not change the sheet identity")
        XCTAssertEqual(SpotlightIndex.lineId(fromIdentifier: "saved-4321-comp-77"), 4321)
        XCTAssertEqual(SpotlightIndex.compId(fromIdentifier: "saved-4321-comp-77"), 77)
        XCTAssertNil(SpotlightIndex.lineId(fromIdentifier: "foreign"))
    }

    // MARK: deep-link vs resume-last-Ang

    /// `sggs://ang/1` (widget fallback, Siri intent) must be distinguishable from the
    /// untouched default so the Reader's resume-last-Ang never overrides it.
    @MainActor
    func testExplicitAngNavigationSetsTheFlag() {
        let c = AppContainer()
        let r = Router()
        XCTAssertFalse(r.navigatedToAngExplicitly, "cold start: resume is allowed")
        r.handle(URL(string: "sggs://ang/1")!, container: c)
        XCTAssertTrue(r.navigatedToAngExplicitly, "deep link to Ang 1 is explicit navigation")
        XCTAssertEqual(r.readerAng, 1)
        XCTAssertEqual(r.selectedTab, .reader)
    }

    // MARK: compositions (Explore → Index → its own reader)

    /// A composition opens on the EXPLORE stack, under the Index — never by switching to the
    /// Nitnem tab, and never by replacing the Reader's Ang.
    @MainActor
    func testOpenCompositionPushesOnTheExploreStack() {
        let r = Router()
        r.openComposition(key: "sukhmani")
        XCTAssertEqual(r.selectedTab, .explore)
        XCTAssertEqual(r.explorePath.count, 2, "Index then the composition, so Back lands on the Index")
        XCTAssertTrue(r.nitnemPath.isEmpty, "the Nitnem stack must not move")
        XCTAssertFalse(r.navigatedToAngExplicitly, "a composition read is not an Ang navigation")
    }

    /// A hostile key or an unknown variant must change nothing at all.
    @MainActor
    func testMalformedCompositionRequestChangesNothing() {
        let r = Router()
        for (k, v) in [("../etc", ""), ("", ""), ("SUKHMANI", ""), ("sukhmani", "bogus"),
                       ("sukhmani", "x' OR 1=1"), (String(repeating: "a", count: 33), "")] {
            r.openComposition(key: k, variant: v)
        }
        XCTAssertEqual(r.selectedTab, .nitnem, "still the launch tab")
        XCTAssertTrue(r.explorePath.isEmpty)
    }

    /// `sggs://bani/<key>` stays the Nitnem entry point, but asking for ONE form of a bani
    /// (`?variant=`) is a composition read — otherwise a Live-Activity tap on the printed Vaar
    /// would reopen the kirtan form in Nitnem.
    @MainActor
    func testBaniDeepLinkRoutesByVariant() {
        let c = AppContainer(); let r = Router()
        r.handle(URL(string: "sggs://bani/sukhmani")!, container: c)
        XCTAssertEqual(r.selectedTab, .nitnem)
        XCTAssertEqual(r.nitnemPath.count, 1)

        r.handle(URL(string: "sggs://bani/asa_di_vaar?variant=printed")!, container: c)
        XCTAssertEqual(r.selectedTab, .explore)
        XCTAssertEqual(r.explorePath.count, 2)

        let before = r.explorePath.count
        r.handle(URL(string: "sggs://composition/asa_di_vaar?variant=nope")!, container: c)
        XCTAssertEqual(r.explorePath.count, before, "an unknown variant must be ignored")
    }

    /// Hostile/malformed deep links must neither navigate nor set the explicit flag.
    @MainActor
    func testMalformedAngLinkChangesNothing() {
        let c = AppContainer()
        let r = Router()
        for bad in ["sggs://ang/0", "sggs://ang/1431", "sggs://ang/abc", "sggs://ang/"] {
            r.handle(URL(string: bad)!, container: c)
        }
        XCTAssertFalse(r.navigatedToAngExplicitly)
        XCTAssertEqual(r.readerAng, 1)
    }
}
