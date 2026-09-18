import SwiftUI
import GurbaniSearchKit

/// A quiet month record of the days each daily practice was read — for the reader's own
/// reflection, from the data already stored. No badges, targets, or sharing.
struct NitnemJourneyScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @AppStorage(NitnemPrefs.rehrasVariantKey) private var rehrasVariant = NitnemPrefs.rehrasDefault

    @State private var monthAnchor = NitnemClock.now()
    @State private var practices: [String: Set<BaniCategory>] = [:]

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                headerCard
                monthCard
                Text("A record for your own reflection. It stays on this device.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Ink.canvas.ignoresSafeArea())
        .navigationTitle("Reading journey")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPractices() }
    }

    private func loadPractices() async {
        guard let corpus = container.corpus else { return }
        let rows = await corpus.banis().banis.filter {
            $0.key == "rehras" ? $0.variant == NitnemPrefs.variant(for: "rehras", rehras: rehrasVariant) : $0.isDefault
        }
        let focus: [BaniCategory: [String]] = [
            .nitnemMorning: rows.filter { $0.category == .nitnemMorning }.map(\.id),
            .nitnemEvening: rows.filter { $0.category == .nitnemEvening }.map(\.id),
            .nitnemNight: rows.filter { $0.category == .nitnemNight }.map(\.id),
        ]
        practices = container.nitnem.practiceDays(focus: focus)
    }

    private func completed(_ key: String) -> Set<BaniCategory> { practices[key] ?? [] }

    private var headerCard: some View {
        let days = NitnemJourney.consecutiveDays(completed: completed)
        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            SectionEyebrow(text: "Together")
            Text(days == 0 ? "Begin today" : "\(days) \(days == 1 ? "day" : "days") together")
                .font(Brand.heading(.title3))
            Text("Morning banis, Rehras, and Sohila as you complete them.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(Ink.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
        .accessibilityElement(children: .combine)
    }

    private var monthCard: some View {
        let grid = NitnemJourney.month(monthAnchor, completed: completed, calendar: calendar)
        return VStack(spacing: Theme.Space.m) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 32) }
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 32) }
                    .disabled(isCurrentMonth)
                    .accessibilityLabel("Next month")
            }
            .foregroundStyle(palette.accent)
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { w in
                    Text(w).font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(grid) { day in JourneyCell(day: day) }
            }
        }
        .padding(Theme.Space.l)
        .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
    }

    private var weekdaySymbols: [String] {
        let s = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(s[first...] + s[..<first])
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(monthAnchor, equalTo: NitnemClock.now(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthAnchor) { monthAnchor = d }
    }
}

/// One day of the month: the number, plus a ring that fills as the day's practices complete.
private struct JourneyCell: View {
    let day: JourneyDay
    @Environment(\.palette) private var palette

    private var count: Int { day.practices.count }
    private var all: Bool { count >= NitnemJourney.practices.count }

    var body: some View {
        ZStack {
            if all {
                Circle().fill(palette.accentFill).overlay(Circle().strokeBorder(palette.accent))
            } else if count > 0 {
                Circle().strokeBorder(Ink.hairline, lineWidth: 2)
                Circle().trim(from: 0, to: CGFloat(count) / CGFloat(NitnemJourney.practices.count))
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle().strokeBorder(Ink.hairline, lineWidth: 1)
            }
            Text("\(day.dayNumber)")
                .font(.caption2.weight(day.isToday ? .bold : .regular))
                .foregroundStyle(all ? palette.onAccent : (day.inMonth ? .primary : .secondary))
            if day.isToday {
                Circle().strokeBorder(palette.accent, lineWidth: 1.5).padding(-2)
            }
        }
        .frame(height: 34)
        .opacity(day.inMonth ? 1 : 0.35)
        .accessibilityElement()
        .accessibilityLabel(label)
    }

    private var label: String {
        let date = day.date.formatted(.dateTime.day().month(.wide))
        if day.practices.isEmpty { return "\(date), nothing recorded" }
        let names = NitnemJourney.practices.filter { day.practices.contains($0) }.map(\.practiceLabel)
        return "\(date), \(names.joined(separator: " and ")) completed"
    }
}
