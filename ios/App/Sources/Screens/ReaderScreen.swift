import SwiftUI
import UIKit
import OSLog
import GurbaniSearchKit

@MainActor @Observable
final class ReaderModel {
    /// Ang cache shared across the pager's live pages: a page turn paints instantly from here,
    /// the "continues on Ang N+1" pill reads the next page's boundary field, and neighbours are
    /// pre-warmed so a fast double-swipe never shows a skeleton. Bounded, evicted by distance
    /// from the anchor (the current Ang).
    private(set) var pages: [Int: AngPage] = [:]
    /// One shared load per Ang. A page that mounts while its Ang is being pre-warmed AWAITS that
    /// load — the old `inflight` set made it skip the load, read an empty cache once, and sit on
    /// the skeleton forever (TestFlight 1.3.0 (4)).
    private var loads: [Int: Task<AngPage?, Never>] = [:]
    /// The Ang eviction measures distance from. Follows `router.readerAng` via `setCurrent` — it
    /// must not be owned by `ensure`: a swiped-to page mounts BEFORE it is current, so the anchor
    /// stayed on the last jump and the 4th swipe evicted the very page it had just loaded.
    private(set) var anchor = 1
    private let corpus: CorpusActor?
    private let loader: @Sendable (Int) async throws -> AngPage
    let hasTiming: Bool

    static let bounds = 1...1430
    static let capacity = 7                      // anchor ±2 protected + slack
    private static let log = Logger(subsystem: "org.sggs", category: "Reader")

    init(corpus: CorpusActor?) {
        self.corpus = corpus
        self.hasTiming = corpus?.capabilities.hasTiming ?? false
        self.loader = { n in
            guard let corpus else { throw CancellationError() }
            return try await corpus.ang(n)
        }
    }

    /// Test seam: any loader, no corpus.
    init(loader: @escaping @Sendable (Int) async throws -> AngPage) {
        self.corpus = nil; self.hasTiming = false; self.loader = loader
    }

    func page(_ ang: Int) -> AngPage? { pages[ang] }

    /// The reader is now on `ang` (swipe-settle, chevron, jump, deep link, resume, pill — every
    /// writer of `router.readerAng`). Moves the eviction anchor and pre-warms around it.
    func setCurrent(_ ang: Int) {
        anchor = min(max(Self.bounds.lowerBound, ang), Self.bounds.upperBound)
        prefetchNeighbours(of: anchor)
    }

    /// The page for `ang` (local SQLite, ~ms), or nil if the read failed — failures are never
    /// cached, so calling again really retries. Returns the page it loaded rather than making the
    /// caller re-read the cache, so eviction can never blank a page that was just loaded.
    @discardableResult
    func ensure(_ ang: Int) async -> AngPage? {
        guard Self.bounds.contains(ang) else { return nil }
        let page = await load(ang)
        prefetchNeighbours(of: ang)
        return page
    }

