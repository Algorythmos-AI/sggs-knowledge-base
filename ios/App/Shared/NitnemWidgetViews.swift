import SwiftUI
import WidgetKit

/// The Nitnem widget views (in `Shared` so `WidgetRenderTests` can render every family). Warm
/// paper, one gold accent, a small-caps eyebrow, scripture in ink Sant Lipi — the same
/// vocabulary as the Raag Now and Hukam widgets (brand book §6, "Widgets").
struct NitnemWidgetView: View {
    let entry: NitnemEntry
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var envFamily
    private var family: WidgetFamily { familyOverride ?? envFamily }
    private var palette: AccentPalette { .brandDefault }

    private var eyebrow: String { entry.band.setKey == "morning" ? "MORNING BANIS"
        : entry.band.setKey == "evening" ? "REHRAS" : "SOHILA" }
    private var symbol: String { entry.band.setKey == "morning" ? "sunrise"
        : entry.band.setKey == "evening" ? "sunset" : "moon.stars" }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: medium
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .widgetURL(URL(string: entry.next.map { "sggs://bani/\($0.key)" } ?? "sggs://nitnem"))
    }

    // MARK: pieces

    private var ring: some View {
        ZStack {
            Circle().strokeBorder(palette.accent.opacity(0.22), lineWidth: 4)
            Circle().trim(from: 0, to: CGFloat(entry.setFraction))
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if entry.allDone {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.accentText)
            } else {
                Text("\(entry.doneCount)/\(entry.total)").font(.system(size: 12, weight: .bold)).monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder private func nextTitle(gm: CGFloat, en: CGFloat) -> some View {
        if let n = entry.next {
            VStack(alignment: .leading, spacing: 1) {
                Text(n.titleGm).font(WidgetType.gurmukhi(gm)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                Text(n.titleEn).font(.system(size: en, weight: .medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
        } else if entry.hasNitnem {
            Text(entry.band.setKey == "morning" ? "Morning banis complete" : "\(entry.band.title) complete")
                .font(WidgetType.serif(15)).foregroundStyle(.primary).lineLimit(2).minimumScaleFactor(0.8)
        } else {
            Text("Open Gurbani Soul once to load.").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    // MARK: families

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow(text: eyebrow, symbol: symbol)
                Spacer()
                Mark(size: 14)
            }
            Spacer(minLength: 0)
            nextTitle(gm: 17, en: 11)
            Spacer(minLength: 2)
            HStack(spacing: 6) {
                ring.frame(width: 26, height: 26)
                if let n = entry.next, let m = n.minutes {
                    Text("about \(m) min").font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    Text("\(entry.doneCount) of \(entry.total)").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            ring.frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Eyebrow(text: eyebrow, symbol: symbol)
                    Spacer()
                    Mark(size: 15)
                }
                Spacer(minLength: 4)
                nextTitle(gm: 20, en: 12)
                Spacer(minLength: 4)
                if let n = entry.next {
                    Text("Read \(n.titleEn)\(n.minutes.map { " · about \($0) min" } ?? "")")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                } else if entry.hasNitnem {
                    Text("\(entry.doneCount) of \(entry.total) read today").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var circular: some View {
        Gauge(value: entry.setFraction) {
            Image(systemName: symbol)
        } currentValueLabel: {
            if entry.allDone { Image(systemName: "checkmark") }
            else { Text("\(entry.doneCount)").font(.system(.body, design: .rounded)).monospacedDigit() }
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(entry.band.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            .widgetAccentable()
            if let n = entry.next {
                Text(n.titleGm).font(WidgetType.gurmukhi(13)).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(entry.doneCount) of \(entry.total) · next \(n.titleEn)")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            } else {
                Text(entry.hasNitnem ? "Complete for now" : "Open the app to load")
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        if let n = entry.next {
            return Text("\(n.titleEn) next · \(entry.doneCount)/\(entry.total)")
        }
        return Text(entry.hasNitnem ? "\(entry.band.title) complete" : "Nitnem")
    }

    private var a11y: String {
        if let n = entry.next {
            return "\(entry.band.title). Next, \(n.titleEn). \(entry.doneCount) of \(entry.total) read today."
        }
        return entry.hasNitnem ? "\(entry.band.title) complete." : "Open Gurbani Soul once to load Nitnem."
    }
}

/// Paper ground for the home families; the lock screen gets the system material.
struct NitnemGround: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: AccessoryWidgetBackground()
        default: PaperGround()
        }
    }
}
