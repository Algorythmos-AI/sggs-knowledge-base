import Foundation
import GurbaniSearchKit

/// Reading steps for the bani reader's bottom bar.
///
/// A long composition's printed rhythm is its pauris / ashtapadis, not the `line_group`s the
/// registry stores: Sukhmani Sahib has three groups (the ਗੁਰਦੇਵ ਮਾਤਾ salok, the whole body, the
/// salok again), so "Part 1 of 3" would offer a 2,027-line "part". When the verbatim markers give
/// a trustworthy outline, step by that instead; otherwise the printed groups still apply
/// (Rehras Sahib, Aarti). Pure logic so it can be tested without a view.
enum BaniPager {

    /// The sections that make sensible reading steps: numbered pauris/ashtapadis, and only when
    /// there is more than one (a single section is not a rhythm — the bar keeps top/end).
    static func steps(in outline: [BaniSection]) -> [BaniSection] {
        let steps = outline.filter { $0.kind == .pauri || $0.kind == .ashtapadi }
        return steps.count > 1 ? steps : []
    }

    /// The index of the step a `seq` sits in — the last step that has started.
    static func index(of seq: Int, in steps: [BaniSection]) -> Int? {
        guard !steps.isEmpty else { return nil }
        if let i = steps.lastIndex(where: { $0.startSeq <= seq }) { return i }
        return 0        // before the first step (a heading run) reads as "in the first"
    }

    /// The `seq` to jump to one step back (-1) or forward (+1), or nil at the ends.
    static func neighbour(of seq: Int, in steps: [BaniSection], direction: Int) -> Int? {
        guard let i = index(of: seq, in: steps) else { return nil }
        // Stepping back from inside a step returns to its own start first, which is what a
        // reader means by "previous" when they are halfway through a pauri.
        if direction < 0, steps[i].startSeq < seq { return steps[i].startSeq }
        let target = i + (direction < 0 ? -1 : 1)
        guard steps.indices.contains(target) else { return nil }
        return steps[target].startSeq
    }

    /// Whether a step exists in that direction from `seq`.
    static func canStep(from seq: Int, in steps: [BaniSection], direction: Int) -> Bool {
        neighbour(of: seq, in: steps, direction: direction) != nil
    }
}
