import SwiftUI
import WidgetKit
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
    @Environment(\.locale) private var locale
    /// "fixed" | "solar" — lives in the App-Group suite so the widgets mirror the choice.
    @AppStorage(SharedDefaults.clockModeKey, store: SharedDefaults.suite) private var mode = "fixed"
    @State private var clock: TimingClock?
    /// Lazily created in .task — a `@State = SolarLocation()` default would construct a fresh
    /// CLLocationManager (delegate wired, defaults read) on EVERY ClockScreen struct init,
    /// i.e. every RootView body re-evaluation (the documented @State-autoclosure anti-pattern).
    @State private var location: SolarLocation?
    @State private var detailPahar: PaharSelection?
    @State private var showDivergence = false
    @State private var unknownRaagNote: String?
    @State private var showManualLocation = false
    /// Bumped when the system time zone or clock changes so the face redraws immediately.
    @State private var clockEpoch = 0
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
                    // Ticks on the minute boundary so the digits flip with the status-bar clock.
                    TimelineView(.periodic(from: PaharFormat.nextMinuteBoundary(), by: 60)) { _ in
                        content(clock: clock)
                    }
                    .id(clockEpoch)
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
            #if DEBUG
            // XCUITest pins the mode (SGGS_CLOCK_MODE=fixed|solar) so a device's stored choice
            // can never change the strings a test asserts; never ships in Release.
            if let m = ProcessInfo.processInfo.environment["SGGS_CLOCK_MODE"], m == "fixed" || m == "solar" {
                mode = m
            }
            #endif
            if location == nil { location = SolarLocation() }
            guard clock == nil, let corpus = container.corpus else { return }
            clock = await corpus.timingClock()
            consumePendingRaag()
        }
        .onChange(of: container.router.pendingClockRaag) { _, _ in consumePendingRaag() }
        .onChange(of: mode) { _, _ in reloadWidgets() }
        .onChange(of: location?.coords?.lat) { _, _ in reloadWidgets() }
        .onChange(of: location?.coords?.lon) { _, _ in reloadWidgets() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in clockEpoch += 1 }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in clockEpoch += 1 }
    }

    // MARK: time plumbing

    /// The instant the face shows. In DEBUG, `SGGS_CLOCK_NOW=<minute-of-day>` pins it on
    /// today's date so the hand, the readout and the pinned UI-test strings all agree.
    private var nowDate: Date {
        #if DEBUG
        // test override (XCUITests run the Debug configuration; this hook never ships in Release)
        if let env = ProcessInfo.processInfo.environment["SGGS_CLOCK_NOW"], let m = Int(env),
           let pinned = PaharFormat.date(minuteOfDay: m, on: now()) {
            return pinned
        }
        #endif
        return now()
    }

    private var minutesNow: Int { PaharFormat.minutesOfDay(nowDate) }

    /// Usable sunrise/sunset (solar mode, stored coords, non-polar) — else nil → fixed clock.
    private var sun: (sunrise: Int, sunset: Int)? {
        guard mode == "solar", let coords = location?.coords else { return nil }
        return PaharFormat.usableSun(PaharFormat.sunTimes(on: nowDate, lat: coords.lat, lon: coords.lon))
    }

    /// True when solar mode is on but unusable (polar day/night at this latitude).
    private var solarIsPolar: Bool {
        guard mode == "solar", let coords = location?.coords else { return false }
        return PaharFormat.sunTimes(on: nowDate, lat: coords.lat, lon: coords.lon).polar
    }

    /// (currentPahar, usableSolar) — solar falls back to fixed at polar latitudes / no fix.
    private func currentPahar() -> (pahar: Int, solar: (sunrise: Int, sunset: Int)?) {
        if let s = sun { return (Pahar.paharSolar(minutesNow, sunrise: s.sunrise, sunset: s.sunset), s) }
        return (Pahar.paharFromMinutes(minutesNow), nil)
    }

    /// The window of a pahar on the reader's own clock (12/24-h, locale), fixed or solar.
    private func windowText(_ p: Int) -> String {
        let w = sun.map { Pahar.solarWindow(p, sunrise: $0.sunrise, sunset: $0.sunset) } ?? Pahar.window(p)
        return PaharFormat.window(w, on: nowDate, locale: locale)
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "RaagNow")
        #endif
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
        let boundary = solar.map { Pahar.nextBoundary(minutesNow, mode: "solar", sunrise: $0.sunrise, sunset: $0.sunset) }
            ?? Pahar.nextBoundary(minutesNow, mode: "fixed")

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                nowCard(clock: clock, pahar: p, boundary: boundary, solarLive: solar != nil)
                RaagDial(clock: clock, currentPahar: p, minutesNow: minutesNow, now: nowDate,
                         sun: solar, boundary: boundary) { tapped in
                    Haptics.tap()
                    detailPahar = PaharSelection(p: tapped)
                }
                // Square FIRST, then cap: capping the width before the aspect ratio let the
                // GeometryReader-backed dial claim a full-width-tall slot on iPad (a small dial
                // floating in ~700 pt of empty space).
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 420)                 // iPad/landscape: never taller than a screen
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Space.m)
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
                Text("next: \(Pahar.label(boundary.nextPahar)) \(PaharFormat.countdown(minutes: boundary.minutes))")
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
            } else if solarIsPolar {
                Text("Polar day/night at this latitude — showing the fixed clock.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Sunrise and sunset coincide at this location today — showing the fixed clock.")
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
                 + "The fixed-clock view anchors pahar 1 at 6 AM as a modern rendering. The dial is a "
                 + "24-hour face on your local clock: noon at the top, midnight at the bottom. Every placement "
                 + "here is an attributed scholarly claim with its citation — where traditions disagree, "
                 + "both are kept.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

/// sheet(item:) target for a tapped pahar (never conform Int to Identifiable globally).
struct PaharSelection: Identifiable { let p: Int; var id: Int { p } }

/// The dial: the shared 24-hour face (`PaharDialRenderer`) with the live LOCAL clock in its
/// hollow — the reader's own time, the current watch and the countdown to the next one — so
/// one glance answers "what time is it here, and which raags belong to it". The painted face
/// is decorative for accessibility; the hollow readout is a real element and the pahar LIST
/// below remains the full-content path. Taps on a wedge open that pahar's detail sheet.
struct RaagDial: View {
    let clock: TimingClock
    let currentPahar: Int
    let minutesNow: Int
    let now: Date
    let sun: (sunrise: Int, sunset: Int)?
    let boundary: Pahar.Boundary
    var onTap: (Int) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    private var model: PaharDialModel {
        var beads: [Int: Int] = [:]
        for p in 1...8 { beads[p] = clock.raags(forPahar: p).count }
        if let s = sun {
            return .solar(sunrise: s.sunrise, sunset: s.sunset, current: currentPahar, minutesNow: minutesNow, beads: beads)
        }
        return .fixed(current: currentPahar, minutesNow: minutesNow, beads: beads)
    }

    private var spoken: String {
        "It is \(PaharFormat.time(now, locale: locale)). \(Pahar.label(currentPahar)). "
        + "Next watch, \(Pahar.label(boundary.nextPahar)), \(PaharFormat.countdownSpoken(minutes: boundary.minutes))."
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let m = DialMetrics(size: size, center: center, style: .full)
            ZStack {
                PaharDialRenderer(model: model, style: .full, palette: palette,
                                  numerals: PaharFormat.dialNumerals(locale: locale))
                    .accessibilityHidden(true)
                readout(m)
                    .position(center)
            }
            .contentShape(Circle())
            .onTapGesture { pt in
                // hit-test: angle → minutes → pahar (respect the active mode's windows);
                // the hollow (readout) is not a target
                guard let minute = m.minute(at: pt) else { return }
                if let s = sun {
                    onTap(Pahar.paharSolar(minute, sunrise: s.sunrise, sunset: s.sunset))
                } else {
                    onTap(Pahar.paharFromMinutes(minute))
                }
            }
        }
    }

    /// The live readout on the analog face: the watch above the hub, the digital local time
    /// below it (the face's numerals + hands are painted by the renderer).
    private func readout(_ m: DialMetrics) -> some View {
        let r = m.faceRadius
        return ZStack {
            Text(Pahar.label(currentPahar))
                .font(.system(size: max(9, r * 0.11), weight: .semibold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: r * 0.9)
                .offset(y: -r * 0.42)
            Text(PaharFormat.time(now, locale: locale))
                .font(Brand.heading(.callout, weight: 650))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: r * 0.9)
                .offset(y: r * 0.42)
        }
        .foregroundStyle(.primary)
        .frame(width: r * 2, height: r * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("clockNowReadout")
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
