import SwiftUI
import GurbaniSearchKit

/// "My Nitnem" — reorder, hide, or add a bani to each daily set. Edits are display/plan only: the
/// library still lists every bani, and the scripture text is never touched. Writes go to
/// `nitnem-plan.json` (a sibling of the reading history, never a migration of it).
struct NitnemSetsScreen: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(NitnemPrefs.rehrasVariantKey) private var rehrasVariant = NitnemPrefs.rehrasDefault

    @State private var category: BaniCategory = .nitnemMorning
    @State private var registry: [BaniSummary] = []
    @State private var entries: [NitnemSetEntry] = []
    @State private var showingAdd = false
    @State private var editMode: EditMode = .inactive

    private let categories: [BaniCategory] = [.nitnemMorning, .nitnemEvening, .nitnemNight]

    private var store: NitnemPlanStore { container.nitnemPlan }
    private func title(for key: String) -> BaniSummary? { registry.first { $0.key == key } }
    /// Keys that are a registry default of the CURRENT category (cannot be deleted, only hidden).
    private var defaultKeys: Set<String> { Set(registry.filter { $0.category == category && $0.isDefault }.map(\.key)) }

    var body: some View {
        List {
            Section {
                Picker("Set", selection: $category) {
                    Text("Morning").tag(BaniCategory.nitnemMorning)
                    Text("Rehras").tag(BaniCategory.nitnemEvening)
                    Text("Sohila").tag(BaniCategory.nitnemNight)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("nitnemSetsPicker")
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(entries, id: \.key) { entry in
                    row(entry)
                }
                .onMove(perform: move)
                Button { showingAdd = true } label: {
                    Label("Add a bani", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("nitnemSetsAdd")
            } header: {
                Text(headerTitle)
            } footer: {
                Text("Reorder with the grip, swipe to hide, or add another bani. This changes only your daily set — every bani stays in the library.")
            }
            if store.isCustomised(category) {
                Section {
                    Button(role: .destructive) { reset() } label: { Text("Reset to default") }
                        .accessibilityIdentifier("nitnemSetsReset")
                }
            }
        }
        .inkGroupedList()
        .navigationTitle("My Nitnem")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .task { await loadRegistry() }
        .onChange(of: category) { _, _ in seed() }
        .sheet(isPresented: $showingAdd) { addSheet }
    }

    private var headerTitle: String {
        switch category {
        case .nitnemMorning: return "Morning banis"
        case .nitnemEvening: return "Rehras Sahib"
        case .nitnemNight: return "Kirtan Sohila"
        default: return ""
        }
    }

    @ViewBuilder private func row(_ entry: NitnemSetEntry) -> some View {
        let summary = title(for: entry.key)
        HStack(spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 1) {
                Text(summary?.titleEn ?? entry.key)
                    .foregroundStyle(entry.hidden ? .secondary : .primary)
                if let gm = summary?.titleGm {
                    GurmukhiText(verbatim: gm, size: 15)
                }
            }
            Spacer()
            if entry.hidden {
                Text("Hidden").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button { toggleHidden(entry) } label: {
                Label(entry.hidden ? "Show" : "Hide", systemImage: entry.hidden ? "eye" : "eye.slash")
            }.tint(entry.hidden ? .green : .gray)
            if !defaultKeys.contains(entry.key) {
                Button(role: .destructive) { remove(entry) } label: { Label("Remove", systemImage: "trash") }
            }
        }
        .accessibilityIdentifier("setRow_\(entry.key)")
        .accessibilityLabel("\(summary?.titleEn ?? entry.key)\(entry.hidden ? ", hidden" : "")")
    }

    private var addSheet: some View {
        let options = NitnemSets.addable(to: category, plan: entries, registry: registry, rehrasVariant: rehrasVariant)
        return NavigationStack {
            List {
                if options.isEmpty {
                    Text("Every bani is already in this set.").foregroundStyle(.secondary)
                }
                ForEach(options) { s in
                    Button { add(s) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.titleEn).foregroundStyle(.primary)
                            GurmukhiText(verbatim: s.titleGm, size: 15)
                        }
                    }
                    .accessibilityIdentifier("addOption_\(s.key)")
                }
            }
            .inkGroupedList()
            .navigationTitle("Add a bani")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingAdd = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: mutations

    private func loadRegistry() async {
        guard let corpus = container.corpus, corpus.capabilities.hasBanis else { return }
        registry = await corpus.banis().banis
        seed()
    }

    private func seed() {
        let existing = store.entries(for: category)
        if existing.isEmpty {
            let defaults = NitnemSets.resolved(category: category, plan: [], registry: registry, rehrasVariant: rehrasVariant)
            entries = defaults.map { NitnemSetEntry(key: $0.key, hidden: false) }
        } else {
            entries = existing
        }
    }

    private func commit() {
        store.setEntries(entries, for: category)
    }

    private func move(from source: IndexSet, to dest: Int) {
        entries.move(fromOffsets: source, toOffset: dest)
        commit()
    }
    private func toggleHidden(_ entry: NitnemSetEntry) {
        guard let i = entries.firstIndex(where: { $0.key == entry.key }) else { return }
        entries[i].hidden.toggle()
        commit()
    }
    private func remove(_ entry: NitnemSetEntry) {
        entries.removeAll { $0.key == entry.key }
        commit()
    }
    private func add(_ s: BaniSummary) {
        guard !entries.contains(where: { $0.key == s.key }) else { showingAdd = false; return }
        entries.append(NitnemSetEntry(key: s.key, hidden: false))
        commit()
        showingAdd = false
    }
    private func reset() {
        store.reset(category)
        seed()
    }
}
