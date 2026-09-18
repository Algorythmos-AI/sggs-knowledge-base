import SwiftUI
import GurbaniSearchKit

/// Reads one bani from the Nitnem registry the way a well-made Gutka reads: paper, ink
/// Gurmukhi, a quiet rhythm of parts, nothing moving unless the reader moves it.
///
/// Fidelity: every Sri Guru Granth Sahib Ji line is the verbatim corpus line (cited by Ang,
/// tappable to its composition, saveable). Lines from the extra layer (Sri Dasam Granth /
/// Ardaas) carry their own source label and offer none of the scripture-only actions — the
/// `switch` over `BaniCitation` below is exhaustive, so a Dasam line can never be built as
/// an Ang citation. `seq` is the only identity used for scrolling, landing and progress.
struct BaniReaderScreen: View {
    let key: String

    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(NitnemPrefs.rehrasVariantKey) private var rehrasVariant = NitnemPrefs.rehrasDefault
    @AppStorage("sggs_show_english") private var showEnglish = true
    @AppStorage("sggs_translit") private var showTranslit = true
    @AppStorage("sggs_focus_mode") private var focusMode = false

    @State private var bani: Bani?
    @State private var registry: [BaniSummary] = []
    @State private var failed = false
    /// `scrollPosition` binding (a line `seq`): set once on load to resume, then written by the
    /// scroll view as the reader moves — it IS the reading position.
    @State private var positionId: Int?
    @State private var highlightedId: Int?
    @AccessibilityFocusState private var voFocus: Int?
    @State private var chrome = AmbientChrome()
    @State private var chromeHidden = false
    @State private var saveTask: Task<Void, Never>?
    @State private var completedNow = false

    private var variant: String { NitnemPrefs.variant(for: key, rehras: rehrasVariant) }
    private var progressId: String { bani.map { $0.summary.id } ?? NitnemPrefs.progressId(key: key, variant: variant) }

