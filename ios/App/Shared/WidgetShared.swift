import Foundation

/// The tiny snapshot the main app writes for the widget extension (compiled into BOTH targets).
/// Widgets NEVER open the ~100 MB corpus DB — they read this <50 KB JSON + the dependency-free
/// GurbaniPahar math. Scripture in the snapshot is verbatim (copied from the DB, never edited).
struct WidgetSnapshot: Codable, Sendable {
    var generatedAt: Date
    /// A complete-unit Hukam verse (first non-header line) + its citation.
    var hukamGurmukhi: String
    var hukamTranslit: String
    var hukamAng: Int
    var hukamCompId: Int
    /// Fixed-clock primary raag claims: pahar (1–8) → roman raag names, from /api/timing/clock.
    /// Precomputed so the widget needs zero SQLite/location/solar logic.
    var paharRaags: [Int: [String]]
    /// The same claims' Gurmukhi raag names (verbatim from the timing table), parallel to
    /// `paharRaags`. Optional so a snapshot written by an older app still decodes.
    var paharRaagsGurmukhi: [Int: [String]]? = nil
}

enum WidgetStore {
    static let appGroup = "group.org.sggs"
    static let filename = "widget-snapshot.json"

    /// App Group container when entitled; falls back to the caller's own container in
    /// unsigned/simulator builds where the group is unavailable (widget then shows its
    /// placeholder — a designed state, never a crash).
    static func url() -> URL? {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return group.appendingPathComponent(filename)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(filename)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = url(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let url = url(), let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
