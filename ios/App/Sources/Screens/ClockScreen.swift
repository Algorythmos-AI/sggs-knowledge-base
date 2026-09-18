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
    @AppStorage(SharedDefaults.clockModeKey, store: SharedDefaults.suite) private var mode = SharedDefaults.defaultClockMode
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
        // Pushed from the Explore stack (or opened via sggs://clock) — no NavigationStack of
        // its own: a nested stack inside a pushed destination misbehaves.
        Group {
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

    /// True when the clock is pinned (UI tests): the hands show the pinned minute, seconds at
    /// 0, and nothing animates — deterministic screenshots, no idle-wait stalls.
    private var handsFrozen: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["SGGS_CLOCK_NOW"] != nil || env["SGGS_UITEST"] == "1"
        #else
        return false
        #endif
    }

    /// The stored solar location. DEBUG: `SGGS_CLOCK_NO_COORDS=1` makes a UI test see the
    /// no-location state regardless of what the simulator has stored; never ships in Release.
    private var coords: (lat: Double, lon: Double)? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SGGS_CLOCK_NO_COORDS"] == "1" { return nil }
        #endif
        return location?.coords
    }

    /// Usable sunrise/sunset (solar mode, stored coords, non-polar) — else nil → fixed clock.
    private var sun: (sunrise: Int, sunset: Int)? {
        guard mode == "solar", let coords = self.coords else { return nil }
        return PaharFormat.usableSun(PaharFormat.sunTimes(on: nowDate, lat: coords.lat, lon: coords.lon))
    }

    /// True when solar mode is on but unusable (polar day/night at this latitude).
    private var solarIsPolar: Bool {
        guard mode == "solar", let coords = self.coords else { return false }
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
                         sun: solar, handsFrozen: handsFrozen, epoch: clockEpoch) { tapped in
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
                readoutRow(pahar: p, boundary: boundary)
                currentRaagList(clock: clock, pahar: p)
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
                Text("next: \(Pahar.label(boundary.nextPahar)) \(PaharFormat.countdown(minutes: boundary.minutes))")
                    .font(.caption).foregroundStyle(.secondary)
                if mode == "solar" {
                    solarControls(live: solarLive)
                }
            }
    }

    /// Solar status. With no location yet this is the ONE-TAP CARD: location is never requested
    /// on its own — only from this explicit button (offline guardrail), or entered by hand.
    @ViewBuilder private func solarControls(live: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if live {
                Text("Solar watches from your stored location (rounded ~1 km; never leaves this device).")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else if coords == nil {
                Text("Sun-accurate watches need your location once. It is rounded to about 1 km, stored on this device, and never sent.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Space.s) { locationButtons }
                    VStack(alignment: .leading, spacing: Theme.Space.s) { locationButtons }
                }
                Text(location?.denied == true
                     ? "Location is off for Gurbani Soul — enter coordinates manually, or stay on the fixed clock."
                     : "Until then: showing the fixed clock (pahar 1 at 6 AM).")
                    .font(.caption2).foregroundStyle(.secondary)
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

    @ViewBuilder private var locationButtons: some View {
        Button { location?.requestOnce() } label: {
            Label("Use my location", systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.onAccent)
                .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.s)
                .background(Capsule().fill(palette.accentFill))
                .overlay(Capsule().strokeBorder(palette.accent, lineWidth: 1))   // brand: fill always bordered
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("useMyLocation")
        Button("Enter manually") { showManualLocation = true }
            .buttonStyle(.bordered).font(.subheadline)
            .accessibilityIdentifier("enterLocationManually")
    }

    // MARK: readout + the current watch's raags

    /// The digital local time and the watch, under the dial (the face itself stays clean).
    private func readoutRow(pahar p: Int, boundary: Pahar.Boundary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            Text(PaharFormat.time(nowDate, locale: locale))
                .font(Brand.heading(.title3, weight: 650)).monospacedDigit()
            Text("·").foregroundStyle(.secondary)
            Text(Pahar.label(p)).font(.subheadline.weight(.semibold))
        }
        .lineLimit(1).minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("It is \(PaharFormat.time(nowDate, locale: locale)). \(Pahar.label(p)). "
            + "Next watch, \(Pahar.label(boundary.nextPahar)), \(PaharFormat.countdownSpoken(minutes: boundary.minutes)).")
        .accessibilityIdentifier("clockNowReadout")
    }

    /// "Sung in this watch": the current pahar's primary raags as a readable list — full
    /// names, never clipped, each a one-tap way into the Granth at that raag's first Ang.
    private func currentRaagList(clock: TimingClock, pahar p: Int) -> some View {
        let raags = clock.raags(forPahar: p)
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sung in this watch").font(.headline)
                Spacer()
                if !raags.isEmpty {
                    Text("\(raags.count) raag\(raags.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 0) {
                if raags.isEmpty {
                    Text(p == 7 ? "Deliberately silent — no raags are assigned to this watch."
                                : "No primary claims for this watch.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Space.m)
                }
                ForEach(Array(raags.enumerated()), id: \.offset) { i, claim in
                    CurrentRaagRow(claim: claim) { ang in container.router.openAng(ang) }
                    if i < raags.count - 1 { Divider().overlay(Ink.hairline).padding(.leading, Theme.Space.m) }
                }
            }
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Ink.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
            Button { detailPahar = PaharSelection(p: p) } label: {
                Label("All claims and sources for this watch", systemImage: "text.book.closed")
                    .font(.footnote)
            }
            .accessibilityIdentifier("currentWatchSources")
        }
        .accessibilityIdentifier("currentRaagList")
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
                 + "Solar is the default; the fixed-clock view anchors pahar 1 at 6 AM as a modern rendering. The dial is a "
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
    /// Pinned clock / UI tests: hands at `now`, seconds 0, no animation.
    var handsFrozen = false
    /// Bumped on a system time-zone/clock change so the hands restart from the new clock.
    var epoch = 0
    var onTap: (Int) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    private var model: PaharDialModel {
        var beads: [Int: Int] = [:]
        for p in 1...8 { beads[p] = clock.raags(forPahar: p).count }
        if let s = sun {
            return .solar(sunrise: s.sunrise, sunset: s.sunset, current: currentPahar, minutesNow: minutesNow, beads: beads)
        }
        return .fixed(current: currentPahar, minutesNow: minutesNow, beads: beads)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let m = DialMetrics(size: size, center: center, style: .full)
            ZStack {
                PaharDialRenderer(model: model, style: .full, palette: palette,
                                  numerals: PaharFormat.dialNumerals(locale: locale), faceDate: now)
                hands
            }
            .accessibilityHidden(true)      // decorative: the readout row + lists carry the content
            .contentShape(Circle())
            .onTapGesture { pt in
                // hit-test: angle → minutes → pahar (respect the active mode's windows);
                // the face in the hollow is not a target
                guard let minute = m.minute(at: pt) else { return }
                if let s = sun {
                    onTap(Pahar.paharSolar(minute, sunrise: s.sunrise, sunset: s.sunset))
                } else {
                    onTap(Pahar.paharFromMinutes(minute))
                }
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }

    /// ONLY this layer animates. Smooth sweep at ≤30 fps while the dial is on screen and the app
    /// is active; one tick per second under Reduce Motion; frozen for pinned/test clocks.
    @ViewBuilder private var hands: some View {
        if handsFrozen {
            ClockHandsLayer(date: now, style: .full, palette: palette, showSeconds: false)
        } else if reduceMotion {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                ClockHandsLayer(date: Self.wholeSecond(ctx.date), style: .full, palette: palette)
            }
            .id(epoch)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !visible || scenePhase != .active)) { ctx in
                ClockHandsLayer(date: ctx.date, style: .full, palette: palette)
            }
            .id(epoch)
        }
    }

    private static func wholeSecond(_ d: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: d.timeIntervalSinceReferenceDate.rounded(.down))
    }
}

/// One row of "Sung in this watch": the raag's Gurmukhi name (verbatim, ink Sant Lipi) over its
/// roman form, and a way in. The whole row is a single button for VoiceOver and Switch Control.
struct CurrentRaagRow: View {
    let claim: TimingClaim
    var onOpenAng: (Int) -> Void

    var body: some View {
        Button {
            if let ang = claim.firstAng { Haptics.tap(); onOpenAng(ang) }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Theme.Space.m) { names; Spacer(minLength: Theme.Space.s); read }
                VStack(alignment: .leading, spacing: Theme.Space.xs) { names; read }
            }
            .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.s + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(claim.firstAng == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Raag \(claim.roman ?? claim.raagName ?? "")"
            + (claim.firstAng.map { ", read from Ang \(String($0))" } ?? ""))
        .accessibilityAddTraits(.isButton)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let name = claim.raagName { GurmukhiText(verbatim: name, size: 21) }
            if let roman = claim.roman { Text(roman).font(.caption).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var read: some View {
        if let ang = claim.firstAng {
            HStack(spacing: 4) {
                Text("Ang \(String(ang))").font(.caption.weight(.medium)).monospacedDigit()
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
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
