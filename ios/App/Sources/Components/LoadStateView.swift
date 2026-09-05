import SwiftUI

/// Renders the idle/loading/loaded/empty/failed states uniformly.
/// `onRetry` (optional) gives the failed state a real way out instead of a dead end;
/// `idle` (optional) replaces the blank idle canvas with guidance (e.g. Search examples).
struct LoadStateView<T: Sendable, Content: View>: View {
    let state: LoadState<T>
    var emptyTitle = "No results"
    var emptyMessage = ""
    var onRetry: (() -> Void)? = nil
    var idle: (() -> AnyView)? = nil
    @ViewBuilder var content: (T) -> Content

    var body: some View {
        switch state {
        case .idle:
            if let idle { idle() } else { Color.clear }
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let value):
            content(value)
        case .empty:
            EmptyStateView(title: emptyTitle, message: emptyMessage)
        case .failed(let message):
            EmptyStateView(title: "Something went wrong", message: message, isError: true,
                           actionTitle: onRetry == nil ? nil : "Try again", action: onRetry)
        }
    }
}
