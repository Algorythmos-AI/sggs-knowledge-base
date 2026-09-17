import SwiftUI
import UIKit
import GurbaniSearchKit

@MainActor @Observable
final class ReaderModel {
    var state: LoadState<AngPage> = .loading
    /// Timing chip data for the current page's raag (metadata-only; nil = no chip).
    var timing: RaagTiming?
    /// Adjacent-Ang cache: page turns paint from here (no spinner), and the "continues on
    /// Ang N+1" pill reads the next page's boundary field. Bounded, evicted by distance.
    private(set) var pages: [Int: AngPage] = [:]
    private var inflight: Set<Int> = []
    private let corpus: CorpusActor?
    init(corpus: CorpusActor?) { self.corpus = corpus }

    func load(_ ang: Int) async {
        guard let corpus else { state = .failed("No database"); return }
        // Page turns keep the current page on screen while the next loads (local SQLite,
        // ~ms) — no spinner flash mid-read. The spinner only shows on first entry.
        if case .loaded = state {} else { state = .loading }
        do {
            let page: AngPage
            if let cached = pages[ang] { page = cached }
            else {
                page = try await corpus.ang(ang)
                if Task.isCancelled { return }
                remember(page)
            }
            MotionGate.run(Motion.gentle) { state = .loaded(page) }
            prefetchNeighbours(of: ang)
            timing = nil
            if corpus.capabilities.hasTiming, let raag = page.raag {
                let t = await corpus.timingRaag(name: raag)
                if !Task.isCancelled, t.available, !t.claims.isEmpty { timing = t }
            }
        }
        catch { state = .failed(UserMessage.load(error)) }
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
        guard pages.count > 5 else { return }
        // evict the farthest from the page just remembered
        let current: Int = { if case .loaded(let p) = state { return p.ang } else { return page.ang } }()
        if let far = pages.keys.filter({ $0 != current }).max(by: { abs($0 - current) < abs($1 - current) }) {
            pages.removeValue(forKey: far)
        }
    }

    /// Warm ang±1 in their own tasks (the view's `.task` is cancelled on every page turn).
    private func prefetchNeighbours(of ang: Int) {
        for n in [ang + 1, ang - 1] where (1...1430).contains(n) && pages[n] == nil && !inflight.contains(n) {
            inflight.insert(n)
            Task { [weak self] in
                guard let self, let corpus = self.corpus else { return }
                if let page = try? await corpus.ang(n) { self.remember(page) }
                self.inflight.remove(n)
            }
        }
    }

