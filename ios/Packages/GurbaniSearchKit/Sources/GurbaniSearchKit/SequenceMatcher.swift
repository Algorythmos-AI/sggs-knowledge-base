import Foundation

/// Byte-identical Swift port of CPython `difflib.SequenceMatcher(isjunk=None, autojunk=True)`
/// `.ratio()` — the LCS-based similarity (`2*M / (len(a)+len(b))`) that `webapp/verify.py`
/// scoring and the `blob_search` tier depend on. This is NOT Levenshtein.
///
/// Critical fidelity points (see CLAUDE.md / the SME review):
///  - Elements are compared as Unicode SCALARS (`[UInt32]`), never Swift `Character`
///    (grapheme clustering would merge a base + matra and corrupt the match count M).
///  - autojunk only fires when `len(b) >= 200` (popularity cutoff `len(b)/100 + 1`); `b` is the
///    DB line, so it can trigger on long canonical lines even with a short claim.
///  - `find_longest_match` keeps the EARLIEST maximal block (strict `>` on bestsize), and extends
///    the block over equal neighbours on both sides.
///
/// Pinned by `contract/golden_difflib.ndjson` (repr-exact ratios from the real Python function).
public struct SequenceMatcher {
    private let a: [UInt32]
    private let b: [UInt32]
    private var b2j: [UInt32: [Int]] = [:]
    private let autojunk: Bool

    public init(a: String, b: String, autojunk: Bool = true) {
        self.a = a.unicodeScalars.map { $0.value }
        self.b = b.unicodeScalars.map { $0.value }
        self.autojunk = autojunk
        chainB()
    }

    /// __chain_b: build b2j, then (isjunk is None) prune autojunk-popular elements when len(b) >= 200.
    private mutating func chainB() {
        b2j = [:]
        for (i, elt) in b.enumerated() {
            b2j[elt, default: []].append(i)
        }
        // isjunk == nil → no bjunk set.
        if autojunk && b.count >= 200 {
            let ntest = b.count / 100 + 1
            var popular: Set<UInt32> = []
            for (elt, idxs) in b2j where idxs.count > ntest {
                popular.insert(elt)
            }
            for elt in popular { b2j.removeValue(forKey: elt) }
        }
    }

    /// find_longest_match(alo, ahi, blo, bhi). With isjunk == nil the junk-extension loops are
    /// inert, so only the two equal-neighbour extensions run.
    private func findLongestMatch(_ alo: Int, _ ahi: Int, _ blo: Int, _ bhi: Int) -> (Int, Int, Int) {
        var besti = alo, bestj = blo, bestsize = 0
        var j2len: [Int: Int] = [:]
        var i = alo
        while i < ahi {
            var newj2len: [Int: Int] = [:]
            if let js = b2j[a[i]] {
                for j in js {
                    if j < blo { continue }
                    if j >= bhi { break }
                    let k = (j2len[j - 1] ?? 0) + 1
                    newj2len[j] = k
                    if k > bestsize {
                        besti = i - k + 1
                        bestj = j - k + 1
                        bestsize = k
                    }
                }
            }
            j2len = newj2len
            i += 1
        }
        while besti > alo && bestj > blo && a[besti - 1] == b[bestj - 1] {
            besti -= 1; bestj -= 1; bestsize += 1
        }
        while besti + bestsize < ahi && bestj + bestsize < bhi
            && a[besti + bestsize] == b[bestj + bestsize] {
            bestsize += 1
        }
        return (besti, bestj, bestsize)
    }

    /// get_matching_blocks: recursive-via-stack, sort, collapse adjacent, append sentinel.
    private func matchingBlocks() -> [(Int, Int, Int)] {
        let la = a.count, lb = b.count
        var queue: [(Int, Int, Int, Int)] = [(0, la, 0, lb)]
        var blocks: [(Int, Int, Int)] = []
        while let (alo, ahi, blo, bhi) = queue.popLast() {
            let (i, j, k) = findLongestMatch(alo, ahi, blo, bhi)
            if k > 0 {
                blocks.append((i, j, k))
                if alo < i && blo < j { queue.append((alo, i, blo, j)) }
                if i + k < ahi && j + k < bhi { queue.append((i + k, ahi, j + k, bhi)) }
            }
        }
        blocks.sort {
            if $0.0 != $1.0 { return $0.0 < $1.0 }
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.2 < $1.2
        }
        var i1 = 0, j1 = 0, k1 = 0
        var nonAdjacent: [(Int, Int, Int)] = []
        for (i2, j2, k2) in blocks {
            if i1 + k1 == i2 && j1 + k1 == j2 {
                k1 += k2
            } else {
                if k1 > 0 { nonAdjacent.append((i1, j1, k1)) }
                i1 = i2; j1 = j2; k1 = k2
            }
        }
        if k1 > 0 { nonAdjacent.append((i1, j1, k1)) }
        nonAdjacent.append((la, lb, 0))
        return nonAdjacent
    }

    /// ratio() = 2*M / (len(a)+len(b)); _calculate_ratio returns 1.0 when total length is 0.
    public func ratio() -> Double {
        let matches = matchingBlocks().reduce(0) { $0 + $1.2 }
        let length = a.count + b.count
        return length != 0 ? 2.0 * Double(matches) / Double(length) : 1.0
    }
}
