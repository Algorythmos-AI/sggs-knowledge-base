import SwiftUI

/// THE selectable pill — Search modes, Insights views, Lineage sections, Clock chips all
/// draw this one component (it replaces six copy-pasted Capsule patterns). Selected state
/// is a solid accent fill with the palette's AA-checked `onAccent` label; idle is the
/// raised surface with a hairline. Selection animates on the app spring (Reduce-Motion-
/// aware) and ticks a selection haptic.
struct ModePill: View {
    let title: String
    var systemImage: String? = nil
    /// Optional leading legend dot (kind color-coding on Lineage). Independent of selection.
    var dot: Color? = nil
    let isSelected: Bool
    /// Preserved verbatim for XCUITest (`mode_auto`, `insights_Network`, …).
    var accessibilityID: String? = nil
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                if let systemImage { Image(systemName: systemImage).font(.caption) }
                Text(title).lineLimit(1)               // the row scrolls; a pill never wraps
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isSelected ? AnyShapeStyle(palette.accent)
                                          : AnyShapeStyle(Ink.raised))
            )
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Ink.hairline))
            .foregroundStyle(isSelected ? palette.onAccent : .primary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 34)                      // + padding ⇒ ≥44 pt effective target
        .appAnimation(Motion.gentle, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected) { old, new in new && !old }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .modifier(OptionalA11yID(id: accessibilityID))
    }
}

private struct OptionalA11yID: ViewModifier {
    let id: String?
    func body(content: Content) -> some View {
        if let id { content.accessibilityIdentifier(id) } else { content }
    }
}
