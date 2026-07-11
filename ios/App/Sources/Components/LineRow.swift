import SwiftUI
import UIKit
import SwiftData
import GurbaniSearchKit

/// One scripture line: Gurmukhi (saroop-aware) + transliteration + metadata, with verbatim
/// copy/share/save. Tapping opens the composition.
struct LineRow: View {
    let gurmukhi: String
    let translit: String
    let meta: String
    var showTranslit = true
    /// The labelled English translation (Khalsa layer) — a SEPARATE layer under the scripture,
    /// never blended into the Gurmukhi. nil (2,619 lines have none, and the public DB profile
    /// has the whole layer absent) renders nothing — no placeholder.
    var en: String? = nil
    /// Provide line identity to enable the Save (bookmark) action.
    var lineId: Int? = nil
    var ang: Int = 0
    var compId: Int = 0
    var onTap: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @AppStorage("sggs_translit") private var translitPref = true
    @AppStorage("sggs_show_english") private var englishPref = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GurmukhiText(verbatim: gurmukhi, size: 22)
            if showTranslit && translitPref && !translit.isEmpty {
                Text(translit).font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityHidden(true)            // a reading aid, not scripture
            }
            if englishPref, let en, !en.isEmpty {
                Text(en).font(.callout).foregroundStyle(.secondary)
                    .accessibilityLabel("English translation: \(en)")
            }
            if !meta.isEmpty {
                Text(meta).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .contextMenu {
            Button { UIPasteboard.general.string = gurmukhi } label: {
                Label("Copy verse", systemImage: "doc.on.doc")     // verbatim — never the saroop form
            }
            ShareLink(item: gurmukhi) { Label("Share", systemImage: "square.and.arrow.up") }
            if let lineId {
                // Save needs a live SwiftData container; when even the in-memory fallback failed
                // the action is hidden rather than crashing on \.modelContext access.
                if container.modelContainer != nil {
                    Button { save(lineId) } label: { Label("Save", systemImage: "bookmark") }
                }
                Button {
                    container.present(.trail(TrailStart(id: lineId, gurmukhi: gurmukhi,
                                                        translit: translit, ang: ang, compId: compId)))
                } label: { Label("Explore related", systemImage: "point.3.connected.trianglepath.dotted") }
            }
        }
    }

    /// Idempotent save: a verse already bookmarked is a no-op (the @unique lineId would otherwise
    /// throw on the second insert). Verbatim gurmukhi only — never the saroop display form.
    private func save(_ lineId: Int) {
        let existing = FetchDescriptor<SavedLine>(predicate: #Predicate { $0.lineId == lineId })
        if let count = try? modelContext.fetchCount(existing), count > 0 { return }
        modelContext.insert(SavedLine(lineId: lineId, gurmukhi: gurmukhi, translit: translit, ang: ang, compId: compId))
        do { try modelContext.save(); Haptics.success() }
        catch { modelContext.rollback() }     // keep the context clean on failure
    }
}

extension SearchLine {
    var metaLine: String {
        [ "Ang \(ang)", raag, author ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
