import Foundation

/// Display name for a corpus concept slug (`concepts.concept`, e.g. `dukh_sukh` → "Dukh Sukh").
/// One mapping for every theme surface — Themes, Constellation, Theme Network — so a slug's
/// underscores never leak into the UI (`String.capitalized` keeps them: "Dukh_Sukh").
/// Presentation only: the slug itself stays the key for queries, routes and deep links.
enum ConceptName {
    static func display(_ slug: String) -> String {
        slug.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
