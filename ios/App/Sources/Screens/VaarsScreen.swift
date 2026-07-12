import SwiftUI
import GurbaniSearchKit

/// The 22 Vaars — heroic ballads of numbered pauris with flanking saloks. Structural metadata
/// only, never a ranking of scripture. The famous cross-voice editorial structure: a Vaar's
/// PAURIS take the Vaar's author even when interleaved SALOKS carry other Gurus' ਮਃ headers —
/// displayed verbatim from the tables, never re-derived.
struct VaarsScreen: View {
    @Environment(AppContainer.self) private var container
    @State private var vaars: [VaarSummary]?

    var body: some View {
        Group {
            if let vaars {
                if vaars.isEmpty {
                    ContentUnavailableView("Vaar tables not in this build", systemImage: "list.number")
                } else {
                    List(vaars) { v in
                        NavigationLink {
                            VaarAnatomyScreen(summary: v)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                HStack {
                                    if let raag = v.raag { GurmukhiText(verbatim: raag, size: 18) }
                                    if let roman = v.roman { Text(roman).font(.caption).foregroundStyle(.secondary) }
                                    Spacer()
                                    if v.crossAuthor {
                                        Badge(text: "cross-voice", color: Ink.special)
                                    }
                                }
                                if let title = v.title, !title.isEmpty {
                                    GurmukhiText(verbatim: title, size: 15)
                                }
                                Text("\(String(v.nPauris)) pauris · \(String(v.nSaloks)) saloks · Angs \(String(v.firstAng))–\(String(v.lastAng))"
                                     + (v.pauriAuthor.map { " · \($0)" } ?? ""))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Vaars")
        .task {
            guard vaars == nil, let corpus = container.corpus else { return }
            vaars = await corpus.vaars()
        }
    }
}

/// One Vaar's salok + pauri anatomy in reading order; tap a unit to read it in place.
struct VaarAnatomyScreen: View {
    let summary: VaarSummary
    @Environment(AppContainer.self) private var container
    @State private var anatomy: VaarAnatomy?

    var body: some View {
        Group {
            if let anatomy {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                            Text("\(String(summary.nPauris)) pauris · \(String(summary.nSaloks)) saloks")
                                .font(.subheadline.weight(.medium))
                            if let pa = summary.pauriAuthor {
                                Text("Pauris by \(pa)" + (summary.salokAuthors.isEmpty ? ""
                                     : " · saloks by \(summary.salokAuthors.joined(separator: ", "))"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("Saloks by a different Guru than the pauris are the famous cross-voice editorial structure — shown verbatim, never re-derived.")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    Section {
                        ForEach(anatomy.units, id: \.seq) { u in
                            Button {
                                container.router.openAng(u.ang)
                            } label: {
                                HStack(spacing: Theme.Space.m) {
                                    Text(u.kind == "pauri" ? "P\(String(u.pauriNo ?? 0))" : "S")
                                        .font(.caption.weight(.bold)).monospacedDigit()
                                        .frame(width: 34, height: 24)
                                        .background(RoundedRectangle(cornerRadius: 6)
                                            .fill(u.kind == "pauri" ? Theme.accent.opacity(0.2) : Color(.tertiarySystemFill)))
                                        .foregroundStyle(u.kind == "pauri" ? Theme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(u.kind).font(.subheadline)
                                            if let author = u.author {
                                                Text("· \(author)").font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Text("\(String(u.nLines)) lines · Ang \(String(u.ang))"
                                             + (u.theme.map { " · \($0)" } ?? ""))
                                            .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(u.kind)\(u.pauriNo.map { " \($0)" } ?? "")\(u.author.map { " by \($0)" } ?? ""), \(u.nLines) lines, Ang \(u.ang)")
                        }
                    } header: {
                        Text("Anatomy in reading order")
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(summary.roman.map { "Vaar · \($0)" } ?? "Vaar")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard anatomy == nil, let corpus = container.corpus else { return }
            anatomy = await corpus.vaar(id: summary.vaarId)
        }
    }
}
