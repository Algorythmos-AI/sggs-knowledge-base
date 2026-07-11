import Foundation

/// The 30 voices of the Granth — static biographical metadata bundled from the web app's
/// frontend/public/contributors.json (single source of truth; referenced, not copied).
/// Dates are historical approximations; volume comes from the DB, never from here.
struct Contributor: Decodable, Identifiable, Sendable, Hashable {
    let name: String        // matches authors/author_analytics.author exactly (verified: 30/30)
    let roman: String
    let kind: String        // guru | bhagat | bhatt | gursikh
    let seq: Int?
    let born: Int?
    let died: Int?
    let circa: Bool
    let era: String
    let region: String
    let tradition: String
    let blurb: String
    var id: String { name }

    /// Sort key for the timeline (birth year; unknowns last).
    var timelineYear: Int { born ?? died ?? 9999 }
}

enum ContributorsStore {
    struct File: Decodable { let contributors: [Contributor] }

    /// Loads the bundled roster (nil only if the resource is missing/corrupt — the Lineage
    /// screen shows its designed empty state then, never crashes).
    static func load(bundle: Bundle = .main) -> [Contributor]? {
        guard let url = bundle.url(forResource: "contributors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data),
              !file.contributors.isEmpty
        else { return nil }
        return file.contributors
    }
}
