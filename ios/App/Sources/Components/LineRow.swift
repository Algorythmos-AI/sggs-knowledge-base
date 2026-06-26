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
    /// Provide line identity to enable the Save (bookmark) action.
    var lineId: Int? = nil
    var ang: Int = 0
    var compId: Int = 0
    var onTap: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GurmukhiText(verbatim: gurmukhi, size: 22)
            if showTranslit && !translit.isEmpty {
                Text(translit).font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityHidden(true)            // a reading aid, not scripture
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
                Button { save(lineId) } label: { Label("Save", systemImage: "bookmark") }
                Button {
                    container.activeTrail = TrailStart(id: lineId, gurmukhi: gurmukhi,
                                                       translit: translit, ang: ang, compId: compId)
                } label: { Label("Explore related", systemImage: "point.3.connected.trianglepath.dotted") }
            }
        }
    }

    private func save(_ lineId: Int) {
        let item = SavedLine(lineId: lineId, gurmukhi: gurmukhi, translit: translit, ang: ang, compId: compId)
        modelContext.insert(item)
        try? modelContext.save()
    }
}

extension SearchLine {
    var metaLine: String {
        [ "Ang \(ang)", raag, author ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
