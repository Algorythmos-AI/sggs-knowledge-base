import GurbaniSearchKit

/// Which raag / bani span an Ang falls in — for the Jump sheet's live location line and the
/// scrubber's VoiceOver value. Pure and cheap: a linear scan over `CorpusMeta` (≈31 raag rows,
/// already in memory once `AppContainer.loadMeta()` has run). Raag spans answer first; after
/// Ang 1353 the Granth leaves the raag framework (Saloks, Swaiyye, Mundavani, Raagmala…), so
/// section spans answer there. Never touches scripture text.
enum AngLocator {
    struct Location: Equatable {
        /// The raag name in Gurmukhi (nil for a post-1353 section span, which has no raag).
        let gurmukhi: String?
        /// Roman / English label (raag roman, or the section name).
        let roman: String?
        let firstAng: Int
        let lastAng: Int

        var rangeLabel: String {
            firstAng == lastAng ? "Ang \(firstAng)" : "Angs \(firstAng)–\(lastAng)"
        }
    }

    /// The span containing `ang`, or nil when meta is unavailable or nothing matches.
    static func location(for ang: Int, meta: CorpusMeta?) -> Location? {
        guard let meta else { return nil }
        if let r = meta.raags.first(where: { ($0.firstAng...$0.lastAng).contains(ang) }) {
            return Location(gurmukhi: r.name, roman: r.roman, firstAng: r.firstAng, lastAng: r.lastAng)
        }
        if let s = meta.sections.first(where: { ($0.firstAng...$0.lastAng).contains(ang) }) {
            return Location(gurmukhi: nil, roman: s.name, firstAng: s.firstAng, lastAng: s.lastAng)
        }
        return nil
    }

    /// The Ang at which each raag span begins — the scrubber's tick marks. Sorted, de-duplicated.
    static func raagBoundaries(meta: CorpusMeta?) -> [Int] {
        guard let meta else { return [] }
        return Array(Set(meta.raags.map { $0.firstAng })).sorted()
    }
}
