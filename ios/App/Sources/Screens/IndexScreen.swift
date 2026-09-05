import SwiftUI
import GurbaniSearchKit

/// Browse the Granth — native parity with the web /browse: a Major-Compositions quick-access
/// rail, then pill-switched Raags / Banis & Sections / Voices (meta-driven). Tapping anything
/// jumps the Reader to its first Ang. Stack-less: pushed inside the Explore NavigationStack.
struct IndexScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @State private var tab = "compositions"

    /// Web parity (`frontend/src/scripts/browse.ts` QUICK_ACCESS): headline compositions that
    /// live inside larger raag sections, routed straight to their starting Ang. Every Ang was
    /// verified against the section-header line in the corpus when the web list was built.
    private static let quickAccess: [(gm: String, roman: String, ang: Int, where_: String)] = [
        ("ਸੁਖਮਨੀ ਸਾਹਿਬ", "Sukhmani Sahib", 262, "Raag Gauri"),
        ("ਆਸਾ ਕੀ ਵਾਰ", "Asa Ki Vaar", 462, "Raag Asa"),
        ("ਅਨੰਦੁ ਸਾਹਿਬ", "Anand Sahib", 917, "Raag Ramkali"),
        ("ਬਾਵਨ ਅਖਰੀ", "Bavan Akhri", 250, "Raag Gauri"),
        ("ਸਿਧ ਗੋਸਟਿ", "Sidh Gosht", 938, "Raag Ramkali"),
        ("ਓਅੰਕਾਰੁ", "Dakhni Oankaar", 929, "Raag Ramkali"),
    ]

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
        .task { await container.loadMeta() }
    }

    // MARK: compositions — the hero rail

    private var compositionsGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("MAJOR COMPOSITIONS — QUICK ACCESS")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: Theme.Space.m) {
                ForEach(Self.quickAccess, id: \.ang) { c in
                    Button { container.router.openAng(c.ang) } label: {
                        Card {
                            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                GurmukhiText(verbatim: c.gm, size: 20)
                                Text(c.roman)
                                    .font(.footnote.weight(.medium)).italic()
                                    .foregroundStyle(palette.accentText)
                                Text("Ang \(String(c.ang)) · \(c.where_)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(c.roman) — open Ang \(c.ang)")
                }
            }
        }
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
