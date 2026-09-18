import Foundation
import Observation

/// Where the reader is in each bani and which days each was completed. A small, versioned
/// JSON file in the App Group container (next to the widget snapshot) — NOT SwiftData: the
/// bookmarks store has a destroy-on-repeated-failure ladder that progress must never be
/// hostage to, and a widget can read this file without opening anything else.
///
/// A "Nitnem day" is the local calendar day. Corrupt or missing file → empty state, never a
/// crash. Writes are atomic; callers debounce.
struct BaniProgress: Codable, Equatable, Sendable {
    var lastSeq: Int
    var lastReadAt: Date
    /// Local calendar days (YYYY-MM-DD) this bani was marked complete, newest last, capped.
    var completedDays: [String]
}

struct NitnemProgressFile: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var banis: [String: BaniProgress] = [:]
}

@MainActor @Observable
final class NitnemProgressStore {
    static let filename = "nitnem-progress.json"
    static let maxCompletedDays = 400

    private(set) var file: NitnemProgressFile
    let url: URL?

    init(url: URL? = NitnemProgressStore.defaultURL()) {
        self.url = url
        self.file = NitnemProgressStore.load(from: url)
    }

    // MARK: reads

    func progress(for id: String) -> BaniProgress? { file.banis[id] }

    /// 0…1 reading position (by line), 1 when completed today.
    func fraction(for id: String, total: Int, on date: Date = Date()) -> Double {
        guard total > 0 else { return 0 }
        if isCompleted(id, on: date) { return 1 }
        guard let p = file.banis[id] else { return 0 }
        return min(1, max(0, Double(p.lastSeq) / Double(total)))
    }

    func isCompleted(_ id: String, on date: Date = Date()) -> Bool {
        file.banis[id]?.completedDays.contains(Self.dayKey(date)) ?? false
    }

    /// Consecutive days (ending today or yesterday) on which ALL of `ids` were completed.
    func streak(for ids: [String], on date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard !ids.isEmpty else { return 0 }
        var day = date
        var n = 0
        // a streak that ended yesterday still counts until today is done
        if !ids.allSatisfy({ isCompleted($0, on: day) }) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        while ids.allSatisfy({ isCompleted($0, on: day) }) {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    // MARK: writes

    func setPosition(_ id: String, seq: Int, at date: Date = Date()) {
        var p = file.banis[id] ?? BaniProgress(lastSeq: 0, lastReadAt: date, completedDays: [])
        p.lastSeq = max(1, seq)
        p.lastReadAt = date
        file.banis[id] = p
        save()
    }

    func markComplete(_ id: String, on date: Date = Date()) {
        var p = file.banis[id] ?? BaniProgress(lastSeq: 0, lastReadAt: date, completedDays: [])
        let key = Self.dayKey(date)
        if !p.completedDays.contains(key) { p.completedDays.append(key) }
        if p.completedDays.count > Self.maxCompletedDays {
            p.completedDays.removeFirst(p.completedDays.count - Self.maxCompletedDays)
        }
        p.lastReadAt = date
        p.lastSeq = 0            // next open starts from the top
        file.banis[id] = p
        save()
    }

    /// "Start again": forget the position, keep the completed-day history.
    func resetPosition(_ id: String) {
        guard var p = file.banis[id] else { return }
        p.lastSeq = 0
        file.banis[id] = p
        save()
    }

    // MARK: persistence

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func defaultURL() -> URL? {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetStore.appGroup) {
            return group.appendingPathComponent(filename)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(filename)
    }

    static func load(from url: URL?) -> NitnemProgressFile {
        guard let url, let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(NitnemProgressFile.self, from: data),
              f.schemaVersion == 1 else { return NitnemProgressFile() }
        return f
    }

    func save() {
        guard let url, let data = try? JSONEncoder().encode(file) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Debug/UI-test residue wipe (never called in release flows).
    static func wipe() {
        guard let url = defaultURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
