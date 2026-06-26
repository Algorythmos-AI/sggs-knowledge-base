import SwiftUI
import UIKit
import GurbaniSearchKit

/// One scripture line: Gurmukhi (saroop-aware) + transliteration + metadata, with verbatim
/// copy/share. Tapping opens the composition. Used by Search results, Reader, Themes, Trail.
struct LineRow: View {
    let gurmukhi: String
    let translit: String
    let meta: String
    var showTranslit = true
    var onTap: (() -> Void)? = nil

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
        }
    }
}

extension SearchLine {
    var metaLine: String {
        [ "Ang \(ang)", raag, author ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