    /// Coalesced load. MainActor-isolated with no suspension between the lookup and the insert,
    /// so two callers can never start two loads. The shared task is unstructured on purpose: a
    /// cancelled page task must not cancel a load another page is awaiting.
    private func load(_ ang: Int) async -> AngPage? {
        if let cached = pages[ang] { return cached }
        if let running = loads[ang] { return await running.value }
        let loader = self.loader
        let task = Task<AngPage?, Never> {
            do { return try await loader(ang) } catch {
                Self.log.error("Ang \(ang, privacy: .public) failed to load: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        loads[ang] = task
        let page = await task.value
        loads[ang] = nil
        if let page { remember(page) }
        return page
    }

    /// Timing claims for a raag (metadata-only; nil = no chip). Not cached — cheap, per page.
    func timing(forRaag raag: String) async -> RaagTiming? {
        guard hasTiming, let corpus else { return nil }
        let t = await corpus.timingRaag(name: raag)
        return (t.available && !t.claims.isEmpty) ? t : nil
    }

    /// True when the composition at the end of `ang` carries on into the next Ang. Derived
    /// only from the next page's `continuedFrom` (the server's boundary field) — never from
    /// the last line's comp_id, which may be a header that opens the next composition.
    func continuesOn(after ang: Int) -> Bool {
        guard let next = pages[ang + 1], let from = next.continuedFrom else { return false }
        return from <= ang
    }

    /// Cache `page`, then trim to capacity. Never evicts the anchor ±2 (the pager's live pages and
    /// the "continues on" lookahead) nor the page just remembered; drops the farthest of the rest.
    private func remember(_ page: AngPage) {
        pages[page.ang] = page
        while pages.count > Self.capacity {
            let evictable = pages.keys.filter { abs($0 - anchor) > 2 && $0 != page.ang }
            guard let far = evictable.max(by: { abs($0 - anchor) < abs($1 - anchor) }) else { return }
            pages.removeValue(forKey: far)
        }
    }

    /// Warm ang±1 and ±2 in their own tasks so a fast swipe never hits an unloaded page.
    private func prefetchNeighbours(of ang: Int) {
        for n in [ang + 1, ang - 1, ang + 2, ang - 2]
        where Self.bounds.contains(n) && pages[n] == nil && loads[n] == nil {
            Task { [weak self] in _ = await self?.load(n) }
        }
    }

    /// The chip line for a raag's timing, from the first primary claim (or seasonal note).
    static func timingChipText(_ t: RaagTiming) -> String? {
        if let primary = t.claims.first(where: { $0.claimType == "primary" }), let p = primary.pahar {
            return "\(Pahar.label(p)) · \(Pahar.range(p))"
        }
        if let seasonal = t.claims.first(where: { $0.claimType == "seasonal" }), let season = seasonal.season {
            return "in season · \(season)"
        }
        if t.claims.contains(where: { $0.claimType == "ceremonial" }) { return "ceremonial · any time" }
        return nil
    }
}

struct ReaderScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @State private var model: ReaderModel?
    /// Sehaj focus: chrome collapses, generous leading, pure Gurmukhi (an explicit mode). The
    /// display toggles + text size live in the Reading-options popover, which reads these keys itself.
    @AppStorage("sggs_focus_mode") private var focusMode = false
    /// Resume where the reader left off (persisted on every Ang change; 1 = never read).
    @AppStorage("sggs_last_ang") private var lastAng = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showJump = false
    /// True when Jump was opened from the "Ang N" title — the sheet then opens with the keypad up.
    @State private var jumpTyping = false
    @State private var showOptions = false
    @State private var resumed = false
    /// Ambient chrome (the bottom page bar): hidden while reading downwards, restored on any
    /// upward scroll. Driven only by the CURRENT page's scroll (AngPageView gates its reports).
    @State private var chromeHidden = false
    @State private var lastOffset: CGFloat = 0
    @State private var downRun: CGFloat = 0
    @State private var upRun: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    /// Set on every Ang change: the next scroll report is the *new* page's offset, not a scroll on the
    /// old one, so it must re-baseline `lastOffset` instead of being read as a big downward run (which
    /// would wrongly hide the bottom bar on arriving at a page previously read partway down).
    @State private var justTurned = false

    var body: some View {
        @Bindable var router = container.router
        NavigationStack {
            Group {
                if let model {
                    // Finger-tracked Ang-to-Ang paging (UIPageViewController): each page is a live
                    // AngPageView, so a swipe follows the finger, rubber-bands at 1/1430, and a
                    // page's scroll position survives a swipe-back. `readerAng` is the single source
                    // of truth — the pager writes it via `pagerSettled` on a swipe, and external
                    // navigation (Jump, deep link, chevrons, pills) drives the pager through it.
                    AngPager(index: router.readerAng, bounds: 1...1430, reduceMotion: reduceMotion) { ang in
                        AngPageView(ang: ang, model: model,
                                    onOpenJump: { showJump = true },
                                    onScroll: { y, content, viewport in
                                        if content > 0 { contentHeight = content }
                                        if viewport > 0 { viewportHeight = viewport }
                                        if !y.isNaN { handleScroll(offset: y) }
                                    })
                            .environment(container)
                            .environment(\.palette, palette)
                    } onSettle: { n in
                        Haptics.tap(.soft)
                        router.pagerSettled(on: n)
                    }
                    .ignoresSafeArea(edges: .horizontal)
                } else { Color.clear }
            }
            .background(GeometryReader { g in Color.clear.onAppear { viewportHeight = g.size.height }
                .onChange(of: g.size.height) { _, h in viewportHeight = h } })
            .background(Ink.paper.ignoresSafeArea())
            .navigationTitle("Ang \(String(router.readerAng))")
            .navigationBarTitleDisplayMode(.inline)
            // The navigation bar stays visible. Toggling it from scroll offsets re-lays-out the
            // scroll view (the top inset changes by the bar height), which the scroll handler read
            // as a reverse scroll → show → hide … an endless update loop that froze the app on a
            // 120 Hz device (TestFlight 1.1.3 (1), watchdog 0x8BADF00D). Only the bottom page bar
            // fades — opacity/offset don't change layout, so it cannot feed back.
            .onChange(of: router.readerAng) { _, n in
                justTurned = true          // re-baseline scroll tracking for the new page (C5)
                showChrome()               // page turn: chrome back
                UIAccessibility.post(notification: .pageScrolled, argument: "Ang \(n)")
            }
            .onChange(of: focusMode) { _, _ in showChrome() }
            .onChange(of: container.presentation?.id) { _, id in if id == nil { showChrome() } }
            // Page controls live in a bottom safe-area inset, NOT a `.bottomBar` toolbar: inside a
            // TabView on iOS 26 the bottom toolbar is drawn UNDER the floating glass tab bar, so
            // Previous / Hukam / Next were invisible (verified in the simulator; the July
            // baseline screenshots show the same). The inset is laid out above the tab bar.
            .safeAreaInset(edge: .bottom) {
                if !focusMode {
                    let prev = router.readerAng - 1
                    let next = router.readerAng + 1
                    VStack(spacing: Theme.Space.xs) {
                        // "Ang N of 1430" + a Granth-progress hairline — a thumb-reachable third
                        // way into Jump, and a sense of place in the whole Granth.
                        Button { Haptics.tap(); showJump = true } label: {
                            VStack(spacing: 3) {
                                Text("Ang \(String(router.readerAng)) of 1430")
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Ink.hairline).frame(height: 2)
                                        Capsule().fill(palette.accent)
                                            .frame(width: g.size.width * CGFloat(router.readerAng) / 1430, height: 2)
                                    }
                                }.frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("readerProgress")
                        .accessibilityHint("Jump to another Ang")

                        // Chevrons show their destination Ang; the whole side is a ≥44 pt target.
                        HStack {
                            Button { Haptics.tap(); router.openAng(prev) } label: {
                                HStack(spacing: Theme.Space.xs) {
                                    Image(systemName: "chevron.left")
                                    if prev >= 1 { Text(String(prev)).monospacedDigit() }
                                }
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .disabled(router.readerAng <= 1)
                            .accessibilityLabel("Previous Ang")
                            .accessibilityValue(prev >= 1 ? "Ang \(prev)" : "")
                            .accessibilityIdentifier("prevAng")
                            Spacer()
                            Button { Haptics.tap(); container.present(.hukam) } label: {
                                // Keep the word where it fits; at large Dynamic Type sizes fall back to
                                // the glyph alone so the chevrons + their numbers never truncate.
                                ViewThatFits(in: .horizontal) {
                                    Label("Hukam", systemImage: "sparkles").lineLimit(1)
                                    Image(systemName: "sparkles")
                                }
                                .frame(minHeight: 44)
                            }
                            .accessibilityLabel("Hukam")
                            Spacer()
                            Button { Haptics.tap(); router.openAng(next) } label: {
                                HStack(spacing: Theme.Space.xs) {
                                    if next <= 1430 { Text(String(next)).monospacedDigit() }
                                    Image(systemName: "chevron.right")
                                }
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .disabled(router.readerAng >= 1430)
                            .accessibilityLabel("Next Ang")
                            .accessibilityValue(next <= 1430 ? "Ang \(next)" : "")
                            .accessibilityIdentifier("nextAng")
                        }
                        .font(.body.weight(.medium))
                        .padding(.horizontal, Theme.Space.m)
                        .background(Capsule().fill(Ink.card))
                        .overlay(Capsule().strokeBorder(Ink.hairline))
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .frame(maxWidth: 520)                 // iPad: a reading-width capsule, centred
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Theme.Space.xs)
                    .opacity(chromeHidden ? 0 : 1)
                    .offset(y: chromeHidden ? 40 : 0)
                    .allowsHitTesting(!chromeHidden)
                    .accessibilityHidden(chromeHidden)   // leaves the a11y tree when faded out
                    .appAnimation(Motion.gentle, value: chromeHidden)
                    .accessibilityIdentifier("readerPageBar")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // A labelled control, not a cryptic "#": word + open-book glyph so a first-time
                    // or elderly reader knows it jumps to an Ang. Keeps the id/label the tests use.
                    Button { Haptics.tap(); showJump = true } label: {
                        Label("Go to", systemImage: "book.pages")
                    }
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("Jump to Ang")
                    .accessibilityIdentifier("jumpToAng")
                }
                // The title is a control: tap "Ang N" to type where to go. `.navigationTitle` stays
                // set — it names the bar for VoiceOver's rotor and the XCUITests (`navigationBars["Ang N"]`).
                ToolbarItem(placement: .principal) {
                    Button { Haptics.tap(); jumpTyping = true; showJump = true } label: {
                        HStack(spacing: Theme.Space.xs) {
                            Text("Ang \(String(router.readerAng))")
                                .font(Brand.heading(.headline)).monospacedDigit()
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold)).foregroundStyle(palette.accent)
                                .accessibilityHidden(true)
                        }
                        .lineLimit(1)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)   // never crowds the side buttons
                    .accessibilityLabel("Ang \(String(router.readerAng))")
                    .accessibilityHint("Type an Ang number to go to")
                    .accessibilityIdentifier("angTitle")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showOptions = true } label: { Image(systemName: "textformat.size") }
                        .accessibilityLabel("Reading options")
                        .accessibilityIdentifier("readerOptions")
                        .popover(isPresented: $showOptions) { ReaderOptionsPopover().environment(container) }
                }
            }
            .sheet(isPresented: $showJump, onDismiss: { jumpTyping = false }) {
                JumpToAngSheet(current: router.readerAng, focusField: jumpTyping) { n in router.openAng(n) }
            }
        }
        .task { await container.loadMeta() }   // raag roman names + Jump-sheet ticks (idempotent)
        .task(id: container.router.readerAng) {
            if model == nil { model = ReaderModel(corpus: container.corpus) }
            // The eviction anchor follows EVERY Ang change (swipe-settle included) — see ReaderModel.
            model?.setCurrent(container.router.readerAng)
            // resume-last-Ang: once per launch, only from the untouched default. The router
            // flag (not the Ang value) marks explicit navigation, so sggs://ang/1 is honoured.
            if !resumed {
                resumed = true
                if !container.router.navigatedToAngExplicitly,
                   container.router.readerAng == 1, lastAng > 1 {
                    container.router.resumeAng(lastAng)   // documented resume writer (single-writer rule)
                    return   // the task re-fires with the resumed Ang; the pager builds from it
                }
            }
            lastAng = container.router.readerAng   // per-page loading + landing live in AngPageView
        }
    }
}

