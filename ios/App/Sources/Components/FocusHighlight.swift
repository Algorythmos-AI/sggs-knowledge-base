import SwiftUI

/// The one-shot "here is the verse you asked for" tint: a soft accent wash behind the row that
/// fades away (Reduce Motion: appears/disappears without animation — same duration, no fade).
/// Presentation only — the verse text is untouched. Tokens only (palette accent).
struct FocusHighlight: ViewModifier {
    let active: Bool
    @Environment(\.palette) private var palette
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(palette.accent.opacity(active ? 0.18 : 0))
                    .padding(-Theme.Space.s)
            )
            .appAnimation(Motion.gentle, value: active)
    }
}

extension View {
    /// Highlight this row while `active`; callers clear it after ~1.6 s.
    func focusHighlight(_ active: Bool) -> some View { modifier(FocusHighlight(active: active)) }
}

/// Shared timing for the landing highlight (kept in one place so both surfaces agree).
enum FocusLanding {
    static let highlightSeconds: Double = 1.6
    /// VoiceOver moves to the verse only after the sheet/system focus has settled.
    static let voiceOverDelaySeconds: Double = 0.4
}
