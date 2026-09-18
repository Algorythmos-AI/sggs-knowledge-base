import Foundation
import GurbaniSearchKit

/// One entry in a customised daily set: a bani key and whether the reader hid it. Order is the
/// array order. A hidden default is remembered (so it is not re-added) but never shown.
struct NitnemSetEntry: Codable, Equatable, Sendable {
    var key: String
    var hidden: Bool = false
}

/// The "My Nitnem" plan — a NEW sibling file to `nitnem-progress.json`, never a migration of it,
/// so an older build can never lose reading history (Robustness 2). Keyed by `BaniCategory.rawValue`.
struct NitnemPlanFile: Codable, Equatable, Sendable {
    var version: Int = 1
    var sets: [String: [NitnemSetEntry]] = [:]
}

/// Atomic, corrupt-safe store for the plan. Corrupt or missing → empty (never crash); a
/// newer-version file loads read-only and is never overwritten. Lives in the App Group so the
/// widget snapshot can be resolved against the same customised sets.
@MainActor
final class NitnemPlanStore {
    static let filename = "nitnem-plan.json"
    static let version = 1

    private(set) var file: NitnemPlanFile
    private(set) var isReadOnly: Bool
    private let url: URL?
    /// Fired after any change so the home + widget snapshot refresh.
    var onChange: (() -> Void)?

    init(url: URL? = NitnemPlanStore.defaultURL()) {
        self.url = url
        (self.file, self.isReadOnly) = Self.load(from: url)
    }

    static func defaultURL() -> URL? {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetStore.appGroup) {
            return group.appendingPathComponent(filename)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(filename)
    }

    static func load(from url: URL?) -> (NitnemPlanFile, Bool) {
        guard let url, let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(NitnemPlanFile.self, from: data) else {
            return (NitnemPlanFile(), false)
        }
        if f.version > version { return (f, true) }   // never overwrite a newer file
        return (f, false)
    }

    func entries(for category: BaniCategory) -> [NitnemSetEntry] { file.sets[category.rawValue] ?? [] }

    /// Whether the reader has customised this set at all (drives the "Reset" affordance).
    func isCustomised(_ category: BaniCategory) -> Bool { !(file.sets[category.rawValue] ?? []).isEmpty }

    func setEntries(_ entries: [NitnemSetEntry], for category: BaniCategory) {
        file.sets[category.rawValue] = entries
        persist()
    }

    /// Reset a set to the registry defaults (removes the plan override for that category).
    func reset(_ category: BaniCategory) {
        file.sets[category.rawValue] = nil
        persist()
    }

    private func persist() {
        guard !isReadOnly, let url, let data = try? JSONEncoder().encode(file) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        onChange?()
    }

    static func wipe() {
        guard let url = defaultURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
