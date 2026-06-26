import SwiftUI
import SwiftData

/// Bookmarked verses (SwiftData). Verbatim text; tap to open the composition; swipe to delete.
struct SavedScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedLine.savedAt, order: .reverse) private var saved: [SavedLine]

    var body: some View {
        Group {
            if saved.isEmpty {
                ContentUnavailableView("No saved verses", systemImage: "bookmark",
                                       description: Text("Press and hold any verse, then Save."))
            } else {
                List {
                    ForEach(saved) { item in
                        LineRow(gurmukhi: item.gurmukhi, translit: item.translit,
                                meta: "Ang \(item.ang)") {
                            container.presentation = .shabad(compId: item.compId)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { idx in
                        for i in idx { modelContext.delete(saved[i]) }
                        do { try modelContext.save() } catch { modelContext.rollback() }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }
}
