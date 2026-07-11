import SwiftUI
import SwiftData

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
            }
            .onOpenURL { url in container.router.handle(url, container: container) }
        }
    }
}
