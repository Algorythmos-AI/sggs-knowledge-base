import SwiftUI
import GurbaniSearchKit

/// Reads one bani from the Nitnem registry the way a well-made Gutka reads: warm paper, ink
/// Gurmukhi, a quiet rhythm of pauris, nothing moving unless the reader moves it.
///
/// Fidelity: every Sri Guru Granth Sahib Ji line is the verbatim corpus line (cited by Ang,
/// tappable, saveable). Lines from the extra layer (Sri Dasam Granth / Ardaas) carry their own
/// source label and offer none of the scripture-only actions — the `switch` over `BaniCitation`
/// is exhaustive, so a Dasam line can never be built as an Ang citation. Pauri numbers come only
/// from the verbatim `markers` (see `BaniOutline`); `seq` is the only identity used for scrolling.
struct BaniReaderScreen: View {
    let key: String
    /// Ask for ONE registry form regardless of the reader's Nitnem preferences (the Index opens
    /// e.g. Asa Di Vaar as printed). nil = the preference / registry default, as Nitnem does.
    var variantOverride: String? = nil
    /// Nitnem (the daily practice) or Explore (a composition read on its own). Only the closing
    /// chrome differs — same scripture, same outline, same saved position.
    var context: BaniReaderContext = .nitnem

    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(NitnemPrefs.rehrasVariantKey) private var rehrasVariant = NitnemPrefs.rehrasDefault
    @AppStorage("sggs_focus_mode") private var focusMode = false
    @AppStorage(ReaderPrefs.leadingKey) private var leading = ReaderPrefs.leadingDefault
    @AppStorage(ReaderPrefs.toneKey) private var toneRaw = ReaderTone.paper.rawValue

    @State private var bani: Bani?
    @State private var outline: [BaniSection] = []
    @State private var registry: [BaniSummary] = []
    @State private var failed = false
    @State private var positionId: Int?
    @State private var highlightedId: Int?
    @AccessibilityFocusState private var voFocus: Int?
    @State private var chrome = AmbientChrome()
    @State private var chromeHidden = false
    @State private var saveTask: Task<Void, Never>?
    @State private var completedNow = false
    @StateObject private var live = ReadingActivityController()
    @State private var liveStartTask: Task<Void, Never>?
    @StateObject private var autoScroll = AutoScrollController()
    @AppStorage(AutoScrollPace.storageKey) private var paceRaw = AutoScrollPace.steady.rawValue
    @AppStorage("sggs_gurmukhi_size") private var gurmukhiSize = 24.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tone: ReaderTone { ReaderTone(rawValue: toneRaw) ?? .paper }
    private var variant: String { variantOverride ?? NitnemPrefs.variant(for: key, rehras: rehrasVariant) }
    private var progressId: String { bani.map { $0.summary.id } ?? NitnemPrefs.progressId(key: key, variant: variant) }
    private var pace: AutoScrollPace { AutoScrollPace(rawValue: paceRaw) ?? .steady }
    /// Auto-scroll is offered only with a real scroll view and away from assistive/Reduce-Motion
    /// contexts (moving content under a VoiceOver cursor or against Reduce Motion is hostile).
    private var showsAutoScroll: Bool {
        autoScroll.available && !reduceMotion
        && !UIAccessibility.isVoiceOverRunning && !UIAccessibility.isSwitchControlRunning
    }

