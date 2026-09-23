import Foundation
import GurbaniSearchKit

/// The Index's "Major Compositions": long works that live structurally INSIDE a raag section and
/// are read as one composition (Sukhmani Sahib, Asa Ki Vaar, …). Each entry names a registry bani
/// by `key` + `variant`, so tapping one opens the composition reader rather than dropping the
/// reader mid-Ang.
///
/// `ang` / `raag` are the verified facts the web Index has always shown (web parity:
/// `frontend/src/scripts/browse.ts` QUICK_ACCESS) and double as the FALLBACK route for a bundled
/// DB that carries no bani registry — in that case the card still opens the Ang, as before.
///
/// Titles come from the registry whenever it resolves, so a card and the screen it opens can never
/// disagree; the curated Gurmukhi/roman here are only used when the registry is absent.
enum CompositionCatalog {

    struct Hero: Identifiable, Equatable, Sendable {
        let key: String
        /// "" = whichever variant the registry marks default.
        let variant: String
        let gm: String
        let roman: String
        let ang: Int
        let raag: String
        /// Matches `BaniSummary.id` so progress/rings line up.
        var id: String { variant.isEmpty ? key : "\(key)/\(variant)" }
    }

    /// The curated rail, in the order the Index has always shown it.
    static let heroes: [Hero] = [
        Hero(key: "sukhmani", variant: "", gm: "ਸੁਖਮਨੀ ਸਾਹਿਬ", roman: "Sukhmani Sahib",
             ang: 262, raag: "Raag Gauri"),
        // The Vaar as printed (Ang 462–475), not the kirtan interleave the Nitnem list carries.
        Hero(key: "asa_di_vaar", variant: "printed", gm: "ਆਸਾ ਕੀ ਵਾਰ", roman: "Asa Ki Vaar",
             ang: 462, raag: "Raag Asa"),
        Hero(key: "anand", variant: "", gm: "ਅਨੰਦੁ ਸਾਹਿਬ", roman: "Anand Sahib",
             ang: 917, raag: "Raag Ramkali"),
        Hero(key: "bavan_akhri", variant: "", gm: "ਬਾਵਨ ਅਖਰੀ", roman: "Bavan Akhri",
             ang: 250, raag: "Raag Gauri"),
        Hero(key: "sidh_gosht", variant: "", gm: "ਸਿਧ ਗੋਸਟਿ", roman: "Sidh Gosht",
             ang: 938, raag: "Raag Ramkali"),
        Hero(key: "oankaar", variant: "", gm: "ਓਅੰਕਾਰੁ", roman: "Dakhni Oankaar",
             ang: 929, raag: "Raag Ramkali"),
    ]

    /// The registry row a hero names, or nil when this DB profile has no registry / no such row.
    /// An empty `variant` resolves the default row exactly as `/api/bani/{key}` does.
    static func resolve(_ hero: Hero, in registry: [BaniSummary]) -> BaniSummary? {
        registry.first { $0.key == hero.key
            && (hero.variant.isEmpty ? $0.isDefault : $0.variant == hero.variant) }
    }

    /// The next hero after `key`/`variant` — the one gold action at the end of a composition.
    static func nextHero(after key: String, variant: String) -> Hero? {
        guard let i = heroes.firstIndex(where: {
            $0.key == key && ($0.variant == variant || ($0.variant.isEmpty && variant.isEmpty))
        }) else { return nil }
        return i + 1 < heroes.count ? heroes[i + 1] : nil
    }

    /// The rest of the registry worth offering on a scripture Index: default rows from the
    /// Popular / Ceremony shelves that are NOT already a hero. `hasExtra` rows are excluded —
    /// the Index is a way into Sri Guru Granth Sahib Ji, and the separate Sri Dasam Granth /
    /// Ardaas layer belongs to the Nitnem surface that labels it.
    static func more(from registry: [BaniSummary]) -> [BaniSummary] {
        let heroKeys = Set(heroes.map(\.key))
        return registry
            .filter { ($0.category == .popular || $0.category == .ceremony)
                && $0.isDefault && !$0.hasExtra && !heroKeys.contains($0.key) }
            .sorted { $0.orderNo < $1.orderNo }
    }
}
