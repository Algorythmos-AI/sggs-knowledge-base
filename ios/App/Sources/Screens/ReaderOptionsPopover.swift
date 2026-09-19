import SwiftUI

/// The Reader's "AA" options — text size front and centre (elders resize here, not buried in
/// Settings), then the display toggles. Bound to the same `sggs_gurmukhi_size` key as Settings, so
/// the choice is one setting everywhere. Presented as a compact popover.
struct ReaderOptionsPopover: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @AppStorage("sggs_gurmukhi_size") private var gurmukhiSize = 24.0
    @AppStorage("sggs_translit") private var showTranslit = true
    @AppStorage("sggs_show_english") private var showEnglish = true
    @AppStorage("sggs_show_timing") private var showTiming = true
    @AppStorage("sggs_focus_mode") private var focusMode = false

    private let range = 18.0...32.0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("Text size").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: Theme.Space.m) {
                sizeButton("A", delta: -2, disabled: gurmukhiSize <= range.lowerBound, label: "Smaller")
                // live sample at the current size
                Text("ੴ ਸਤਿ").font(Brand.gurmukhi(gurmukhiSize, relativeTo: .title3))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Sample, \(Int(gurmukhiSize)) point")
                sizeButton("A", delta: +2, disabled: gurmukhiSize >= range.upperBound, label: "Larger", big: true)
            }
            Divider()
            Toggle("Transliteration", isOn: $showTranslit)
            if container.corpus?.capabilities.hasEnglish == true {
                Toggle("English translation", isOn: $showEnglish)
            }
            if container.corpus?.capabilities.hasTiming == true {
                Toggle("Timing chip", isOn: $showTiming)
            }
            Toggle("Sehaj focus", isOn: $focusMode)
        }
        .padding(Theme.Space.l)
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }

    private func sizeButton(_ glyph: String, delta: Double, disabled: Bool, label: String, big: Bool = false) -> some View {
        Button {
            Haptics.tap()
            gurmukhiSize = min(max(range.lowerBound, gurmukhiSize + delta), range.upperBound)
        } label: {
            Text(glyph)
                .font(.system(size: big ? 26 : 16, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Ink.hairline))
        }
        .buttonStyle(.pressableCard)
        .disabled(disabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(delta < 0 ? "textSmaller" : "textLarger")
    }
}
