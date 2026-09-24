import Foundation

/// Byte-identical Swift port of `roman_norm` from `webapp/serve.py` (and its twin in
/// `pipeline/sggs_pipeline.py`). The phonetic fold applied to BOTH the indexed column and
/// the query — the query-time half MUST match the index-time fold or search silently breaks.
///
/// Pinned by `contract/golden_roman_norm.ndjson` (generated from the real Python function).
/// Any change here must keep that contract green. See docs/engineering/invariants.md (fidelity contract).
public enum RomanNorm {

    // Digraph collapse, applied in THIS EXACT ORDER (order is load-bearing: `chh` before `ch`).
    // Each maps to its first letter, except `f` -> `p` (which the later voicing pass turns to v).
    private static let digraphs: [(from: String, to: String)] = [
        ("sh", "s"), ("chh", "c"), ("ch", "c"), ("kh", "k"), ("gh", "g"), ("jh", "j"),
        ("th", "t"), ("dh", "d"), ("bh", "b"), ("ph", "p"), ("rh", "r"), ("f", "p"),
    ]

    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u"]

    /// Mirrors:
    ///   for w in s.lower().split():
    ///       w = w.replace('w','v').replace('z','j').replace('q','k').replace('x','k')
    ///       for dg in (...): w = w.replace(dg, dg[0] or 'p' for 'f')
    ///       w = w.replace('b','v').replace('k','g').replace('t','d').replace('p','v')
    ///       if w.startswith('y'): w = 'j' + w[1:]
    ///       w = w.replace('y','')
    ///       head = w[0] if w and w[0] in 'aeiou' else ''
    ///       body = collapse_doubles(strip_vowels(w))
    ///       out.append((head+body) if (head+body) else w)
    ///   return ' '.join(o for o in out if o)
    public static func fold(_ s: String) -> String {
        var out: [String] = []
        // Python str.split() with no args splits on runs of whitespace and drops empties.
        let words = s.lowercased().split(whereSeparator: { $0.isWhitespace })

        for wsub in words {
            var w = String(wsub)
            w = w.replacingOccurrences(of: "w", with: "v")
                 .replacingOccurrences(of: "z", with: "j")
                 .replacingOccurrences(of: "q", with: "k")
                 .replacingOccurrences(of: "x", with: "k")

            for (from, to) in digraphs {
                w = w.replacingOccurrences(of: from, with: to)
            }

            w = w.replacingOccurrences(of: "b", with: "v")
                 .replacingOccurrences(of: "k", with: "g")
                 .replacingOccurrences(of: "t", with: "d")
                 .replacingOccurrences(of: "p", with: "v")

            if w.hasPrefix("y") { w = "j" + String(w.dropFirst()) }
            w = w.replacingOccurrences(of: "y", with: "")

            let chars = Array(w)
            // head = first char iff it is a vowel
            let head: String
            if let first = chars.first, vowels.contains(first) {
                head = String(first)
            } else {
                head = ""
            }
            // body = strip all vowels, then collapse runs of identical consonants to one.
            // (Removing vowels first can make two same consonants adjacent — they then collapse.)
            var body = ""
            var prev: Character? = nil
            for c in chars where !vowels.contains(c) {
                if c != prev {
                    body.append(c)
                    prev = c
                }
            }

            let combined = head + body
            out.append(combined.isEmpty ? w : combined)
        }

        return out.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
