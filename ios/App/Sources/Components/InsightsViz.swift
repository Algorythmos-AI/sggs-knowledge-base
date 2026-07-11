import SwiftUI
import Charts
import GurbaniSearchKit

// MARK: - Deterministic force layout

/// Seeded spring-electric layout for the theme network. DETERMINISTIC by construction:
/// SplitMix64 PRNG with a fixed seed and a fixed iteration count, run to completion off-main
/// BEFORE first frame — under Reduce Motion there is no entry animation at all, and normal
/// mode gets a short fade, never a live simulation.
enum ForceLayout {
    struct SplitMix64 {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    }

    /// nodes: identifiers; edges: (i, j, weight). Returns unit-square positions [0,1]².
    static func layout(nodeCount: Int, edges: [(Int, Int, Double)],
                       iterations: Int = 250, seed: UInt64 = 42) -> [CGPoint] {
        guard nodeCount > 0 else { return [] }
        var rng = SplitMix64(seed: seed)
        var x = (0..<nodeCount).map { _ in rng.unit() }
        var y = (0..<nodeCount).map { _ in rng.unit() }
        let k = 1.0 / (Double(nodeCount).squareRoot())   // ideal spring length
        var temp = 0.12
        for _ in 0..<iterations {
            var dx = [Double](repeating: 0, count: nodeCount)
            var dy = [Double](repeating: 0, count: nodeCount)
            // repulsion (k²/d), O(n²) — fine for the 54-concept graph
            for i in 0..<nodeCount {
                for j in (i + 1)..<nodeCount {
                    var ddx = x[i] - x[j], ddy = y[i] - y[j]
                    var d2 = ddx * ddx + ddy * ddy
                    if d2 < 1e-8 { ddx = rng.unit() * 1e-3; ddy = rng.unit() * 1e-3; d2 = ddx * ddx + ddy * ddy }
                    let f = k * k / d2
                    dx[i] += ddx * f; dy[i] += ddy * f
                    dx[j] -= ddx * f; dy[j] -= ddy * f
                }
            }
            // attraction along edges (d²/k, weighted)
            for (i, j, w) in edges {
                let ddx = x[i] - x[j], ddy = y[i] - y[j]
                let d = max((ddx * ddx + ddy * ddy).squareRoot(), 1e-6)
                let f = d * d / k * min(w, 3) * 0.35
                let ux = ddx / d, uy = ddy / d
                dx[i] -= ux * f * 0.01; dy[i] -= uy * f * 0.01
                dx[j] += ux * f * 0.01; dy[j] += uy * f * 0.01
            }
            for i in 0..<nodeCount {
                let d = max((dx[i] * dx[i] + dy[i] * dy[i]).squareRoot(), 1e-9)
                let step = min(d, temp)
                x[i] = min(1, max(0, x[i] + dx[i] / d * step))
                y[i] = min(1, max(0, y[i] + dy[i] / d * step))
            }
            temp *= 0.985   // cooling
        }
        return zip(x, y).map { CGPoint(x: $0, y: $1) }
    }
}

// MARK: - Theme co-occurrence network

/// The theme network as a force graph (web parity: opens at min-PPMI 0.7; the slider reveals
/// more). "View as list" is the accessibility/keyboard path — same data, always available.
struct ThemeNetworkSection: View {
    @Environment(AppContainer.self) private var container
    @State private var edges: [ThemeEdge] = []
    @State private var minPPMI = 0.7
    @State private var asList = false
    @State private var graph: (names: [String], points: [CGPoint], links: [(Int, Int, Double)])?

