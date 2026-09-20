import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct SGGSApp: App {
    @State private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // XCUITest launches set SGGS_UITEST=1: clear per-launch residue that would otherwise
        // leak between tests (resume-last-Ang, the transliteration toggle). Never the accent —
        // its persistence across a relaunch is itself under test. Debug builds only.
        if ProcessInfo.processInfo.environment["SGGS_UITEST"] == "1" {
            for key in ["sggs_last_ang", "sggs_translit", "sggs_rehras_variant", "sggs_reader_tone", "sggs_reader_leading", "sggs_gurmukhi_size", "sggs_focus_mode"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            NitnemProgressStore.wipe()
            NitnemPlanStore.wipe()
        }
        #endif
        Brand.applyNavigationTitleFonts()
        _container = State(initialValue: AppContainer())
    }

    var body: some Scene {
        WindowGroup {
            // The SwiftData container is built (with fallbacks) in AppContainer — never via the
            // implicit `.modelContainer(for:)`, which fatalErrors on an unopenable store. If even
            // the in-memory fallback failed (container nil), the app still runs: scripture
            // reading must never be hostage to the bookmarks store.
            Group {
                if let modelContainer = container.modelContainer {
                    RootView().modelContainer(modelContainer)
                } else {
                    RootView()
                }
            }
            .environment(container)
            .task {
                CrashMonitor.shared.start()   // local-only diagnostics; QA requires zero collected
                ReadingActivityController.sweepOrphaned()   // clear any activity left by a prior launch
                await container.runIntegrity()
                await container.loadMeta()
                await container.refreshWidgetSnapshot()
                await container.refreshReminders()
            }
            .onOpenURL { url in container.router.handle(url, container: container) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    container.flushIfIdle()   // never presents mid-dismiss
                    Task { await container.refreshReminders() }   // re-plan dated reminders on return
                }
            }
            // The dated plan drops "today" once its time has passed, so a time-zone or clock change
            // while the app is open re-plans at once rather than waiting for the next foreground.
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                Task { await container.refreshReminders() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                Task { await container.refreshReminders() }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                // a saved verse tapped in system search → open its composition
                if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                   let compId = SpotlightIndex.compId(fromIdentifier: id) {
                    container.present(.shabad(compId: compId, focusLineId: SpotlightIndex.lineId(fromIdentifier: id)))
                }
            }
        }
    }
}
