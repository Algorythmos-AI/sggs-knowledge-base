import WidgetKit
import SwiftUI
import GurbaniPahar

/// SGGS widgets — read the App-Group snapshot + pure GurbaniPahar math only (never the corpus
/// DB; extension memory stays in kilobytes). Deep links route through the app's sggs:// table.
///
/// Design (brand book §6, "Widgets"): warm paper ground, one gold accent, a small-caps eyebrow,
/// scripture in ink Sant Lipi with air around it, the full citation in the heading serif.
/// Scripture is verbatim from the snapshot and is never coloured or restyled.

@main
struct SGGSWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RaagNowWidget()
        HukamWidget()
        NitnemWidget()
        #if canImport(ActivityKit)
        NitnemLiveActivity()   // Lock Screen + Dynamic Island while reading
        #endif
    }
}

// MARK: - Raag now (the 24-hour dial, fixed or solar — mirrors the app's clock mode)

struct RaagNowProvider: TimelineProvider {
    func placeholder(in context: Context) -> RaagNowEntry {
        let d = Date.now
        var e = RaagNowTimeline.entry(at: d, config: RaagClockConfig(solar: false), snapshot: nil)
        e = RaagNowEntry(date: d, pahar: 4, windows: e.windows, sunrise: nil, sunset: nil, nextPahar: 5,
                         boundaryDate: d.addingTimeInterval(3600), raags: ["maajh", "gaurhee", "tilang"],
                         raagsGurmukhi: [], beads: [1: 3, 2: 6, 3: 3, 4: 4, 5: 6, 6: 6, 8: 4], hasSnapshot: true, solar: false)
        return e
    }

    func getSnapshot(in context: Context, completion: @escaping (RaagNowEntry) -> Void) {
        let snap = WidgetStore.load()
        completion(RaagNowTimeline.entry(at: .now, config: .current(snapshot: snap), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RaagNowEntry>) -> Void) {
        let snap = WidgetStore.load()
        let config = RaagClockConfig.current(snapshot: snap)
        let entries = RaagNowTimeline.dates(from: .now, config: config).map {
            RaagNowTimeline.entry(at: $0, config: config, snapshot: snap)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RaagNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaagNow", provider: RaagNowProvider()) { entry in
            RaagNowView(entry: entry)
                .containerBackground(for: .widget) { RaagNowGround() }
        }
        .configurationDisplayName("Raag now")
        .description("Your local time on the 24-hour Raag Clock — the current watch and its raags. Follows the app's Fixed/Solar setting.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
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
                .containerBackground(for: .widget) { PaperGround() }
        }
        .configurationDisplayName("Hukam verse")
        .description("A Hukam unit's opening verse, verbatim with its Ang — a new draw each time you open the app.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct HukamView: View {
    let entry: HukamEntry
    @Environment(\.widgetFamily) private var family

    private var large: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Eyebrow(text: "HUKAM")
                Spacer()
                Mark(size: large ? 22 : 16)
            }
            if let s = entry.snapshot {
                Spacer(minLength: large ? 14 : 8)
                // The verse: verbatim, ink, generous leading for stacked matras.
                Text(s.hukamGurmukhi)
                    .font(WidgetType.gurmukhi(large ? 26 : 21))
                    .lineSpacing(large ? 8 : 5)
                    .minimumScaleFactor(0.7)
                    .lineLimit(large ? 5 : 3)
                    .foregroundStyle(.primary)
                    .accessibilityLabel(Text(punjabi(s.hukamGurmukhi)))
                if !s.hukamTranslit.isEmpty {
                    Text(s.hukamTranslit)
                        .font(.system(size: large ? 13 : 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(large ? 3 : 1)
                        .padding(.top, large ? 10 : 6)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: large ? 14 : 8)
                Citation(ang: s.hukamAng, action: large ? "Tap to read the shabad" : "Tap to read")
            } else {
                Spacer(minLength: 8)
                Text("Open Gurbani Soul once to draw a Hukam.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                Spacer(minLength: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: entry.snapshot.map { "sggs://shabad/\($0.hukamCompId)" } ?? "sggs://ang/1"))
    }

    private func punjabi(_ s: String) -> AttributedString {
        var a = AttributedString(s); a.languageIdentifier = "pa"; return a
    }
}

// MARK: - Nitnem (the daily reading: next bani + today's progress; reads the App-Group snapshot
// + the live progress file, never the corpus DB)

struct NitnemProvider: TimelineProvider {
    private func entry(at date: Date) -> NitnemEntry {
        NitnemTimeline.entry(at: date, snapshot: WidgetStore.load(), progress: NitnemProgressReading.load())
    }
    func placeholder(in context: Context) -> NitnemEntry {
        let sample = NitnemWidgetData.Bani(id: "japji", key: "japji", titleEn: "Japji Sahib",
                                           titleGm: "ਜਪੁਜੀ ਸਾਹਿਬ", minutes: 20, nLines: 385)
        return NitnemEntry(date: .now, band: .amritVela, banis: [sample],
                           completed: [:], fractions: [:], hasNitnem: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (NitnemEntry) -> Void) {
        completion(entry(at: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NitnemEntry>) -> Void) {
        let entries = NitnemTimeline.dates(from: .now).map { entry(at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NitnemWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NitnemNow", provider: NitnemProvider()) { entry in
            NitnemWidgetView(entry: entry)
                .containerBackground(for: .widget) { NitnemGround() }
        }
        .configurationDisplayName("Nitnem")
        .description("The bani to read now and how far along today is. Tap to open it.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
