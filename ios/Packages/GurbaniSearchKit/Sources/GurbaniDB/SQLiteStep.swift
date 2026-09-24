import Foundation
import CSQLite

/// The ONLY place `sqlite3_step` is called for row iteration.
///
/// `while sqlite3_step(stmt) == SQLITE_ROW { … }` reads SQLITE_CORRUPT, SQLITE_IOERR, SQLITE_NOMEM
/// and SQLITE_INTERRUPT as "no more rows": the loop ends early and the caller returns a shorter
/// result with no error — for this app, a silently truncated Ang or shabad. Scripture is shown
/// complete or not at all, so every step goes through here and anything other than ROW / DONE
/// throws. A repo gate (ios/tests/test_ios_gates.py) forbids raw step loops elsewhere.
///
/// Returns `true` when a row is available, `false` at SQLITE_DONE.
@inline(__always)
func stepRow(_ stmt: OpaquePointer?) throws -> Bool {
    let rc = sqlite3_step(stmt)
    switch rc {
    case SQLITE_ROW: return true
    case SQLITE_DONE: return false
    default:
        let message = sqlite3_db_handle(stmt).map { String(cString: sqlite3_errmsg($0)) } ?? "step failed"
        throw SQLiteCandidateSource.DBError.step(code: rc, message: message)
    }
}

/// For readers whose protocol cannot throw (analytics, timing, banis). Steps exactly like
/// `stepRow(_:)`, but a failure sets `failed` and ends the loop, and the caller MUST then return its
/// empty / unavailable value instead of the partial rows — "complete or not at all", without a throw
/// path through functions that finalize their statements by hand.
@inline(__always)
func stepRow(_ stmt: OpaquePointer?, failed: inout Bool) -> Bool {
    do { return try stepRow(stmt) } catch { failed = true; return false }
}
