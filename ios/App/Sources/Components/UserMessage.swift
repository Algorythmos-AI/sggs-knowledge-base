import Foundation
import os

/// User-facing copy for failures. Never surface raw `Error`/SQLite strings (they leak internals and
/// aren't localized-friendly). The underlying error is logged for debugging, not shown.
enum UserMessage {
    static func load(_ error: Error) -> String {
        FailureLog.record(error)
        return "Couldn't load that just now. Please try again."
    }
    static func search(_ error: Error) -> String {
        FailureLog.record(error)
        return "Couldn't complete the search. Please try again."
    }
}

/// Release builds used to drop every non-fatal error on the floor (the only log was a DEBUG
/// `print`), so a field report had nothing behind it. The unified log stays on the device; the
/// error's type is public, its description is redacted unless a developer attaches a debugger or
/// the reader shares a sysdiagnose — it can never contain what someone searched for.
private enum FailureLog {
    private static let log = os.Logger(subsystem: "org.sggs", category: "Failure")
    static func record(_ error: Error) {
        log.error("non-fatal \(String(describing: type(of: error)), privacy: .public): \(String(describing: error), privacy: .private)")
    }
}
