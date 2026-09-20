import Foundation
import MetricKit

/// LOCAL-ONLY crash/hang evidence (offline guardrail: nothing ever leaves the device — no
/// analytics service, no network). MetricKit diagnostic payloads are written as JSON files
/// under Application Support/diagnostics; the QA definition-of-done requires this folder to
/// be EMPTY after a full manual pass.
///
/// The files leave the device only if the reader chooses **About → Share diagnostics…** (the
/// system share sheet, their own choice of destination). That keeps the App Store privacy label
/// "Data Not Collected" true: the developer collects nothing; a user may hand something over.
/// The folder is capped and excluded from device backups — it is scratch evidence, not user data.
final class CrashMonitor: NSObject, MXMetricManagerSubscriber, Sendable {
    static let shared = CrashMonitor()
    /// Newest files kept. A crash loop must not be able to fill the disk.
    static let keep = 50

    static var folder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("diagnostics", isDirectory: true)
    }

    func start() { MXMetricManager.shared.add(self) }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard var folder = Self.folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
        for p in payloads {
            let stamp = ISO8601DateFormatter().string(from: p.timeStampEnd)
                .replacingOccurrences(of: ":", with: "-")
            try? p.jsonRepresentation().write(
                to: folder.appendingPathComponent("diagnostic-\(stamp).json"), options: .atomic)
        }
        Self.prune(in: folder, keep: Self.keep)
    }

    /// The collected files, oldest first (the ISO-8601 stamp in the name sorts chronologically).
    static func files(in folder: URL? = CrashMonitor.folder) -> [URL] {
        guard let folder,
              let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return [] }
        return items.filter { $0.lastPathComponent.hasPrefix("diagnostic-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Count of collected diagnostics (surfaced in About → Integrity for the QA pass).
    static func diagnosticCount() -> Int { files().count }

    /// Delete the oldest files beyond `keep`.
    static func prune(in folder: URL, keep: Int) {
        let all = files(in: folder)
        for url in all.dropLast(max(0, keep)) { try? FileManager.default.removeItem(at: url) }
    }

    /// The reader's "Delete diagnostics" action.
    static func deleteAll(in folder: URL? = CrashMonitor.folder) {
        for url in files(in: folder) { try? FileManager.default.removeItem(at: url) }
    }
}
