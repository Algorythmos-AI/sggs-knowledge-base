import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// The Live Activity contract, shared by the app (which starts/updates it) and the widget
/// extension (which renders it). Plain strings/ints only — NEVER verse text on the Lock Screen.
/// `titleGm` is a bani TITLE (e.g. ਜਪੁਜੀ ਸਾਹਿਬ), verbatim from the registry, never a scripture line.
struct NitnemActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Whole-percent reading progress, 0…1 (stepped to whole percents by the controller).
        var progress: Double
        /// A quiet section label ("Pauri 12 of 38") or empty — never a verse.
        var sectionLabel: String
        var done: Bool
    }
    let key: String
    let titleEn: String
    let titleGm: String
}
#endif
