import SwiftUI
import GurbaniSearchKit

/// Semantic Trail: walk from a verse to verses whose *English meaning* is closest (TF-IDF cosine).
/// Scores are shown as calibrated relatedness BANDS, never a raw % — and never as a ranking of
/// scripture (the note makes this explicit). You can step deeper (breadcrumb) or open any verse.
struct TrailScreen: View {
    let start: TrailStart
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var trail: [TrailStart] = []
    @State private var state: LoadState<NeighborsResult> = .loading

    private var current: TrailStart { trail.last ?? start }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if !trail.isEmpty { breadcrumb }
                pinnedVerse
                Divider()
                LoadStateView(state: state, emptyTitle: "No related verses",
                              emptyMessage: "This verse has no computed neighbours.") { result in
                    List {
                        Section {
                            ForEach(result.neighbors) { n in
                                neighborRow(n)
                            }
                        } header: {
                            Text(result.level == "composition"
                                 ? "Compositions with the closest theme profile"
                                 : "Verses closest in meaning")
                        } footer: {
                            Text("Descriptive relatedness by English-meaning similarity — not a ranking of scripture.")
                                .font(.caption2)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Related verses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                if !trail.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { trail.removeLast() } label: { Label("Back", systemImage: "chevron.left") }
                    }
                }
            }
        }
        .task(id: current.id) { await load(current.id) }
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Ang \(String(start.ang))").font(.caption2)
                ForEach(trail) { step in
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    Text("Ang \(String(step.ang))").font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal).padding(.top, 8)
        }
    }

    private var pinnedVerse: some View {
        VStack(alignment: .leading, spacing: 6) {
            GurmukhiText(verbatim: current.gurmukhi, size: 22)
            HStack {
                Text("Ang \(String(current.ang))").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { container.present(.shabad(compId: current.compId)) } label: {
                    Label("Open", systemImage: "book").font(.caption)
                }
            }
        }
        .padding()
        .background(Brand.saffron.opacity(0.08))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Ink.hairline), alignment: .bottom)
    }

    private func neighborRow(_ n: Neighbor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GurmukhiText(verbatim: n.gurmukhi, size: 20)
            HStack(spacing: 8) {
                RelatednessBadge(score: n.score)
                Text(["Ang \(n.ang)", n.raag, n.author].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {                                   // step deeper into the trail
            trail.append(TrailStart(id: n.id, gurmukhi: n.gurmukhi, translit: n.translit,
                                    ang: n.ang, compId: n.compId))
        }
        .swipeActions(edge: .trailing) {
            Button { container.present(.shabad(compId: n.compId)) } label: { Label("Open", systemImage: "book") }
        }
    }

    private func load(_ lineId: Int) async {
        guard let corpus = container.corpus else { state = .failed("No database"); return }
        state = .loading
        do {
            let r = try await corpus.neighbors(lineId: lineId, limit: 12)
            state = r.neighbors.isEmpty ? .empty : .loaded(r)
        } catch { state = .failed(UserMessage.load(error)) }
    }
}

/// Calibrated relatedness band (NOT a raw %). Floor is the build's 0.30 min-cosine.
/// Thresholds + labels come from Theme.echoBand (web core.ts relBand parity: 0.65/0.45).
struct RelatednessBadge: View {
    let score: Double
    private var band: (label: String, color: Color) { Theme.echoBand(score) }
    var body: some View {
        Text(band.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(band.color.opacity(0.15)))
            .foregroundStyle(band.color)
            .accessibilityLabel("\(band.label) by meaning")
    }
}
