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
    }
}

// MARK: - Shared vocabulary (the widget target has no Theme.swift; Sant Lipi + Source Serif 4
// are bundled and registered in the extension's own Info.plist)

private enum WidgetType {
    static func gurmukhi(_ size: CGFloat) -> Font { .custom("SantLipi-ExtraLight", size: size) }
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("SourceSerif4Variable-Roman", size: size).weight(weight)
    }
    static let eyebrow: Font = .system(size: 10, weight: .semibold, design: .default)
}

/// The paper ground every widget sits on: `Ink.paper` plus a faint gold light in one corner —
/// the only decoration, at ≤8% so scripture always leads.
private struct PaperGround: View {
    var body: some View {
        ZStack {
            Ink.paper
            RadialGradient(colors: [AccentPalette.brandDefault.accentFill.opacity(0.14), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 260)
        }
    }
}

/// Small-caps label in the accent — "HUKAM", "RAAG NOW".
private struct Eyebrow: View {
    let text: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(WidgetType.eyebrow).tracking(1.4)
        }
        .foregroundStyle(AccentPalette.brandDefault.accentText)
        .accessibilityHidden(true)
    }
}

/// The ੴ mark, gold, used as the widget's signature.
private struct Mark: View {
    var size: CGFloat = 18
    var body: some View {
        Text("ੴ").font(WidgetType.gurmukhi(size))
            .foregroundStyle(AccentPalette.brandDefault.accentText)
            .accessibilityHidden(true)
    }
}

/// Gold rule + citation in the serif. Always the full name of the Granth (brand book §1).
private struct Citation: View {
    let ang: Int
    var action: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            RoundedRectangle(cornerRadius: 1).fill(AccentPalette.brandDefault.accentFill)
                .frame(width: 22, height: 2).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            Text("Sri Guru Granth Sahib Ji · Ang \(String(ang))")
                .font(WidgetType.serif(12))
                .foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.8)
            if let action {
                Spacer(minLength: 4)
                Text(action).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AccentPalette.brandDefault.accentText)
            }
        }
    }
}

// MARK: - Current raag (fixed-clock pahar timeline)

struct RaagNowEntry: TimelineEntry {
    let date: Date
    let pahar: Int
    let raags: [String]            // roman
    let raagsGurmukhi: [String]    // verbatim Gurmukhi names, parallel to `raags` when present
    let hasSnapshot: Bool
}

struct RaagNowProvider: TimelineProvider {
    private func entry(at date: Date, snapshot: WidgetSnapshot?) -> RaagNowEntry {
        let c = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let p = Pahar.paharFromMinutes(m)
        return RaagNowEntry(date: date, pahar: p, raags: snapshot?.paharRaags[p] ?? [],
                            raagsGurmukhi: snapshot?.paharRaagsGurmukhi?[p] ?? [],
                            hasSnapshot: snapshot != nil)
    }

    func placeholder(in context: Context) -> RaagNowEntry {
        RaagNowEntry(date: .now, pahar: 4, raags: ["maajh", "gaurhee", "tilang"],
                     raagsGurmukhi: [], hasSnapshot: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RaagNowEntry) -> Void) {
        completion(entry(at: .now, snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RaagNowEntry>) -> Void) {
        let snap = WidgetStore.load()
        var entries: [RaagNowEntry] = [entry(at: .now, snapshot: snap)]
        // one entry per fixed-clock pahar boundary over the next 24 h (8 boundaries).
        // Boundaries are WALL-CLOCK times (6:00, 9:00, …), so each is resolved with
        // `nextDate(matching:)` rather than by adding minutes — adding absolute time drifts
        // by an hour across a DST change while `entry(at:)` re-derives the pahar from the clock.
        var cursor = Date.now
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        for _ in 0..<8 {
            let c = cal.dateComponents([.hour, .minute], from: cursor)
            let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            let next = Pahar.window(Pahar.paharFromMinutes(m)).end            // start of the next pahar
            let match = DateComponents(hour: next / 60, minute: next % 60)
            guard let at = cal.nextDate(after: cursor, matching: match, matchingPolicy: .nextTime) else { break }
            cursor = at
            entries.append(entry(at: cursor, snapshot: snap))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RaagNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaagNow", provider: RaagNowProvider()) { entry in
            RaagNowView(entry: entry, hasSnapshot: entry.hasSnapshot)
                .containerBackground(for: .widget) { PaperGround() }
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
    @Environment(\.widgetFamily) private var family

    private var isDay: Bool { (1...4).contains(entry.pahar) }
    private var chipLimit: Int { family == .systemSmall ? 2 : 4 }

    /// A raag chip: Gurmukhi name (verbatim) over its roman form; roman only if the snapshot
    /// predates the Gurmukhi field.
    private func chip(_ i: Int) -> some View {
        let roman = entry.raags[i].capitalized
        let gm = i < entry.raagsGurmukhi.count ? entry.raagsGurmukhi[i] : nil
        return VStack(spacing: 1) {
            if let gm { Text(gm).font(WidgetType.gurmukhi(15)).foregroundStyle(.primary) }
            Text(roman).font(.system(size: gm == nil ? 12 : 9, weight: .medium))
                .foregroundStyle(gm == nil ? .primary : .secondary)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(AccentPalette.brandDefault.accentFill.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(AccentPalette.brandDefault.accentFill.opacity(0.45), lineWidth: 0.5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Eyebrow(text: "RAAG NOW", symbol: isDay ? "sun.max.fill" : "moon.stars.fill")
                Spacer()
                Mark(size: 15)
            }
            Spacer(minLength: 6)
            Text(Pahar.label(entry.pahar))
                .font(WidgetType.serif(family == .systemSmall ? 16 : 19))
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(Pahar.range(entry.pahar))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.top, 1)
            Spacer(minLength: 8)
            if entry.raags.isEmpty {
                Text(entry.pahar == 7 ? "Deliberately silent — no raags are assigned to this watch."
                     : hasSnapshot ? "No raags named for this watch." : "Open Gurbani Soul once to load.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<min(chipLimit, entry.raags.count), id: \.self) { chip($0) }
                    if entry.raags.count > chipLimit {
                        Text("+\(entry.raags.count - chipLimit)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AccentPalette.brandDefault.accentText)
                    }
                }
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .widgetURL(URL(string: "sggs://clock"))
    }

    private var a11y: String {
        let names = entry.raagsGurmukhi.isEmpty ? entry.raags.map { $0.capitalized } : entry.raagsGurmukhi
        return "Raag now. \(Pahar.label(entry.pahar)), \(Pahar.range(entry.pahar)). "
            + (names.isEmpty ? "No raags named." : names.joined(separator: ", "))
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
