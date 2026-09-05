import SwiftUI
import GurbaniSearchKit

/// The Contributors: 30 voices across five centuries gathered into one Granth — the Gurus,
/// the Bhagats of the Bhakti and Sufi traditions, the court Bhatts, the Gursikh companions.
/// Native parity with the web /lineage: timeline (grouped by century, sized by preserved
/// Bani volume), kind filters, full profiles (life + stylometry + signature themes +
/// distinctive terms), and ⇄ compare two voices. A voice's size reflects how much of its
/// Bani is preserved here — NEVER its importance (stated on-screen, as on the web).
struct LineageScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.palette) private var palette
    @State private var contributors: [Contributor]?
    @State private var authorRows: [String: AuthorRow] = [:]   // author → nLines/firstAng/lastAng
    @State private var kindFilter: String = "all"
    @State private var groupMode = "time"                      // time | kind | volume (web parity)
    @State private var profile: Contributor?
    @State private var compareMode = false
    @State private var comparePicks: [Contributor] = []
    @State private var comparePair: ComparePair?

    struct ComparePair: Identifiable {
        let a: Contributor; let b: Contributor
        var id: String { "\(a.name)⇄\(b.name)" }
    }

    private static let kinds: [(id: String, label: String)] = [
        ("all", "All"), ("guru", "Gurus"), ("bhagat", "Bhagats"),
        ("bhatt", "Bhatts"), ("gursikh", "Gursikhs"),
    ]
    private static let groupModes: [(id: String, label: String)] = [
        ("time", "Timeline"), ("kind", "By tradition"), ("volume", "Most Bani"),
    ]
    /// Web KIND_DESC — the "By tradition" band titles.
    private static let kindBands: [(kind: String, title: String)] = [
        ("guru", "The Sikh Gurus"), ("bhagat", "Bhakti & Sufi saints"),
        ("bhatt", "Court bards (Bhatts)"), ("gursikh", "Gursikh companions"),
    ]

    var body: some View {
        Group {
            if let contributors {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        hero(contributors)
                        controls
                        ForEach(bands(contributors), id: \.title) { band in
                            bandView(band.title, band.members)
                        }
                    }
                    .padding(Theme.Space.l)
                    .appAnimation(Motion.gentle, value: groupMode)
                    .appAnimation(Motion.gentle, value: kindFilter)
                }
                .background(Ink.canvas)
                .contentMargins(.bottom, Theme.Space.xl, for: .scrollContent)
            } else {
                ContentUnavailableView("Contributor roster unavailable", systemImage: "person.2.slash")
            }
        }
        .navigationTitle("Lineage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    compareMode.toggle()
                    comparePicks = []
                } label: {
                    Label(compareMode ? "Cancel compare" : "Compare two voices",
                          systemImage: "arrow.left.arrow.right")
                }
                .accessibilityIdentifier("compareVoices")
            }
        }
        .sheet(item: $profile) { c in
            AuthorProfileSheet(contributor: c, nLines: authorRows[c.name]?.nLines ?? 0,
                               firstAng: authorRows[c.name]?.firstAng)
        }
        .sheet(item: $comparePair) { pair in
            CompareVoicesSheet(a: pair.a, b: pair.b)
        }
        .task {
            if contributors == nil { contributors = ContributorsStore.load() }
            if authorRows.isEmpty {
                if container.meta == nil { await container.loadMeta() }
                if let meta = container.meta {
                    authorRows = Dictionary(uniqueKeysWithValues: meta.authors.map { ($0.name, $0) })
                }
            }
        }
    }

    // MARK: hero — web .lin-hero parity

    private func hero(_ list: [Contributor]) -> some View {
        let years = list.map(\.timelineYear).filter { $0 != 9999 }
        let span = years.isEmpty ? "" :
            "\(String((years.min()! / 100) + 1))th–\(String((years.max()! / 100) + 1))th"
        let verses = authorRows.values.reduce(0) { $0 + $1.nLines }
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("THE CONTRIBUTORS")
                .font(.caption2.weight(.semibold)).kerning(1.2)
                .foregroundStyle(palette.accentText)
            // With the bundled roster this renders "30 voices · 12th–17th century" —
            // the exact header string testLineageAndVaars asserts.
            Text("\(String(list.count)) voices · \(span) century").font(.headline)
            Text("Five centuries of voices gathered into one Granth — the Gurus, the Bhagats of the Bhakti and Sufi traditions, the court Bhatts, and the Gursikh companions. Tap any voice for a full profile"
                 + (compareMode ? " — compare mode: pick two." : "; ⇄ compares two."))
                .font(.caption).foregroundStyle(.secondary)
            Text("Dates are historical approximations; a voice's bar reflects how much of its Bani is preserved here — never its importance.")
                .font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: Theme.Space.s) {
                StatTile(value: "\(String(list.count))", caption: "contributors")
                StatTile(value: verses.formatted(), caption: "verses preserved here")
                StatTile(value: span.isEmpty ? "—" : "\(span) c.", caption: "span of voices")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Ink.card)
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(LinearGradient(colors: [palette.accent.opacity(0.14), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
    }

    // MARK: controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(Self.kinds, id: \.id) { k in
                        let count = k.id == "all" ? (contributors?.count ?? 0)
                            : (contributors?.filter { $0.kind == k.id }.count ?? 0)
                        ModePill(title: "\(k.label) · \(count)",
                                 dot: k.id == "all" ? nil : Contributor.kindColor(k.id),
                                 isSelected: kindFilter == k.id) { kindFilter = k.id }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(Self.groupModes, id: \.id) { g in
                        ModePill(title: g.label, isSelected: groupMode == g.id) { groupMode = g.id }
                    }
                }
            }
        }
    }

    // MARK: bands (time / kind / volume)

    private func bands(_ list: [Contributor]) -> [(title: String, members: [Contributor])] {
        let filtered = list.filter { kindFilter == "all" || $0.kind == kindFilter }
        switch groupMode {
        case "kind":
            return Self.kindBands.compactMap { band in
                let members = filtered.filter { $0.kind == band.kind }
                    .sorted { $0.timelineYear != $1.timelineYear ? $0.timelineYear < $1.timelineYear : $0.name < $1.name }
                return members.isEmpty ? nil : (band.title, members)
            }
        case "volume":
            let sorted = filtered.sorted {
                let na = authorRows[$0.name]?.nLines ?? 0, nb = authorRows[$1.name]?.nLines ?? 0
                return na != nb ? na > nb : $0.name < $1.name
            }
            return sorted.isEmpty ? [] : [("Ordered by how much Bani is preserved here", sorted)]
        default:
            let sorted = filtered
                .sorted { $0.timelineYear != $1.timelineYear ? $0.timelineYear < $1.timelineYear : $0.name < $1.name }
            var groups: [(String, [Contributor])] = []
            for c in sorted {
                let label = c.timelineYear == 9999 ? "Undated"
                    : "\(String((c.timelineYear / 100) + 1))th century"
                if let i = groups.firstIndex(where: { $0.0 == label }) { groups[i].1.append(c) }
                else { groups.append((label, [c])) }
            }
            return groups.map { (title: $0.0, members: $0.1) }
        }
    }

    private func bandView(_ title: String, _ members: [Contributor]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(members.count) voice\(members.count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            LazyVStack(spacing: 0) {
                ForEach(Array(members.enumerated()), id: \.element.id) { i, c in
                    node(c, isFirst: i == 0, isLast: i == members.count - 1)
                }
            }
        }
    }

    // MARK: timeline node — year column · glowing rail · voice card

    private func node(_ c: Contributor, isFirst: Bool, isLast: Bool) -> some View {
        let row = authorRows[c.name]
        let n = row?.nLines ?? 0
        let maxN = max(authorRows.values.map(\.nLines).max() ?? 1, 1)
        let picked = comparePicks.contains(c)
        let k = c.kindColor
        return Button {
            if compareMode {
                if picked { comparePicks.removeAll { $0 == c } }
                else {
                    comparePicks.append(c)
                    if comparePicks.count == 2 {
                        comparePair = ComparePair(a: comparePicks[0], b: comparePicks[1])
                        compareMode = false
                        comparePicks = []
                    }
                }
            } else {
                profile = c
            }
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.s) {
                // year column
                Text(c.timelineYear == 9999 ? "—" : (c.circa ? "c. " : "") + String(c.timelineYear))
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(minWidth: 44, alignment: .trailing)   // grows with Dynamic Type
                    .padding(.top, Theme.Space.l + 2)
                // the rail: continuous line + a glowing kind-colored node dot
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle().fill(isFirst ? Color.clear : Ink.hairline).frame(width: 2)
                        Rectangle().fill(isLast ? Color.clear : Ink.hairline).frame(width: 2)
                    }
                    Circle().fill(k)
                        .frame(width: 9, height: 9)
                        .shadow(color: k.opacity(0.55), radius: 4)
                        .padding(.top, Theme.Space.l + 4)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(width: 12)
                // the voice card
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.Space.s) {
                        Text(c.medallion)
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(k.opacity(0.16)))
                            .overlay(Circle().strokeBorder(k.opacity(0.4)))
                            .foregroundStyle(k)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.roman).font(.subheadline.weight(.semibold))
                            Text(c.kindTag)
                                .font(.caption2.weight(.semibold)).kerning(0.5)
                                .foregroundStyle(k)
                        }
                        Spacer()
                        if compareMode {
                            Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(picked ? Theme.accent : .secondary)
                        }
                    }
                    Text("\(c.era) · \(c.region)").font(.caption).foregroundStyle(.secondary)
                    // sqrt-scaled so a 15-line voice stays visible beside a 5,000-line one
                    VolumeBar(color: k, fraction: sqrt(Double(n) / Double(maxN)))
                    Text(row.map { "\(String(n)) lines · Angs \(String($0.firstAng))–\(String($0.lastAng))" }
                         ?? "\(String(n)) lines")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(Theme.Space.m)
                .background(Ink.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Ink.hairline))
                .padding(.vertical, Theme.Space.xs)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(c.roman), \(c.kind), \(c.era), \(n) lines preserved")
        .accessibilityHint(compareMode ? "Selects for comparison" : "Opens the full profile")
    }
}

