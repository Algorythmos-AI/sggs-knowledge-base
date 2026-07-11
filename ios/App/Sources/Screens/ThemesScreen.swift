import SwiftUI
import GurbaniSearchKit

/// The 54 corpus themes; tapping shows the lines tagged with that concept.
/// Stack-less: pushed inside the Explore tab's NavigationStack, whose destination
/// table resolves Route.theme — theme deep links land here via Router.explorePath.
struct ThemesScreen: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            if let meta = container.meta {
                List(meta.concepts) { c in
                    NavigationLink(value: Route.theme(c.concept)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(c.concept.capitalized).font(.body)
                                if !c.description.isEmpty {
                                    Text(c.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(c.nLines)").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle("Themes")
        .task { await container.loadMeta() }
    }
}

struct ThemeResultsScreen: View {
    let concept: String
    @Environment(AppContainer.self) private var container
    @State private var state: LoadState<[SearchLine]> = .loading

    var body: some View {
        LoadStateView(state: state) { lines in
            List(lines, id: \.id) { line in
                LineRow(gurmukhi: line.gurmukhi, translit: line.translit, meta: line.metaLine,
                        en: line.en, lineId: line.id, ang: line.ang, compId: line.compId) {
                    container.present(.shabad(compId: line.compId))
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
        .navigationTitle(concept.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: concept) {
            guard let corpus = container.corpus else { state = .failed("No database"); return }
            do { let t = try await corpus.theme(concept); state = t.lines.isEmpty ? .empty : .loaded(t.lines) }
            catch { state = .failed(UserMessage.load(error)) }
        }
    }
}
