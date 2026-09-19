import XCTest
import GurbaniSearchKit
@testable import SGGS

/// `ReaderModel` is the Reader's Ang cache. These pin the two defects behind the "blank Ang after
/// a few swipes" report (TestFlight 1.3.0 (4)): a page evicting ITSELF because the eviction anchor
/// never followed a swipe, and a page mounting mid-pre-warm getting nothing back. Pure logic over
/// an injected loader — no corpus, no text.
@MainActor
final class ReaderModelTests: XCTestCase {

    /// Records calls; can stall or fail chosen Angs.
    private actor Loader {
        private(set) var calls: [Int: Int] = [:]
        private var failing: Set<Int> = []
        private var gates: [Int: CheckedContinuation<Void, Never>] = [:]
        private var gated: Set<Int> = []

        func fail(_ ang: Int, _ on: Bool) { if on { failing.insert(ang) } else { failing.remove(ang) } }
        func gate(_ ang: Int) { gated.insert(ang) }
        func isWaiting(_ ang: Int) -> Bool { gates[ang] != nil }
        func open(_ ang: Int) { gated.remove(ang); gates.removeValue(forKey: ang)?.resume() }
        func count(_ ang: Int) -> Int { calls[ang] ?? 0 }

        func load(_ ang: Int) async throws -> AngPage {
            calls[ang, default: 0] += 1
            if gated.contains(ang) { await withCheckedContinuation { gates[ang] = $0 } }
            if failing.contains(ang) { throw CancellationError() }
            return AngPage(ang: ang, lines: [], continuedFrom: nil, raag: nil, section: nil, authors: [])
        }
    }

    private func make() -> (ReaderModel, Loader) {
        let loader = Loader()
        return (ReaderModel(loader: { try await loader.load($0) }), loader)
    }

    private func settle() async { for _ in 0..<20 { await Task.yield() }; try? await Task.sleep(for: .milliseconds(20)) }

    /// Bug A. A swipe mounts the neighbour BEFORE it is current, then the router settles on it.
    /// Every page of a long run must come back non-nil — before the fix the 4th was evicted on arrival.
    func testSwipeRunNeverEvictsThePageItJustLoaded() async {
        for (start, step) in [(1100, 1), (348, 1), (915, -1)] {
            let (model, _) = make()
            model.setCurrent(start)
            let first = await model.ensure(start)
            XCTAssertNotNil(first)
            await settle()
            var ang = start
            for _ in 0..<12 {
                let next = ang + step
                let mounted = await model.ensure(next)          // neighbour mounts, not yet current
                XCTAssertNotNil(mounted, "Ang \(next) must render after swiping from \(start)")
                model.setCurrent(next)                          // swipe settles
                await settle()
                XCTAssertNotNil(model.page(next), "the current Ang must stay cached")
                ang = next
            }
        }
    }

    /// Bug B. A page that mounts while its Ang is being pre-warmed awaits that load — one read, a page back.
    func testEnsureDuringPrefetchAwaitsTheSameLoad() async {
        let (model, loader) = make()
        await loader.gate(501)
        model.setCurrent(500)                                   // pre-warms 501 (stalls at the gate)
        for _ in 0..<200 { if await loader.isWaiting(501) { break }; await Task.yield() }
        let waiting = await loader.isWaiting(501)
        XCTAssertTrue(waiting, "the pre-warm of 501 should be in flight")

        async let mounted = model.ensure(501)
        await settle()
        await loader.open(501)
        let page = await mounted
        XCTAssertEqual(page?.ang, 501)
        let reads = await loader.count(501)
        XCTAssertEqual(reads, 1, "the mount must share the pre-warm's read, not start another")
    }

    func testFailureIsNotCachedAndRetrySucceeds() async {
        let (model, loader) = make()
        await loader.fail(700, true)
        let failed = await model.ensure(700)
        XCTAssertNil(failed)
        XCTAssertNil(model.page(700))
        await loader.fail(700, false)
        let retried = await model.ensure(700)
        XCTAssertEqual(retried?.ang, 700)
    }

    func testEvictionKeepsAnchorNeighbourhoodAndCapacity() async {
        let (model, _) = make()
        model.setCurrent(200)
        for n in stride(from: 180, through: 230, by: 1) { _ = await model.ensure(n) }
        await settle()
        XCTAssertLessThanOrEqual(model.pages.count, ReaderModel.capacity)
        for n in 198...202 { XCTAssertNotNil(model.page(n), "anchor ±2 must survive eviction (Ang \(n))") }
    }

    func testBounds() async {
        let (model, loader) = make()
        model.setCurrent(1)
        let first = await model.ensure(1)
        XCTAssertEqual(first?.ang, 1)
        model.setCurrent(1430)
        let last = await model.ensure(1430)
        XCTAssertEqual(last?.ang, 1430)
        let below = await model.ensure(0), above = await model.ensure(1431)
        XCTAssertNil(below); XCTAssertNil(above)
        await settle()
        let zero = await loader.count(0), over = await loader.count(1431)
        XCTAssertEqual(zero + over, 0, "nothing outside 1…1430 is ever read")
        model.setCurrent(99_999)
        XCTAssertEqual(model.anchor, 1430)
    }

    /// A page task cancelled mid-load (swiped away) must not cancel the shared load another page awaits.
    func testCancelledCallerDoesNotCancelTheSharedLoad() async {
        let (model, loader) = make()
        await loader.gate(900)
        let doomed = Task { await model.ensure(900) }
        for _ in 0..<200 { if await loader.isWaiting(900) { break }; await Task.yield() }
        async let survivor = model.ensure(900)
        await settle()
        doomed.cancel()
        await loader.open(900)
        let page = await survivor
        XCTAssertEqual(page?.ang, 900)
        let reads = await loader.count(900)
        XCTAssertEqual(reads, 1)
    }
}
