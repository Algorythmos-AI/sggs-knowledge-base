import WidgetKit
import SwiftUI
import GurbaniPahar

/// SGGS widgets — read the App-Group snapshot + pure GurbaniPahar math only (never the corpus
/// DB; extension memory stays in kilobytes). Deep links route through the app's sggs:// table.

@main
struct SGGSWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RaagNowWidget()
        HukamWidget()
    }
}

// MARK: - Current raag (fixed-clock pahar timeline)

struct RaagNowEntry: TimelineEntry {
    let date: Date
    let pahar: Int
    let raags: [String]
    let hasSnapshot: Bool
}

struct RaagNowProvider: TimelineProvider {
    private func entry(at date: Date, snapshot: WidgetSnapshot?) -> RaagNowEntry {
        let c = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let p = Pahar.paharFromMinutes(m)
        return RaagNowEntry(date: date, pahar: p, raags: snapshot?.paharRaags[p] ?? [],
                            hasSnapshot: snapshot != nil)
    }

    func placeholder(in context: Context) -> RaagNowEntry {
        RaagNowEntry(date: .now, pahar: 4, raags: ["maajh", "gaurhee", "tilang"], hasSnapshot: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RaagNowEntry) -> Void) {
        completion(entry(at: .now, snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RaagNowEntry>) -> Void) {
        let snap = WidgetStore.load()
        var entries: [RaagNowEntry] = [entry(at: .now, snapshot: snap)]
        // one entry per fixed-clock pahar boundary over the next 24 h (8 boundaries)
        var cursor = Date.now
        let cal = Calendar(identifier: .gregorian)
        for _ in 0..<8 {
            let c = cal.dateComponents([.hour, .minute], from: cursor)
            let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            let wait = Pahar.nextBoundary(m, mode: "fixed").minutes
            cursor = cursor.addingTimeInterval(TimeInterval(wait * 60))
            entries.append(entry(at: cursor, snapshot: snap))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RaagNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaagNow", provider: RaagNowProvider()) { entry in
            RaagNowView(entry: entry, hasSnapshot: entry.hasSnapshot)
                .containerBackground(for: .widget) { Ink.card }
        }
        .configurationDisplayName("Raag now")
        .description("Which raags are traditionally sung in the current watch (fixed clock).")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RaagNowView: View {
    let entry: RaagNowEntry
    /// Distinguishes "no snapshot yet" (open the app) from a pahar that legitimately has
    /// no primary raags — the two used to share one misleading message.
    let hasSnapshot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock").font(.caption2)
                Text(Pahar.label(entry.pahar)).font(.caption.weight(.semibold))
            }
            .foregroundStyle(AccentPalette.saffron.accentText)
            Text(Pahar.range(entry.pahar)).font(.caption2).foregroundStyle(.tertiary)
            Spacer(minLength: 2)
            if entry.raags.isEmpty {
                Text(entry.pahar == 7 ? "Deliberately silent"
                     : hasSnapshot ? "No raags named for this watch" : "Open the app to load")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(entry.raags.prefix(4).map { $0.capitalized }.joined(separator: " · "))
                    .font(.footnote.weight(.medium))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "sggs://clock"))
    }
}

// MARK: - Hukam verse

struct HukamEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct HukamProvider: TimelineProvider {
    func placeholder(in context: Context) -> HukamEntry { HukamEntry(date: .now, snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (HukamEntry) -> Void) {
        completion(HukamEntry(date: .now, snapshot: WidgetStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HukamEntry>) -> Void) {
        // The verse ROTATES when the app is opened (the app writes a fresh snapshot);
        // the midnight refresh only re-reads the store so a rotation done during the day
        // still lands by next morning. The widget copy/description must not promise daily.
        let next = Calendar(identifier: .gregorian).nextDate(
            after: .now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [HukamEntry(date: .now, snapshot: WidgetStore.load())],
                            policy: .after(next)))
    }
}

struct HukamWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Hukam", provider: HukamProvider()) { entry in
            HukamView(entry: entry)
                .containerBackground(for: .widget) { Ink.card }
        }
        .configurationDisplayName("Hukam verse")
        .description("A Hukam unit's opening verse, verbatim with its Ang — a new draw each time you open the app.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct HukamView: View {
    let entry: HukamEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = entry.snapshot {
                Text(s.hukamGurmukhi)
                    .font(.custom("SantLipi-ExtraLight", size: 20))
                    .minimumScaleFactor(0.6)
                    .lineLimit(4)
                Spacer(minLength: 2)
                Text(s.hukamTranslit).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AccentPalette.saffron.heroGradient)
                        .frame(width: 22, height: 2)
                    Text("Ang \(String(s.hukamAng)) · tap to read")
                        .font(.caption2).foregroundStyle(AccentPalette.gold.accentText)
                }
            } else {
                Text("ੴ").font(.custom("SantLipi-ExtraLight", size: 28))
                    .foregroundStyle(AccentPalette.saffron.accent)
                Text("Open SGGS once to load a Hukam.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: entry.snapshot.map { "sggs://shabad/\($0.hukamCompId)" } ?? "sggs://ang/1"))
    }
}
