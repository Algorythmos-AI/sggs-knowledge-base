import SwiftUI

/// The tab shell + the single shared composition sheet + the fail-closed integrity gate.
struct RootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var c = container
        @Bindable var router = container.router
        Group {
            if let report = container.integrity, !report.ok {
                IntegrityFailView(report: report)
            } else if container.startupError != nil {
                IntegrityFailView(report: nil)
            } else {
                TabView(selection: $router.selectedTab) {
                    SearchScreen().tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(Tab.search)
                    ReaderScreen().tabItem { Label("Reader", systemImage: "book") }.tag(Tab.reader)
                    IndexScreen().tabItem { Label("Index", systemImage: "list.bullet") }.tag(Tab.index)
                    ThemesScreen().tabItem { Label("Themes", systemImage: "circle.grid.2x2") }.tag(Tab.themes)
                    MoreScreen().tabItem { Label("More", systemImage: "ellipsis") }.tag(Tab.more)
                }
                .sheet(item: $c.activeComposition) { ShabadSheet(presentation: $0) }
            }
        }
        .tint(Brand.saffron)
    }
}

struct IntegrityFailView: View {
    let report: IntegrityReport?
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.shield").font(.largeTitle).foregroundStyle(.red)
            Text("Scripture integrity check failed").font(.headline)
            Text("The app will not display scripture that cannot be verified against the certified corpus. Please reinstall.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let report {
                ForEach(report.checks.filter { !$0.passed }) { c in
                    Text("• \(c.name)").font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(32)
    }
}
