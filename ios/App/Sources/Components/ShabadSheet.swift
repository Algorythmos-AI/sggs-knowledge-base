import SwiftUI
import GurbaniSearchKit

/// The single shared composition modal (the panel.ts analogue): a full shabad by comp_id, or a
/// Hukam-style random draw. Presented from one root `.sheet(item:)` driven by AppContainer.
struct ShabadSheet: View {
    let presentation: CompositionPresentation
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState<[ReaderLine]> = .loading
    @State private var title = "Loading…"
    @State private var openAng: Int?

    var body: some View {
        NavigationStack {
            LoadStateView(state: state, emptyTitle: "Composition not found",
                          emptyMessage: "No lines carry this composition id.",
                          onRetry: { Task { await load() } }) { lines in
                List {
                    ForEach(lines, id: \.id) { line in
                        // Full line identity: Share carries the Ang citation, and Save /
                        // Explore-related work from inside the sheet (never an "Ang 0" card).
                        LineRow(gurmukhi: line.gurmukhi, translit: line.translit,
                                meta: line.isRahao ? "ਰਹਾਉ · refrain" : "", en: line.en,
                                lineId: line.id, ang: line.ang, compId: line.compId)
                            .listRowSeparator(.hidden)
                    }
                    if let ang = openAng {
                        Button("Open Ang \(String(ang)) in Reader") { container.router.openAng(ang); dismiss() }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                if case .hukam = presentation {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { Task { await load() } } label: { Label("Another", systemImage: "arrow.clockwise") }
                    }
                }
            }
        }
        .task(id: presentation) { await load() }
    }

    private func load() async {
        guard let corpus = container.corpus else { state = .failed("No database"); return }
        state = .loading
        do {
            switch presentation {
            case .shabad(let compId):
                let s = try await corpus.shabad(compId: compId)
                title = s.lines.first.map { "Ang \($0.ang)" } ?? "Composition not found"
                openAng = s.lines.first?.ang
                state = s.lines.isEmpty ? .empty : .loaded(s.lines)
            case .hukam:
                let h = try await corpus.randomHukam()
                title = h.lines.first.map { "Hukam · Ang \($0.ang)" } ?? "Hukam"
                openAng = h.lines.first?.ang
                state = h.lines.isEmpty ? .empty : .loaded(h.lines)
            }
        } catch { state = .failed(UserMessage.load(error)) }
    }
}
