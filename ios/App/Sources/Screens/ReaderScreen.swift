import SwiftUI
import GurbaniSearchKit

@MainActor @Observable
final class ReaderModel {
    var state: LoadState<AngPage> = .loading
    /// Timing chip data for the current page's raag (metadata-only; nil = no chip).
    var timing: RaagTiming?
    private let corpus: CorpusActor?
    init(corpus: CorpusActor?) { self.corpus = corpus }
    func load(_ ang: Int) async {
        guard let corpus else { state = .failed("No database"); return }
        // Page turns keep the current page on screen while the next loads (local SQLite,
        // ~ms) — no spinner flash mid-read. The spinner only shows on first entry.
        if case .loaded = state {} else { state = .loading }
        do {
            let page = try await corpus.ang(ang)
            if Task.isCancelled { return }
            MotionGate.run(Motion.gentle) { state = .loaded(page) }
            timing = nil
            if corpus.capabilities.hasTiming, let raag = page.raag {
                let t = await corpus.timingRaag(name: raag)
                if !Task.isCancelled, t.available, !t.claims.isEmpty { timing = t }
            }
        }
        catch { state = .failed(UserMessage.load(error)) }
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

    var body: some View {
        @Bindable var router = container.router
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(state: model.state,
                                  onRetry: { Task { await model.load(router.readerAng) } }) { page in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
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
                                ForEach(page.lines, id: \.id) { line in
                                    if line.isHeader {
                                        GurmukhiText(verbatim: line.gurmukhi, size: 20, weight: .semibold)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 4)
                                    } else {
                                        LineRow(gurmukhi: line.gurmukhi,
                                                translit: focusMode ? "" : line.translit,
                                                meta: line.isRahao ? "ਰਹਾਉ · refrain" : "",
                                                en: focusMode ? nil : line.en,
                                                lineId: line.id, ang: line.ang, compId: line.compId) {
                                            container.present(.shabad(compId: line.compId))
                                        }
                                        .padding(.vertical, focusMode ? Theme.Space.s : 0)
                                    }
                                }
                            }
                            .padding()
                        }
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
            .background(Ink.paper.ignoresSafeArea())
            .navigationTitle("Ang \(String(router.readerAng))")
            .navigationBarTitleDisplayMode(.inline)
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
                            Label("Hukam", systemImage: "sparkles").frame(minHeight: 44)
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
                    .padding(.bottom, Theme.Space.xs)
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
                return
            }
            await model?.load(container.router.readerAng)
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
