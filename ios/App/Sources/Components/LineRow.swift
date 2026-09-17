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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("sggs_translit") private var translitPref = true
    @AppStorage("sggs_show_english") private var englishPref = true
    @Environment(\.palette) private var palette

    /// ਰਹਾਉ marks the shabad's central line — it gets a quiet accent rule in the margin.
    /// The scripture itself stays ink (brand book: never colour the text).
    private var isRahao: Bool { meta.hasPrefix("ਰਹਾਉ") }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GurmukhiText(verbatim: gurmukhi, size: 22)
            if showTranslit && translitPref && !translit.isEmpty {
                Text(translit).font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)            // a reading aid, not scripture
            }
            if englishPref, let en, !en.isEmpty {
                Text(en).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("English translation: \(en)")
            }
            if !meta.isEmpty {
                Text(meta).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, isRahao ? Theme.Space.m : 0)
        .overlay(alignment: .leading) {
            if isRahao {
                RoundedRectangle(cornerRadius: 1.5).fill(palette.accent)
                    .frame(width: 3).accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .contextMenu {
            Button { UIPasteboard.general.string = gurmukhi } label: {
                Label("Copy verse", systemImage: "doc.on.doc")     // verbatim — never the saroop form
            }
            ShareLink(item: shareText) { Label("Share", systemImage: "square.and.arrow.up") }
            Button {
                // A card is only ever rendered WITH its Ang citation — a call site that didn't
                // provide line identity falls back to the plain text share (which self-gates).
                if ang > 0, let img = VerseCardRenderer.render(gurmukhi: gurmukhi, translit: translit,
                                                               en: englishPref ? en : nil, ang: ang,
                                                               scheme: colorScheme) {
                    presentShareSheet(items: [img])
                } else {
                    assert(ang > 0, "LineRow used without line identity — pass lineId/ang/compId")
                    presentShareSheet(items: [shareText])
                }
            } label: { Label("Share as card", systemImage: "photo") }
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
        // VoiceOver/Switch Control: ONE combined element with every context-menu action mirrored
        // as an accessibility action (a contextMenu alone is unreachable non-visually). The label
        // speaks the VERBATIM Gurmukhi in Punjabi, then the English layer, then the metadata —
        // the translit stays out (redundant phonetics for a listener already hearing Punjabi).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(composedA11yLabel))
        .accessibilityAddTraits(onTap != nil ? [.isButton] : [])
        .accessibilityHint(onTap != nil ? "Opens the composition" : "")
        .accessibilityAction(named: "Copy verse") { UIPasteboard.general.string = gurmukhi }
        .accessibilityAction(named: "Share") { presentShareSheet(items: [shareText]) }
        .accessibilityActions {
            if let lineId {
                if container.modelContainer != nil {
                    Button("Save") { save(lineId) }
                }
                Button("Explore related") {
                    container.present(.trail(TrailStart(id: lineId, gurmukhi: gurmukhi,
                                                        translit: translit, ang: ang, compId: compId)))
                }
            }
        }
    }

    /// Shared text carries the Ang citation (never bare scripture without its source).
    private var shareText: String {
        var out = gurmukhi
        if ang > 0 { out += "\n— Sri Guru Granth Sahib Ji, Ang \(ang)" }
        return out
    }

    /// Gurmukhi (spoken as Punjabi) → English layer → metadata.
    private var composedA11yLabel: AttributedString {
        var g = AttributedString(gurmukhi)
        g.languageIdentifier = "pa"
        var out = g
        if let en, !en.isEmpty {
            out += AttributedString(". English translation: \(en)")
        }
        if !meta.isEmpty { out += AttributedString(". \(meta)") }
        else if ang > 0 { out += AttributedString(". Ang \(ang)") }
        return out
    }

    /// UIKit share presenter (ShareLink can't be invoked programmatically; card images need it
    /// too). Verbatim scripture + Ang citation only.
    private func presentShareSheet(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let root = scene.keyWindow?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        var top = root
        while let presented = top.presentedViewController { top = presented }
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }

    /// Idempotent save: a verse already bookmarked is a no-op (the @unique lineId would otherwise
    /// throw on the second insert). Verbatim gurmukhi only — never the saroop display form.
    private func save(_ lineId: Int) {
        let existing = FetchDescriptor<SavedLine>(predicate: #Predicate { $0.lineId == lineId })
        if let count = try? modelContext.fetchCount(existing), count > 0 { return }
        modelContext.insert(SavedLine(lineId: lineId, gurmukhi: gurmukhi, translit: translit, ang: ang, compId: compId))
        do {
            try modelContext.save()
            Haptics.success()
            // saved verses surface in system search (verbatim + Ang; removed on delete)
            SpotlightIndex.index(lineId: lineId, compId: compId, gurmukhi: gurmukhi,
                                 translit: translit, ang: ang)
        }
        catch { modelContext.rollback() }     // keep the context clean on failure
    }
}

extension SearchLine {
    var metaLine: String {
        [ "Ang \(ang)", raag, author ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
