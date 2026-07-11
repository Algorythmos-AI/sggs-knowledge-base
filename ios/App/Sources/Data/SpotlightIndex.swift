import Foundation
import CoreSpotlight

/// System-search indexing for SAVED verses only (a user's own bookmarks — never the full 60k
/// corpus: index size/rebuild cost isn't worth it, and search inside the app is far better).
/// Verbatim Gurmukhi + Ang citation; tapping a result deep-links to the composition.
enum SpotlightIndex {
    private static let domain = "org.sggs.saved"

    static func identifier(lineId: Int, compId: Int) -> String { "saved-\(lineId)-comp-\(compId)" }

    static func index(lineId: Int, compId: Int, gurmukhi: String, translit: String, ang: Int) {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = gurmukhi                       // verbatim — never the saroop display form
        attrs.contentDescription = "\(translit)\nSri Guru Granth Sahib · Ang \(ang)"
        attrs.keywords = ["Gurbani", "SGGS", translit]
        let item = CSSearchableItem(uniqueIdentifier: identifier(lineId: lineId, compId: compId),
                                    domainIdentifier: domain, attributeSet: attrs)
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func remove(lineId: Int, compId: Int) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [identifier(lineId: lineId, compId: compId)])
    }

    /// Parse a Spotlight result back to its composition (nil for foreign identifiers).
    static func compId(fromIdentifier id: String) -> Int? {
        guard id.hasPrefix("saved-"), let range = id.range(of: "-comp-") else { return nil }
        return Int(id[range.upperBound...])
    }
}