    var body: some View {
        List {
            Section {
                Toggle("View as list", isOn: $asList).font(.caption)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Minimum PPMI: \(minPPMI, format: .number.precision(.fractionLength(2)))")
                        .font(.caption).foregroundStyle(.secondary)
                    Slider(value: $minPPMI, in: 0...1.4)
                        .accessibilityLabel("Minimum co-occurrence strength")
                }
            }
            // graph and list share the same filtered edges; the list is always present (a11y path)
            if !asList, let graph {
                Section {
                    NetworkCanvas(graph: graph)
                        .frame(height: 340)
                        .accessibilityHidden(true)
                } footer: {
                    Text("Themes that appear together within shabads more than chance (PPMI). Layout is deterministic — seeded and settled before display, no live simulation. Descriptive only.")
                }
            }
            Section(asList ? "Theme pairs" : "Strongest pairs") {
                ForEach(asList ? edges : Array(edges.prefix(12))) { e in
                    HStack {
                        Text("\(e.source.capitalized) + \(e.target.capitalized)").font(.subheadline)
                        Spacer()
                        Text("PPMI \(e.ppmi, format: .number.precision(.fractionLength(2))) · \(String(e.shabadCount))")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(e.source) and \(e.target): PPMI \(String(format: "%.2f", e.ppmi)), \(e.shabadCount) shabads")
                }
            }
        }
        .task(id: minPPMI) {
            guard let corpus = container.corpus else { return }
            let mp = minPPMI
            let loaded = (try? await corpus.themeNetwork(minPPMI: mp, limit: 1500)) ?? []
            if Task.isCancelled { return }
            edges = loaded
            // settle the layout OFF-main before first frame (deterministic seed)
            let names = Array(Set(loaded.flatMap { [$0.source, $0.target] })).sorted()
            let index = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) })
            let links = loaded.compactMap { e -> (Int, Int, Double)? in
                guard let i = index[e.source], let j = index[e.target] else { return nil }
                return (i, j, e.ppmi)
            }
            let pts = await Task.detached(priority: .userInitiated) {
                ForceLayout.layout(nodeCount: names.count, edges: links)
            }.value
            if Task.isCancelled { return }
            graph = (names, pts, links)
        }
    }
}

private struct NetworkCanvas: View {
    let graph: (names: [String], points: [CGPoint], links: [(Int, Int, Double)])
    var body: some View {
        Canvas { ctx, size in
            let pad: CGFloat = 26
            func at(_ p: CGPoint) -> CGPoint {
                CGPoint(x: pad + p.x * (size.width - 2 * pad), y: pad + p.y * (size.height - 2 * pad))
            }
            for (i, j, w) in graph.links {
                var path = Path()
                path.move(to: at(graph.points[i])); path.addLine(to: at(graph.points[j]))
                ctx.stroke(path, with: .color(Brand.gold.opacity(min(0.08 + w * 0.18, 0.5))), lineWidth: 0.7)
            }
            for (i, name) in graph.names.enumerated() {
                let pt = at(graph.points[i])
                let degree = graph.links.reduce(0) { $0 + (($1.0 == i || $1.1 == i) ? 1 : 0) }
                let r = CGFloat(3 + min(degree, 20) / 3)
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(Brand.saffron.opacity(0.85)))
                if degree >= 6 {
                    ctx.draw(Text(name).font(.system(size: 8)).foregroundStyle(.secondary),
                             at: CGPoint(x: pt.x, y: pt.y - r - 7))
                }
            }
        }
    }
}

// MARK: - Cross-contributor resonance (chord)

/// Whose lines land semantically nearest whose — relative to corpus share (lift). Arcs sized
/// by preserved lines; ribbons are the >= threshold edges. The list below is the a11y path.
struct ResonanceSection: View {
    @Environment(AppContainer.self) private var container
    @State private var graph: ResonanceGraph?

