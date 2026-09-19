import SwiftUI
import GurbaniSearchKit

/// One Ang, rendered inside the Reader's pager. Each page owns its own `ScrollView`, loads its Ang
/// from the shared `ReaderModel` cache (neighbours are pre-warmed), lands on a requested verse, and
/// reports its scroll offset up for the shared chrome — but only while it is the current page.
///
/// Kept a `LazyVStack` of id'd rows: an eager stack of ~60 fully-labelled rows made accessibility
/// snapshots stall for minutes (the 15-min XCUITest history), and `scrollPosition(id:)` needs the
/// lazy layout to resolve a not-yet-materialised verse id (unlike `ScrollViewReader.scrollTo`).
struct AngPageView: View {
    let ang: Int
    let model: ReaderModel
    /// Opens the Jump-to-Ang sheet (owned by ReaderScreen) — the raag banner is an affordance.
    var onOpenJump: () -> Void = {}
    /// (offset, contentHeight, viewportHeight) for the shared chrome; fires only for the current page.
    var onScroll: (CGFloat, CGFloat, CGFloat) -> Void = { _, _, _ in }

    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @AppStorage("sggs_show_timing") private var showTiming = true   // web default-ON parity
    @AppStorage("sggs_focus_mode") private var focusMode = false

    @State private var page: AngPage?
    @State private var timingChip: String?
    @State private var timing: RaagTiming?
    @State private var highlightedId: Int?
    @AccessibilityFocusState private var voFocus: Int?
    /// `scrollPosition` binding: written only when landing on a requested verse (a value present at
    /// the ScrollView's first layout becomes its initial offset — no timing games).
    @State private var landingId: Int?
    @State private var landingInProgress = false

    private var isCurrent: Bool { container.router.readerAng == ang }

