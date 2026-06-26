import SwiftUI
import GurbaniSearchKit

@MainActor @Observable
final class SearchModel {
    var query = ""
    var mode = "auto"
    var state: LoadState<SearchOutput> = .idle
    var verify: VerifyResult?
    private let corpus: CorpusActor?
    init(corpus: CorpusActor?) { self.corpus = corpus }

    static let modes: [(id: String, label: String)] = [
        ("auto", "Auto"), ("gurmukhi", "Gurmukhi"), ("roman", "Roman"),
        ("first", "First letters"), ("theme", "Theme"), ("verify", "Verify"),
    ]

    func run() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        verify = nil
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
                verify = v
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
        .task { if model == nil { model = SearchModel(corpus: container.corpus) } }
    }

    @ViewBuilder private var content: some View {
        if let model {
            VStack(spacing: 0) {
                Picker("Mode", selection: Binding(get: { model.mode }, set: { model.mode = $0 })) {
                    ForEach(SearchModel.modes, id: \.id) { Text($0.label).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
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
            ScrollView { VerdictView(result: v) { ang in container.router.openAng(ang) }.padding() }
        } else {
            LoadStateView(state: model.state, emptyTitle: "No matches",
                          emptyMessage: "Try fewer words, first-letters mode, or a theme (naam, hukam, haumai).") { out in
                List {
                    if let themes = out.relatedThemes, !themes.isEmpty {
                        Section { Text("Related themes: " + themes.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Brand.gold) }
                    }
                    ForEach(out.results, id: \.id) { line in
                        LineRow(gurmukhi: line.gurmukhi, translit: line.translit, meta: line.metaLine,
                                lineId: line.id, ang: line.ang, compId: line.compId) {
                            container.presentation = .shabad(compId: line.compId)
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
