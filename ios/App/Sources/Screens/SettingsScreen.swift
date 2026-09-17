import SwiftUI

struct MoreScreen: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("sggs_saroop") private var saroop = true
    @AppStorage("sggs_translit") private var showTranslit = true
    @AppStorage("sggs_show_english") private var showEnglish = true
    @AppStorage("sggs_gurmukhi_size") private var gurmukhiSize = 24.0
    @AppStorage("sggs_appearance") private var appearance = "system"
    @AppStorage(AccentPalette.storageKey) private var accentChoice = AccentPalette.saffron.rawValue

    var body: some View {
        NavigationStack {
            List {
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

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Accent")
                        HStack(spacing: Theme.Space.m) {
                            ForEach(AccentPalette.allCases) { p in
                                Button {
                                    accentChoice = p.rawValue
                                } label: {
                                    Circle()
                                        .fill(p.accent)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if accentChoice == p.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(p.onAccent)
                                            }
                                        }
                                        .overlay(Circle().strokeBorder(Ink.hairline))
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
                    NavigationLink { AboutScreen() } label: { Label("About & credits", systemImage: "info.circle") }
                }
            }
            .navigationTitle("More")
        }
    }
}

struct AboutScreen: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("ੴ").font(Brand.gurmukhi(64)).foregroundStyle(Brand.saffron)
                    Text("Gurbani Soul").font(.headline).multilineTextAlignment(.center)
                    Text("Sri Guru Granth Sahib Ji · 1430 Angs · verbatim · offline").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text("Built by Algorythmos").font(.caption2).foregroundStyle(.secondary)
                    Text("Version \(LaunchIntegrity.bundleVersionString())")
                        .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                        .accessibilityIdentifier("aboutVersion")
                }
                .frame(maxWidth: .infinity)
            }
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
                    let diag = CrashMonitor.diagnosticCount()
                    Text("Diagnostics collected on this device: \(String(diag)) (local only, never sent)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Section("Credits") {
                Text("Gurmukhi text: verbatim from the source edition, cited by Ang.")
                if container.corpus?.capabilities.hasEnglish == true {
                    Text("English translation by Dr. Sant Singh Khalsa (sourced via BaniDB) — a separate labelled layer, never the scripture.")
                }
                Text("Font: Sant Lipi © Shabad OS, SIL Open Font License 1.1.")
                Text("No accounts. No network. No tracking. Ever.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