    var body: some View {
        Group {
            if let bani {
                reader(bani)
            } else if failed {
                EmptyStateView(title: "Bani not found", message: "This bani is not in the bundled registry.", isError: true)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Ink.paper.ignoresSafeArea())
        .navigationTitle(bani?.summary.titleEn ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Transliteration", isOn: $showTranslit)
                    if container.corpus?.capabilities.hasEnglish == true {
                        Toggle("English translation", isOn: $showEnglish)
                    }
                    Toggle("Sehaj focus", isOn: $focusMode)
                    Divider()
                    Button { startAgain() } label: { Label("Start again", systemImage: "arrow.counterclockwise") }
                } label: { Image(systemName: "textformat.size") }
                .accessibilityLabel("Reading options")
                .accessibilityIdentifier("baniOptions")
            }
        }
        .task(id: key + "/" + variant) { await load() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }     // a Gutka doesn't switch off mid-pauri
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; flushSave() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { flushSave() } }
        .onChange(of: positionId) { _, _ in scheduleSave() }
        .onChange(of: focusMode) { _, _ in showChrome() }
    }

    // MARK: load / progress

    private func load() async {
        guard let corpus = container.corpus else { failed = true; return }
        let loaded = await corpus.bani(key: key, variant: variant)
        registry = await corpus.banis().banis
        guard let loaded else { failed = true; return }
        completedNow = false
        // resume: the saved position becomes the ScrollView's initial offset
        let saved = container.nitnem.progress(for: loaded.summary.id)?.lastSeq ?? 0
        if saved > 1, saved <= loaded.lines.count {
            chrome.landingInProgress = true
            positionId = saved
            highlightedId = saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { chrome.landingInProgress = false }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(FocusLanding.highlightSeconds))
                if highlightedId == saved { highlightedId = nil }
            }
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + FocusLanding.voiceOverDelaySeconds) { voFocus = saved }
            }
        } else {
            positionId = nil
        }
        bani = loaded
    }

    private func scheduleSave() {
        saveTask?.cancel()
        guard let seq = positionId, seq > 0, bani != nil else { return }
        let id = progressId
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            container.nitnem.setPosition(id, seq: seq)
        }
    }

    private func flushSave() {
        saveTask?.cancel()
        if let seq = positionId, seq > 0, bani != nil { container.nitnem.setPosition(progressId, seq: seq) }
    }

    private func startAgain() {
        container.nitnem.resetPosition(progressId)
        completedNow = false
        MotionGate.run(Motion.gentle) { positionId = bani?.lines.first?.seq }
        showChrome()
    }

    private func markComplete() {
        saveTask?.cancel()
        container.nitnem.markComplete(progressId)
        Haptics.success()
        MotionGate.run(Motion.gentle) { completedNow = true }
    }

    /// The bani to offer after this one: the next unfinished bani of the current band.
    private var nextBani: BaniSummary? {
        let band = NitnemSchedule.band(at: NitnemScreen.injectedNow())
        let rows = registry.filter { b in
            b.key == "rehras" ? b.variant == NitnemPrefs.variant(for: "rehras", rehras: rehrasVariant) : b.isDefault
        }
        return NitnemSchedule.next(in: band, from: rows) { b in
            b.id == progressId ? completedNow || container.nitnem.isCompleted(b.id) : container.nitnem.isCompleted(b.id)
        }
    }

    // MARK: reader

    private func reader(_ bani: Bani) -> some View {
        let lines = bani.lines
        let total = lines.count
        let groups = bani.summary.nGroups
        return ScrollView {
            GeometryReader { g in
                Color.clear.preference(key: ReaderScrollOffsetKey.self,
                                       value: -g.frame(in: .named("baniScroll")).minY)
            }
            .frame(height: 0)
            // LazyVStack + scrollTargetLayout: Sukhmani Sahib is 2,047 lines — the a11y tree and
            // the layout stay to what is on screen; `scrollPosition(id:)` still lands any seq.
            LazyVStack(alignment: .leading, spacing: 18) {
                header(bani)
                ForEach(Array(lines.enumerated()), id: \.element.seq) { index, line in
                    let opensGroup = index > 0 && lines[index - 1].lineGroup != line.lineGroup
                    if opensGroup {
                        Rectangle().fill(Ink.hairline).frame(width: 56, height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Space.m)
                            .accessibilityHidden(true)
                    }
                    lineView(line)
                        .padding(.vertical, focusMode ? Theme.Space.s : 0)
                        .focusHighlight(highlightedId == line.seq)
                        .accessibilityFocused($voFocus, equals: line.seq)
                        .id(line.seq)
                }
                completion(bani)
                    .padding(.top, Theme.Space.xl)
                    .id(Int.max)
            }
            .scrollTargetLayout()
            .padding()
            .readingColumn()
            .background(GeometryReader { g in
                Color.clear.preference(key: ReaderContentHeightKey.self, value: g.size.height)
            })
        }
        .scrollPosition(id: $positionId, anchor: .top)
        .coordinateSpace(name: "baniScroll")
        .modifier(ReaderScrollTracking(
            onScroll: { y, content, viewport in
                if content > 0 { chrome.contentHeight = content }
                if viewport > 0 { chrome.viewportHeight = viewport }
                if let change = chrome.scrolled(to: y) { MotionGate.run(Motion.gentle) { chromeHidden = change } }
            },
            onContentHeight: { h in chrome.contentHeight = h }))
        .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
        // a thin accent rule at the top of the paper — position, not a percentage
        .overlay(alignment: .top) {
            GeometryReader { g in
                Rectangle().fill(palette.accent)
                    .frame(width: g.size.width * CGFloat(fraction(total)), height: 2)
                    .appAnimation(Motion.gentle, value: positionId)
            }
            .frame(height: 2)
            .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom) {
            if !focusMode { bar(lines: lines, groups: groups) }
        }
    }

    private func fraction(_ total: Int) -> Double {
        guard total > 0 else { return 0 }
        if completedNow { return 1 }
        return min(1, Double(positionId ?? 0) / Double(total))
    }

    @ViewBuilder
    private func header(_ bani: Bani) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(bani.summary.titleEn).font(Brand.heading(.title2))
            GurmukhiText(verbatim: bani.summary.titleGm, size: 22)
            HStack(spacing: Theme.Space.s) {
                if !bani.citationRange.isEmpty { Text(bani.citationRange) }
                if let m = bani.summary.estimatedMinutes { Text("· about \(m) min") }
            }
            .font(.caption).foregroundStyle(.secondary)
            if bani.summary.hasExtra {
                Text(NitnemReview.extraLayerLabel)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Theme.Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// One line, by its source. Exhaustive on purpose: an extra-layer line can only be built
    /// with a source label, never with an Ang.
    @ViewBuilder
    private func lineView(_ line: BaniLine) -> some View {
        if VerseTypography.rendersAsHeading(line.gurmukhi, flaggedHeader: line.isHeader) {
            VerseHeading(verbatim: line.gurmukhi)
        } else {
            switch line.citation {
            case .sggs(let ang, let lineId, let compId):
                LineRow(gurmukhi: line.gurmukhi,
                        translit: focusMode ? "" : line.translit,
                        meta: line.isRahao ? "ਰਹਾਉ · refrain" : "",
                        en: focusMode ? nil : line.en,
                        lineId: lineId, ang: ang, compId: compId) {
                    container.present(.shabad(compId: compId, focusLineId: lineId))
                }
            case .dasam, .ardaas:
                LineRow(gurmukhi: line.gurmukhi,
                        translit: focusMode ? "" : line.translit,
                        meta: "",
                        sourceLabel: line.citation.citation)
            }
        }
    }

    /// The end of the bani: mark it read; then the one gold action leads on.
    @ViewBuilder
    private func completion(_ bani: Bani) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Rectangle().fill(Ink.hairline).frame(height: 1).accessibilityHidden(true)
            if completedNow || container.nitnem.isCompleted(progressId) {
                Label("\(bani.summary.titleEn) complete", systemImage: "checkmark.circle")
                    .font(Brand.heading(.headline)).foregroundStyle(palette.accentText)
                if !bani.citationRange.isEmpty {
                    Text(bani.citationRange).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: Theme.Space.m) {
                    if let next = nextBani {
                        Button {
                            Haptics.tap()
                            container.router.nitnemPath = NavigationPath([Route.bani(next.key)])
                        } label: { Label("Next: \(next.titleEn)", systemImage: "arrow.right") }
                        .buttonStyle(.prominentPill)
                        .accessibilityIdentifier("nitnemNext")
                    }
                    Button("Back to Nitnem") { container.router.nitnemPath = NavigationPath() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("baniBackToNitnem")
                }
            } else {
                Text("End of \(bani.summary.titleEn)").font(.subheadline).foregroundStyle(.secondary)
                Button { markComplete() } label: { Label("Mark as read today", systemImage: "checkmark") }
                    .buttonStyle(.prominentPill)
                    .accessibilityIdentifier("baniMarkComplete")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Bottom bar: part navigation for multi-part banis, top/end for single-part ones, with
    /// the reading position in words. Fades with the ambient chrome (never a layout change).
    private func bar(lines: [BaniLine], groups: Int) -> some View {
        let seq = positionId ?? (lines.first?.seq ?? 1)
        let group = lines.first(where: { $0.seq == seq })?.lineGroup ?? 1
        return HStack {
            Button {
                if groups > 1 { jump(toGroup: group - 1, lines: lines) } else { jump(toSeq: lines.first?.seq) }
            } label: { Image(systemName: groups > 1 ? "chevron.left" : "arrow.up.to.line").frame(minWidth: 44, minHeight: 44) }
                .disabled(groups > 1 ? group <= 1 : seq <= 1)
                .accessibilityLabel(groups > 1 ? "Previous part" : "Top")
            Spacer()
            Text(groups > 1 ? "Part \(group) of \(groups)" : "Line \(min(seq, lines.count)) of \(lines.count)")
                .font(.subheadline.weight(.medium)).monospacedDigit()
                .accessibilityIdentifier("baniPosition")
            Spacer()
            Button {
                if groups > 1 { jump(toGroup: group + 1, lines: lines) } else { jump(toSeq: Int.max) }
            } label: { Image(systemName: groups > 1 ? "chevron.right" : "arrow.down.to.line").frame(minWidth: 44, minHeight: 44) }
                .disabled(groups > 1 && group >= groups)
                .accessibilityLabel(groups > 1 ? "Next part" : "End")
        }
        .font(.body.weight(.medium))
        .padding(.horizontal, Theme.Space.m)
        .background(Capsule().fill(Ink.card))
        .overlay(Capsule().strokeBorder(Ink.hairline))
        .padding(.horizontal, Theme.Space.l)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(.bottom, Theme.Space.xs)
        .opacity(chromeHidden ? 0 : 1)
        .offset(y: chromeHidden ? 40 : 0)
        .allowsHitTesting(!chromeHidden)
        .appAnimation(Motion.gentle, value: chromeHidden)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("baniPageBar")
    }

    private func jump(toGroup g: Int, lines: [BaniLine]) {
        guard let target = lines.first(where: { $0.lineGroup == g }) else { return }
        jump(toSeq: target.seq)
    }

    private func jump(toSeq seq: Int?) {
        guard let seq else { return }
        Haptics.tap()
        chrome.landingInProgress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { chrome.landingInProgress = false }
        showChrome()
        positionId = nil
        DispatchQueue.main.async { MotionGate.run(Motion.gentle) { positionId = seq } }
    }

    private func showChrome() {
        chrome.reset()
        if chromeHidden { MotionGate.run(Motion.gentle) { chromeHidden = false } }
    }
}
