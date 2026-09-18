import Foundation

/// A widget-safe, read-only view of `nitnem-progress.json` (the widget target links only
/// GurbaniPahar, not GurbaniSearchKit, so it cannot use `NitnemProgressStore`). Decodes just
/// the fields a widget needs; unknown/newer keys are ignored, corrupt/missing → empty.
struct NitnemProgressReading: Sendable {
    struct Entry: Decodable, Sendable {
        var lastSeq: Int = 0
        var completedDays: [String] = []
        var nLines: Int? = nil
    }
    private struct File: Decodable { var banis: [String: Entry] = [:] }
    var banis: [String: Entry] = [:]

    static func load() -> NitnemProgressReading {
        guard let url = WidgetStore.url()?.deletingLastPathComponent()
                .appendingPathComponent("nitnem-progress.json"),
              let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(File.self, from: data) else {
            return NitnemProgressReading()
        }
        return NitnemProgressReading(banis: f.banis)
    }

    func isCompleted(_ id: String, on date: Date) -> Bool {
        banis[id]?.completedDays.contains(NitnemClock.dayKey(date)) ?? false
    }

    /// 0…1 position, 1 when completed today. `total` comes from the snapshot (the widget has no DB).
    func fraction(_ id: String, total: Int, on date: Date) -> Double {
        guard total > 0 else { return 0 }
        if isCompleted(id, on: date) { return 1 }
        let seq = banis[id]?.lastSeq ?? 0
        return min(1, max(0, Double(seq) / Double(total)))
    }
}
