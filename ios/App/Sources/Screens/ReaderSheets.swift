import SwiftUI
import GurbaniSearchKit

/// What a Contents sheet needs to render and route back. Carried by `Presentation.baniContents`.
struct BaniContentsRequest: Identifiable {
    let baniId: String
    let title: String
    let sections: [BaniSection]
    let currentSeq: Int
    var id: String { baniId }
}

/// Jump to a pauri / ashtapadi / part. Selection returns through `router.pendingBaniSeq`, which
/// the reader consumes — the sheet never holds a closure, so it survives the single sheet host.
struct BaniContentsSheet: View {
    let request: BaniContentsRequest
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private var current: BaniSection? { BaniOutline.section(at: request.currentSeq, in: request.sections) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(request.sections) { section in
                    Button {
                        container.router.pendingBaniSeq = section.startSeq
                        dismiss()
                    } label: {
                        HStack {
                            Text(section.contentsLabel)
                                .foregroundStyle(.primary)
                            Spacer()
                            if section.id == current?.id {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(section.id == current?.id ? palette.accent.opacity(0.10) : Ink.card)
                    .accessibilityLabel(section.accessibilityLabel)
                    .accessibilityAddTraits(section.id == current?.id ? [.isSelected] : [])
                }
            }
            .inkGroupedList()
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Reading appearance for the bani reader (and it drives `GurmukhiText` everywhere): size,
/// line spacing, paper tone, and the two content toggles. Pure preference writes.
struct ReadingSettingsSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sggs_gurmukhi_size") private var gurmukhiSize = 24.0
    @AppStorage(ReaderPrefs.leadingKey) private var leading = ReaderPrefs.leadingDefault
    @AppStorage(ReaderPrefs.toneKey) private var toneRaw = ReaderTone.paper.rawValue
    @AppStorage("sggs_translit") private var showTranslit = true
    @AppStorage("sggs_show_english") private var showEnglish = true

    private var tone: Binding<ReaderTone> {
        Binding(get: { ReaderTone(rawValue: toneRaw) ?? .paper }, set: { toneRaw = $0.rawValue })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gurmukhi") {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        HStack {
                            Text("Size"); Spacer()
                            GurmukhiText(verbatim: "ੴ ਸਤਿ", size: 20)
                        }
                        Slider(value: $gurmukhiSize, in: 18...32, step: 1)
                            .accessibilityIdentifier("gurmukhiSizeSlider")
                            .accessibilityValue("\(Int(gurmukhiSize)) point")
                    }
                    Picker("Line spacing", selection: $leading) {
                        Text("Compact").tag(0.40)
                        Text("Comfortable").tag(0.55)
                        Text("Open").tag(0.70)
                    }
                    .accessibilityIdentifier("readerLeadingPicker")
                }
                Section("Page") {
                    Picker("Paper tone", selection: tone) {
                        ForEach(ReaderTone.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("readerTonePicker")
                }
                Section("Reading aids") {
                    Toggle("Transliteration", isOn: $showTranslit)
                        .accessibilityIdentifier("translitToggle")
                    if container.corpus?.capabilities.hasEnglish == true {
                        Toggle("English translation", isOn: $showEnglish)
                            .accessibilityIdentifier("englishToggle")
                    }
                }
            }
            .inkGroupedList()
            .navigationTitle("Reading settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
