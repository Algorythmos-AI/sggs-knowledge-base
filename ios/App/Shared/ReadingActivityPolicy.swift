import Foundation

/// Pure update policy for the reading Live Activity — no ActivityKit, so it is unit-testable.
/// The activity starts only after a genuine dwell, updates on a whole-percent change and not more
/// than once every 10 s, and carries a stale date so a forgotten activity fades by itself.
enum ReadingActivityPolicy {
    /// Only start once the reader has stayed in a bani this long (a glance never starts one).
    static let startDelay: TimeInterval = 20
    /// Never update more often than this.
    static let minInterval: TimeInterval = 10
    /// The system dims the activity after this if it is never ended (a safety net).
    static let staleAfter: TimeInterval = 20 * 60

    static func wholePercent(_ fraction: Double) -> Int {
        max(0, min(100, Int((fraction * 100).rounded(.down))))
    }

    /// Whether to push an update given the last shown whole-percent and update time.
    static func shouldUpdate(lastPercent: Int?, newFraction: Double, lastUpdate: Date?, now: Date) -> Bool {
        let p = wholePercent(newFraction)
        guard let lastPercent else { return true }         // first update always lands
        guard p != lastPercent else { return false }        // no visible change
        if let lastUpdate, now.timeIntervalSince(lastUpdate) < minInterval { return false }
        return true
    }

    static func staleDate(from now: Date) -> Date { now.addingTimeInterval(staleAfter) }
}
