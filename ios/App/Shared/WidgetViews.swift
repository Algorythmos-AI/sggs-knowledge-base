import SwiftUI
import WidgetKit
import GurbaniPahar

/// Widget vocabulary + the Raag Now views, in `Shared` so the unit-test target can render
/// every family (`WidgetRenderTests`) without linking the extension bundle.

// MARK: - Shared vocabulary (the widget target has no Theme.swift; Sant Lipi + Source Serif 4
// are bundled and registered in the extension's own Info.plist)

enum WidgetType {
    static func gurmukhi(_ size: CGFloat) -> Font { .custom("SantLipi-ExtraLight", size: size) }
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("SourceSerif4Variable-Roman", size: size).weight(weight)
    }
    static let eyebrow: Font = .system(size: 10, weight: .semibold, design: .default)
}

/// The paper ground every widget sits on: `Ink.paper` plus a faint gold light in one corner —
/// the only decoration, at ≤8% so scripture always leads.
struct PaperGround: View {
    var body: some View {
        ZStack {
            Ink.paper
            RadialGradient(colors: [AccentPalette.brandDefault.accentFill.opacity(0.14), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 260)
        }
    }
}

/// Small-caps label in the accent — "HUKAM", "RAAG NOW".
struct Eyebrow: View {
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
struct Mark: View {
    var size: CGFloat = 18
    var body: some View {
        Text("ੴ").font(WidgetType.gurmukhi(size))
            .foregroundStyle(AccentPalette.brandDefault.accentText)
            .accessibilityHidden(true)
    }
}

/// Gold rule + citation in the serif. Always the full name of the Granth (brand book §1).
struct Citation: View {
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

/// Paper ground for the home-screen families; the lock screen gets the system's own material.
struct RaagNowGround: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: AccessoryWidgetBackground()
        default: PaperGround()
        }
    }
}

