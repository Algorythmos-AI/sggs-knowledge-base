import SwiftUI

struct MoreScreen: View {
    @AppStorage("sggs_saroop") private var saroop = true
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
                }
                Section {
                    NavigationLink { InsightsScreen() } label: { Label("Insights", systemImage: "chart.bar.xaxis") }
                    NavigationLink { ConstellationScreen() } label: { Label("Concept Constellation", systemImage: "circle.hexagongrid") }
                    NavigationLink { SavedScreen() } label: { Label("Saved verses", systemImage: "bookmark") }
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
                    Text("Sri Guru Granth Sahib — Knowledge Base").font(.headline).multilineTextAlignment(.center)
                    Text("1430 Angs · verbatim Gurmukhi · fully offline").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            if let report = container.integrity {
                Section("Integrity") {
                    ForEach(report.checks) { c in
                        Label(c.name, systemImage: c.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(c.passed ? .green : .red)
                    }
                    Text("db_sha256 \(report.dbSha256.prefix(16))…").font(.caption2).foregroundStyle(.tertiary)
                    Text("SQLite (pinned) \(report.sqliteVersion)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Section("Credits") {
                Text("Gurmukhi text: verbatim from the source edition, cited by Ang.")
                Text("Font: Sant Lipi © Shabad OS, SIL Open Font License 1.1.")
                Text("No accounts. No network. No tracking. Ever.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