extension ReaderScreen {
    /// Ambient chrome (bottom page bar only — never the nav bar; see the watchdog note above).
    /// Hide when clearly reading downwards (> 24 pt run, past 80 pt, on a page taller than the
    /// viewport + 120 so short Angs never flicker); restore on ≥ 8 pt upwards or at the top. Never
    /// for VoiceOver / Switch Control users — the chrome is their navigation. Fed only by the
    /// current page (AngPageView gates its scroll reports).
    fileprivate func handleScroll(offset: CGFloat) {
        if justTurned {                    // first report after a page turn: re-baseline, don't act (C5)
            justTurned = false
            lastOffset = offset
            downRun = 0; upRun = 0
            return
        }
        let delta = offset - lastOffset
        lastOffset = offset
        if UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning { showChrome(); return }
        if delta > 0 { downRun += delta; upRun = 0 } else if delta < 0 { upRun += -delta; downRun = 0 }
        if !chromeHidden, downRun > 24, offset > 80, contentHeight > viewportHeight + 120 {
            MotionGate.run(Motion.gentle) { chromeHidden = true }
        } else if chromeHidden, upRun >= 8 || offset <= 0 {
            showChrome()
        }
    }

    fileprivate func showChrome() {
        downRun = 0; upRun = 0
        if chromeHidden { MotionGate.run(Motion.gentle) { chromeHidden = false } }
    }
}

/// A capsule that navigates between compositions across an Ang boundary (backward: "Shabad starts
/// on Ang N"; forward: "Continues on Ang N+1"). One styled, ≥44 pt, accent-washed control for both
/// directions so the two never drift apart again (the backward one shipped as a dead label).
struct ContinuationPill: View {
    let text: String
    let systemImage: String
    let identifier: String
    let hint: String
    var action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.s)
                .frame(minHeight: 44)
                .background(Capsule().fill(palette.wash))
                .overlay(Capsule().strokeBorder(palette.accent.opacity(0.55)))
                .foregroundStyle(palette.accentText)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityHint(hint)
    }
}
