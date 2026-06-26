import SwiftUI
import SwiftData

@main
struct SGGSApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .task {
                    await container.runIntegrity()
                    await container.loadMeta()
                }
                .onOpenURL { url in container.router.handle(url, container: container) }
        }
        .modelContainer(for: SavedLine.self)
    }
}
