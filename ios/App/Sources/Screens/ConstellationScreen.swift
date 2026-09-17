import SwiftUI
import GurbaniSearchKit

/// Concept Constellation: pick a theme; its verses cluster around the OTHER themes they most share.
/// Rendered as a deterministic radial map (centre = the theme, orbiting bubbles = co-theme clusters
/// sized by verse count). Descriptive structure — never a ranking of scripture.
struct ConstellationScreen: View {
    @Environment(AppContainer.self) private var container
    @State private var concept = "naam"
    @State private var state: LoadState<ConstellationResult> = .loading

    private var concepts: [ConceptRow] { container.meta?.concepts ?? [] }

    var body: some View {
        VStack(spacing: 12) {
            Menu {
                ForEach(concepts) { c in
                    Button(c.concept.capitalized) { concept = c.concept }
                }
            } label: {
                HStack {
                    Text("Theme: \(concept.capitalized)").font(.headline)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
            }
            .padding(.top, 8)

            LoadStateView(state: state) { result in
                VStack(spacing: 12) {
                    Text("\(result.total) verses carry this theme · grouped by their closest companion theme")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    if result.clusters.isEmpty {
                        ContentUnavailableView("No companion themes", systemImage: "circle.dotted")
                    } else {
                        ConstellationMap(center: concept, clusters: result.clusters) {
                            container.present(.cluster(center: concept, cluster: $0))
                        }
                        .padding()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Ink.base.ignoresSafeArea())
        .navigationTitle("Constellation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await container.loadMeta() }
        .task(id: concept) { await load() }
    }

    private func load() async {
        guard let corpus = container.corpus else { state = .failed("No database"); return }
        state = .loading
        do {
            let r = try await corpus.constellation(concept: concept)
            // .task(id: concept) cancels on switch — never let theme A's late reply
            // overwrite theme B's view, and never swallow a real failure into a spinner.
            if Task.isCancelled { return }
            state = .loaded(r)
        } catch is CancellationError {
        } catch { state = .failed(UserMessage.load(error)) }
    }
}

/// Deterministic radial layout: centre node + co-theme bubbles on a ring, sized by √(verse count).
private struct ConstellationMap: View {
    let center: String
    let clusters: [ConstellationCluster]
    var onSelect: (ConstellationCluster) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let c = CGPoint(x: w / 2, y: h / 2)
            let ring = min(w, h) * 0.36
            let maxN = Double(clusters.map(\.n).max() ?? 1)
            ZStack {
                // connecting lines (the "constellation")
                Path { p in
                    for (i, _) in clusters.enumerated() {
                        p.move(to: c); p.addLine(to: point(i, c, ring))
                    }
                }
                .stroke(Brand.gold.opacity(0.25), lineWidth: 1)

                // centre node
                bubble(label: center.capitalized, sub: nil, diameter: 84, fill: Brand.primaryFill)
                    .position(c)
                    .accessibilityHidden(true)

                // co-theme bubbles
                ForEach(Array(clusters.enumerated()), id: \.element.id) { i, cl in
                    let d = 44 + CGFloat((Double(max(cl.n, 0)).squareRoot() / maxN.squareRoot())) * 52
                    Button { onSelect(cl) } label: {
                        bubble(label: cl.co.capitalized, sub: "\(cl.n)", diameter: d, fill: Brand.gold)
                    }
                    .buttonStyle(.plain)
                    .position(point(i, c, ring))
                    .accessibilityLabel("\(cl.co), \(cl.n) verses shared with \(center)")
                }
            }
        }
        .frame(minHeight: 360)
    }

    private func point(_ i: Int, _ c: CGPoint, _ r: CGFloat) -> CGPoint {
        let a = 2 * Double.pi * Double(i) / Double(max(clusters.count, 1)) - Double.pi / 2
        return CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
    }

    private func bubble(label: String, sub: String?, diameter: CGFloat, fill: Color) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
            if let sub { Text(sub).font(.caption2).opacity(0.85) }
        }
        .foregroundStyle(AccentPalette.brandDefault.onAccent)
        .frame(width: diameter, height: diameter)
        .background(Circle().fill(fill.gradient))
    }
}

struct ClusterSheet: View {
    let center: String
    let cluster: ConstellationCluster
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(cluster.verses) { v in
                LineRow(gurmukhi: v.gurmukhi, translit: "", meta: "Ang \(v.ang)",
                        lineId: v.id, ang: v.ang, compId: v.compId) {
                    container.present(.shabad(compId: v.compId, focusLineId: v.id))
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Ink.base)
            }
            .listStyle(.plain)
            .inkPlainList()
            .navigationTitle("\(center.capitalized) + \(cluster.co.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