    /// The chip line for the raag banner, from the first primary claim (or seasonal note).
    var timingChipText: String? {
        guard let t = timing else { return nil }
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
    @State private var model: ReaderModel?
    @AppStorage("sggs_show_timing") private var showTiming = true   // web default-ON parity
    @AppStorage("sggs_show_english") private var showEnglish = true
    @AppStorage("sggs_translit") private var showTranslit = true
    /// Sehaj focus: chrome collapses, generous leading, pure Gurmukhi (an explicit mode).
    @AppStorage("sggs_focus_mode") private var focusMode = false
    /// Resume where the reader left off (persisted on every Ang change; 1 = never read).
    @AppStorage("sggs_last_ang") private var lastAng = 1
    @State private var showJump = false
    @State private var resumed = false
    /// Which edge the incoming page enters from (next → trailing, previous → leading).
    @State private var turnEdge: Edge = .trailing
    /// Landing highlight for a requested verse (deep link / "Open Ang N in Reader").
    @State private var highlightedId: Int?
    @AccessibilityFocusState private var voFocus: Int?
    /// Ambient chrome: hidden while reading downwards, restored on any upward scroll.
    @State private var chromeHidden = false
    @State private var lastOffset: CGFloat = 0
    @State private var downRun: CGFloat = 0
    @State private var upRun: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    /// True while the Reader tab's content is actually on screen (TabView keeps other tabs
    /// mounted): a landing scroll issued while off screen is a silent no-op that would consume
    /// the pending verse, so landing waits for visibility.
    @State private var readerVisible = false
    /// `scrollPosition` binding: written ONLY when landing on a requested verse (SwiftUI applies
    /// a value present at the ScrollView's first layout as its initial offset — no timing games).
    @State private var landingId: Int?
    /// The landing scroll is programmatic: it must never trip the ambient-chrome "reading down" rule.
    @State private var landingInProgress = false

    var body: some View {
        @Bindable var router = container.router
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(state: model.state,
                                  onRetry: { Task { await model.load(router.readerAng) } }) { page in
                        ScrollView {
                            // zero-height offset probe (iOS 17-safe ambient-chrome tracker)
                            GeometryReader { g in
                                Color.clear.preference(key: ReaderScrollOffsetKey.self,
                                                       value: -g.frame(in: .named("readerScroll")).minY)
                            }
                            .frame(height: 0)
                            // LazyVStack + scrollTargetLayout: `scrollPosition(id:)` resolves ids the
                            // layout has not materialised yet (unlike ScrollViewReader.scrollTo), and
                            // an eager VStack of ~60 fully-labelled rows made accessibility snapshots
                            // stall for minutes (XCUITest 15-min Reader tests) — lazy keeps the a11y
                            // tree to what is on screen.
                            LazyVStack(alignment: .leading, spacing: 18) {
                                if let raag = page.raag {
                                    HStack(spacing: Theme.Space.s) {
                                        Text(raag).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AccentPalette.gold.accentText)
                                        if showTiming, let chip = model.timingChipText, let t = model.timing {
                                            // metadata-only, dashed (web parity) — never part of the scripture
                                            Button {
                                                container.router.openClock(raag: t.roman ?? t.raag)
                                            } label: {
                                                Label(chip, systemImage: "clock")
                                                    .font(.caption2)
                                                    .padding(.horizontal, Theme.Space.s).padding(.vertical, 3)
                                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip)
                                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3])))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("Traditional singing time: \(chip). Opens the Raag Clock.")
                                        }
                                    }
                                }
                                if let from = page.continuedFrom {
                                    Label("Continues from Ang \(String(from))", systemImage: "arrow.up.backward")
                                        .font(.caption)
                                        .padding(.horizontal, Theme.Space.m).padding(.vertical, 5)
                                        .overlay(Capsule().strokeBorder(AccentPalette.gold.accentText.opacity(0.45)))
                                        .foregroundStyle(AccentPalette.gold.accentText)
                                }
                                ForEach(Array(page.lines.enumerated()), id: \.element.id) { index, line in
                                    if VerseTypography.rendersAsHeading(line.gurmukhi, flaggedHeader: line.isHeader) {
                                        // A heading run opens a composition: a hairline + air above its
                                        // FIRST line separates shabads; the run itself stays tight.
                                        let opensRun = index > 0 && !VerseTypography.rendersAsHeading(
                                            page.lines[index - 1].gurmukhi, flaggedHeader: page.lines[index - 1].isHeader)
                                        VStack(spacing: Theme.Space.m) {
                                            if opensRun {
                                                Rectangle().fill(Ink.hairline).frame(width: 56, height: 1)
                                                    .padding(.top, Theme.Space.s).accessibilityHidden(true)
                                            }
                                            VerseHeading(verbatim: line.gurmukhi)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .id(line.id)
                                    } else {
                                        LineRow(gurmukhi: line.gurmukhi,
                                                translit: focusMode ? "" : line.translit,
                                                meta: line.isRahao ? "ਰਹਾਉ · refrain" : "",
                                                en: focusMode ? nil : line.en,
                                                lineId: line.id, ang: line.ang, compId: line.compId) {
                                            container.present(.shabad(compId: line.compId, focusLineId: line.id))
                                        }
                                        .padding(.vertical, focusMode ? Theme.Space.s : 0)
                                        .focusHighlight(highlightedId == line.id)
                                        .accessibilityFocused($voFocus, equals: line.id)
                                        .id(line.id)
                                    }
                                }
                                // fixed-height slot: the pill appears without shifting the verses above
                                HStack {
                                    Spacer()
                                    if page.ang < 1430, model.continuesOn(after: page.ang) {
                                        Button {
                                            turnEdge = .trailing; Haptics.tap(); router.openAng(page.ang + 1)
                                        } label: {
                                            Label("Continues on Ang \(String(page.ang + 1))", systemImage: "arrow.down.forward")
                                                .font(.caption)
                                                .padding(.horizontal, Theme.Space.m).padding(.vertical, 5)
                                                .overlay(Capsule().strokeBorder(AccentPalette.gold.accentText.opacity(0.45)))
                                                .foregroundStyle(AccentPalette.gold.accentText)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("continuesOnPill")
                                    }
                                }
                                .frame(minHeight: 30)        // reserved slot; grows with Dynamic Type
                            }
                            .scrollTargetLayout()
                            .padding()
                            .readingColumn()
                            .background(GeometryReader { g in
                                Color.clear.preference(key: ReaderContentHeightKey.self, value: g.size.height)
                            })
                            // same-Ang landing (the sheet's "Open Ang N" while already on Ang N) and
                            // re-selection of an already-mounted Reader tab with a verse pending
                            .onChange(of: router.pendingReaderLineId) { _, _ in land(on: page) }
                            .onChange(of: router.selectedTab) { _, tab in
                                if tab == .reader { DispatchQueue.main.async { land(on: page) } }
                            }
                        }
                        .scrollPosition(id: $landingId, anchor: .center)
                        .coordinateSpace(name: "readerScroll")
                        .modifier(ReaderScrollTracking(
                            onScroll: { y, content, viewport in
                                if content > 0 { contentHeight = content }
                                if viewport > 0 { viewportHeight = viewport }
                                handleScroll(offset: y)
                            },
                            onContentHeight: { h in contentHeight = h }))
                        .id(page.ang)   // page identity — drives the turn transition below
                        .transition(.asymmetric(
                            insertion: .move(edge: turnEdge).combined(with: .opacity),
                            removal: .opacity))
                        // horizontal page-turn; plain .gesture so vertical scrolling always wins
                        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
                            guard abs(v.translation.width) > 60,
                                  abs(v.translation.width) > abs(v.translation.height) * 2 else { return }
                            let forward = v.translation.width < 0
                            let next = router.readerAng + (forward ? 1 : -1)
                            guard (1...1430).contains(next) else { return }   // no haptic on a no-op edge swipe
                            turnEdge = forward ? .trailing : .leading
                            Haptics.tap()
                            router.openAng(next)
                        })
                        .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
                    }
                } else { Color.clear }
            }
            .background(GeometryReader { g in Color.clear.onAppear { viewportHeight = g.size.height }
                .onChange(of: g.size.height) { _, h in viewportHeight = h } })
            .onAppear { readerVisible = true }
            .onDisappear { readerVisible = false }
            .background(Ink.paper.ignoresSafeArea())
            .navigationTitle("Ang \(String(router.readerAng))")
            .navigationBarTitleDisplayMode(.inline)
            // The navigation bar stays visible. Toggling it from scroll offsets re-lays-out the
            // scroll view (the top inset changes by the bar height), which the scroll handler read
            // as a reverse scroll → show → hide … an endless update loop that froze the app on a
            // 120 Hz device (TestFlight 1.1.3 (1), watchdog 0x8BADF00D). Only the bottom page bar
            // fades — opacity/offset don't change layout, so it cannot feed back.
            .onChange(of: router.readerAng) { _, _ in landingId = nil; showChrome() }   // page turn: fresh position, chrome back
            .onChange(of: focusMode) { _, _ in showChrome() }
            .onChange(of: container.presentation?.id) { _, id in if id == nil { showChrome() } }
            // Page controls live in a bottom safe-area inset, NOT a `.bottomBar` toolbar: inside a
            // TabView on iOS 26 the bottom toolbar is drawn UNDER the floating glass tab bar, so
            // Previous / Hukam / Next were invisible (verified in the simulator; the July
            // baseline screenshots show the same). The inset is laid out above the tab bar.
            .safeAreaInset(edge: .bottom) {
                if !focusMode {
                    HStack {
                        Button { turnEdge = .leading; router.openAng(router.readerAng - 1) }
                            label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }
                            .disabled(router.readerAng <= 1)
                            .accessibilityLabel("Previous Ang")
                        Spacer()
                        Button { Haptics.tap(); container.present(.hukam) } label: {
                            Label("Hukam", systemImage: "sparkles").lineLimit(1).frame(minHeight: 44)
                        }
                        Spacer()
                        Button { turnEdge = .trailing; router.openAng(router.readerAng + 1) }
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
                    .appAnimation(Motion.gentle, value: chromeHidden)
                    .accessibilityIdentifier("readerPageBar")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showJump = true } label: { Image(systemName: "number") }
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
                    .presentationDetents([.medium])
            }
        }
        .task(id: container.router.readerAng) {
            if model == nil { model = ReaderModel(corpus: container.corpus) }
            // resume-last-Ang: once per launch, only from the untouched default. The router
            // flag (not the Ang value) marks explicit navigation, so sggs://ang/1 is honoured.
            if !resumed {
                resumed = true
                if !container.router.navigatedToAngExplicitly,
                   container.router.readerAng == 1, lastAng > 1 {
                    container.router.readerAng = lastAng
                    return   // the task re-fires with the resumed Ang
                }
            }
            lastAng = container.router.readerAng
            // Returning to the tab re-fires this task; skip the reload (and the loading
            // flash + scroll reset) when the page for this Ang is already on screen.
            if let model, case .loaded(let page) = model.state, page.ang == container.router.readerAng {
                land(on: page)                    // same page already on screen → nil-then-set scroll
                return
            }
            // A requested verse becomes the page's INITIAL scroll position: present before the
            // ScrollView's first layout, so the insertion transition cannot drop it.
            landingId = container.router.pendingReaderLineId
            await model?.load(container.router.readerAng)
            if let model, case .loaded(let page) = model.state { finishLanding(page) }
        }
    }
}

