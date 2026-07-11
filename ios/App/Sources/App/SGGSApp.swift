import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct SGGSApp: App {
    @State private var container = AppContainer()

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
                await container.runIntegrity()
                await container.loadMeta()
                await container.refreshWidgetSnapshot()
            }
            .onOpenURL { url in container.router.handle(url, container: container) }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                // a saved verse tapped in system search → open its composition
                if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                   let compId = SpotlightIndex.compId(fromIdentifier: id) {
                    container.present(.shabad(compId: compId))
                }
            }
        }
    }
}
