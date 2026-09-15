import SwiftUI
import UIKit
import GurbaniSearchKit

/// The single shared composition modal (the panel.ts analogue): a full shabad by comp_id, or a
/// Hukam-style random draw. Presented from one root `.sheet(item:)` driven by AppContainer.
/// When opened from a specific verse it scrolls that verse to the centre, highlights it, and
/// (with VoiceOver) starts reading there rather than at the title.
struct ShabadSheet: View {
    let presentation: CompositionPresentation
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState<[ReaderLine]> = .loading
    @State private var title = "Loading…"
    @State private var openAng: Int?
    @State private var highlightedId: Int?
    @AccessibilityFocusState private var voFocus: Int?

    private var focusLineId: Int? {
        if case .shabad(_, let l) = presentation { return l }
        return nil
    }

    var body: some View {
        NavigationStack {
            LoadStateView(state: state, emptyTitle: "Composition not found",
                          emptyMessage: "No lines carry this composition id.",
                          onRetry: { Task { await load() } }) { lines in
                ScrollViewReader { proxy in
                    List {
                        ForEach(lines, id: \.id) { line in
                            if line.isHeader {
                                // Verbatim heading row(s) — a raag/title line
                                // ('ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ') and/or the ੴ invocation
                                // now open the composition (matches the printed saroop and
                                // the Reader). Rendered as a centred heading, never a savable
                                // verse row. Mirrors ReaderScreen.
                                GurmukhiText(verbatim: line.gurmukhi, size: 20, weight: .semibold)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 4)
                                    .id(line.id)
                                    .listRowSeparator(.hidden)
                            } else {
                                // Full line identity: Share carries the Ang citation, and Save /
                                // Explore-related work from inside the sheet (never an "Ang 0" card).
                                LineRow(gurmukhi: line.gurmukhi, translit: line.translit,
                                        meta: line.isRahao ? "ਰਹਾਉ · refrain" : "", en: line.en,
                                        lineId: line.id, ang: line.ang, compId: line.compId)
                                    .focusHighlight(highlightedId == line.id)
                                    .accessibilityFocused($voFocus, equals: line.id)
                                    .id(line.id)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    // A fresh List instance per load: land on the requested verse once it has rows.
                    .onAppear { landOnFocusLine(proxy, lines: lines) }
                    // Always-visible footer (a 385-line composition must not hide the Reader link
                    // at its very end). Lands the Reader on the verse this sheet was opened from,
                    // or the composition's first verse for Hukam / plain opens.
                    .safeAreaInset(edge: .bottom) {
                        // Compositions span Angs: open the Ang the FOCUSED verse is on (else the
                        // Reader would land on the composition's first Ang and drop the verse).
                        let targetLine = lines.first(where: { $0.id == focusLineId })
                            ?? lines.first(where: { !$0.isHeader }) ?? lines.first
                        if let ang = targetLine?.ang ?? openAng {
                            Button {
                                container.router.openAng(ang, lineId: targetLine?.id)
                                dismiss()
                            } label: {
                                Label("Open Ang \(String(ang)) in Reader", systemImage: "book")
                                    .font(.body.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Theme.Space.m)
                            .background(Capsule().fill(Ink.card))
                            .overlay(Capsule().strokeBorder(Ink.hairline))
                            .padding(.horizontal, Theme.Space.l)
                            .frame(maxWidth: 520).frame(maxWidth: .infinity)
                            .padding(.bottom, Theme.Space.xs)
                            .accessibilityIdentifier("openInReader")
                        }
                    }
                }
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

    /// Two-pass landing: List rows exist only after the first layout, so the scroll is issued on
    /// the next main-queue turn (unanimated to materialise, then animated to centre). A line id
    /// that is not in this composition is ignored — no scroll, no highlight.
    private func landOnFocusLine(_ proxy: ScrollViewProxy, lines: [ReaderLine]) {
        guard let id = focusLineId, lines.contains(where: { $0.id == id }) else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .center)
            DispatchQueue.main.async {
                MotionGate.run(Motion.gentle) { proxy.scrollTo(id, anchor: .center) }
                highlightedId = id
            }
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + FocusLanding.voiceOverDelaySeconds) { voFocus = id }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(FocusLanding.highlightSeconds))
                if highlightedId == id { highlightedId = nil }
            }
        }
    }

    private func load() async {
        guard let corpus = container.corpus else { state = .failed("No database"); return }
        state = .loading
        do {
            switch presentation {
            case .shabad(let compId, _):
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