/// Scroll tracking with the modern API where available (iOS 18+: exact offset + content and
/// container sizes from the scroll view itself) and the zero-height GeometryReader probe +
/// preference keys as the iOS 17.0 fallback.
private struct ReaderScrollTracking: ViewModifier {
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
private struct ScrollSnapshot: Equatable { let y: CGFloat; let content: CGFloat; let viewport: CGFloat }

private struct ReaderScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct ReaderContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

extension ReaderScreen {
    /// Ambient chrome. Hide only when the reader is clearly reading downwards (> 24 pt run,
    /// past 80 pt, on a page taller than the viewport + 120 so short Angs never flicker);
    /// restore on ≥ 8 pt upwards or at the top. Never for VoiceOver / Switch Control users —
    /// the chrome is their navigation. Reduce Motion: MotionGate makes the change instant.
    fileprivate func handleScroll(offset: CGFloat) {
        let delta = offset - lastOffset
        lastOffset = offset
        if landingInProgress { downRun = 0; upRun = 0; return }       // programmatic landing scroll
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

    /// Land on a pending verse when the page is already on screen: nil-then-set the
    /// `scrollPosition` binding (a same-value assignment does not re-scroll). Only while the
    /// Reader tab is selected — an off-screen scroll would consume the request silently.
    fileprivate func land(on page: AngPage) {
        guard readerVisible, container.router.selectedTab == .reader,
              let id = container.router.pendingReaderLineId, page.ang == container.router.readerAng,
              page.lines.contains(where: { $0.id == id }) else { return }
        landingId = nil
        DispatchQueue.main.async {
            MotionGate.run(Motion.gentle) { landingId = id }
            finishLanding(page)
        }
    }

    /// Consume the pending verse: highlight it, keep the chrome, move VoiceOver to it. A verse
    /// id that is not on this page is dropped without scrolling or highlighting.
    fileprivate func finishLanding(_ page: AngPage) {
        guard let id = container.router.pendingReaderLineId else { return }
        container.router.pendingReaderLineId = nil
        guard page.lines.contains(where: { $0.id == id }) else { landingId = nil; return }
        showChrome()
        landingInProgress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { landingInProgress = false }
        // Re-assert once the page's insertion transition has settled (≤ 0.3 s; instant under
        // Reduce Motion): a position set during the animated insert is not always honoured.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            landingId = nil
            DispatchQueue.main.async { MotionGate.run(Motion.gentle) { landingId = id } }
        }
        highlightedId = id
        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + FocusLanding.voiceOverDelaySeconds) { voFocus = id }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(FocusLanding.highlightSeconds))
            if highlightedId == id { highlightedId = nil }
        }
    }
}

