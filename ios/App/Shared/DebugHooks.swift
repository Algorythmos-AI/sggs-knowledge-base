import Foundation

/// The one place test hooks (`SGGS_UITEST`, `SGGS_CLOCK_NOW`, `SGGS_AUTOSCROLL_PPS`, …) read the
/// process environment. In a Release build it is always empty, so no hook can change how a shipped
/// app behaves (App Review 2.3.1) — and the repo gate forbids reading
/// `ProcessInfo.processInfo.environment` outside `#if DEBUG`, so a new hook has to come through here.
enum DebugHooks {
    static var environment: [String: String] {
        #if DEBUG
        ProcessInfo.processInfo.environment
        #else
        [:]
        #endif
    }

    /// True only in a Debug build launched by the XCUITest runner.
    static var isUITest: Bool { environment["SGGS_UITEST"] == "1" }
}
