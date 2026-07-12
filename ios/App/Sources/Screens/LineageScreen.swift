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
    @State private var contributors: [Contributor]?
    @State private var volumes: [String: Int] = [:]     // author → n_lines (from the DB)
    @State private var kindFilter: String = "all"
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

    var body: some View {
        Group {
            if let contributors {
                let filtered = contributors
                    .filter { kindFilter == "all" || $0.kind == kindFilter }
                    .sorted { $0.timelineYear != $1.timelineYear ? $0.timelineYear < $1.timelineYear : $0.name < $1.name }
                List {
                    Section {
                        header(count: contributors.count)
                    }
                    ForEach(centuries(filtered), id: \.century) { group in
                        Section(group.century) {
                            ForEach(group.members) { c in
                                row(c)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
            AuthorProfileSheet(contributor: c, nLines: volumes[c.name] ?? 0)
        }
        .sheet(item: $comparePair) { pair in
            CompareVoicesSheet(a: pair.a, b: pair.b)
        }
        .task {
            if contributors == nil { contributors = ContributorsStore.load() }
            if volumes.isEmpty, let meta = container.meta {
                volumes = Dictionary(uniqueKeysWithValues: meta.authors.map { ($0.name, $0.nLines) })
            } else if volumes.isEmpty {
                await container.loadMeta()
                if let meta = container.meta {
                    volumes = Dictionary(uniqueKeysWithValues: meta.authors.map { ($0.name, $0.nLines) })
                }
            }
        }
    }

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("\(String(count)) voices · 12th–17th century").font(.headline)
            Text("Five centuries of voices gathered into one Granth. Tap any voice for a full profile"
                 + (compareMode ? " — compare mode: pick two." : "; ⇄ compares two."))
                .font(.caption).foregroundStyle(.secondary)
            Text("Dates are historical approximations; a voice's bar reflects how much of its Bani is preserved here — never its importance.")
                .font(.caption2).foregroundStyle(.tertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(Self.kinds, id: \.id) { k in
                        ModePill(title: k.label, isSelected: kindFilter == k.id) { kindFilter = k.id }
                    }
                }
            }
        }
    }

    private func row(_ c: Contributor) -> some View {
        let n = volumes[c.name] ?? 0
        let maxN = max(volumes.values.max() ?? 1, 1)
        let picked = comparePicks.contains(c)
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
            HStack(spacing: Theme.Space.m) {
                Text(String(c.roman.prefix(1)))
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(kindColor(c.kind).opacity(0.2)))
                    .foregroundStyle(kindColor(c.kind))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(c.roman).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(c.kind.uppercased()).font(.caption2.weight(.semibold))
                            .foregroundStyle(kindColor(c.kind))
                    }
                    Text("\(c.era) · \(c.region)").font(.caption).foregroundStyle(.secondary)
                    GeometryReader { geo in
                        Capsule().fill(kindColor(c.kind).opacity(0.5))
                            .frame(width: max(4, geo.size.width * CGFloat(n) / CGFloat(maxN)), height: 4)
                    }
                    .frame(height: 4)
                    Text("\(String(n)) lines").font(.caption2).foregroundStyle(.tertiary)
                }
                if compareMode {
                    Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(picked ? Theme.accent : .secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(c.roman), \(c.kind), \(c.era), \(n) lines preserved")
        .accessibilityHint(compareMode ? "Selects for comparison" : "Opens the full profile")
    }

    private func kindColor(_ kind: String) -> Color {
        switch kind {
        case "guru": return Theme.accent
        case "bhagat": return Ink.info
        case "bhatt": return Ink.special
        default: return Ink.positive
        }
    }

    private func centuries(_ list: [Contributor]) -> [(century: String, members: [Contributor])] {
        var groups: [(String, [Contributor])] = []
        for c in list {
            let label = c.timelineYear == 9999 ? "Undated"
                : "\(String((c.timelineYear / 100) + 1))th century"
            if let i = groups.firstIndex(where: { $0.0 == label }) { groups[i].1.append(c) }
            else { groups.append((label, [c])) }
        }
        return groups.map { (century: $0.0, members: $0.1) }
    }
}

/// One voice in full: life, stylometry, signature themes (lift), distinctive terms (z-score).
struct AuthorProfileSheet: View {
    let contributor: Contributor
    let nLines: Int
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var profile: AuthorProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        GurmukhiText(verbatim: contributor.name, size: 24)
                        Text("\(contributor.era) · \(contributor.region)").font(.subheadline).foregroundStyle(.secondary)
                        Text(contributor.tradition).font(.caption).foregroundStyle(.secondary)
                    }
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
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            Text("Signature themes").font(.headline)
                            Text("Theme emphasis vs the corpus baseline (lift) — descriptive, never a ranking of scripture.")
                                .font(.caption2).foregroundStyle(.tertiary)
                            ForEach(themes) { t in
                                HStack {
                                    Text(t.concept).font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.2f×", t.lift)).font(.caption).monospacedDigit()
                                        .foregroundStyle(Theme.accent)
                                }
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
                }
                .padding()
            }
            .navigationTitle(contributor.roman)
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
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                    .accessibilityLabel("\(t.term), z-score \(String(format: "%.1f", t.zScore))")
            }
        }
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