/// The animated Bani-volume bar: kind-color → gold gradient, sqrt-scaled fraction,
/// grows on appearance (Reduce-Motion-safe via appAnimation).
private struct VolumeBar: View {
    let color: Color
    let fraction: Double   // 0…1, already sqrt-scaled by the caller
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(colors: [color, AccentPalette.gold.accent],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: shown ? max(4, geo.size.width * CGFloat(fraction)) : 4, height: 4)
                .appAnimation(Motion.gentle, value: shown)
        }
        .frame(height: 4)
        .onAppear { shown = true }
        .accessibilityHidden(true)   // the "N lines" caption carries the value
    }
}

// MARK: shared kind identity (screen + sheets)

extension Contributor {
    var kindColor: Color { Self.kindColor(kind) }

    static func kindColor(_ kind: String) -> Color {
        switch kind {
        case "guru": return Theme.accent
        case "bhagat": return Ink.info
        case "bhatt": return Ink.special
        default: return AccentPalette.teal.accent   // gursikh — web parity teal
        }
    }

    /// Medallion text: M1–M10 for the Gurus (mahalla), else up to two initials with
    /// honorifics stripped (web lineage.ts `initials()` parity).
    var medallion: String {
        if kind == "guru", let seq { return "M\(seq)" }
        let honorifics: Set<String> = ["baba", "bhai", "bhagat", "guru", "sant"]
        let words = roman.split(separator: " ").map(String.init)
            .filter { !honorifics.contains($0.lowercased()) }
        let initials = words.prefix(2).compactMap { $0.first.map(String.init) }.joined()
        return initials.isEmpty ? String(roman.prefix(1)) : initials
    }