    var body: some View {
        List {
            if let graph, !graph.nodes.isEmpty {
                Section {
                    ChordCanvas(graph: graph)
                        .frame(height: 320)
                        .accessibilityHidden(true)
                } footer: {
                    Text("How often a voice's lines land semantically nearest another voice's, relative to corpus share (lift). Descriptive, never a ranking of scripture.")
                }
                Section("Strongest resonances") {
                    ForEach(Array(graph.edges.prefix(20).enumerated()), id: \.offset) { _, e in
                        HStack {
                            Text("\(InsightsScreen.shortAuthor(e.source)) → \(InsightsScreen.shortAuthor(e.target))")
                                .font(.subheadline)
                            Spacer()
                            Text("lift \(e.lift, format: .number.precision(.fractionLength(2)))")
                                .font(.caption).foregroundStyle(Theme.accent).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(e.source) resonates with \(e.target), lift \(String(format: "%.2f", e.lift)), \(e.edges) nearest-neighbour links")
                    }
                }
            } else if graph != nil {
                ContentUnavailableView("Resonance data not in this build", systemImage: "circle.hexagonpath")
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task {
            guard graph == nil, let corpus = container.corpus else { return }
            graph = await corpus.resonance()
        }
    }
}

private struct ChordCanvas: View {
    let graph: ResonanceGraph
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 34
            let total = Double(graph.nodes.reduce(0) { $0 + $1.nLines })
            guard total > 0 else { return }
            // arcs: angle share ∝ preserved lines; small gaps between
            var angles: [String: (mid: Double, start: Double, end: Double)] = [:]
            var cursor = -Double.pi / 2
            let gap = 0.02
            for n in graph.nodes {
                let span = (Double(n.nLines) / total) * (2 * .pi - gap * Double(graph.nodes.count))
                angles[n.author] = (cursor + span / 2, cursor, cursor + span)
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .radians(cursor),
                           endAngle: .radians(cursor + span), clockwise: false)
                ctx.stroke(arc, with: .color(Brand.saffron), lineWidth: 8)
                let labelPt = CGPoint(x: center.x + cos(cursor + span / 2) * (radius + 18),
                                      y: center.y + sin(cursor + span / 2) * (radius + 18))
                ctx.draw(Text(InsightsScreen.shortAuthor(n.author)).font(.system(size: 8))
                    .foregroundStyle(.secondary), at: labelPt)
                cursor += span + gap
            }
            // ribbons for the strongest edges (top 24 by lift)
            let maxLift = graph.edges.first?.lift ?? 1
            for e in graph.edges.prefix(24) {
                guard let a = angles[e.source], let b = angles[e.target] else { continue }
                let pa = CGPoint(x: center.x + cos(a.mid) * (radius - 6), y: center.y + sin(a.mid) * (radius - 6))
                let pb = CGPoint(x: center.x + cos(b.mid) * (radius - 6), y: center.y + sin(b.mid) * (radius - 6))
                var ribbon = Path()
                ribbon.move(to: pa)
                ribbon.addQuadCurve(to: pb, control: center)
                ctx.stroke(ribbon, with: .color(Brand.gold.opacity(0.15 + 0.5 * e.lift / max(maxLift, 0.01))),
                           lineWidth: 1 + CGFloat(e.lift / max(maxLift, 0.01)) * 2.5)
            }
        }
    }
}

// MARK: - Raag theme-progression (streamgraph)

/// Concept-tag density along a raag in reading order — Swift Charts stacked areas (accessible
/// via audio graph + the per-bin numbers are real data, not a rendering).
struct ProgressionSection: View {
    @Environment(AppContainer.self) private var container
    @State private var raag: String?
    @State private var progression: Progression?

    private struct Point: Identifiable {
        let id = UUID()
        let bin: Int
        let ang: Int
        let concept: String
        let count: Int
    }

    var body: some View {
        List {
            Section {
                if let meta = container.meta {
                    Picker("Raag", selection: Binding(get: { raag ?? meta.raags.first?.name ?? "" },
                                                      set: { raag = $0 })) {
                        ForEach(meta.raags) { r in
                            Text(r.roman?.capitalized ?? r.name).tag(r.name)
                        }
                    }
                    .accessibilityIdentifier("progressionRaagPicker")
                }
            }
            if let p = progression, p.bins > 0 {
                Section {
                    Chart(points(p)) { pt in
                        AreaMark(x: .value("Ang", pt.ang),
                                 y: .value("Verses", pt.count))
                            .foregroundStyle(by: .value("Theme", pt.concept))
                            .interpolationMethod(.monotone)
                    }
                    .chartXAxisLabel("Ang")
                    .frame(height: 260)
                    .accessibilityLabel("Theme density along \(p.roman.isEmpty ? p.raag : p.roman) in reading order")
                } footer: {
                    Text("Concept-tag density along the raag in reading order (\(String(p.nLines)) lines). Descriptive only.")
                }
            } else if progression != nil {
                Section { Text("No tagged lines in this raag.").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .task(id: raag) {
            guard let corpus = container.corpus else { return }
            if container.meta == nil { await container.loadMeta() }
            let name = raag ?? container.meta?.raags.first?.name
            guard let name else { return }
            let p = await corpus.progression(raag: name)
            if Task.isCancelled { return }   // fast picker flips must not chart a stale raag
            progression = p
        }
    }

    private func points(_ p: Progression) -> [Point] {
        var out: [Point] = []
        for concept in p.concepts {
            guard let series = p.series[concept] else { continue }
            for (b, count) in series.enumerated() where b < p.angAxis.count {
                out.append(Point(bin: b, ang: p.angAxis[b], concept: concept, count: count))
            }
        }
        return out
    }
}
