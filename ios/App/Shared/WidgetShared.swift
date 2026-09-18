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
    /// The reader's clock mode ("fixed" | "solar") and their stored solar coordinates
    /// (already rounded to ~1 km by SolarLocation) at snapshot time, so a widget can mirror
    /// the app's Solar choice without linking CoreLocation. Optional: older snapshots decode.
    var clockMode: String? = nil
    var solarLat: Double? = nil
    var solarLon: Double? = nil
}

/// The App-Group `UserDefaults` suite shared by the app and its widgets — where the clock
/// mode and the rounded solar coordinates live so both surfaces agree. Falls back to
/// `.standard` when the group is unavailable (unsigned simulator builds), so nothing crashes.
enum SharedDefaults {
    static let clockModeKey = "sggs_clock_mode"      // "fixed" | "solar"
    static let solarCoordsKey = "sggs_solar_coords"  // "lat,lon" rounded to 2 dp

    /// UserDefaults is documented thread-safe; the type simply predates Sendable.
    nonisolated(unsafe) static let suite: UserDefaults = UserDefaults(suiteName: WidgetStore.appGroup) ?? .standard

    /// One-time migration: copy a value the app stored in `.standard` before the keys moved
    /// to the group. Never overwrites a value already in the suite.
    static func migrateFromStandard() {
        guard suite !== UserDefaults.standard else { return }
        for key in [clockModeKey, solarCoordsKey] where suite.object(forKey: key) == nil {
            if let v = UserDefaults.standard.object(forKey: key) { suite.set(v, forKey: key) }
        }
    }

    static var clockMode: String {
        get { suite.string(forKey: clockModeKey) ?? "fixed" }
        set { suite.set(newValue, forKey: clockModeKey) }
    }

    /// Parsed, range-checked stored coordinates.
    static func solarCoords() -> (lat: Double, lon: Double)? {
        guard let s = suite.string(forKey: solarCoordsKey) else { return nil }
        let parts = s.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]),
              abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return (lat, lon)
    }

    static func storeSolarCoords(lat: Double, lon: Double) {
        let r = { (x: Double) in (x * 100).rounded() / 100 }   // 2 dp ≈ 1 km — enough for sunrise
        suite.set("\(r(lat)),\(r(lon))", forKey: solarCoordsKey)
    }
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
