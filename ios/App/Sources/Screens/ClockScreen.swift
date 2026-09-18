import SwiftUI
import GurbaniSearchKit

/// The Raag Clock: when each raag is traditionally sung — shown as ATTRIBUTED SCHOLARLY
/// CLAIMS with citations, never facts. Where traditions disagree, both placements are kept
/// with their sources (see DivergenceScreen). Native parity with the web /raag-clock.
///
/// Time is injectable (`now`) so tests can pin the clock; the live screen ticks on a
/// 1-minute TimelineView. The dial is decorative for accessibility — the pahar LIST below
/// is the full-content path (VoiceOver / Switch Control / keyboard).
struct ClockScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @AppStorage("sggs_clock_mode") private var mode = "fixed"     // fixed | solar
    @State private var clock: TimingClock?
    /// Lazily created in .task — a `@State = SolarLocation()` default would construct a fresh
    /// CLLocationManager (delegate wired, defaults read) on EVERY ClockScreen struct init,
    /// i.e. every RootView body re-evaluation (the documented @State-autoclosure anti-pattern).
    @State private var location: SolarLocation?
    @State private var detailPahar: PaharSelection?
    @State private var showDivergence = false
    @State private var unknownRaagNote: String?
    @State private var showManualLocation = false
    /// Injectable for tests (XCUITest launches with SGGS_CLOCK_NOW=<minutes> to pin the time).
    var now: () -> Date = { Date() }

    var body: some View {
        NavigationStack {
            Group {
                if container.corpus?.capabilities.hasTiming != true {
                    ContentUnavailableView("Raag timing not in this build",
                                           systemImage: "clock.badge.questionmark",
                                           description: Text("This database profile doesn't carry the timing layer."))
                } else if let clock {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        content(clock: clock)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Raag Clock")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $detailPahar) { sel in
                PaharDetailSheet(pahar: sel.p, clock: clock ?? TimingClock(available: false),
                                 windowText: windowText(sel.p))
            }
            .sheet(isPresented: $showDivergence) { DivergenceScreen() }
        }
        .task {
            if location == nil { location = SolarLocation() }
            guard clock == nil, let corpus = container.corpus else { return }
            clock = await corpus.timingClock()
            consumePendingRaag()
        }
        .onChange(of: container.router.pendingClockRaag) { _, _ in consumePendingRaag() }
    }

    // MARK: time plumbing

    private var minutesNow: Int {
        #if DEBUG
        // test override: pin the wall clock to a minute-of-day (XCUITests run the Debug
        // configuration; this hook never ships in Release)
        if let env = ProcessInfo.processInfo.environment["SGGS_CLOCK_NOW"], let m = Int(env) {
            return ((m % 1440) + 1440) % 1440
        }
        #endif
        let c = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: now())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var sun: Pahar.SunTimes? {
        guard mode == "solar", let coords = location?.coords else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day], from: now())
        // JS getTimezoneOffset convention: UTC+5:30 → -330
        let tzOffsetMin = -TimeZone.current.secondsFromGMT(for: now()) / 60
        return Pahar.sunTimes(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1,
                              lat: coords.lat, lon: coords.lon, tzOffsetMin: tzOffsetMin)
    }

    /// (currentPahar, usableSolar) — solar falls back to fixed at polar latitudes / no fix.
    private func currentPahar() -> (pahar: Int, solar: Pahar.SunTimes?) {
        if let s = sun, !s.polar, let sr = s.sunrise, let ss = s.sunset {
            return (Pahar.paharSolar(minutesNow, sunrise: sr, sunset: ss), s)
        }
        return (Pahar.paharFromMinutes(minutesNow), nil)
    }

    private func windowText(_ p: Int) -> String {
        if let s = sun, !s.polar, let sr = s.sunrise, let ss = s.sunset {
            let w = Pahar.solarWindow(p, sunrise: sr, sunset: ss)
            func f(_ m: Int) -> String { Pahar.fmt12("\(m / 60):\(String(format: "%02d", m % 60))") }
            return "\(f(w.start))–\(f(w.end))"
        }
        return Pahar.range(p)
    }

    private func consumePendingRaag() {
        guard clock != nil, let raag = container.router.pendingClockRaag else { return }
        container.router.pendingClockRaag = nil
        // focus the pahar that raag's primary claim names (roman or gurmukhi)
        if let claim = clock?.primary.first(where: { $0.roman == raag.lowercased() || $0.raagName == raag }),
           let p = claim.pahar {
            unknownRaagNote = nil
            detailPahar = PaharSelection(p: p)
        } else {
            // a widget/Siri/sggs:// link named a raag with no primary timing claim — say so
            // instead of silently landing on the Clock as if nothing was asked
            unknownRaagNote = "No timing claim is recorded for “\(raag)” — showing the current watch."
        }
    }

    // MARK: content

    @ViewBuilder private func content(clock: TimingClock) -> some View {
        let (p, solar) = currentPahar()
        let boundary = solar.flatMap { s -> Pahar.Boundary? in
            guard let sr = s.sunrise, let ss = s.sunset else { return nil }
            return Pahar.nextBoundary(minutesNow, mode: "solar", sunrise: sr, sunset: ss)
        } ?? Pahar.nextBoundary(minutesNow, mode: "fixed")

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                nowCard(clock: clock, pahar: p, boundary: boundary, solarLive: solar != nil)
                RaagDial(clock: clock, currentPahar: p, minutesNow: minutesNow, sun: solar) { tapped in
                    Haptics.tap()
                    detailPahar = PaharSelection(p: tapped)
                }
                // Square FIRST, then cap: capping the width before the aspect ratio let the
                // GeometryReader-backed dial claim a full-width-tall slot on iPad (a small dial
                // floating in ~700 pt of empty space).
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 420)                 // iPad/landscape: never taller than a screen
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Space.xl)
                .accessibilityHidden(true)   // decorative — the list below is the a11y path
                paharList(clock: clock, current: p)
                seasonalSection(clock: clock)
                footer
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: 760)                     // iPad: a centred column, not edge-to-edge
            .frame(maxWidth: .infinity)
        }
        .background(Ink.canvas)
        .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
    }

    /// The hero card: an accent ember wash over the card surface (content stays on the
    /// AA-checked surface — the gradient is a glow, never a text background).
    private func nowCard(clock: TimingClock, pahar p: Int, boundary: Pahar.Boundary, solarLive: Bool) -> some View {
        nowCardContent(clock: clock, pahar: p, boundary: boundary, solarLive: solarLive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.l)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Ink.card)
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(LinearGradient(colors: [palette.accent.opacity(0.16), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
    }

    private func nowCardContent(clock: TimingClock, pahar p: Int, boundary: Pahar.Boundary, solarLive: Bool) -> some View {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("What raag is it now?").font(.headline)
                    Spacer()
                    Picker("Clock mode", selection: $mode) {
                        Text("Fixed").tag("fixed"); Text("Solar").tag("solar")
                    }
                    .pickerStyle(.segmented).fixedSize()   // no fixed width — survives AX type sizes
                    .accessibilityIdentifier("clockModePicker")
                }
                Text("\(Pahar.label(p))  ·  \(windowText(p))")
                    .font(.title3.weight(.semibold))
                if let unknownRaagNote {
                    Text(unknownRaagNote).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("unknownRaagNote")
                }
                let raags = clock.raags(forPahar: p)
                if raags.isEmpty {
                    Text(p == 7 ? "Deliberately silent — no raags are assigned to this watch."
                                : "No primary claims for this watch.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    FlowChips(raags: raags) { claim in
                        if let ang = claim.firstAng { container.router.openAng(ang) }
                    }
                }
                Text("next: \(Pahar.label(boundary.nextPahar)) in \(boundary.minutes / 60 > 0 ? "\(boundary.minutes / 60) h " : "")\(boundary.minutes % 60) min")
                    .font(.caption).foregroundStyle(.secondary)
                if mode == "solar" {
                    solarControls(live: solarLive)
                }
            }
    }

    @ViewBuilder private func solarControls(live: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if live {
                Text("Solar watches from your stored location (rounded ~1 km; never leaves this device).")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else if location?.coords == nil {
                HStack(spacing: Theme.Space.s) {
                    Button("Use my location") { location?.requestOnce() }
                        .buttonStyle(.bordered).font(.caption)
                    Button("Enter manually") { showManualLocation = true }
                        .buttonStyle(.bordered).font(.caption)
                }
                if location?.denied == true {
                    Text("Location denied — enter coordinates manually, or stay on the fixed clock.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("Polar day/night at this latitude — showing the fixed clock.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showManualLocation) {
            ManualLocationSheet { lat, lon in location?.setManually(lat: lat, lon: lon) }
                .presentationDetents([.medium])
        }
    }

    private func paharList(clock: TimingClock, current: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("The eight watches").font(.headline)
            ForEach(1...8, id: \.self) { p in
                Button { detailPahar = PaharSelection(p: p) } label: {
                    HStack {
                        Text("P\(p)").font(.caption.weight(.bold)).monospacedDigit()
                            .padding(6)
                            .background(Circle().fill(p == current ? Theme.accent.opacity(0.25) : Color(.tertiarySystemFill)))
                        VStack(alignment: .leading) {
                            Text(Pahar.label(p)).font(.subheadline.weight(p == current ? .semibold : .regular))
                            Text(windowText(p)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        let n = clock.raags(forPahar: p).count
                        Text(n == 0 ? (p == 7 ? "silent" : "—") : "\(n) raag\(n == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Pahar.label(p)), \(windowText(p)), \(clock.raags(forPahar: p).count) raags\(p == current ? ", current watch" : "")")
            }
        }
    }

    @ViewBuilder private func seasonalSection(clock: TimingClock) -> some View {
        if !clock.seasonal.isEmpty || !clock.ceremonial.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("In season · any time").font(.headline)
                ForEach(Array((clock.seasonal + clock.ceremonial).enumerated()), id: \.offset) { _, c in
                    ClaimRow(claim: c, showRaag: true) { ang in container.router.openAng(ang) }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Button { showDivergence = true } label: {
                Label("See every disagreement", systemImage: "arrow.triangle.branch")
                    .font(.subheadline)
            }
            .accessibilityIdentifier("divergenceLink")
            Text("Pahars were traditionally solar — four equal watches of daylight and four of night. "
                 + "The fixed-clock view anchors pahar 1 at 6 AM as a modern rendering. Every placement "
                 + "here is an attributed scholarly claim with its citation — where traditions disagree, "
                 + "both are kept.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

/// sheet(item:) target for a tapped pahar (never conform Int to Identifiable globally).
struct PaharSelection: Identifiable { let p: Int; var id: Int { p } }

/// The dial: 8 pahar arcs on a 24-hour circle (noon at top), day/night palette, current-pahar
/// glow, raag-count beads, deliberately-empty pahar 7, live now-hand. Decorative (a11y-hidden);
/// taps forward to the detail sheet.
struct RaagDial: View {
    let clock: TimingClock
    let currentPahar: Int
    let minutesNow: Int
    let sun: Pahar.SunTimes?
    var onTap: (Int) -> Void

    private func window(_ p: Int) -> Pahar.Window {
        if let s = sun, let sr = s.sunrise, let ss = s.sunset { return Pahar.solarWindow(p, sunrise: sr, sunset: ss) }
        return Pahar.window(p)
    }
    /// minutes → angle, noon at top, clockwise.
    private func angle(_ m: Int) -> Angle { .degrees(Double(m) / 1440 * 360 + 90) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outer = size / 2 - 8
            let inner = outer * 0.62
            ZStack {
                Canvas { ctx, _ in
                    for p in 1...8 {
                        let w = window(p)
                        let endMin = w.end <= w.start ? w.end + 1440 : w.end
                        let path = Path { path in
                            path.addArc(center: center, radius: outer,
                                        startAngle: angle(w.start), endAngle: angle(endMin),
                                        clockwise: false)
                            path.addArc(center: center, radius: inner,
                                        startAngle: angle(endMin), endAngle: angle(w.start),
                                        clockwise: true)
                            path.closeSubpath()
                        }
                        let day = p <= 4
                        var color = day ? Color(hue: 0.09, saturation: 0.55, brightness: 0.95)
                                        : Color(hue: 0.65, saturation: 0.45, brightness: 0.55)
                        if p == 7 { color = color.opacity(0.25) }        // deliberately silent
                        ctx.fill(path, with: .color(color.opacity(p == currentPahar ? 0.9 : 0.45)))
                        if p == currentPahar {
                            ctx.stroke(path, with: .color(Brand.primary), lineWidth: 3)
                        }
                        // raag-count beads along the arc's middle radius
                        let n = clock.raags(forPahar: p).count
                        if n > 0 {
                            let midR = (outer + inner) / 2
                            let span = Double(endMin - w.start)
                            for i in 0..<min(n, 8) {
                                let t = (Double(i) + 1) / (Double(min(n, 8)) + 1)
                                let m = Double(w.start) + span * t
                                let a = angle(Int(m)).radians
                                let pt = CGPoint(x: center.x + cos(a) * midR, y: center.y + sin(a) * midR)
                                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5)),
                                         with: .color(.white.opacity(0.9)))
                            }
                        }
                    }
                    // now-hand
                    let a = angle(minutesNow).radians
                    var hand = Path()
                    hand.move(to: center)
                    hand.addLine(to: CGPoint(x: center.x + cos(a) * (outer + 4), y: center.y + sin(a) * (outer + 4)))
                    ctx.stroke(hand, with: .color(Brand.primary), lineWidth: 2)
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                             with: .color(Brand.primary))
                }
                // labels
                Text("NOON").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    .position(x: center.x, y: center.y - outer - 0)
                    .offset(y: -6)
                Text("MIDNIGHT").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    .position(x: center.x, y: center.y + outer)
                    .offset(y: 8)
            }
            .contentShape(Circle())
            .onTapGesture { pt in
                // hit-test: angle → minutes → pahar (respect the active mode's windows)
                let dx = pt.x - center.x, dy = pt.y - center.y
                let r = sqrt(dx * dx + dy * dy)
                guard r >= inner * 0.8, r <= outer + 8 else { return }
                var deg = atan2(dy, dx) * 180 / .pi - 90       // undo the +90 noon-at-top offset
                deg = (deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
                let m = Int(deg / 360 * 1440)
                if let s = sun, let sr = s.sunrise, let ss = s.sunset {
                    onTap(Pahar.paharSolar(m, sunrise: sr, sunset: ss))
                } else {
                    onTap(Pahar.paharFromMinutes(m))
                }
            }
        }
    }
}

/// One pahar's raags in detail: every claim with type/confidence/tradition badges + citation.
struct PaharDetailSheet: View {
    let pahar: Int
    let clock: TimingClock
    let windowText: String
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let primary = clock.raags(forPahar: pahar)
                    let variants = clock.variant.filter { $0.pahar == pahar }
                    if primary.isEmpty && variants.isEmpty {
                        Text(pahar == 7 ? "Deliberately silent — the sources assign no raags to this watch; that absence is content, not a gap."
                                        : "No claims place a raag in this watch.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(Array((primary + variants).enumerated()), id: \.offset) { _, c in
                        ClaimRow(claim: c, showRaag: true) { ang in
                            dismiss()
                            container.router.openAng(ang)
                        }
                    }
                } header: {
                    Text("\(Pahar.label(pahar)) · \(windowText)")
                }
            }
            .navigationTitle("P\(pahar)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// A cited claim row: raag (gurmukhi + roman) + type/confidence/tradition badges + source.
struct ClaimRow: View {
    let claim: TimingClaim
    var showRaag = false
    var onOpenAng: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if showRaag, let name = claim.raagName {
                HStack(spacing: Theme.Space.s) {
                    GurmukhiText(verbatim: name, size: 18)
                    if let roman = claim.roman { Text(roman).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if let ang = claim.firstAng {
                        Button("Read →") { onOpenAng(ang) }.font(.caption).buttonStyle(.bordered)
                    }
                }
            }
            HStack(spacing: Theme.Space.xs) {
                Badge(text: claim.claimType, color: claim.claimType == "primary" ? Theme.accent : .secondary)
                Badge(text: claim.confidence, color: claim.confidence == "disputed" ? Ink.negative : Ink.positive)
                Badge(text: claim.tradition.replacingOccurrences(of: "_", with: " "), color: Ink.info)
            }
            if let season = claim.season { Text("Season: \(season)").font(.caption) }
            if let occasion = claim.occasion { Text("Occasion: \(occasion)").font(.caption) }
            if let notes = claim.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
            Text("Source: \(claim.sourceName)").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Space.xs)
    }
}

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, Theme.Space.s).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

/// Primary-claim raag chips for the now card.
struct FlowChips: View {
    let raags: [TimingClaim]
    var onTap: (TimingClaim) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.s) {
                ForEach(Array(raags.enumerated()), id: \.offset) { _, c in
                    Button { onTap(c) } label: {
                        VStack(spacing: 2) {
                            GurmukhiText(verbatim: c.raagName ?? "", size: 18)
                            if let roman = c.roman { Text(roman).font(.caption2).foregroundStyle(.secondary) }
                        }
                        .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.s)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.chip).fill(Ink.raised))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Ink.hairline))
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityLabel("Raag \(c.roman ?? c.raagName ?? ""), read from Ang \(String(c.firstAng ?? 0))")
                }
            }
        }
    }
}

