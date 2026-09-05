import SwiftUI
import GurbaniSearchKit

/// The 54 corpus themes, grouped theologically — native parity with the web /themes
/// (frontend/src/scripts/themes.ts THEME_CATS). Tapping a card shows every tagged verse.
/// Stack-less: pushed inside the Explore tab's NavigationStack, whose destination
/// table resolves Route.theme — theme deep links land here via Router.explorePath.
struct ThemesScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette

    /// Web THEME_CATS, with one correction: the web list still says `akal_kaal`, which was
    /// split into `akal` + `kaal` in v2.9.5 — here `akal` (the Timeless) stays under the
    /// Divine Reality and `kaal` (time/death) joins the Human Condition beside jam.
    /// Any slug not matched below falls into "More Themes" — a theme is NEVER dropped.
    private static let groups: [(title: String, caption: String, keys: [String])] = [
        ("The Divine Reality", "God, the Names, and the cosmic Word",
         ["ik_onkar", "vahiguru", "karta", "akal", "hukam", "naam", "shabad", "bani", "jot", "anhad", "patit_pavan"]),
        ("The Human Condition & Illusions", "Ego, mind, attachment, and the wheel of birth–death",
         ["haumai", "maya", "man", "sansar", "janam_maran", "avagavan", "manmukh", "bharam", "dukh_sukh", "garab", "trishna", "bhavjal", "jam", "kaal"]),
        ("The Five Vices", "The panj chor that rob the soul",
         ["kaam", "krodh", "lobh", "moh", "ahankar"]),
        ("The Path & Praxis", "The Guru, the Sangat, and the daily practice",
         ["satguru", "gurmukh", "simran", "bhagti", "seva", "sangat", "sant_sadh", "sifat_salah", "darshan", "charan", "marag_panth"]),
        ("Virtues & Divine Attributes", "The qualities the gurmukh cultivates and the Lord embodies",
         ["prem_pyar", "daya", "nimrata", "santokh", "bhau", "bhana", "karam_nadar"]),
        ("Spiritual States", "The fruits of the path — poise, bliss, liberation",
         ["anand", "sahaj", "sach", "mukti", "amrit", "maran_jeevan"]),
    ]

    private let columns = [GridItem(.flexible(), spacing: Theme.Space.m), GridItem(.flexible())]

    private static func titleCase(_ slug: String) -> String {
        slug.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    var body: some View {
        Group {
            if let meta = container.meta {
                let byKey = Dictionary(uniqueKeysWithValues: meta.concepts.map { ($0.concept, $0) })
                let placed = Set(Self.groups.flatMap(\.keys))
                let leftover = meta.concepts.filter { !placed.contains($0.concept) }
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        Text("Explore the Granth by idea — each theme gathers every verse that uses its corpus-verified Gurmukhi words, shown verbatim with its Ang.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(Self.groups, id: \.title) { group in
                            let concepts = group.keys.compactMap { byKey[$0] }
                            if !concepts.isEmpty {
                                themeSection(title: group.title, caption: group.caption, concepts: concepts)
                            }
                        }
                        if !leftover.isEmpty {
                            themeSection(title: "More Themes", caption: "", concepts: leftover)
                        }
                    }
                    .padding(Theme.Space.l)
                }
                .background(Ink.canvas)
                .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle("Themes")
        .task { await container.loadMeta() }
    }

    private func themeSection(title: String, caption: String, concepts: [ConceptRow]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                if !caption.isEmpty {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: columns, spacing: Theme.Space.m) {
                ForEach(concepts) { c in
                    NavigationLink(value: Route.theme(c.concept)) {
                        Card {
                            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                Text(Self.titleCase(c.concept))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if !c.description.isEmpty {
                                    Text(c.description)
                                        .font(.caption2).foregroundStyle(.secondary)
                                        .lineLimit(3, reservesSpace: true)
                                        .multilineTextAlignment(.leading)
                                }
                                Text("Explore \(c.nLines.formatted()) lines →")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(palette.accentText)
                            }
                        }
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(Self.titleCase(c.concept)) — explore \(c.nLines) lines")
                }
            }
        }
    }
}

struct ThemeResultsScreen: View {
    let concept: String
    @Environment(AppContainer.self) private var container
    @State private var state: LoadState<[SearchLine]> = .loading

    var body: some View {
        LoadStateView(state: state, onRetry: { Task { await load() } }) { lines in
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
        .task(id: concept) { await load() }
    }

    private func load() async {
        guard let corpus = container.corpus else { state = .failed("No database"); return }
        state = .loading
        do { let t = try await corpus.theme(concept); state = t.lines.isEmpty ? .empty : .loaded(t.lines) }
        catch { state = .failed(UserMessage.load(error)) }
    }
}
