import SwiftUI

/// Branded empty/error state: a quiet ੴ mark above the title instead of a generic
/// SF Symbol. Title and message render as plain text so existing XCUITest staticText
/// queries keep matching.
struct EmptyStateView: View {
    let title: String
    var message: String = ""
    /// Failure states show the warning triangle instead of the brand mark —
    /// the ੴ is reserved for calm states, never for errors.
    var isError: Bool = false
    /// Optional single action (e.g. "Try again") — a failure state should never be a dead end.
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            if isError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.secondary)
            } else {
                Text("ੴ")
                    .font(Brand.gurmukhi(44, relativeTo: .largeTitle))
                    .foregroundStyle(palette.accent.opacity(0.55))
                    .accessibilityHidden(true)
            }
            VStack(spacing: Theme.Space.xs) {
                Text(title).font(.headline)
                if !message.isEmpty {
                    Text(message)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, Theme.Space.xs)
                    .accessibilityIdentifier("retryButton")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Space.xl)
    }
}