    /// "GURU · M5" / "BHAGAT" style tag.
    var kindTag: String {
        if kind == "guru", let seq { return "GURU · M\(seq)" }
        return kind.uppercased()
    }

    /// "c. 1173–1266" lifespan chip text; nil when nothing is known.
    var lifespan: String? {
        guard let born else { return died.map { "d. \(String($0))" } }
        let prefix = circa ? "c. " : ""
        return died.map { "\(prefix)\(String(born))–\(String($0))" } ?? "\(prefix)b. \(String(born))"
    }
}

/// One voice in full: life, stylometry, signature themes (lift), distinctive terms (z-score).
struct AuthorProfileSheet: View {
    let contributor: Contributor
    let nLines: Int
    /// First Ang of this voice's Bani (from meta.authors) — powers "Read their first composition".
    var firstAng: Int? = nil
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var profile: AuthorProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    HStack(spacing: Theme.Space.m) {
                        Text(contributor.medallion)
                            .font(.headline.weight(.bold))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(contributor.kindColor.opacity(0.16)))
                            .overlay(Circle().strokeBorder(contributor.kindColor.opacity(0.4)))
                            .foregroundStyle(contributor.kindColor)
                        VStack(alignment: .leading, spacing: 2) {
                            GurmukhiText(verbatim: contributor.name, size: 24)
                            Text(contributor.roman).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    // life chips: kind · lifespan · region · tradition
                    FlowChipsRow(chips: [contributor.kindTag.capitalized,
                                         contributor.lifespan,
                                         contributor.region,
                                         contributor.tradition].compactMap { $0 })
                    Text(contributor.blurb).font(.callout)
                    if let s = profile?.stylometry {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                  spacing: Theme.Space.s) {
                            StatTile(value: "\(String(s.nLines))", caption: "lines preserved")
                            StatTile(value: "\(String(s.nShabads))", caption: "compositions")
                            StatTile(value: "\(String(s.nRaags))", caption: "raags")
                            StatTile(value: String(format: "%.2f", s.mattr100), caption: "lexical diversity")
                            StatTile(value: String(format: "%.1f", s.avgWordsLine), caption: "words / line")
                            StatTile(value: String(format: "%.1f", s.avgLinesShabad), caption: "lines / shabad")
                        }
                        if !s.isReliable {
                            Text("Small sample — stylometry is indicative only.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if let themes = profile?.stylometry?.topThemes, !themes.isEmpty {
                        let maxLift = max(themes.map(\.lift).max() ?? 1, 0.001)
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            Text("Signature themes").font(.headline)
                            Text("Theme emphasis vs the corpus baseline (lift) — descriptive, never a ranking of scripture.")
                                .font(.caption2).foregroundStyle(.tertiary)
                            ForEach(themes) { t in
                                HStack(spacing: Theme.Space.s) {
                                    Text(t.concept).font(.subheadline)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                        .frame(minWidth: 90, alignment: .leading)
                                    // the web .ld-ttrack treatment: a lift/maxLift gradient track
                                    GeometryReader { geo in
                                        Capsule().fill(Ink.raised)
                                            .overlay(alignment: .leading) {
                                                Capsule()
                                                    .fill(LinearGradient(colors: [contributor.kindColor, AccentPalette.gold.accent],
                                                                         startPoint: .leading, endPoint: .trailing))
                                                    .frame(width: max(4, geo.size.width * CGFloat(t.lift / maxLift)))
                                            }
                                    }
                                    .frame(height: 6)
                                    Text(String(format: "%.1f×", t.lift)).font(.caption).monospacedDigit()
                                        .foregroundStyle(Theme.accent)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                        .frame(minWidth: 40, alignment: .trailing)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(t.concept), \(String(format: "%.1f", t.lift)) times the corpus baseline")
                            }
                        }
                    }
                    if let terms = profile?.distinctiveTerms, !terms.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            Text("Distinctive terms").font(.headline)
                            Text("Words this voice uses far more than the rest of the Granth (z-score).")
                                .font(.caption2).foregroundStyle(.tertiary)
                            FlowTermChips(terms: terms)
                        }
                    }
                    if let firstAng {
                        Button {
                            dismiss()
                            container.router.openAng(firstAng)
                        } label: {
                            Label("Read their first composition · Ang \(String(firstAng))",
                                  systemImage: "book")
                        }
                        .buttonStyle(.prominentPill)
                    }
                }
                .padding()
            }
            .navigationTitle("Voice in the Granth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task {
            guard profile == nil, let corpus = container.corpus else { return }
            profile = await corpus.authorProfile(contributor.name, full: false)
        }
    }
}

