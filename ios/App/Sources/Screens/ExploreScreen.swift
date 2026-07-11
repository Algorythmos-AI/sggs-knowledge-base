import SwiftUI

/// The Explore hub: one place for the browse/insight surfaces (web-navbar parity without
/// burying them under settings). Owns the Explore tab's NavigationStack; every destination
/// below is stack-less and pushed via `Route`. New surfaces (Lineage, Vaars, Raag Clock
/// detail…) get a card + a Route case here — that's the whole checklist for adding one.
struct ExploreScreen: View {
    @Environment(AppContainer.self) private var container

    private struct Entry: Identifiable {
        let route: Route
        let title: String
        let caption: String
        let icon: String
        var id: String { title }
    }

    private let entries: [Entry] = [
        .init(route: .index, title: "Index",
              caption: "Raags, sections & authors — jump anywhere", icon: "list.bullet"),
        .init(route: .themes, title: "Themes",
              caption: "54 concepts, every tagged verse", icon: "circle.grid.2x2"),
        .init(route: .lineage, title: "Lineage",
              caption: "30 voices across five centuries", icon: "person.2"),
        .init(route: .insights, title: "Insights",
              caption: "Contributors, network, resonance & flow", icon: "chart.bar.xaxis"),
        .init(route: .constellation, title: "Constellation",
              caption: "A theme's verses clustered by co-theme", icon: "circle.hexagongrid"),
        .init(route: .vaars, title: "Vaars",
              caption: "22 ballads — pauri & salok anatomy", icon: "list.number"),
    ]

    var body: some View {
        @Bindable var router = container.router
        NavigationStack(path: $router.explorePath) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.m), GridItem(.flexible())],
                          spacing: Theme.Space.m) {
                    ForEach(entries) { e in
                        NavigationLink(value: e.route) {
                            Card {
                                VStack(alignment: .leading, spacing: Theme.Space.s) {
                                    Image(systemName: e.icon)
                                        .font(.title2)
                                        .foregroundStyle(Theme.accent)
                                    Text(e.title).font(.headline).foregroundStyle(.primary)
                                    Text(e.caption)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(e.title)
                        .accessibilityHint(e.caption)
                        .accessibilityIdentifier(e.title)
                    }
                }
                .padding(Theme.Space.l)
            }
            .navigationTitle("Explore")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .index: IndexScreen()
                case .themes: ThemesScreen()
                case .lineage: LineageScreen()
                case .insights: InsightsScreen()
                case .constellation: ConstellationScreen()
                case .vaars: VaarsScreen()
                case .theme(let name): ThemeResultsScreen(concept: name)
                case .raagAng: EmptyView()   // reserved (future: raag detail)
                }
            }
        }
    }
}
