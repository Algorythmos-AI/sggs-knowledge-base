import Foundation
import Observation
import GurbaniSearchKit

/// Where the reader is in each bani and which Nitnem days each was completed. A small JSON file
/// in the App Group container (next to the widget snapshot) — NOT SwiftData: the bookmarks store
/// has a destroy-on-repeated-failure ladder that progress must never be hostage to, and a widget
/// can read this file without opening anything else.
///
/// The file stays **schema v1 forever** (My-Nitnem sets and the journey live in a separate
/// `nitnem-plan.json`), so an older build can never wipe it. A file written by a *newer* schema
/// is loaded read-only and never overwritten. Corrupt or missing → empty, never a crash.
///
/// A "Nitnem day" rolls at 03:00 — see `NitnemClock`.
struct BaniProgress: Codable, Equatable, Sendable {
    var lastSeq: Int
    var lastReadAt: Date
    /// Nitnem days (YYYY-MM-DD) this bani was marked complete, newest last, capped.
    var completedDays: [String]
    /// The verbatim anchor of the saved line (SGGS `lineId`, or an `extraId`), so the position
    /// survives a registry rebuild that shifts `seq`. Optional: absent in files from 1.2.x.
    var anchor: Int?
    /// The bani's line count when the position was saved. If it still matches, resume by `seq`.
    var nLines: Int?

    init(lastSeq: Int, lastReadAt: Date, completedDays: [String], anchor: Int? = nil, nLines: Int? = nil) {
        self.lastSeq = lastSeq; self.lastReadAt = lastReadAt; self.completedDays = completedDays
        self.anchor = anchor; self.nLines = nLines
    }
}

struct NitnemProgressFile: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var banis: [String: BaniProgress] = [:]
}

@MainActor @Observable
final class NitnemProgressStore {
    static let filename = "nitnem-progress.json"
    static let maxCompletedDays = 400
    static let schemaVersion = 1

    private(set) var file: NitnemProgressFile
    /// A file written by a newer schema is read but never written back.
    private(set) var isReadOnly: Bool
    /// Fired after a completion so the app can reload the Nitnem widget timelines.
    var onChange: (() -> Void)?
    let url: URL?

    init(url: URL? = NitnemProgressStore.defaultURL()) {
        self.url = url
        let (f, ro) = NitnemProgressStore.load(from: url)
        self.file = f
        self.isReadOnly = ro
    }

    // MARK: reads

    func progress(for id: String) -> BaniProgress? { file.banis[id] }

    /// 0…1 reading position (by line), 1 when completed today.
    func fraction(for id: String, total: Int, on date: Date = NitnemClock.now()) -> Double {
        guard total > 0 else { return 0 }
        if isCompleted(id, on: date) { return 1 }
        guard let p = file.banis[id] else { return 0 }
        return min(1, max(0, Double(p.lastSeq) / Double(total)))
    }

    func isCompleted(_ id: String, on date: Date = NitnemClock.now()) -> Bool {
        file.banis[id]?.completedDays.contains(NitnemClock.dayKey(date)) ?? false
    }

    /// For each Nitnem day, which focus categories were fully completed. `focus` maps a
    /// category to the bani ids that must ALL be complete that day. Used by the reading journey.
    func practiceDays(focus: [BaniCategory: [String]]) -> [String: Set<BaniCategory>] {
        var out: [String: Set<BaniCategory>] = [:]
        for (cat, ids) in focus where !ids.isEmpty {
            var common: Set<String>? = nil
            for id in ids {
                let days = Set(file.banis[id]?.completedDays ?? [])
                common = common.map { $0.intersection(days) } ?? days
                if common?.isEmpty == true { break }
            }
            for day in common ?? [] { out[day, default: []].insert(cat) }
        }
        return out
    }

    /// Consecutive Nitnem days (ending today or yesterday) on which ALL of `ids` were completed.
    func streak(for ids: [String], on date: Date = NitnemClock.now(), calendar: Calendar = .current) -> Int {
        guard !ids.isEmpty else { return 0 }
        var day = date
        var n = 0
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

    /// The seq to resume at for a bani whose lines are `lines`: by `seq` when the registry is
    /// unchanged, else by anchor, else the top. Never lands on a wrong line after a DB update.
    func resumeSeq(for id: String, lines: [BaniLine]) -> Int? {
        guard let p = file.banis[id], p.lastSeq > 1 else { return nil }
        if let n = p.nLines, n == lines.count, p.lastSeq <= lines.count { return p.lastSeq }
        if let anchor = p.anchor,
           let match = lines.first(where: { anchorOf($0) == anchor }) { return match.seq }
        if p.nLines == nil, p.lastSeq <= lines.count { return p.lastSeq }   // 1.2.x file, no anchor yet
        return nil
    }

    /// The verbatim anchor of a line: its SGGS `lineId`, or the negative of an extra id so the
    /// two namespaces never collide.
    static func anchor(of line: BaniLine) -> Int {
        switch line.citation {
        case .sggs(_, let lineId, _): return lineId
        case .dasam(_, let extraId), .ardaas(let extraId): return -extraId
        }
    }
    private func anchorOf(_ line: BaniLine) -> Int { Self.anchor(of: line) }

    // MARK: writes

    func setPosition(_ id: String, seq: Int, anchor: Int? = nil, nLines: Int? = nil,
                     at date: Date = NitnemClock.now()) {
        var p = file.banis[id] ?? BaniProgress(lastSeq: 0, lastReadAt: date, completedDays: [])
        p.lastSeq = max(1, seq)
        p.lastReadAt = date
        if let anchor { p.anchor = anchor }
        if let nLines { p.nLines = nLines }
        file.banis[id] = p
        save()
    }

    func markComplete(_ id: String, on date: Date = NitnemClock.now()) {
        var p = file.banis[id] ?? BaniProgress(lastSeq: 0, lastReadAt: date, completedDays: [])
        let key = NitnemClock.dayKey(date)
        if !p.completedDays.contains(key) { p.completedDays.append(key) }
        if p.completedDays.count > Self.maxCompletedDays {
            p.completedDays.removeFirst(p.completedDays.count - Self.maxCompletedDays)
        }
        p.lastReadAt = date
        p.lastSeq = 0
        file.banis[id] = p
        save()
        onChange?()
    }

    /// "Start again": forget the position, keep the completed-day history.
    func resetPosition(_ id: String) {
        guard var p = file.banis[id] else { return }
        p.lastSeq = 0
        p.anchor = nil
        file.banis[id] = p
        save()
    }

    // MARK: persistence

    static func dayKey(_ date: Date) -> String { NitnemClock.dayKey(date) }

    static func defaultURL() -> URL? {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetStore.appGroup) {
            return group.appendingPathComponent(filename)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(filename)
    }

    /// -> (file, isReadOnly). A newer-schema file loads read-only; corrupt/missing → empty.
    static func load(from url: URL?) -> (NitnemProgressFile, Bool) {
        guard let url, let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(NitnemProgressFile.self, from: data) else {
            return (NitnemProgressFile(), false)
        }
        if f.schemaVersion > schemaVersion { return (f, true) }   // never overwrite a newer file
        return (f, false)
    }

    func save() {
        guard !isReadOnly, let url, let data = try? JSONEncoder().encode(file) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Debug/UI-test residue wipe (never called in release flows).
    static func wipe() {
        guard let url = defaultURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
