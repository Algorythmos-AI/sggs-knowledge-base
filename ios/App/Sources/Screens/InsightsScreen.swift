import SwiftUI
import Charts
import GurbaniSearchKit

@MainActor @Observable
final class InsightsModel {
    var authors: [AuthorStat] = []
    var raags: [RaagStat] = []
    var edges: [ThemeEdge] = []
    var loaded = false
    private let corpus: CorpusActor?
    init(corpus: CorpusActor?) { self.corpus = corpus }
    func load() async {
        guard !loaded, let corpus else { return }
        authors = (try? await corpus.authorAnalytics()) ?? []
        raags = (try? await corpus.raagAnalytics()) ?? []
        edges = (try? await corpus.themeNetwork(minPPMI: 0.7, limit: 40)) ?? []
        loaded = true
    }
}

struct InsightsScreen: View {
    @Environment(AppContainer.self) private var container
    @State private var model: InsightsModel?
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $tab) {
                Text("Contributors").tag(0); Text("Raags").tag(1); Text("Themes").tag(2)
            }
            .pickerStyle(.segmented).padding()

            if let model, model.loaded {
                switch tab {
                case 0: ContributorsView(authors: model.authors)
                case 1: RaagsView(raags: model.raags)
                default: ThemeConnectionsView(edges: model.edges)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = InsightsModel(corpus: container.corpus) }
            await model?.load()
        }
    }

    static func shortAuthor(_ s: String) -> String {
        if let r = s.range(of: #"\(M\d+\)"#, options: .regularExpression) { return String(s[r]) }
        return s.replacingOccurrences(of: " Ji", with: "").replacingOccurrences(of: "Bhagat ", with: "")
    }
}

private struct ContributorsView: View {
    let authors: [AuthorStat]
    var body: some View {
        List {
            Section {
                Chart(authors.prefix(12)) { a in
                    BarMark(x: .value("Lines", a.nLines),
                            y: .value("Author", InsightsScreen.shortAuthor(a.author)))
                        .foregroundStyle(Brand.saffron.gradient)
                }
                .chartXAxisLabel("Lines")
                .frame(height: 300)
                .accessibilityLabel("Lines contributed per author")
            } footer: {
                Text("Lines contributed to the Granth, per author. Descriptive — never a ranking of merit.")
            }
            Section("Stylometry") {
                ForEach(authors) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.author).font(.subheadline)
                        Text("\(a.nLines) lines · \(a.nShabads) shabads · \(a.nRaags) raags · lexical diversity \(a.mattr100, format: .number.precision(.fractionLength(2)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct RaagsView: View {
    let raags: [RaagStat]
    var body: some View {
        List {
            Section {
                Chart(raags.prefix(14)) { r in
                    BarMark(x: .value("Lines", r.nLines), y: .value("Raag", r.raag))
                        .foregroundStyle(Brand.gold.gradient)
                }
                .chartXAxisLabel("Lines")
                .frame(height: 340)
                .accessibilityLabel("Lines per raag")
            } footer: {
                Text("How much of the Granth sits in each raag (musical measure).")
            }
            Section("Detail") {
                ForEach(raags) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        GurmukhiText(verbatim: r.raag, size: 18)
                        Text("\(r.nLines) lines · \(r.nShabads) shabads · \(r.nAuthors) authors")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ThemeConnectionsView: View {
    let edges: [ThemeEdge]
    var body: some View {
        List {
            Section {
                ForEach(edges) { e in
                    HStack {
                        Text("\(e.source.capitalized) + \(e.target.capitalized)")
                        Spacer()
                        Text("\(e.shabadCount) shabads").font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(e.source) and \(e.target) co-occur in \(e.shabadCount) shabads")
                }
            } header: {
                Text("Themes that appear together")
            } footer: {
                Text("Concept pairs that co-occur within shabads more than chance (PPMI ≥ 0.7). Descriptive.")
            }
        }
    }
}