/// Jump-to-Ang: number field + slider across the full 1430 (with an "Ang N of 1430" readout).
struct JumpToAngSheet: View {
    let current: Int
    var onGo: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var slider: Double = 1

    private var typedAng: Int? {
        guard let n = Int(text.trimmingCharacters(in: .whitespaces)), (1...1430).contains(n) else { return nil }
        return n
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ang \(String(current)) of 1430") {
                    TextField("Ang number (1–1430)", text: $text)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("angField")
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty, typedAng == nil {
                        // typed input must never be silently discarded in favour of the slider
                        Text("Enter an Ang between 1 and 1430.")
                            .font(.caption).foregroundStyle(Ink.negative)
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        Slider(value: $slider, in: 1...1430, step: 1) { Text("Ang") }
                            .accessibilityIdentifier("angSlider")
                        Text("Ang \(String(Int(slider)))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Button("Go") {
                    let target = typedAng ?? Int(slider)
                    onGo(target)
                    dismiss()
                }
                // invalid typed text disables Go outright — the slider only stands in when
                // the field is empty (never silently overriding what the user typed)
                .disabled(!text.trimmingCharacters(in: .whitespaces).isEmpty && typedAng == nil
                          || text.trimmingCharacters(in: .whitespaces).isEmpty && Int(slider) == current)
                .accessibilityIdentifier("goToAng")
            }
            .navigationTitle("Jump to Ang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { slider = Double(current) }
        }
    }
}
