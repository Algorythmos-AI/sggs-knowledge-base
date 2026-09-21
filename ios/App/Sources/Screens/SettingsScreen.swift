import SwiftUI

struct MoreScreen: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("sggs_saroop") private var saroop = true
    @AppStorage("sggs_translit") private var showTranslit = true
    @AppStorage("sggs_show_english") private var showEnglish = true
    @AppStorage("sggs_gurmukhi_size") private var gurmukhiSize = 24.0
    @AppStorage("sggs_appearance") private var appearance = "system"
    @AppStorage(AccentPalette.storageKey) private var accentChoice = AccentPalette.brandDefault.rawValue
    @AppStorage(NitnemPrefs.rehrasVariantKey) private var rehrasVariant = NitnemPrefs.rehrasDefault
    @AppStorage(ReadingActivityController.enabledKey) private var liveActivity = false

    var body: some View {
        NavigationStack {
            List {
                if container.corpus?.capabilities.hasBanis == true {
                    Section {
                        Picker("Rehras Sahib", selection: $rehrasVariant) {
                            Text("SGPC (standard)").tag("sgpc")
                            Text("Damdami Taksal").tag("taksal")
                        }
                        .id(accentChoice)
                        .accessibilityIdentifier("rehrasVariantPicker")
                        NavigationLink { NitnemSetsScreen() } label: {
                            Label("My Nitnem", systemImage: "list.bullet.rectangle")
                        }
                        .accessibilityIdentifier("nitnemSetsLink")
                        NavigationLink { NitnemRemindersScreen() } label: {
                            Label("Reminders", systemImage: "bell")
                        }
                        .accessibilityIdentifier("nitnemRemindersLink")
                        Toggle(isOn: $liveActivity) {
                            VStack(alignment: .leading) {
                                Text("Live Activity while reading")
                                Text("Show progress on the Lock Screen and Dynamic Island. Title and percentage only — never the verse.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("liveActivityToggle")
                    } header: {
                        Text("Nitnem")
                    } footer: {
                        Text("The evening prayer as printed in the SGPC Nitnem Gutka, or the longer Damdami Taksal reading. Changing it starts Rehras from the top.")
                    }
                    .inkRow()
                }
                Section("Display") {
                    Toggle(isOn: $saroop) {
                        VStack(alignment: .leading) {
                            Text("Traditional saroop")
                            Text("Display only — does not change the scripture text.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("saroopToggle")

                    Toggle("Show transliteration", isOn: $showTranslit)
                        .accessibilityIdentifier("translitToggle")

                    if container.corpus?.capabilities.hasEnglish == true {
                        Toggle(isOn: $showEnglish) {
                            VStack(alignment: .leading) {
                                Text("Show English translation")
                                Text("Dr. Sant Singh Khalsa (via BaniDB) — a separate labelled layer, never the scripture.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("englishToggle")
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Gurmukhi size"); Spacer()
                            GurmukhiText(verbatim: "ੴ", size: 24)   // scaled by the preference below
                        }
                        Slider(value: $gurmukhiSize, in: 18...32, step: 1)
                            .accessibilityIdentifier("gurmukhiSizeSlider")
                            .accessibilityValue("\(Int(gurmukhiSize)) point")
                    }

                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }
                    // The menu label is UIKit-backed and caches its tint at creation — re-key
                    // just this control so an accent change repaints it (nav state untouched).
                    .id(accentChoice)

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Accent")
                        HStack(spacing: Theme.Space.m) {
                            ForEach(AccentPalette.allCases) { p in
                                Button {
                                    accentChoice = p.rawValue
                                } label: {
                                    Circle()
                                        .fill(p.accentFill)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if accentChoice == p.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(p.onAccent)
                                            }
                                        }
                                        .overlay(Circle().strokeBorder(p.accent))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(p.label) accent")
                                .accessibilityAddTraits(accentChoice == p.rawValue ? [.isSelected] : [])
                            }
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("accentPicker")
                }
                .inkRow()
                Section {
                    // Insights & Constellation moved to the Explore tab (nav restructure)
                    if container.modelContainer != nil {
                        NavigationLink { SavedScreen() } label: { Label("Saved verses", systemImage: "bookmark") }
                    } else {
                        // SavedScreen's @Query fatal-errors without a model container in the
                        // environment — when even the in-memory fallback failed, show why
                        // instead of a crashing link (mirrors the RootView banner copy).
                        Label {
                            VStack(alignment: .leading) {
                                Text("Saved verses").foregroundStyle(.secondary)
                                Text("Unavailable this session — the bookmarks store could not be opened.")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        } icon: { Image(systemName: "bookmark.slash").foregroundStyle(.secondary) }
                    }
                    NavigationLink { PrivacyPolicyScreen() } label: { Label("Privacy Policy", systemImage: "hand.raised") }
                        .accessibilityIdentifier("privacyPolicyLink")
                    Link(destination: AppLinks.support) { Label("Support", systemImage: "lifepreserver") }
                        .accessibilityIdentifier("supportLink")
                    NavigationLink { AboutScreen() } label: { Label("About & credits", systemImage: "info.circle") }
                }
                .inkRow()
            }
            .inkGroupedList()
            .navigationTitle("More")
        }
    }
}

struct AboutScreen: View {
    @Environment(AppContainer.self) private var container
    /// Local MetricKit files (usually none). State, so "Delete diagnostics" updates the row at once.
    @State private var diagnostics: [URL] = CrashMonitor.files()

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("ੴ").font(Brand.gurmukhi(64)).foregroundStyle(Brand.primary)
                    Text("Gurbani Soul").font(Brand.heading(.title2)).multilineTextAlignment(.center)
                    Text("Sri Guru Granth Sahib Ji · 1430 Angs · verbatim · offline").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Built by Algorythmos").font(.caption2).foregroundStyle(.secondary)
                    Text("Version \(LaunchIntegrity.bundleVersionString())")
                        .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                        .accessibilityIdentifier("aboutVersion")
                }
                .frame(maxWidth: .infinity)
            }
            .inkRow()
            if let report = container.integrity {
                Section("Integrity") {
                    ForEach(report.checks) { c in
                        Label(c.name, systemImage: c.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(c.passed ? Ink.positive : Ink.negative)
                    }
                    Text("db_sha256 \(report.dbSha256.prefix(16))…").font(.caption2).foregroundStyle(.tertiary)
                    Text("SQLite (pinned) \(report.sqliteVersion)").font(.caption2).foregroundStyle(.tertiary)
                    // Widget App Group: silently absent on a mis-provisioned signed build (the
                    // widgets would then read a different container and stay empty forever).
                    let groupOK = FileManager.default
                        .containerURL(forSecurityApplicationGroupIdentifier: WidgetStore.appGroup) != nil
                    Label("Widget App Group \(groupOK ? "available" : "unavailable")",
                          systemImage: groupOK ? "checkmark.circle" : "xmark.circle")
                        .font(.caption2).foregroundStyle(groupOK ? Ink.positive : Ink.negative)
                    Text("Meaningful on a signed device build only — the simulator always reports available.")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text("Diagnostics collected on this device: \(String(diagnostics.count)) (local only, never sent)")
                        .font(.caption2).foregroundStyle(.tertiary)
                    // The only way these files ever leave the device: the reader's own choice, through
                    // the system share sheet. Nothing is sent automatically ("Data Not Collected").
                    if !diagnostics.isEmpty {
                        ShareLink(items: diagnostics) { Label("Share diagnostics…", systemImage: "square.and.arrow.up") }
                            .font(.footnote)
                            .accessibilityIdentifier("shareDiagnostics")
                        Button(role: .destructive) {
                            CrashMonitor.deleteAll()
                            diagnostics = CrashMonitor.files()
                        } label: { Label("Delete diagnostics", systemImage: "trash") }
                            .font(.footnote)
                            .accessibilityIdentifier("deleteDiagnostics")
                    }
                }
                .inkRow()
            }
            Section("Credits") {
                Text("Gurmukhi text: verbatim from the source edition, cited by Ang.")
                if container.corpus?.capabilities.hasEnglish == true {
                    Text("English translation by Dr. Sant Singh Khalsa (sourced via BaniDB) — a separate labelled layer, never the scripture.")
                }
                if container.corpus?.capabilities.hasBanis == true {
                    // Required in-app attribution, verbatim from NOTICE.md.
                    Text("Bani ordering and Sri Dasam Granth / Ardaas text via the ShabadOS open database. Sri Guru Granth Sahib Ji text is this project's own verified corpus.")
                }
                Text("Font: Sant Lipi © Shabad OS, SIL Open Font License 1.1.")
                Text("Headings: Source Serif 4 © Adobe, SIL Open Font License 1.1.")
                Text("No accounts. No network. No tracking. Ever.").foregroundStyle(.secondary)
            }
            .inkRow()
        }
        .inkGroupedList()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
