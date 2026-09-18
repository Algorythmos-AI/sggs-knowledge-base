import SwiftUI
import UIKit
import GurbaniSearchKit

@MainActor @Observable
final class ReaderModel {
    /// Ang cache shared across the pager's live pages: a page turn paints instantly from here,
    /// the "continues on Ang N+1" pill reads the next page's boundary field, and neighbours are
    /// pre-warmed so a fast double-swipe never shows a skeleton. Bounded, evicted by distance
    /// from the anchor (the current Ang).
    private(set) var pages: [Int: AngPage] = [:]
    private var inflight: Set<Int> = []
    /// The Ang eviction measures distance from — kept near the reader so live pages survive.
    private var anchor = 1
    private let corpus: CorpusActor?
    let hasTiming: Bool
    init(corpus: CorpusActor?) { self.corpus = corpus; self.hasTiming = corpus?.capabilities.hasTiming ?? false }

    var isReady: Bool { corpus != nil }
    func page(_ ang: Int) -> AngPage? { pages[ang] }

    /// Load `ang` into the cache if absent (local SQLite, ~ms), then pre-warm ±2. Idempotent and
    /// cancellation-safe; the pager calls this per page as it comes on screen.
    func ensure(_ ang: Int) async {
        anchor = ang
        if pages[ang] == nil, !inflight.contains(ang), let corpus {
            inflight.insert(ang)
            if let p = try? await corpus.ang(ang) { remember(p) }
            inflight.remove(ang)
        }
        prefetchNeighbours(of: ang)
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

    private func remember(_ page: AngPage) {
        pages[page.ang] = page
        guard pages.count > 7 else { return }        // current ±2 live + slack
        if let far = pages.keys.filter({ $0 != anchor }).max(by: { abs($0 - anchor) < abs($1 - anchor) }) {
            pages.removeValue(forKey: far)
        }
    }

    /// Warm ang±1 and ±2 in their own tasks so a fast swipe never hits an unloaded page.
    private func prefetchNeighbours(of ang: Int) {
        for n in [ang + 1, ang - 1, ang + 2, ang - 2]
        where (1...1430).contains(n) && pages[n] == nil && !inflight.contains(n) {
            inflight.insert(n)
            Task { [weak self] in
                guard let self, let corpus = self.corpus else { return }
                if let page = try? await corpus.ang(n) { self.remember(page) }
                self.inflight.remove(n)
            }
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
    @AppStorage("sggs_show_timing") private var showTiming = true   // web default-ON parity
    @AppStorage("sggs_show_english") private var showEnglish = true
    @AppStorage("sggs_translit") private var showTranslit = true
    /// Sehaj focus: chrome collapses, generous leading, pure Gurmukhi (an explicit mode).
    @AppStorage("sggs_focus_mode") private var focusMode = false
    /// Resume where the reader left off (persisted on every Ang change; 1 = never read).
    @AppStorage("sggs_last_ang") private var lastAng = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showJump = false
    @State private var resumed = false
    /// Ambient chrome (the bottom page bar): hidden while reading downwards, restored on any
    /// upward scroll. Driven only by the CURRENT page's scroll (AngPageView gates its reports).
    @State private var chromeHidden = false
    @State private var lastOffset: CGFloat = 0
    @State private var downRun: CGFloat = 0
    @State private var upRun: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

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
                    AngPager(index: $router.readerAng, bounds: 1...1430, reduceMotion: reduceMotion) { ang in
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
            .onChange(of: router.readerAng) { _, _ in showChrome() }   // page turn: chrome back
            .onChange(of: focusMode) { _, _ in showChrome() }
            .onChange(of: container.presentation?.id) { _, id in if id == nil { showChrome() } }
            // Page controls live in a bottom safe-area inset, NOT a `.bottomBar` toolbar: inside a
            // TabView on iOS 26 the bottom toolbar is drawn UNDER the floating glass tab bar, so
            // Previous / Hukam / Next were invisible (verified in the simulator; the July
            // baseline screenshots show the same). The inset is laid out above the tab bar.
            .safeAreaInset(edge: .bottom) {
                if !focusMode {
                    HStack {
                        Button { Haptics.tap(); router.openAng(router.readerAng - 1) }
                            label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }
                            .disabled(router.readerAng <= 1)
                            .accessibilityLabel("Previous Ang")
                        Spacer()
                        Button { Haptics.tap(); container.present(.hukam) } label: {
                            Label("Hukam", systemImage: "sparkles").lineLimit(1).frame(minHeight: 44)
                        }
                        Spacer()
                        Button { Haptics.tap(); router.openAng(router.readerAng + 1) }
                            label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44) }
                            .disabled(router.readerAng >= 1430)
                            .accessibilityLabel("Next Ang")
                    }
                    .font(.body.weight(.medium))
                    .padding(.horizontal, Theme.Space.m)
                    .background(Capsule().fill(Ink.card))
                    .overlay(Capsule().strokeBorder(Ink.hairline))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Transliteration", isOn: $showTranslit)
                        if container.corpus?.capabilities.hasEnglish == true {
                            Toggle("English translation", isOn: $showEnglish)
                        }
                        if container.corpus?.capabilities.hasTiming == true {
                            Toggle("Timing chip", isOn: $showTiming)
                        }
                        Divider()
                        Toggle("Sehaj focus", isOn: $focusMode)
                    } label: { Image(systemName: "textformat.size") }
                    .accessibilityLabel("Reading options")
                    .accessibilityIdentifier("readerOptions")
                }
            }
            .sheet(isPresented: $showJump) {
                JumpToAngSheet(current: router.readerAng) { n in router.openAng(n) }
            }
        }
        .task { await container.loadMeta() }   // raag roman names + Jump-sheet ticks (idempotent)
        .task(id: container.router.readerAng) {
            if model == nil { model = ReaderModel(corpus: container.corpus) }
            // resume-last-Ang: once per launch, only from the untouched default. The router
            // flag (not the Ang value) marks explicit navigation, so sggs://ang/1 is honoured.
            if !resumed {
                resumed = true
                if !container.router.navigatedToAngExplicitly,
                   container.router.readerAng == 1, lastAng > 1 {
                    container.router.readerAng = lastAng
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
