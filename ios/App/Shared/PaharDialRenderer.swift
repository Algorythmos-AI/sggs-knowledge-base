import SwiftUI
import GurbaniPahar

/// The 24-hour Raag Clock face, drawn once for the app and every widget family (compiled into
/// both targets; no `TimingClock`/DB dependency — the widget links only `GurbaniPahar`).
///
/// Geometry contract (unchanged since v1): noon at the top, midnight at the bottom, clockwise,
/// `angle(m) = m/1440·360° + 90°` in screen coordinates. From the centre outwards:
///   hollow (the live readout, drawn by the caller) · pahar band `inner…outer` (8 watches,
///   raag beads, current-watch glow) · hour ring (24 ticks, a major every 3 h) · numerals.
/// Colours are brand tokens only (brand book §3): the current watch is `accentFill` with an
/// `accent` stroke, the hand is `accent`, day watches sit on `accentDeep`, night on `Ink.info`;
/// pahar 7 stays faint on purpose — its silence is content.
struct PaharDialModel: Equatable {
    /// Windows for pahars 1…8 (index 0 = pahar 1), fixed or solar.
    var windows: [Pahar.Window]
    var current: Int
    var minutesNow: Int
    /// Present only when solar mode is live (draws the sunrise/sunset marks).
    var sunrise: Int? = nil
    var sunset: Int? = nil
    /// Primary raag count per pahar → beads along the arc.
    var beads: [Int: Int] = [:]

    static func fixed(current: Int, minutesNow: Int, beads: [Int: Int] = [:]) -> PaharDialModel {
        PaharDialModel(windows: (1...8).map { Pahar.window($0) }, current: current,
                       minutesNow: minutesNow, beads: beads)
    }

    static func solar(sunrise: Int, sunset: Int, current: Int, minutesNow: Int, beads: [Int: Int] = [:]) -> PaharDialModel {
        PaharDialModel(windows: (1...8).map { Pahar.solarWindow($0, sunrise: sunrise, sunset: sunset) },
                       current: current, minutesNow: minutesNow, sunrise: sunrise, sunset: sunset, beads: beads)
    }
}

enum DialStyle: Equatable {
    /// The app and the large widget: hour ring, numerals, beads, solar marks.
    case full
    /// Small/medium widgets: ticks only, no numerals.
    case compact
    /// Lock-screen accessories and tinted rendering: strokes in `.primary`, no fills.
    case mono
}

/// Radii for one dial size — shared by the renderer, the hit-test and the hollow overlay.
struct DialMetrics {
    let size: CGFloat
    let center: CGPoint
    let outer: CGFloat
    let inner: CGFloat
    let style: DialStyle

    init(size: CGFloat, center: CGPoint? = nil, style: DialStyle) {
        self.size = size
        self.center = center ?? CGPoint(x: size / 2, y: size / 2)
        self.style = style
        let inset: CGFloat = switch style {
        case .full: max(34, size * 0.11)       // room for ticks + numerals (never clipped)
        case .compact: 6
        case .mono: 4
        }
        outer = max(size / 2 - inset, 8)
        inner = outer * (style == .mono ? 0.66 : 0.62)
    }

    /// Diameter available to the hollow readout.
    var hollowWidth: CGFloat { max(inner * 2 - 10, 0) }
    /// Radius of the analog face drawn in the hollow.
    var faceRadius: CGFloat { inner - (style == .full ? 7 : 3) }
    var tickInner: CGFloat { outer + 3 }
    var tickMinor: CGFloat { outer + 7 }
    var tickMajor: CGFloat { outer + 10 }
    var numeralRadius: CGFloat { outer + 19 }

    /// minutes → angle, noon at top, clockwise.
    static func angle(_ m: Int) -> Angle { .degrees(Double(m) / 1440 * 360 + 90) }
    static func angle(_ m: Double) -> Angle { .degrees(m / 1440 * 360 + 90) }

    func point(minute m: Double, radius r: CGFloat) -> CGPoint {
        let a = Self.angle(m).radians
        return CGPoint(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r)
    }

    /// Inverse of the geometry for taps: a point inside the pahar band → minute-of-day.
    func minute(at pt: CGPoint) -> Int? {
        let dx = pt.x - center.x, dy = pt.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        guard r >= inner * 0.8, r <= outer + 12 else { return nil }
        var deg = atan2(Double(dy), Double(dx)) * 180 / .pi - 90       // undo the +90° offset
        deg = (deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return Int(deg / 360 * 1440) % 1440
    }
}

struct PaharDialRenderer: View {
    let model: PaharDialModel
    var style: DialStyle = .full
    var palette: AccentPalette = .brandDefault
    /// Cardinal numerals (`PaharFormat.dialNumerals`); ignored unless `style == .full`.
    var numerals: [(minute: Int, label: String)] = []
    /// Tinted/vibrant widget rendering: everything becomes `.primary` strokes.
    var monochrome = false
    /// Draw the classic 12-hour analog face (numerals 1–12, hour + minute hands) in the hollow,
    /// so the modern clock and the eight Sikhi watches read on one face. Off for `.mono`.
    var analogFace = true
    /// The date shown by the face's day/date complication (nil hides it).
    var faceDate: Date? = nil

