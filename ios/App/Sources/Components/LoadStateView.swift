import SwiftUI

/// Renders the idle/loading/loaded/empty/failed states uniformly.
struct LoadStateView<T: Sendable, Content: View>: View {
    let state: LoadState<T>
    var emptyTitle = "No results"
    var emptyMessage = ""
    @ViewBuilder var content: (T) -> Content

    var body: some View {
        switch state {
        case .idle:
            Color.clear
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let value):
            content(value)
        case .empty:
            EmptyStateView(title: emptyTitle, message: emptyMessage)
        case .failed(let message):
            EmptyStateView(title: "Something went wrong", message: message, isError: true)
        }
    }
}
