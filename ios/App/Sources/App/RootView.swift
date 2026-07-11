import SwiftUI

/// The tab shell + the single shared composition sheet + the fail-closed integrity gate.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("sggs_appearance") private var appearance = "system"
    @State private var savedStoreNoticeDismissed = false

    var body: some View {
        @Bindable var c = container
        @Bindable var router = container.router
        Group {
            if container.startupError != nil {
                IntegrityFailView(report: nil)
            } else if container.integrity == nil {
                // Still verifying — do NOT present scripture before the integrity check passes.
                VStack(spacing: 14) {
                    Text("ੴ").font(Brand.gurmukhi(64)).foregroundStyle(Brand.saffron)
                    ProgressView()
                    Text("Verifying scripture integrity…").font(.caption).foregroundStyle(.secondary)
                }
            } else if let report = container.integrity, !report.ok {
                IntegrityFailView(report: report, onRetry: {
                    Task { await container.retryIntegrity() }
                })
            } else {
                TabView(selection: $router.selectedTab) {
                    ReaderScreen().tabItem { Label("Reader", systemImage: "book") }.tag(Tab.reader)
                    SearchScreen().tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(Tab.search)
                    ExploreScreen().tabItem { Label("Explore", systemImage: "square.grid.2x2") }.tag(Tab.explore)
                    MoreScreen().tabItem { Label("More", systemImage: "ellipsis") }.tag(Tab.more)
                }
                .sheet(item: $c.presentation, onDismiss: { container.flushPendingPresentation() }) { p in
                    switch p {
                    case .shabad, .hukam: ShabadSheet(presentation: p.composition ?? .hukam)
                    case .trail(let start): TrailScreen(start: start)
                    case .cluster(let center, let cluster): ClusterSheet(center: center, cluster: cluster)
                    }
                }
                .safeAreaInset(edge: .top) {
                    if container.savedStoreDegraded && !savedStoreNoticeDismissed {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.slash").foregroundStyle(.secondary)
                            Text(container.modelContainer == nil
                                 ? "Saved verses are unavailable this session."
                                 : "Saved verses won't persist from before — the bookmarks store was reset.")
                                .font(.caption)
                            Spacer()
                            Button { savedStoreNoticeDismissed = true } label: {
                                Image(systemName: "xmark").font(.caption2)
                            }
                            .accessibilityLabel("Dismiss notice")
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.thinMaterial)
                    }
                }
            }
        }
        .tint(Brand.saffron)
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
    }
}

struct IntegrityFailView: View {
    let report: IntegrityReport?
    /// Re-runs the launch verification (a transient I/O hiccup shouldn't need a reinstall).
    var onRetry: (() -> Void)? = nil
    @State private var retrying = false
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.shield").font(.largeTitle).foregroundStyle(.red)
            Text("Scripture integrity check failed").font(.headline)
            Text("The app will not display scripture that cannot be verified against the certified corpus.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let report {
                ForEach(report.checks.filter { !$0.passed }) { c in
                    Text("• \(c.name)").font(.caption).foregroundStyle(.red)
                }
            }
            if let onRetry {
                Button {
                    retrying = true
                    onRetry()
                } label: {
                    if retrying { ProgressView() } else { Text("Verify again") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(retrying)
            }
            Text("If this keeps failing, reinstall the app.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(32)
    }
}
