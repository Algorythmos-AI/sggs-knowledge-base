import SwiftUI
import GurbaniSearchKit

@MainActor @Observable
final class SearchModel {
    var query = ""
    var mode = "auto"
    var state: LoadState<SearchOutput> = .idle
    var verify: VerifyResult?
    /// English of the verified canonical line (display layer; nil when absent/public profile).
    var verifyEn: String?
    private let corpus: CorpusActor?
    init(corpus: CorpusActor?) { self.corpus = corpus }

    /// Web pill order (index.astro): Auto · Gurmukhi · Roman · English · First letters · Theme ·
    /// Verify. English appears only when the DB profile carries the translation layer.
    static func modes(hasEnglish: Bool) -> [(id: String, label: String)] {
        var m: [(id: String, label: String)] = [("auto", "Auto"), ("gurmukhi", "Gurmukhi"), ("roman", "Roman")]
        if hasEnglish { m.append(("english", "English")) }
        m += [("first", "First letters"), ("theme", "Theme"), ("verify", "Verify")]
        return m
    }

    func run() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        verify = nil; verifyEn = nil
        guard !q.isEmpty else { state = .idle; return }
        guard let corpus else { state = .failed("No database"); return }
        state = .loading
        do {
            if mode == "verify" {
                var ang: Int? = nil
                var claim = q
                if let r = q.range(of: #"(?:^|\s)@(\d{1,4})\s*$"#, options: .regularExpression),
                   let n = Int(q[r].drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })),
                   (1...1430).contains(n) {
                    ang = n
                    claim = String(q[q.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                let v = try await corpus.verify(claim, ang: ang)
                if Task.isCancelled { return }
                var en: String? = nil
                if let lid = v.matchedLineId { en = try? await corpus.english(forLine: lid) }
                if Task.isCancelled { return }
                verify = v
                verifyEn = en
                state = .idle
            } else {
                let out = try await corpus.search(q, mode: mode, limit: 50, offset: 0)
                if Task.isCancelled { return }
                state = out.results.isEmpty ? .empty : .loaded(out)
            }
        } catch is CancellationError {
        } catch { state = .failed(UserMessage.search(error)) }
    }
}

struct SearchScreen: View {
    @Environment(AppContainer.self) private var container
    @State private var model: SearchModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: Binding(get: { model?.query ?? "" },
                                          set: { model?.query = $0 }),
                            prompt: "ਨਾਮੁ · waheguru · ਸ ਨ ਕ · naam")
        }
        .task {
            if model == nil { model = SearchModel(corpus: container.corpus) }
            consumePendingQuery()
        }
        .onChange(of: container.router.pendingSearchQuery) { _, _ in consumePendingQuery() }
    }

    /// Deep-linked query (sggs://search?q=…) — consumed exactly once, only after the model
    /// exists (a link landing before first render must not be dropped).
    private func consumePendingQuery() {
        guard let model, let q = container.router.pendingSearchQuery, !q.isEmpty else { return }
        model.query = q
        model.mode = "auto"   // a deep-linked query must not inherit a sticky Verify/theme mode
        container.router.pendingSearchQuery = nil
    }

    @ViewBuilder private var content: some View {
        if let model {
            let modes = SearchModel.modes(hasEnglish: container.corpus?.capabilities.hasEnglish == true)
            VStack(spacing: 0) {
                // web-style mode pills (7 modes don't fit a segmented control)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.s) {
                        ForEach(modes, id: \.id) { m in
                            ModePill(title: m.label, isSelected: model.mode == m.id,
                                     accessibilityID: "mode_\(m.id)") { model.mode = m.id }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, Theme.Space.xs)
                .accessibilityIdentifier("searchModePicker")

                resultArea(model)
            }
            .task(id: SearchKey(q: model.query, mode: model.mode)) {
                if model.query.trimmingCharacters(in: .whitespaces).isEmpty { model.state = .idle; model.verify = nil; return }
                try? await Task.sleep(for: .milliseconds(250))     // debounce
                guard !Task.isCancelled else { return }
                await model.run()
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder private func resultArea(_ model: SearchModel) -> some View {
        if let v = model.verify {
            ScrollView { VerdictView(result: v, en: model.verifyEn) { ang in container.router.openAng(ang) }.padding() }
        } else {
            LoadStateView(state: model.state, emptyTitle: "No matches",
                          emptyMessage: "Try fewer words, first-letters mode, or a theme (naam, hukam, haumai).",
                          onRetry: { Task { await model.run() } },
                          idle: { AnyView(SearchIdleView(mode: model.mode)) }) { out in
                List {
                    if let themes = out.relatedThemes, !themes.isEmpty {
                        Section { Text("Related themes: " + themes.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Brand.gold) }
                    }
                    ForEach(out.results, id: \.id) { line in
                        LineRow(gurmukhi: line.gurmukhi, translit: line.translit, meta: line.metaLine,
                                en: line.en, lineId: line.id, ang: line.ang, compId: line.compId) {
                            container.present(.shabad(compId: line.compId))
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct SearchKey: Equatable { let q: String; let mode: String }

/// The Search tab's idle canvas: what to type and which mode does what — instead of a blank
/// pane under the pills (the empty-RESULTS state already had guidance; the idle state didn't).
struct SearchIdleView: View {
    let mode: String
    @Environment(\.palette) private var palette
    private var hint: (title: String, lines: [String]) {
        switch mode {
        case "verify": return ("Verify a quotation",
                               ["Paste a line as you remember it — Gurmukhi or Roman.",
                                "Add @Ang to check a claimed page, e.g. “… @1”.",
                                "The verdict cites the canonical line and its Ang."])
        case "first": return ("First letters", ["Type the first letter of each word: ਸ ਨ ਕ", "or in Roman: s n k"])
        case "theme": return ("Theme", ["Try naam, hukam, haumai, seva, simran", "Every tagged verse, cited by Ang"])
        case "english": return ("English", ["Search the labelled translation layer: mercy, light, ego"])
        case "gurmukhi": return ("Gurmukhi", ["ਨਾਮੁ · ਸਤਿਗੁਰ · ਹੁਕਮਿ"])
        case "roman": return ("Roman", ["waheguru · satgur · naam — spelling is forgiven"])
        default: return ("Search the Granth", ["ਨਾਮੁ · waheguru · ਸ ਨ ਕ · naam",
                                                "Words, sounds, first letters or a theme — Auto picks the tier.",
                                                "Every result is verbatim scripture, cited by Ang."])
        }
    }
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Text("ੴ").font(Brand.gurmukhi(44, relativeTo: .largeTitle))
                .foregroundStyle(palette.accent.opacity(0.55)).accessibilityHidden(true)
            Text(hint.title).font(.headline)
            ForEach(hint.lines, id: \.self) { l in
                Text(l).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
        .accessibilityIdentifier("searchIdle")
    }
}