    private var mono: Bool { monochrome || style == .mono }

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let m = DialMetrics(size: min(size.width, size.height),
                                center: CGPoint(x: size.width / 2, y: size.height / 2), style: style)
            drawHourRing(&ctx, m)
            drawWatches(&ctx, m)
            drawSolarMarks(&ctx, m)
            drawNumerals(&ctx, m)
            if analogFace && style != .mono { drawAnalogFace(&ctx, m) }
            drawHand(&ctx, m)
        }
    }

    // MARK: the 12-hour face (static part — the hands live in `ClockHandsLayer`)

    /// The Apple-clean face in the hollow: a quiet surface, 60 rim ticks with bold hour bars,
    /// thin SF numerals 1–12 and a small day/date complication. No hands here — they are a
    /// separate layer so the app can sweep the seconds without redrawing the ring.
    private func drawAnalogFace(_ ctx: inout GraphicsContext, _ m: DialMetrics) {
        let f = FaceMetrics(dial: m)
        guard f.drawsFace else { return }
        let r = f.r, c = f.center
        let face = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.fill(face, with: .color(FaceMetrics.faceColor))
        ctx.stroke(face, with: .color(Ink.hairline), lineWidth: 1)
        // rim ticks: 60 minutes, the 12 hours as bold rounded bars
        for i in 0..<60 {
            let hourTick = i % 5 == 0
            if !hourTick && !f.showsMinuteTicks { continue }
            if (f.quartersOnly || f.handsOnly) && i % 15 != 0 { continue }
            let a = Double(i) / 60 * 2 * .pi - .pi / 2
            var t = Path()
            t.move(to: f.point(angle: a, radius: r - 2.5))
            t.addLine(to: f.point(angle: a, radius: r - (hourTick ? max(6, r * 0.085) : max(4, r * 0.05))))
            ctx.stroke(t, with: .color(Color.primary.opacity(hourTick ? 0.95 : 0.35)),
                       style: StrokeStyle(lineWidth: hourTick ? max(1.5, r * 0.028) : 0.75, lineCap: .round))
        }
        // numerals: thin and airy (SF), quarters only on a tiny face
        if !f.handsOnly {
            let weight: Font.Weight = r >= 110 ? .light : .regular
            for h in 1...12 where !f.quartersOnly || h % 3 == 0 {
                let a = Double(h) / 12 * 2 * .pi - .pi / 2
                let t = Text("\(h)").font(.system(size: f.numeralSize, weight: weight))
                    .monospacedDigit().foregroundStyle(Color.primary)
                ctx.draw(ctx.resolve(t), at: f.point(angle: a, radius: f.numeralRadius), anchor: .center)
            }
        }
        // day/date complication between the hub and the "3"
        if f.showsDate, let faceDate {
            let (weekday, day) = PaharFormat.weekdayDay(faceDate)
            let size = max(9, r * 0.105)
            let t = Text(weekday + " ").font(.system(size: size, weight: .medium)).foregroundStyle(Color.secondary)
                + Text(day).font(.system(size: size, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(mono ? Color.primary : palette.accentText)
            ctx.draw(ctx.resolve(t), at: CGPoint(x: c.x + r * 0.40, y: c.y), anchor: .center)
        }
    }

    // MARK: layers

    private func wedge(_ w: Pahar.Window, _ m: DialMetrics) -> (path: Path, start: Int, end: Int) {
        let end = w.end <= w.start ? w.end + 1440 : w.end
        let path = Path { p in
            p.addArc(center: m.center, radius: m.outer, startAngle: DialMetrics.angle(w.start),
                     endAngle: DialMetrics.angle(end), clockwise: false)
            p.addArc(center: m.center, radius: m.inner, startAngle: DialMetrics.angle(end),
                     endAngle: DialMetrics.angle(w.start), clockwise: true)
            p.closeSubpath()
        }
        return (path, w.start, end)
    }

    private func drawWatches(_ ctx: inout GraphicsContext, _ m: DialMetrics) {
        guard model.windows.count == 8 else { return }
        for p in 1...8 {
            let (path, start, end) = wedge(model.windows[p - 1], m)
            let isCurrent = p == model.current
            let day = p <= 4
            if mono {
                ctx.fill(path, with: .color(.primary.opacity(isCurrent ? 0.55 : (p == 7 ? 0.06 : 0.16))))
                ctx.stroke(path, with: .color(.primary.opacity(isCurrent ? 0.95 : 0.35)), lineWidth: isCurrent ? 1.5 : 0.5)
            } else {
                let base: Color = day ? palette.accentDeep : Ink.info
                var fill = base.opacity(day ? 0.42 : 0.30)
                if p == 7 { fill = base.opacity(0.14) }
                if isCurrent { fill = palette.accentFill.opacity(0.92) }
                ctx.fill(path, with: .color(fill))
                // hairline between watches so the face reads as eight distinct wedges
                ctx.stroke(path, with: .color(Ink.hairline), lineWidth: 0.5)
                if isCurrent { ctx.stroke(path, with: .color(palette.accent), lineWidth: 2) }
            }
            // raag beads along the arc's middle radius
            let n = min(model.beads[p] ?? 0, 8)
            if n > 0 {
                let midR = (m.outer + m.inner) / 2
                let span = Double(end - start)
                let r: CGFloat = style == .full ? 2.6 : 1.8
                for i in 0..<n {
                    let t = (Double(i) + 1) / (Double(n) + 1)
                    let pt = m.point(minute: Double(start) + span * t, radius: midR)
                    let bead = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
                    let c: Color = mono ? .primary : (isCurrent ? palette.onAccent : .white)
                    ctx.fill(bead, with: .color(c.opacity(isCurrent ? 0.95 : 0.85)))
                }
            }
        }
    }

    private func drawHourRing(_ ctx: inout GraphicsContext, _ m: DialMetrics) {
        guard style != .mono else { return }
        for h in 0..<24 {
            let major = h % 3 == 0
            let a = m.point(minute: Double(h * 60), radius: m.tickInner)
            let b = m.point(minute: Double(h * 60), radius: major ? m.tickMajor : m.tickMinor)
            var tick = Path(); tick.move(to: a); tick.addLine(to: b)
            let c: Color = mono ? .primary.opacity(major ? 0.8 : 0.35)
                                : (major ? palette.accent : Ink.hairline)
            ctx.stroke(tick, with: .color(c), style: StrokeStyle(lineWidth: major ? 2 : 1, lineCap: .round))
        }
    }

    private func drawNumerals(_ ctx: inout GraphicsContext, _ m: DialMetrics) {
        guard style == .full, m.inner > 40 else { return }
        for n in numerals {
            let pt = m.point(minute: Double(n.minute), radius: m.numeralRadius)
            let text = Text(n.label).font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit().foregroundStyle(mono ? Color.primary : Color.secondary)
            ctx.draw(ctx.resolve(text), at: pt, anchor: .center)
        }
    }

    /// Sunrise/sunset badges sit INSIDE the band on the day/night seam (never on the hour
    /// ring, where they would collide with the 6 AM / 6 PM numerals).
    private func drawSolarMarks(_ ctx: inout GraphicsContext, _ m: DialMetrics) {
        guard style != .compact, let sr = model.sunrise, let ss = model.sunset else { return }
        let r: CGFloat = style == .full ? 8 : 5.5
        for (minute, symbol) in [(sr, "sunrise.fill"), (ss, "sunset.fill")] {
            let pt = m.point(minute: Double(minute), radius: (m.outer + m.inner) / 2)
            let badge = Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
            if mono {
                ctx.fill(badge, with: .color(.primary.opacity(0.9)))
            } else {
                ctx.fill(badge, with: .color(Ink.card))
                ctx.stroke(badge, with: .color(palette.accent), lineWidth: 1)
            }
            let glyph = Text(Image(systemName: symbol)).font(.system(size: style == .full ? 8 : 6, weight: .bold))
                .foregroundStyle(mono ? Color.black : palette.accent)
            ctx.draw(ctx.resolve(glyph), at: pt, anchor: .center)
        }
    }

    /// The "now" pointer lives in the pahar band only — it never crosses the hollow, which
    /// belongs to the readout. A pip at the inner edge marks where it starts.
    private func drawHand(_ ctx: inout GraphicsContext, _ m: DialMetrics) {
        let now = Double(model.minutesNow)
        let tip = m.point(minute: now, radius: m.outer + (style == .full ? 4 : 2))
        let root = m.point(minute: now, radius: m.inner - (style == .full ? 5 : 3))
        var hand = Path(); hand.move(to: root); hand.addLine(to: tip)
        let c: Color = mono ? .primary : palette.accent
        // a soft halo under the hand so it stays legible over the gold current wedge
        if !mono {
            ctx.stroke(hand, with: .color(Ink.canvas.opacity(0.9)),
                       style: StrokeStyle(lineWidth: style == .full ? 6 : 4, lineCap: .round))
        }
        ctx.stroke(hand, with: .color(c), style: StrokeStyle(lineWidth: style == .full ? 2.5 : 1.8, lineCap: .round))
        let pip: CGFloat = style == .full ? 4 : 2.5
        ctx.fill(Path(ellipseIn: CGRect(x: root.x - pip, y: root.y - pip, width: pip * 2, height: pip * 2)),
                 with: .color(c))
    }
}
