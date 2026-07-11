import SwiftUI
import GurbaniSearchKit

/// Every raag where the timing traditions DISAGREE — conflicting claims side by side with
/// their tradition/confidence badges and citations. Disagreement is preserved scholarship,
/// not error, and is never adjudicated. Native parity with the web /divergence.
struct DivergenceScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var divergence: TimingDivergence?

    var body: some View {
        NavigationStack {
            Group {
                if let divergence {
                    if !divergence.available {
                        ContentUnavailableView("Timing layer not in this build",
                                               systemImage: "clock.badge.questionmark")
                    } else if divergence.raags.isEmpty {
                        ContentUnavailableView("No disagreements recorded",
                                               systemImage: "checkmark.circle")
                    } else {
                        List {
                            Section {
                                Text("Where the sources place a raag in different watches, every claim is kept with its citation.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(divergence.raags) { entry in
                                Section {
                                    ForEach(Array(entry.claims.enumerated()), id: \.offset) { _, c in
                                        VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                            HStack(spacing: Theme.Space.xs) {
                                                Badge(text: c.claimType,
                                                      color: c.claimType == "primary" ? Theme.accent : .purple)
                                                Badge(text: c.confidence,
                                                      color: c.confidence == "disputed" ? .red : .green)
                                                Badge(text: c.tradition.replacingOccurrences(of: "_", with: " "),
                                                      color: .blue)
                                                Spacer()
                                                if let p = c.pahar {
                                                    Text("P\(p) · \(Pahar.range(p))")
                                                        .font(.caption.weight(.medium)).monospacedDigit()
                                                }
                                            }
                                            if let notes = c.notes, !notes.isEmpty {
                                                Text(notes).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Text("Source: \(c.sourceName)").font(.caption2).foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                } header: {
                                    HStack(spacing: Theme.Space.s) {
                                        GurmukhiText(verbatim: entry.raag, size: 18)
                                        if let roman = entry.roman { Text(roman).font(.caption) }
                                        Spacer()
                                        if let ang = entry.firstAng {
                                            Button("Ang \(String(ang))") { dismiss(); container.router.openAng(ang) }
                                                .font(.caption2)
                                        }
                                    }
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Where traditions disagree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task {
            guard divergence == nil, let corpus = container.corpus else { return }
            divergence = await corpus.timingDivergence()
        }
    }
}