struct RaagNowView: View {
    let entry: RaagNowEntry
    /// Set by the render tests; live widgets read the environment.
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var envFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var family: WidgetFamily { familyOverride ?? envFamily }
    private var mono: Bool { renderingMode != .fullColor }
    private var isDay: Bool { (1...4).contains(entry.pahar) }
    private var palette: AccentPalette { .brandDefault }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            case .systemLarge: large
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: medium
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .widgetURL(URL(string: "sggs://clock"))
    }

    // MARK: pieces

    /// A raag chip: Gurmukhi name (verbatim) over its roman form; roman only if the snapshot
    /// predates the Gurmukhi field.
    private func chip(_ i: Int, gurmukhiSize: CGFloat = 15) -> some View {
        let roman = entry.raags[i].capitalized
        let gm = i < entry.raagsGurmukhi.count ? entry.raagsGurmukhi[i] : nil
        return VStack(spacing: 1) {
            if let gm { Text(gm).font(WidgetType.gurmukhi(gurmukhiSize)).foregroundStyle(.primary) }
            Text(roman).font(.system(size: gm == nil ? 12 : 9, weight: .medium))
                .foregroundStyle(gm == nil ? .primary : .secondary)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(palette.accentFill.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(palette.accent.opacity(0.45), lineWidth: 0.5))
    }

    private func chips(limit: Int, gurmukhiSize: CGFloat = 15) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<min(limit, entry.raags.count), id: \.self) { chip($0, gurmukhiSize: gurmukhiSize) }
            if entry.raags.count > limit {
                Text("+\(entry.raags.count - limit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.accentText)
            }
        }
        .lineLimit(1)
    }

    private var emptyText: String {
        entry.pahar == 7 ? "Deliberately silent — no raags are assigned to this watch."
        : entry.hasSnapshot ? "No raags named for this watch." : "Open Gurbani Soul once to load."
    }

    /// The live local time — WidgetKit keeps this text current between timeline entries.
    private func liveTime(_ size: CGFloat) -> some View {
        Text(entry.date, style: .time)
            .font(WidgetType.serif(size, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(.primary)
    }

    /// "next watch in 2 hrs, 17 min" — `.relative` counts live between timeline entries.
    private var nextLine: some View {
        HStack(spacing: 3) {
            Text("next watch in")
            Text(entry.boundaryDate, style: .relative)
        }
        .font(.system(size: 10)).foregroundStyle(.secondary)
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    /// Ring + static face, then the hands at the entry's minute (WidgetKit cannot animate, so
    /// no seconds hand; the minute-dense timeline keeps them current).
    private func dial(_ style: DialStyle) -> some View {
        ZStack {
            PaharDialRenderer(model: entry.model, style: style, palette: palette,
                              numerals: style == .full ? PaharFormat.dialNumerals() : [], monochrome: mono,
                              faceDate: entry.date)
            ClockHandsLayer(date: entry.date, style: style, palette: palette, showSeconds: false, monochrome: mono)
        }
    }

    private var solarBadge: some View {
        Group {
            if entry.solar {
                Image(systemName: "sun.horizon.fill").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.accentText)
            }
        }
    }

    // MARK: families

    private var small: some View {
        VStack(spacing: 2) {
            HStack {
                Eyebrow(text: "RAAG NOW", symbol: isDay ? "sun.max.fill" : "moon.stars.fill")
                Spacer()
                solarBadge
                Mark(size: 14)
            }
            // the face stays clean at this size (quarter numerals + hands); the readout sits below
            dial(.compact)
            HStack(alignment: .firstTextBaseline) {
                liveTime(13)
                Spacer(minLength: 4)
                Text(Pahar.label(entry.pahar))
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            dial(.compact)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Eyebrow(text: "RAAG NOW", symbol: isDay ? "sun.max.fill" : "moon.stars.fill")
                    Spacer()
                    solarBadge
                    Mark(size: 15)
                }
                Spacer(minLength: 4)
                liveTime(24)
                Text(Pahar.label(entry.pahar))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(entry.windowText)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                if entry.raags.isEmpty {
                    Text(emptyText).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                } else {
                    chips(limit: 2, gurmukhiSize: 14)
                }
                Spacer(minLength: 4)
                nextLine
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow(text: "RAAG NOW", symbol: isDay ? "sun.max.fill" : "moon.stars.fill")
                Spacer()
                solarBadge
                Mark(size: 18)
            }
            HStack(alignment: .center, spacing: 12) {
                dial(.compact)                      // no numerals at this size; a fuller ring instead
                    .frame(width: 150, height: 150)
                VStack(alignment: .leading, spacing: 2) {
                    liveTime(26)
                    Text(Pahar.label(entry.pahar))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(entry.windowText)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if entry.raags.isEmpty {
                        Text(emptyText).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    } else {
                        chips(limit: 2, gurmukhiSize: 13)
                    }
                    Spacer(minLength: 4)
                    nextLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            watchList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The eight watches, compact, the current one on a faint gold row.
    private var watchList: some View {
        VStack(spacing: 2) {
            ForEach(1...8, id: \.self) { p in
                let current = p == entry.pahar
                let n = entry.beads[p] ?? 0
                HStack(spacing: 6) {
                    Text("P\(p)").font(.system(size: 9, weight: .bold)).monospacedDigit()
                        .foregroundStyle(current ? palette.accentText : .secondary)
                        .frame(width: 18, alignment: .leading)
                    Text(Pahar.label(p)).font(.system(size: 10, weight: current ? .semibold : .regular))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text(PaharFormat.window(entry.windows[p - 1], on: entry.date))
                        .font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(n == 0 ? (p == 7 ? "silent" : "—") : "\(n)")
                        .font(.system(size: 9, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(current ? palette.accentFill.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }

    private var circular: some View {
        ZStack {
            dial(.mono)
            VStack(spacing: -1) {
                Text("P\(entry.pahar)").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                Text(isDay ? "day" : "night").font(.system(size: 7, weight: .medium))
            }
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill").font(.system(size: 10, weight: .semibold))
                Text(Pahar.label(entry.pahar)).font(.system(size: 13, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .widgetAccentable()
            if entry.raags.isEmpty {
                Text(entry.pahar == 7 ? "Deliberately silent" : emptyText)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            } else if !entry.raagsGurmukhi.isEmpty {
                Text(entry.raagsGurmukhi.prefix(4).joined(separator: "  "))
                    .font(WidgetType.gurmukhi(13)).lineLimit(1).minimumScaleFactor(0.8)
            } else {
                Text(entry.raags.prefix(3).map(\.capitalized).joined(separator: " · "))
                    .font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 3) {
                Text("next in")
                Text(entry.boundaryDate, style: .relative)
            }
            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        let names = entry.raagsGurmukhi.isEmpty ? entry.raags.prefix(3).map(\.capitalized) : Array(entry.raagsGurmukhi.prefix(3))
        return Text("P\(entry.pahar) · " + (names.isEmpty ? Pahar.label(entry.pahar) : names.joined(separator: ", ")))
    }

    private var a11y: String {
        let names = entry.raagsGurmukhi.isEmpty ? entry.raags.map { $0.capitalized } : entry.raagsGurmukhi
        return "Raag now. \(PaharFormat.time(entry.date)). \(Pahar.label(entry.pahar)), \(entry.windowText). "
            + (names.isEmpty ? "No raags named." : names.joined(separator: ", "))
    }
}

