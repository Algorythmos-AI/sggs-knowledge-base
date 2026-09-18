import SwiftUI
import GurbaniSearchKit

/// The daily home: what to read now, how far along the day is, and every bani in the Gutka.
/// A time-of-day paper hero (a faint gold glow, the day drawn as an arc), rings for the focus
/// banis, one gold action; the wall clock only ORDERS the list — nothing is hidden.
struct NitnemScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(NitnemPrefs.rehrasVariantKey) private var rehrasVariant = NitnemPrefs.rehrasDefault
    @State private var list: BaniList?
    @State private var failed = false
    /// Injectable for tests; the single clock honours `SGGS_CLOCK_NOW`.
    var now: () -> Date = { NitnemClock.now() }

    var body: some View {
        @Bindable var router = container.router
        NavigationStack(path: $router.nitnemPath) {
            Group {
                if container.corpus?.capabilities.hasBanis != true {
                    ContentUnavailableView("Nitnem not in this build", systemImage: "sun.horizon",
                                           description: Text("This database profile doesn't carry the bani registry."))
                } else if let list {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        content(list.banis, at: now())
                    }
                } else if failed {
                    EmptyStateView(title: "Nitnem could not load", message: "Reinstalling the app restores the bundled corpus.", isError: true,
                                   actionTitle: "Try again") { Task { await load() } }
                } else {
                    NitnemSkeleton()
                }
            }
            .background(Ink.canvas.ignoresSafeArea())
            .navigationTitle("Nitnem")
            .navigationDestination(for: Route.self) { route in RouteDestination(route: route) }
        }
        .task { await load() }
    }

    private func load() async {
        guard list == nil, let corpus = container.corpus else { return }
        let l = await corpus.banis()
        if l.available { list = l } else { failed = true }
    }

    // MARK: layout

    private func visible(_ banis: [BaniSummary]) -> [BaniSummary] {
        banis.filter { b in
            b.key == "rehras" ? b.variant == NitnemPrefs.variant(for: "rehras", rehras: rehrasVariant) : b.isDefault
        }
    }

    @ViewBuilder
    private func content(_ banis: [BaniSummary], at date: Date) -> some View {
        let band = NitnemSchedule.band(at: date)
        let rows = visible(banis)
        let focus = rows.filter { $0.category == band.focus }
        let next = focus.first { !container.nitnem.isCompleted($0.id, on: date) }
        ScrollView {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    VStack(spacing: Theme.Space.l) {
                        hero(band: band, date: date, focus: focus, next: next)
                        hukamCard
                        journeyCard
                    }
                    .frame(width: 400)
                    VStack(spacing: Theme.Space.l) { sections(band: band, rows: rows, date: date) }
                        .frame(maxWidth: .infinity)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: 1100).frame(maxWidth: .infinity)
            } else {
                VStack(spacing: Theme.Space.l) {
                    hero(band: band, date: date, focus: focus, next: next)
                    hukamCard
                    journeyCard
                    sections(band: band, rows: rows, date: date)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }
        .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
    }

    @ViewBuilder
    private func sections(band: NitnemBand, rows: [BaniSummary], date: Date) -> some View {
        ForEach(band.order, id: \.self) { cat in
            section(cat: cat, rows: rows.filter { $0.category == cat }, date: date)
        }
        section(cat: .popular, rows: rows.filter { $0.category == .popular }, date: date)
        section(cat: .ceremony, rows: rows.filter { $0.category == .ceremony }, date: date)
        Text("Sri Guru Granth Sahib Ji lines are shown verbatim from the verified corpus and cited by Ang. \(NitnemReview.extraLayerLabel)")
            .font(.caption2).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: hero

    @ViewBuilder
    private func hero(band: NitnemBand, date: Date, focus: [BaniSummary], next: BaniSummary?) -> some View {
        let arc = DayArcModel(date: date)
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                SectionEyebrow(text: date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                Text(band.title).font(Brand.heading(.title2))
                Text(band.caption).font(.subheadline).foregroundStyle(.secondary)
            }
            DayArc(model: arc).padding(.vertical, Theme.Space.xs)
            if !focus.isEmpty {
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    ForEach(focus) { b in
                        let done = container.nitnem.isCompleted(b.id, on: date)
                        let frac = container.nitnem.fraction(for: b.id, total: b.nLines, on: date)
                        VStack(spacing: Theme.Space.xs) {
                            ProgressRing(fraction: frac, done: done).frame(width: 44, height: 44)
                            Text(shortTitle(b)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(b.titleEn), \(done ? "complete today" : "\(Int(frac * 100)) percent")")
                    }
                    Spacer(minLength: 0)
                }
            }
            HStack {
                if let next {
                    Button {
                        Haptics.tap()
                        container.router.nitnemPath.append(Route.bani(next.key))
                    } label: {
                        Label(continueTitle(next), systemImage: "book")
                    }
                    .buttonStyle(.prominentPill)
                    .accessibilityIdentifier("nitnemContinue")
                } else if !focus.isEmpty {
                    Label("\(band.title) complete", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(palette.accentText)
                        .accessibilityIdentifier("nitnemDone")
                }
                Spacer()
                let streak = container.nitnem.streak(for: focus.map(\.id), on: date)
                if streak >= 2 {
                    Text("\(streak) days").font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel("\(streak) days in a row")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background {
            PaperGround(palette: palette, intensity: 0.10, center: band.glowCenter)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
    }

    private func shortTitle(_ b: BaniSummary) -> String {
        switch b.key {
        case "japji": return "Japji"
        case "jaap": return "Jaap"
        case "savaiye": return "Savaiye"
        case "chaupai": return "Chaupai"
        case "anand": return "Anand"
        case "rehras": return "Rehras"
        case "sohila": return "Sohila"
        default: return b.titleEn
        }
    }

    private func continueTitle(_ b: BaniSummary) -> String {
        let p = container.nitnem.progress(for: b.id)
        return (p?.lastSeq ?? 0) > 1 ? "Continue \(b.titleEn)" : "Read \(b.titleEn)"
    }

    private var hukamCard: some View {
        Button { Haptics.tap(); container.present(.hukam) } label: {
            Card {
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: "sparkles").font(.title2).foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hukam").font(.headline).foregroundStyle(.primary)
                        Text("A complete Hukam unit, read verbatim").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.pressableCard)
        .accessibilityIdentifier("Hukam")
    }

    private var journeyCard: some View {
        NavigationLink(value: Route.nitnemJourney) {
            Card {
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: "calendar").font(.title2).foregroundStyle(palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reading journey").font(.headline).foregroundStyle(.primary)
                        Text("The days you have read, month by month").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.pressableCard)
        .accessibilityIdentifier("nitnemJourney")
    }

    // MARK: sections

    @ViewBuilder
    private func section(cat: BaniCategory, rows: [BaniSummary], date: Date) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionEyebrow(text: cat.sectionTitle, symbol: cat.symbol)
                    .padding(.horizontal, Theme.Space.xs)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, b in
                        NavigationLink(value: Route.bani(b.key)) { BaniRow(bani: b, date: date) }
                            .buttonStyle(.pressableCard)
                            .accessibilityIdentifier("bani_\(b.key)")
                        if i < rows.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
            }
        }
    }
}

extension BaniCategory {
    var sectionTitle: String {
        switch self {
        case .nitnemMorning: return "Morning"
        case .nitnemEvening: return "Evening"
        case .nitnemNight: return "Night"
        case .popular: return "Popular"
        case .ceremony: return "Ceremony"
        }
    }
    var symbol: String {
        switch self {
        case .nitnemMorning: return "sunrise"
        case .nitnemEvening: return "sunset"
        case .nitnemNight: return "moon.stars"
        case .popular: return "text.book.closed"
        case .ceremony: return "seal"
        }
    }
}

/// One registry row: ring, title, Gurmukhi title (ink), and a quiet meta line.
private struct BaniRow: View {
    let bani: BaniSummary
    let date: Date
    @Environment(AppContainer.self) private var container

    var body: some View {
        let done = container.nitnem.isCompleted(bani.id, on: date)
        let frac = container.nitnem.fraction(for: bani.id, total: bani.nLines, on: date)
        HStack(spacing: Theme.Space.m) {
            ProgressRing(fraction: frac, done: done).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(bani.titleEn).font(.body.weight(.medium)).foregroundStyle(.primary)
                GurmukhiText(verbatim: bani.titleGm, size: 16)
                Text(meta(done: done, frac: frac)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bani.titleEn). \(meta(done: done, frac: frac))")
    }

    private func meta(done: Bool, frac: Double) -> String {
        var parts: [String] = []
        if let m = bani.estimatedMinutes { parts.append("about \(m) min") }
        if bani.hasExtra { parts.append("includes Sri Dasam Granth text") }
        if done {
            parts.append("read today")
        } else if frac > 0 {
            parts.append("\(Int(frac * 100))% read")
        } else if let last = container.nitnem.progress(for: bani.id)?.lastReadAt {
            parts.append("last read \(Self.relative.localizedString(for: last, relativeTo: date))")
        }
        return parts.joined(separator: " · ")
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .full; return f
    }()
}

/// A thin accent ring: today's completion fills it; the position arc is the read fraction.
struct ProgressRing: View {
    let fraction: Double
    let done: Bool
    @Environment(\.palette) private var palette
    var body: some View {
        ZStack {
            Circle().strokeBorder(Ink.hairline, lineWidth: 3)
            Circle()
                .trim(from: 0, to: done ? 1 : CGFloat(fraction))
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.5)
            if done {
                Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(palette.accent)
            }
        }
        .appAnimation(Motion.gentle, value: fraction)
        .accessibilityHidden(true)
    }
}
