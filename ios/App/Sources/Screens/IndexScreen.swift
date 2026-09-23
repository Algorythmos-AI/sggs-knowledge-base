import SwiftUI
import GurbaniSearchKit

/// Browse the Granth — native parity with the web /browse: a Major-Compositions rail, then
/// pill-switched Raags / Banis & Sections / Voices (meta-driven). Stack-less: pushed inside the
/// Explore NavigationStack.
///
/// A major composition opens its OWN reader (`Route.composition`, pushed on this same stack) so
/// Sukhmani Sahib reads as one work — cover, contents, saved position — instead of dropping the
/// Ang reader mid-page. Raags, sections and voices still jump the Reader to their first Ang, and
/// so does a composition when this DB profile carries no bani registry.
struct IndexScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @State private var tab = "compositions"
    /// The bani registry — summary rows only, one query, never any lines. Loaded before the grid
    /// renders so a tap can't race it; empty when this profile has no registry.
    @State private var registry: [BaniSummary] = []

    /// The raag count comes from the DB's `raags` table (31 in the certified corpus).
    private func tabs(_ meta: CorpusMeta) -> [(id: String, label: String)] {
        [("compositions", "Compositions"), ("raags", "The \(String(meta.raags.count)) Raags"),
         ("sections", "Banis & Sections"), ("authors", "Voices")]
    }

    private let columns = [GridItem(.flexible(), spacing: Theme.Space.m), GridItem(.flexible())]

    var body: some View {
        Group {
            if let meta = container.meta {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Space.s) {
                                ForEach(tabs(meta), id: \.id) { t in
                                    ModePill(title: t.label, isSelected: tab == t.id,
                                             accessibilityID: "index_\(t.id)") { tab = t.id }
                                }
                            }
                        }
                        switch tab {
                        case "raags": raagsGrid(meta)
                        case "sections": sectionsList(meta)
                        case "authors": authorsList(meta)
                        default: compositionsGrid
                        }
                    }
                    .padding(Theme.Space.l)
                    .appAnimation(Motion.gentle, value: tab)
                }
                .background(Ink.canvas)
                .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Index")
        .task {
            await container.loadMeta()
            await loadRegistry()
        }
        // The reading rings come from `container.nitnem`, which is @Observable — they refresh
        // themselves when a composition reader writes a position. This only retries the registry
        // when the DB was not open yet on first appearance (a cold launch straight into Explore).
        .task(id: container.corpus == nil) { await loadRegistry() }
    }

    private func loadRegistry() async {
        guard registry.isEmpty, let corpus = container.corpus, corpus.capabilities.hasBanis else { return }
        registry = await corpus.banis().banis
    }

    // MARK: compositions — the hero rail

    private var compositionsGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("MAJOR COMPOSITIONS")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, spacing: Theme.Space.m) {
                    ForEach(CompositionCatalog.heroes) { hero in
                        heroCard(hero)
                    }
                }
            }
            let more = CompositionCatalog.more(from: registry)
            if !more.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionEyebrow(text: "More compositions", symbol: "text.book.closed")
                    VStack(spacing: 0) {
                        ForEach(Array(more.enumerated()), id: \.element.id) { i, b in
                            NavigationLink(value: Route.composition(key: b.key, variant: b.variant)) {
                                BaniRow(bani: b, date: Date())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("composition_\(b.key)")
                            if i < more.count - 1 {
                                Divider().padding(.leading, Theme.Space.l * 2 + 28)
                            }
                        }
                    }
                    .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
                }
            }
        }
    }

    /// One hero card. Titles and reading facts come from the registry when it resolves, so the
    /// card and the screen it opens always agree; the curated text is the no-registry fallback.
    @ViewBuilder
    private func heroCard(_ hero: CompositionCatalog.Hero) -> some View {
        let summary = CompositionCatalog.resolve(hero, in: registry)
        let label = accessibilityLabel(hero, summary)
        if let summary {
            NavigationLink(value: Route.composition(key: hero.key, variant: hero.variant)) {
                heroCardBody(hero, summary)
            }
            .buttonStyle(.pressableCard)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityIdentifier("composition_\(hero.key)")
        } else {
            // No registry in this DB profile (or the key is missing): the card still works,
            // exactly as it always did, by opening the composition's first Ang.
            Button { container.router.openAng(hero.ang) } label: {
                heroCardBody(hero, nil)
            }
            .buttonStyle(.pressableCard)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityIdentifier("composition_\(hero.key)")
        }
    }

    private func heroCardBody(_ hero: CompositionCatalog.Hero, _ summary: BaniSummary?) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(alignment: .top) {
                    GurmukhiText(verbatim: summary?.titleGm ?? hero.gm, size: 20)
                    Spacer(minLength: Theme.Space.xs)
                    // The ring appears only once there IS something to show — an empty ring on
                    // every card would read as a checkbox and clutter a browsing surface.
                    if let summary {
                        let done = container.nitnem.isCompleted(summary.id)
                        let frac = container.nitnem.fraction(for: summary.id, total: summary.nLines)
                        if done || frac > 0 {
                            ProgressRing(fraction: frac, done: done).frame(width: 22, height: 22)
                        }
                    }
                }
                Text(summary?.titleEn ?? hero.roman)
                    .font(.footnote.weight(.medium)).italic()
                    .foregroundStyle(palette.accentText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(meta(hero, summary))
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func meta(_ hero: CompositionCatalog.Hero, _ summary: BaniSummary?) -> String {
        var parts = ["Ang \(String(hero.ang))", hero.raag]
        if let m = summary?.estimatedMinutes { parts.append("about \(m) min") }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(_ hero: CompositionCatalog.Hero, _ summary: BaniSummary?) -> String {
        guard let summary else { return "\(hero.roman) — open Ang \(hero.ang)" }
        let pct = Int(container.nitnem.fraction(for: summary.id, total: summary.nLines) * 100)
        let progress = container.nitnem.isCompleted(summary.id) ? "read today"
            : (pct > 0 ? "\(pct) percent read" : "not started")
        return "\(summary.titleEn) — read the composition. \(meta(hero, summary)). \(progress)."
    }

    // MARK: raags

    private func raagsGrid(_ meta: CorpusMeta) -> some View {
        LazyVGrid(columns: columns, spacing: Theme.Space.m) {
            ForEach(meta.raags) { r in
                Button { container.router.openAng(r.firstAng) } label: {
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            GurmukhiText(verbatim: r.name, size: 20)
                            Text("Ang \(String(r.firstAng))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Raag \(r.name), from Ang \(r.firstAng)")
            }
        }
    }

    // MARK: banis & sections

    private func sectionsList(_ meta: CorpusMeta) -> some View {
        VStack(spacing: Theme.Space.s) {
            ForEach(meta.sections) { s in
                Button { container.router.openAng(s.firstAng) } label: {
                    Card {
                        HStack {
                            GurmukhiText(verbatim: s.name, size: 18)
                            Spacer()
                            Text("Ang \(String(s.firstAng))")
                                .font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("\(s.name), from Ang \(s.firstAng)")
            }
        }
    }

    // MARK: voices

    private func authorsList(_ meta: CorpusMeta) -> some View {
        VStack(spacing: Theme.Space.s) {
            ForEach(meta.authors) { a in
                Button { container.router.openAng(a.firstAng) } label: {
                    Card {
                        HStack {
                            Text(a.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(a.nLines) lines")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("\(a.name), \(a.nLines) lines, from Ang \(a.firstAng)")
            }
        }
    }
}