struct FlowTermChips: View {
    let terms: [DistinctiveTerm]
    var body: some View {
        // simple wrapping grid (2 columns is enough for 12 chips and stays a11y-simple)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: Theme.Space.s) {
            ForEach(terms) { t in
                Text(t.term)
                    .font(.caption)
                    .padding(.horizontal, Theme.Space.s).padding(.vertical, 4)
                    .background(Capsule().fill(Ink.raised))
                    .overlay(Capsule().strokeBorder(Ink.hairline))
                    .accessibilityLabel("\(t.term), z-score \(String(format: "%.1f", t.zScore))")
            }
        }
    }
}

/// Small capsule chips for the profile's life facts (kind · lifespan · region · tradition).
struct FlowChipsRow: View {
    let chips: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], alignment: .leading, spacing: Theme.Space.xs) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.caption2)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.horizontal, Theme.Space.s).padding(.vertical, 4)
                    .background(Capsule().fill(Ink.raised))
                    .overlay(Capsule().strokeBorder(Ink.hairline))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// ⇄ Compare two voices: radar overlay of their 12-axis theme fingerprints + stat columns.
struct CompareVoicesSheet: View {
    let a: Contributor
    let b: Contributor
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var pa: AuthorProfile?
    @State private var pb: AuthorProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    HStack {
                        legendDot(Theme.accent, a.roman)
                        Spacer()
                        legendDot(Ink.info, b.roman)
                    }
                    if let pa, let pb {
                        RadarCompareView(a: pa, b: pb, colorA: Theme.accent, colorB: Ink.info)
                            .frame(height: 280)
                            .accessibilityHidden(true)   // the table below is the a11y path
                        radarTable(pa, pb)
                        statColumns(pa, pb)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    Text("Theme emphasis = lift vs the corpus baseline; stylometry on the English translation. Descriptive only — never a ranking of scripture.")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding()
            }
            .navigationTitle("\(a.roman) ⇄ \(b.roman)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task {
            guard pa == nil, let corpus = container.corpus else { return }
            pa = await corpus.authorProfile(a.name, full: false)
            pb = await corpus.authorProfile(b.name, full: false)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption.weight(.medium))
        }
    }

    /// Accessible/table alternative for the radar (also the exact numbers).
    private func radarTable(_ pa: AuthorProfile, _ pb: AuthorProfile) -> some View {
        let axes = RadarCompareView.axes(pa, pb)
        return VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Theme emphasis (lift)").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.xs) {
                GridRow {
                    Text("Theme").font(.caption.weight(.semibold))
                    Text(a.roman).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text(b.roman).font(.caption.weight(.semibold)).foregroundStyle(Ink.info)
                }
                ForEach(axes, id: \.self) { axis in
                    GridRow {
                        Text(axis).font(.caption)
                        Text(String(format: "%.2f", RadarCompareView.lift(pa, axis))).font(.caption).monospacedDigit()
                        Text(String(format: "%.2f", RadarCompareView.lift(pb, axis))).font(.caption).monospacedDigit()
                    }
                }
            }
        }
    }

    private func statColumns(_ pa: AuthorProfile, _ pb: AuthorProfile) -> some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.xs) {
            GridRow {
                Text("").font(.caption)
                Text(a.roman).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(b.roman).font(.caption.weight(.semibold)).foregroundStyle(Ink.info)
            }
            statRow("Lines", pa.stylometry?.nLines, pb.stylometry?.nLines)
            statRow("Compositions", pa.stylometry?.nShabads, pb.stylometry?.nShabads)
            statRow("Raags", pa.stylometry?.nRaags, pb.stylometry?.nRaags)
            GridRow {
                Text("Lexical diversity").font(.caption)
                Text(String(format: "%.3f", pa.stylometry?.mattr100 ?? 0)).font(.caption).monospacedDigit()
                Text(String(format: "%.3f", pb.stylometry?.mattr100 ?? 0)).font(.caption).monospacedDigit()
            }
        }
    }

    private func statRow(_ label: String, _ va: Int?, _ vb: Int?) -> some View {
        GridRow {
            Text(label).font(.caption)
            Text(String(va ?? 0)).font(.caption).monospacedDigit()
            Text(String(vb ?? 0)).font(.caption).monospacedDigit()
        }
    }
}