    var body: some View {
        Group {
            if let page {
                content(page)
            } else {
                // quiet skeleton — never a spinner flash (page loads in ~ms from local SQLite)
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6).fill(Ink.hairline)
                            .frame(width: i.isMultiple(of: 3) ? 180 : nil, height: 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding().readingColumn().frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.paper)
        .task(id: ang) {
            await model.ensure(ang, isCurrent: isCurrent)
            page = model.page(ang)
            // present a requested verse as the INITIAL scroll offset before first layout
            if isCurrent, let id = container.router.pendingReaderLineId,
               page?.lines.contains(where: { $0.id == id }) == true {
                landingId = id
            }
            await loadTiming()
            finishLanding()
        }
        // same-Ang landing (e.g. "Open Ang N" while already on N) and tab re-selection
        .onChange(of: container.router.pendingReaderLineId) { _, _ in land() }
        .onChange(of: container.router.selectedTab) { _, tab in
            if tab == .reader { DispatchQueue.main.async { land() } }
        }
    }

    // MARK: content

    @ViewBuilder private func content(_ page: AngPage) -> some View {
        ScrollView {
            // zero-height offset probe (iOS 17-safe ambient-chrome tracker)
            GeometryReader { g in
                Color.clear.preference(key: ReaderScrollOffsetKey.self,
                                       value: -g.frame(in: .named("readerScroll")).minY)
            }
            .frame(height: 0)
            LazyVStack(alignment: .leading, spacing: 18) {
                if let raag = page.raag {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Space.s) { raagBanner(raag); timingChipView }
                        VStack(alignment: .leading, spacing: Theme.Space.xs) { raagBanner(raag); timingChipView }
                    }
                }
                if let from = page.continuedFrom {
                    ContinuationPill(text: "Shabad starts on Ang \(String(from))",
                                     systemImage: "arrow.up.backward",
                                     identifier: "continuesFromPill",
                                     hint: "Goes to the beginning of this shabad") {
                        Haptics.tap()
                        container.router.openAng(from, lineId: page.continuedFromLineId)
                    }
                }
                ForEach(Array(page.lines.enumerated()), id: \.element.id) { index, line in
                    if VerseTypography.rendersAsHeading(line.gurmukhi, flaggedHeader: line.isHeader) {
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
                // A forward control ends every Ang (except the last) so the reader is never stranded
                // at the bottom of the page — and it is the way to advance in Sehaj focus, where the
                // bottom bar is hidden. "Continues on Ang N+1" when the shabad carries over, a quieter
                // "Next · Ang N+1" otherwise. Fixed-height slot so it never shifts the verses above.
                HStack {
                    Spacer()
                    if page.ang < 1430 {
                        let carries = model.continuesOn(after: page.ang)
                        ContinuationPill(text: (carries ? "Continues on Ang " : "Next · Ang ") + String(page.ang + 1),
                                         systemImage: "arrow.down.forward",
                                         identifier: carries ? "continuesOnPill" : "nextAngFooter",
                                         hint: "Goes to the next Ang") {
                            Haptics.tap(); container.router.openAng(page.ang + 1)
                        }
                    }
                }
                .frame(minHeight: 44)
            }
            .scrollTargetLayout()
            .padding()
            .readingColumn()
            .background(GeometryReader { g in
                Color.clear.preference(key: ReaderContentHeightKey.self, value: g.size.height)
            })
        }
        .scrollPosition(id: $landingId, anchor: .center)
        .coordinateSpace(name: "readerScroll")
        .modifier(ReaderScrollTracking(
            onScroll: { y, content, viewport in
                if isCurrent && !landingInProgress { onScroll(y, content, viewport) }
            },
            onContentHeight: { h in if isCurrent { onScroll(.nan, h, .nan) } }))
        .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
    }

    // MARK: raag banner + timing chip

    @ViewBuilder private func raagBanner(_ raag: String) -> some View {
        let roman = container.meta?.raags.first(where: { $0.name == raag })?.roman
        Button { Haptics.tap(); onOpenJump() } label: {
            HStack(spacing: Theme.Space.s) {
                Text(raag).font(Brand.gurmukhi(20, relativeTo: .title3)).foregroundStyle(.primary)
                if let roman { Text(roman).font(.subheadline).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Raag \(roman ?? raag). Jump to another Ang.")
    }

    @ViewBuilder private var timingChipView: some View {
        if showTiming, let chip = timingChip, let t = timing {
            Button { Haptics.tap(); container.router.openClock(raag: t.roman ?? t.raag) } label: {
                HStack(spacing: Theme.Space.xs) {
                    Label(chip, systemImage: "clock").font(.footnote)
                    Image(systemName: "chevron.right").font(.caption2)
                }
                .padding(.horizontal, Theme.Space.s).padding(.vertical, Theme.Space.xs)
                .frame(minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3])))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timingChip")
            .accessibilityLabel("Traditional singing time: \(chip). Opens the Raag Clock.")
        }
    }

    // MARK: timing + landing

    private func loadTiming() async {
        guard let raag = page?.raag else { timing = nil; timingChip = nil; return }
        let t = await model.timing(forRaag: raag)
        if t?.raag == raag || t == nil {
            timing = t
            timingChip = t.flatMap(ReaderModel.timingChipText)
        }
    }

    /// Land on a pending verse when this is the current page and the verse is on it.
    private func land() {
        guard isCurrent, container.router.selectedTab == .reader,
              let id = container.router.pendingReaderLineId,
              page?.lines.contains(where: { $0.id == id }) == true else { return }
        landingId = nil
        DispatchQueue.main.async {
            MotionGate.run(Motion.gentle) { landingId = id }
            finishLanding()
        }
    }

    /// Consume the pending verse: highlight it, move VoiceOver to it. A verse not on this page is
    /// dropped without scrolling. Re-asserts the scroll position after the layout settles.
    private func finishLanding() {
        guard isCurrent, let id = container.router.pendingReaderLineId else { return }
        guard page?.lines.contains(where: { $0.id == id }) == true else { return }
        container.router.pendingReaderLineId = nil
        landingInProgress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { landingInProgress = false }
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