/// Manual lat/lon entry — solar mode with location denied (offline guardrail: manual works).
struct ManualLocationSheet: View {
    var onSet: (Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var lat = ""
    @State private var lon = ""

    /// nil unless BOTH values parse AND are in range — the button stays disabled for lat 200
    /// instead of silently dropping it (SolarLocation.setManually guards the same range).
    private var parsed: (lat: Double, lon: Double)? {
        guard let la = Double(lat), let lo = Double(lon), abs(la) <= 90, abs(lo) <= 180 else { return nil }
        return (la, lo)
    }
    private var outOfRange: Bool {
        if let la = Double(lat), abs(la) > 90 { return true }
        if let lo = Double(lon), abs(lo) > 180 { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Latitude (e.g. 31.63)", text: $lat).keyboardType(.numbersAndPunctuation)
                    TextField("Longitude (e.g. 74.87)", text: $lon).keyboardType(.numbersAndPunctuation)
                } header: {
                    Text("Coordinates (stored on this device only)")
                } footer: {
                    if outOfRange {
                        Text("Latitude must be −90…90 and longitude −180…180.")
                            .foregroundStyle(Ink.negative)
                    }
                }
                Button("Use these coordinates") {
                    if let p = parsed { onSet(p.lat, p.lon); dismiss() }
                }
                .disabled(parsed == nil)
            }
            .navigationTitle("Solar location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
