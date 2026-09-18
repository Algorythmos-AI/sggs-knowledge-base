import SwiftUI

/// The shape of the Nitnem day as a half-arc: the four bands laid over a 24-hour semicircle
/// (03:00 at the left, over the top, back to 03:00 at the right), with the current band lit and
/// a sun or moon at the present moment. Pure geometry in `DayArcModel`; the view only draws.
struct DayArcModel: Equatable {
    /// Minutes since the 03:00 Nitnem-day start, clamped to 0…1440.
    let minutesSince3am: Int

    init(minutesSince3am m: Int) { self.minutesSince3am = ((m % 1440) + 1440) % 1440 }

    /// Build from an absolute time.
    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let mins = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        self.init(minutesSince3am: ((mins - 180) % 1440 + 1440) % 1440)
    }

    /// Band segments as fractions 0…1 along the arc (left→right), in day order.
    static let segments: [(band: NitnemBand, start: Double, end: Double)] = [
        (.amritVela, 0,        360.0/1440),
        (.day,       360.0/1440, 840.0/1440),
        (.evening,   840.0/1440, 1080.0/1440),
        (.night,     1080.0/1440, 1)
    ]

    /// The current position along the arc, 0 (03:00) … 1 (next 03:00).
    var markerFraction: Double { Double(minutesSince3am) / 1440 }

    var currentBand: NitnemBand { NitnemSchedule.band(minutesSinceMidnight: minutesSince3am + 180) }

    var isDaylight: Bool { currentBand == .amritVela || currentBand == .day }
}

/// A quiet arc of the day with the present moment marked. One accessibility element.
struct DayArc: View {
    let model: DayArcModel
    @Environment(\.palette) private var palette

    // point on the semicircle for a fraction 0…1 (left→right over the top)
    private func point(_ f: Double, in size: CGSize) -> CGPoint {
        let r = min(size.width / 2, size.height) - 6
        let cx = size.width / 2, cy = size.height - 2
        let theta = Double.pi * (1 - min(max(f, 0), 1))     // π (left) → 0 (right)
        return CGPoint(x: cx + r * cos(theta), y: cy - r * sin(theta))
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Canvas { ctx, _ in
                    for seg in DayArcModel.segments {
                        var path = Path()
                        let steps = 24
                        for i in 0...steps {
                            let f = seg.start + (seg.end - seg.start) * Double(i) / Double(steps)
                            let p = point(f, in: size)
                            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                        }
                        let current = seg.band == model.currentBand
                        ctx.stroke(path,
                                   with: .color(current ? palette.accent : Ink.hairline.opacity(1)),
                                   style: StrokeStyle(lineWidth: current ? 3 : 2, lineCap: .round))
                    }
                }
                // sun / moon at the present moment
                let p = point(model.markerFraction, in: size)
                Image(systemName: model.isDaylight ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .background(Circle().fill(Ink.paper).frame(width: 24, height: 24))
                    .position(p)
            }
        }
        .frame(height: 58)
        .accessibilityElement()
        .accessibilityLabel("\(model.currentBand.title), \(bandRange)")
    }

    private var bandRange: String {
        switch model.currentBand {
        case .amritVela: return "3 am to 9 am"
        case .day: return "9 am to 5 pm"
        case .evening: return "5 pm to 9 pm"
        case .night: return "9 pm to 3 am"
        }
    }
}