/// Canvas polar radar: the union of both authors' top themes as axes, lift as radius.
/// Decorative — CompareVoicesSheet renders the numbers as a Grid for accessibility.
struct RadarCompareView: View {
    let a: AuthorProfile
    let b: AuthorProfile
    let colorA: Color
    let colorB: Color

    /// Up to 12 shared axes: union of both fingerprints ranked by combined lift.
    static func axes(_ a: AuthorProfile, _ b: AuthorProfile) -> [String] {
        var combined: [String: Double] = [:]
        for ax in a.fingerprint { combined[ax.concept, default: 0] += ax.lift }
        for ax in b.fingerprint { combined[ax.concept, default: 0] += ax.lift }
        return combined.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(12).map { $0.key }
    }

    static func lift(_ p: AuthorProfile, _ concept: String) -> Double {
        p.fingerprint.first { $0.concept == concept }?.lift ?? 0
    }

    var body: some View {
        Canvas { ctx, size in
            let axes = Self.axes(a, b)
            guard axes.count >= 3 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 36
            let maxLift = max(axes.map { max(Self.lift(a, $0), Self.lift(b, $0)) }.max() ?? 1, 0.001)

            func point(_ i: Int, _ value: Double) -> CGPoint {
                let angle = -Double.pi / 2 + 2 * .pi * Double(i) / Double(axes.count)
                let r = radius * CGFloat(value / maxLift)
                return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            }
            // rings + spokes
            for ring in [0.25, 0.5, 0.75, 1.0] {
                var path = Path()
                for i in 0...axes.count {
                    let pt = point(i % axes.count, maxLift * ring)
                    i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                }
                ctx.stroke(path, with: .color(.secondary.opacity(0.2)), lineWidth: 0.5)
            }
            for (i, axis) in axes.enumerated() {
                var spoke = Path(); spoke.move(to: center); spoke.addLine(to: point(i, maxLift))
                ctx.stroke(spoke, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
                let labelPt = point(i, maxLift * 1.16)
                ctx.draw(Text(axis).font(.system(size: 8)).foregroundStyle(.secondary), at: labelPt)
            }
            // polygons
            for (profile, color) in [(a, colorA), (b, colorB)] {
                var poly = Path()
                for (i, axis) in axes.enumerated() {
                    let pt = point(i, Self.lift(profile, axis))
                    i == 0 ? poly.move(to: pt) : poly.addLine(to: pt)
                }
                poly.closeSubpath()
                ctx.fill(poly, with: .color(color.opacity(0.18)))
                ctx.stroke(poly, with: .color(color), lineWidth: 1.5)
            }
        }
    }
}
