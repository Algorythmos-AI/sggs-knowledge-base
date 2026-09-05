import Foundation
import MetricKit

/// LOCAL-ONLY crash/hang evidence (offline guardrail: nothing ever leaves the device — no
/// analytics service, no network). MetricKit diagnostic payloads are written as JSON files
/// under Application Support/diagnostics; the QA definition-of-done requires this folder to
/// be EMPTY after a full manual pass. Inspect via Files/Xcode container download.
final class CrashMonitor: NSObject, MXMetricManagerSubscriber, Sendable {
    static let shared = CrashMonitor()

    static var folder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("diagnostics", isDirectory: true)
    }

    func start() { MXMetricManager.shared.add(self) }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let folder = Self.folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for p in payloads {
            let stamp = ISO8601DateFormatter().string(from: p.timeStampEnd)
                .replacingOccurrences(of: ":", with: "-")
            try? p.jsonRepresentation().write(
                to: folder.appendingPathComponent("diagnostic-\(stamp).json"), options: .atomic)
        }
    }

    /// Count of collected diagnostics (surfaced in About → Integrity for the QA pass).
    static func diagnosticCount() -> Int {
        guard let folder, let items = try? FileManager.default.contentsOfDirectory(atPath: folder.path)
        else { return 0 }
        return items.filter { $0.hasPrefix("diagnostic-") }.count
    }
}
