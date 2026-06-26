import SwiftUI
import GurbaniSearchKit

@MainActor @Observable
final class ReaderModel {
    var state: LoadState<AngPage> = .loading
    private let corpus: CorpusActor?
    init(corpus: CorpusActor?) { self.corpus = corpus }
    func load(_ ang: Int) async {
        guard let corpus else { state = .failed("No database"); return }
        state = .loading
        do { let page = try await corpus.ang(ang); if Task.isCancelled { return }; state = .loaded(page) }
        catch { state = .failed(UserMessage.load(error)) }
    }
}

struct ReaderScreen: View {
    @Environment(AppContainer.self) private var container
    @State private var model: ReaderModel?

    var body: some View {
        @Bindable var router = container.router
        NavigationStack {
            Group {
                if let model {
                    LoadStateView(state: model.state) { page in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                if let raag = page.raag {
                                    Text(raag).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.gold)
                                }
                                if let from = page.continuedFrom {
                                    Label("Continues from Ang \(from)", systemImage: "arrow.up.backward")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                ForEach(page.lines, id: \.id) { line in
                                    if line.isHeader {
                                        GurmukhiText(verbatim: line.gurmukhi, size: 20, weight: .semibold)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 4)
                                    } else {
                                        LineRow(gurmukhi: line.gurmukhi, translit: line.translit,
                                                meta: line.isRahao ? "ਰਹਾਉ · refrain" : "",
                                                lineId: line.id, ang: line.ang, compId: line.compId) {
                                            container.presentation = .shabad(compId: line.compId)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else { Color.clear }
            }
            .navigationTitle("Ang \(router.readerAng)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { router.openAng(router.readerAng - 1) } label: { Image(systemName: "chevron.left") }
                        .disabled(router.readerAng <= 1)
                        .accessibilityLabel("Previous Ang")
                    Spacer()
                    Button { Haptics.tap(); container.presentation = .hukam } label: { Label("Hukam", systemImage: "sparkles") }
                    Spacer()
                    Button { router.openAng(router.readerAng + 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(router.readerAng >= 1430)
                        .accessibilityLabel("Next Ang")
                }
            }
        }
        .task(id: container.router.readerAng) {
            if model == nil { model = ReaderModel(corpus: container.corpus) }
            await model?.load(container.router.readerAng)
        }
    }
}
