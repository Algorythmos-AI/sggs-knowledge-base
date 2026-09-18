import SwiftUI
import UIKit

/// Geometry + tiers of the 12-hour face in the dial's hollow. ONE source for the static face
/// (`PaharDialRenderer`) and the hands (`ClockHandsLayer`), so they can never disagree.
/// Everything is a ratio of the face radius `r`; small faces shed detail instead of crowding.
struct FaceMetrics {
    let r: CGFloat
    let center: CGPoint

    init(dial: DialMetrics) { r = dial.faceRadius; center = dial.center }
    init(r: CGFloat, center: CGPoint) { self.r = r; self.center = center }

    var drawsFace: Bool { r > 14 }
    /// Small widget: hands and the four quarter ticks only.
    var handsOnly: Bool { r < 30 }
    /// Numerals 12 · 3 · 6 · 9 only.
    var quartersOnly: Bool { r < 48 }
    var showsMinuteTicks: Bool { r >= 60 }
    /// The day/date complication needs room between the hub and the "3".
    var showsDate: Bool { r >= 70 }

    var numeralRadius: CGFloat { r * (quartersOnly ? 0.66 : 0.70) }
    var numeralSize: CGFloat { max(8, r * 0.20) }
    var hourLength: CGFloat { r * 0.50 }
    var minuteLength: CGFloat { r * 0.84 }
    var hourWidth: CGFloat { max(2.2, r * 0.060) }
    var minuteWidth: CGFloat { max(1.5, r * 0.045) }

    func point(angle a: Double, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + CGFloat(cos(a)) * radius, y: center.y + CGFloat(sin(a)) * radius)
    }

    /// The face surface: the card in light; a warm near-black in dark (never pure black —
    /// brand book §3.4), a touch deeper than the canvas so the face reads as glass.
    static let faceColor = Color(lightSystem: .secondarySystemGroupedBackground, dark: 0x0E0C0A)
}

/// Pure hand angles, in radians clockwise from 12 o'clock. Fractional seconds flow through
/// every hand — the minute hand creeps and the hour hand advances with the minutes, as on a
/// real movement. `wholeMinutes` freezes the seconds (widgets, pinned test clock).
enum ClockHands {
    struct Angles: Equatable { let hour: Double; let minute: Double; let second: Double }

    static func angles(for date: Date, tz: TimeZone = .current, wholeMinutes: Bool = false) -> Angles {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let s = wholeMinutes ? 0 : Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1_000_000_000
        let m = Double(c.minute ?? 0) + s / 60
        let h = Double((c.hour ?? 0) % 12) + m / 60
        return Angles(hour: h / 12 * 2 * .pi, minute: m / 60 * 2 * .pi, second: s / 60 * 2 * .pi)
    }
}

/// The moving part of the clock: tapered hour and minute hands, a thin accent seconds hand with
/// a counterweight, and the ringed hub — modelled on the Apple Watch analog face. Drawn in its
/// own Canvas so the app can animate ONLY this layer (the ring and the static face redraw once
/// a minute). Never hit-testable: taps belong to the pahar wedges underneath.
struct ClockHandsLayer: View {
    let date: Date
    var style: DialStyle = .full
    var palette: AccentPalette = .brandDefault
    var showSeconds = true
    var monochrome = false
    var timeZone: TimeZone = .current

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            guard style != .mono else { return }
            let dial = DialMetrics(size: min(size.width, size.height),
                                   center: CGPoint(x: size.width / 2, y: size.height / 2), style: style)
            let f = FaceMetrics(dial: dial)
            guard f.drawsFace else { return }
            let a = ClockHands.angles(for: date, tz: timeZone, wholeMinutes: !showSeconds)
            let ink: Color = .primary
            taperedHand(&ctx, f, angle: a.hour, length: f.hourLength, width: f.hourWidth, color: ink)
            taperedHand(&ctx, f, angle: a.minute, length: f.minuteLength, width: f.minuteWidth, color: ink)
            let accent: Color = monochrome ? .primary : palette.accent
            if showSeconds && !f.handsOnly {
                let sa = a.second - .pi / 2
                var p = Path()
                p.move(to: f.point(angle: sa + .pi, radius: f.r * 0.18))
                p.addLine(to: f.point(angle: sa, radius: f.r * 0.90))
                ctx.stroke(p, with: .color(accent), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            // hub: accent ring with a face-coloured pin, as on the reference face
            let hub: CGFloat = f.handsOnly ? 2 : max(3, min(4.5, f.r * 0.045))
            let c = f.center
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - hub, y: c.y - hub, width: hub * 2, height: hub * 2)),
                     with: .color(accent))
            let pin = hub * 0.38
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - pin, y: c.y - pin, width: pin * 2, height: pin * 2)),
                     with: .color(FaceMetrics.faceColor))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A slim stem from the hub, then a rounded bar — the Apple hand silhouette. A face-coloured
    /// halo keeps the bar legible where it crosses numerals or the other hand.
    private func taperedHand(_ ctx: inout GraphicsContext, _ f: FaceMetrics, angle: Double,
                             length: CGFloat, width: CGFloat, color: Color) {
        let a = angle - .pi / 2
        let neck = length * 0.17
        var stem = Path()
        stem.move(to: f.center)
        stem.addLine(to: f.point(angle: a, radius: neck))
        var bar = Path()
        bar.move(to: f.point(angle: a, radius: neck))
        bar.addLine(to: f.point(angle: a, radius: length))
        ctx.stroke(bar, with: .color(FaceMetrics.faceColor),
                   style: StrokeStyle(lineWidth: width + 2, lineCap: .round))
        ctx.stroke(stem, with: .color(color), style: StrokeStyle(lineWidth: max(1, width * 0.35), lineCap: .round))
        ctx.stroke(bar, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