    var body: some View {
        content
            .task(id: key + "/" + variant) { await load() }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; flushSave(); autoScroll.stop(); liveStartTask?.cancel(); live.end(done: false) }
            .onChange(of: scenePhase) { _, phase in if phase != .active { flushSave(); autoScroll.pause() } }
            .onChange(of: positionId) { _, _ in scheduleSave(); live.update(fraction: liveFraction, sectionLabel: liveSection) }
            .onChange(of: focusMode) { _, _ in autoScroll.pause(); showChrome() }
            .onChange(of: paceRaw) { _, _ in autoScroll.pace = pace }
            .onChange(of: gurmukhiSize) { _, _ in autoScroll.fontSize = gurmukhiSize }
            .onChange(of: container.presentation?.id) { _, id in if id != nil { autoScroll.pause() } }
            .onChange(of: autoScroll.isRunning) { _, running in
                chrome.autoScrolling = running
                if running { MotionGate.run(Motion.gentle) { chromeHidden = true } } else { showChrome() }
            }
            .onChange(of: container.router.pendingBaniSeq) { _, seq in
                if let seq { container.router.pendingBaniSeq = nil; jump(toSeq: seq) }
            }
    }

    private var content: some View {
        Group {
            if let bani {
                reader(bani)
            } else if failed {
                EmptyStateView(title: "Bani not found", message: "This bani is not in the bundled registry.", isError: true)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(tone.surface.ignoresSafeArea())
        .environment(\.gurmukhiLeading, CGFloat(leading))
        .nightTone(tone.forcesDark)
        .navigationTitle(bani?.summary.titleEn ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if showsAutoScroll {
                    Button { toggleAutoScroll() } label: {
                        Image(systemName: autoScroll.isRunning ? "pause.circle" : "play.circle")
                    }
                    .accessibilityLabel(autoScroll.isRunning ? "Pause auto-scroll" : "Auto-scroll")
                    .accessibilityIdentifier("baniAutoScroll")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !outline.isEmpty {
                        Button { showContents() } label: { Label("Contents", systemImage: "list.bullet") }
                    }
                    Button { container.present(.readingSettings) } label: { Label("Reading settings", systemImage: "textformat.size") }
                    Toggle("Sehaj focus", isOn: $focusMode)
                    Divider()
                    Button { startAgain() } label: { Label("Start again", systemImage: "arrow.counterclockwise") }
                } label: { Image(systemName: "textformat.size") }
                .accessibilityLabel("Reading options")
                .accessibilityIdentifier("baniOptions")
            }
        }
    }

    // MARK: load / progress

    private func load() async {
        guard let corpus = container.corpus else { failed = true; return }
        let loaded = await corpus.bani(key: key, variant: variant)
        registry = await corpus.banis().banis
        guard let loaded else { failed = true; return }
        completedNow = false
        outline = BaniOutline.sections(for: loaded)
        // resume by seq when the registry is unchanged, else by verbatim anchor, else the top
        if let resume = container.nitnem.resumeSeq(for: loaded.summary.id, lines: loaded.lines) {
            chrome.landingInProgress = true
            positionId = resume
            highlightedId = resume
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { chrome.landingInProgress = false }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(FocusLanding.highlightSeconds))
                if highlightedId == resume { highlightedId = nil }
            }
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + FocusLanding.voiceOverDelaySeconds) { voFocus = resume }
            }
        } else {
            positionId = nil
        }
        bani = loaded
        // After `bani` is set (scheduleLiveStart reads it) and for a first read as much as a
        // resumed one — it used to run only in the resume branch, before `bani` existed, so the
        // activity never started on a first load.
        scheduleLiveStart()
    }

    private func anchor(atSeq seq: Int) -> Int? {
        bani?.lines.first { $0.seq == seq }.map { NitnemProgressStore.anchor(of: $0) }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        guard let seq = positionId, seq > 0, let bani else { return }
        let id = progressId, n = bani.lines.count, a = anchor(atSeq: seq)
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            container.nitnem.setPosition(id, seq: seq, anchor: a, nLines: n)
        }
    }

    private func flushSave() {
        saveTask?.cancel()
        if let seq = positionId, seq > 0, let bani {
            container.nitnem.setPosition(progressId, seq: seq, anchor: anchor(atSeq: seq), nLines: bani.lines.count)
        }
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
        live.end(done: true)
    }

    private func showContents() {
        guard let bani else { return }
        container.present(.baniContents(BaniContentsRequest(
            baniId: bani.summary.id, title: bani.summary.titleEn,
            sections: outline, currentSeq: positionId ?? (bani.lines.first?.seq ?? 1))))
    }

    /// The registry rows for the current band's focus category, honouring the Rehras variant.
    /// Empty in the Explore context: a composition read is not part of the day's band.
    private func focusRows() -> [BaniSummary] {
        guard context == .nitnem else { return [] }
        let band = NitnemSchedule.band(at: NitnemClock.now())
        return registry
            .filter { $0.key == "rehras" ? $0.variant == NitnemPrefs.variant(for: "rehras", rehras: rehrasVariant) : $0.isDefault }
            .filter { $0.category == band.focus }
    }

    private func isDone(_ b: BaniSummary) -> Bool {
        b.id == progressId ? (completedNow || container.nitnem.isCompleted(b.id)) : container.nitnem.isCompleted(b.id)
    }

    private var nextBani: BaniSummary? {
        focusRows().sorted { $0.orderNo < $1.orderNo }.first { !isDone($0) }
    }

    /// The next composition on the Index rail (Explore only) — the one gold action at the end.
    private var nextComposition: CompositionCatalog.Hero? {
        guard context == .explore else { return nil }
        return CompositionCatalog.nextHero(after: key, variant: variantOverride ?? "")
    }

    private var bandComplete: Bool {
        let rows = focusRows()
        return !rows.isEmpty && rows.allSatisfy { isDone($0) }
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
            LazyVStack(alignment: .leading, spacing: 18) {
                header(bani)
                ForEach(Array(lines.enumerated()), id: \.element.seq) { index, line in
                    let opensGroup = index > 0 && lines[index - 1].lineGroup != line.lineGroup
                    if let sec = sectionStarting(at: line.seq) {
                        stanzaDivider(sec, firstInBani: index == 0)
                    } else if opensGroup {
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
            .overlay(alignment: .top) { ScrollViewProbe { sv in autoScroll.attach(sv) }.frame(width: 0, height: 0) }
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

    /// The outline section that begins exactly at `seq` (a quiet margin label opens it).
    private func sectionStarting(at seq: Int) -> BaniSection? {
        outline.first { $0.startSeq == seq && ($0.kind == .pauri || $0.kind == .ashtapadi || $0.kind == .salok) }
    }

    @ViewBuilder
    private func stanzaDivider(_ section: BaniSection, firstInBani: Bool) -> some View {
        HStack(spacing: Theme.Space.s) {
            Rectangle().fill(Ink.hairline).frame(width: 28, height: 1)
            Text(section.numberGm.isEmpty ? section.kind.label : "\(section.kind.label) \(section.numberGm)")
                .font(.caption2.weight(.medium)).foregroundStyle(palette.accentText)
            Spacer()
        }
        .padding(.top, firstInBani ? 0 : Theme.Space.m)
        .accessibilityElement()
        .accessibilityLabel(section.accessibilityLabel)
        .accessibilityAddTraits(.isHeader)
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

    /// The end of the bani: mark it read (a quiet seal), then the one gold action leads on. When
    /// the whole set for this time of day is complete, a calm band card closes the reading.
    @ViewBuilder
    private func completion(_ bani: Bani) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Rectangle().fill(Ink.hairline).frame(height: 1).accessibilityHidden(true)
            if completedNow || container.nitnem.isCompleted(progressId) {
                HStack(spacing: Theme.Space.m) {
                    CompletionSeal(sealed: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(bani.summary.titleEn) complete").font(Brand.heading(.headline))
                        if !bani.citationRange.isEmpty {
                            Text(bani.citationRange).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                if bandComplete {
                    bandCompleteCard
                }
                HStack(spacing: Theme.Space.m) {
                    switch context {
                    case .nitnem:
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
                    case .explore:
                        if let next = nextComposition {
                            Button {
                                Haptics.tap()
                                container.router.explorePath.append(
                                    Route.composition(key: next.key, variant: next.variant))
                            } label: { Label("Next: \(next.roman)", systemImage: "arrow.right") }
                            .buttonStyle(.prominentPill)
                            .accessibilityIdentifier("compositionNext")
                        }
                        Button("Back to Index") { popToIndex() }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("baniBackToIndex")
                    }
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

    private var bandCompleteCard: some View {
        let band = NitnemSchedule.band(at: NitnemClock.now())
        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            SectionEyebrow(text: band.title, symbol: "checkmark.seal")
            Text(bandCompleteLine(band)).font(Brand.heading(.headline))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(Ink.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bandComplete")
    }

    private func bandCompleteLine(_ band: NitnemBand) -> String {
        switch band.focus {
        case .nitnemMorning: return "The morning banis are complete."
        case .nitnemEvening: return "Rehras Sahib is complete."
        case .nitnemNight: return "Kirtan Sohila is complete."
        default: return "Complete."
        }
    }

    /// Bottom bar: part navigation for multi-part banis, top/end for single-part, with the
    /// reading position in words and — when there is one — the pauri/ashtapadi caption.
    private func bar(lines: [BaniLine], groups: Int) -> some View {
        let seq = positionId ?? (lines.first?.seq ?? 1)
        let group = lines.first(where: { $0.seq == seq })?.lineGroup ?? 1
        let stanza = stanzaCaption(at: seq)
        return HStack {
            Button {
                if groups > 1 { jump(toGroup: group - 1, lines: lines) } else { jump(toSeq: lines.first?.seq) }
            } label: { Image(systemName: groups > 1 ? "chevron.left" : "arrow.up.to.line").frame(minWidth: 44, minHeight: 44) }
                .disabled(groups > 1 ? group <= 1 : seq <= 1)
                .accessibilityLabel(groups > 1 ? "Previous part" : "Top")
            Spacer()
            VStack(spacing: 1) {
                Text(groups > 1 ? "Part \(group) of \(groups)" : "Line \(min(seq, lines.count)) of \(lines.count)")
                    .font(.subheadline.weight(.medium)).monospacedDigit()
                    .accessibilityIdentifier("baniPosition")
                if let stanza {
                    Text(stanza).font(.caption2).foregroundStyle(.secondary)
                        .accessibilityIdentifier("baniStanza")
                }
            }
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

    /// Live Activity progress inputs (a whole-percent bar; never a verse).
    private var liveFraction: Double {
        guard let bani, bani.lines.count > 0 else { return 0 }
        return min(1, Double(positionId ?? (bani.lines.first?.seq ?? 0)) / Double(bani.lines.count))
    }
    private var liveSection: String { stanzaCaption(at: positionId ?? 0) ?? "" }

    /// Start the reading Live Activity only after a genuine dwell, and never for a bani already
    /// read today (the activity is a companion to reading, never a badge).
    private func scheduleLiveStart() {
        liveStartTask?.cancel()
        guard live.isAvailable, let bani else { return }
        let key = bani.summary.key, en = bani.summary.titleEn, gm = bani.summary.titleGm
        // Reopen the form the reader is actually showing, in the surface it was opened from —
        // otherwise a tap on the printed Vaar's activity would land on the kirtan form in Nitnem.
        let link = activityDeepLink(for: bani.summary)
        liveStartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(ReadingActivityPolicy.startDelay * 1_000_000_000))
            guard !Task.isCancelled, self.bani != nil else { return }
            guard !(completedNow || container.nitnem.isCompleted(progressId)) else { return }
            live.start(key: key, titleEn: en, titleGm: gm, fraction: liveFraction,
                       sectionLabel: liveSection, deepLink: link)
        }
    }

    /// The sggs:// target a Live-Activity tap should reopen: the composition inside Explore, or
    /// the plain bani in Nitnem. Only the registry's own key/variant ever reach the URL.
    private func activityDeepLink(for summary: BaniSummary) -> String {
        switch context {
        case .nitnem:
            return "sggs://bani/\(summary.key)"
        case .explore:
            return summary.variant.isEmpty
                ? "sggs://composition/\(summary.key)"
                : "sggs://composition/\(summary.key)?variant=\(summary.variant)"
        }
    }

    private func stanzaCaption(at seq: Int) -> String? {
        guard let sec = BaniOutline.section(at: seq, in: outline), sec.number > 0 else { return nil }
        let total = outline.filter { $0.kind == sec.kind }.count
        return "\(sec.kind.label) \(sec.number) of \(total)"
    }

    private func toggleAutoScroll() {
        autoScroll.pace = pace
        autoScroll.fontSize = gurmukhiSize
        Haptics.tap()
        autoScroll.toggle()
    }

    private func jump(toGroup g: Int, lines: [BaniLine]) {
        guard let target = lines.first(where: { $0.lineGroup == g }) else { return }
        jump(toSeq: target.seq)
    }

    private func jump(toSeq seq: Int?) {
        guard let seq else { return }
        autoScroll.pause()
        Haptics.tap()
        chrome.landingInProgress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { chrome.landingInProgress = false }
        showChrome()
        positionId = nil
        DispatchQueue.main.async { MotionGate.run(Motion.gentle) { positionId = seq } }
    }

    /// Pop this composition off the Explore stack, leaving the Index. Guarded: a deep link can
    /// put the reader on a stack whose only entry is the reader itself.
    private func popToIndex() {
        var path = container.router.explorePath
        guard !path.isEmpty else { return }
        path.removeLast()
        container.router.explorePath = path
    }

    private func showChrome() {
        chrome.reset()
        if chromeHidden { MotionGate.run(Motion.gentle) { chromeHidden = false } }
    }
}

private extension View {
    /// Force the warm-ink dark scheme on the reader subtree (Night tone) — no new colours.
    @ViewBuilder func nightTone(_ on: Bool) -> some View {
        if on {
            self.environment(\.colorScheme, .dark).toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            self
        }
    }
}
