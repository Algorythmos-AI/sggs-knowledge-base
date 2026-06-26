import Foundation

/// User-facing copy for failures. Never surface raw `Error`/SQLite strings (they leak internals and
/// aren't localized-friendly). The underlying error is logged for debugging, not shown.
enum UserMessage {
    static func load(_ error: Error) -> String {
        Logger.failure(error)
        return "Couldn't load that just now. Please try again."
    }
    static func search(_ error: Error) -> String {
        Logger.failure(error)
        return "Couldn't complete the search. Please try again."
    }
}

private enum Logger {
    static func failure(_ error: Error) {
        #if DEBUG
        print("[SGGS] non-fatal: \(error)")
        #endif
    }
}
