import SwiftUI
import GurbaniSearchKit

/// One registry row: ring, title, Gurmukhi title (ink), and a quiet meta line.
struct BaniRow: View {
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
