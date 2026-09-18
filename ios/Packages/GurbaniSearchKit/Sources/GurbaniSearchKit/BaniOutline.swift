import Foundation

// MARK: - Bani outline (pauri / ashtapadi / salok numbering)
//
// A reading outline derived ONLY from the verbatim text a bani already carries: the
// `markers` array (bare Gurmukhi digits the scripture prints, e.g. ੧, or ੮ ੨੪ closing an
// ashtapadi), `isHeader`, and the trailing ॥N॥ of Sri Dasam Granth lines. Nothing here
// produces a Gurmukhi string, and numbers are shown only OUTSIDE the verse (a contents
// sheet, a caption, a margin label). Every strategy passes through a strict validity gate:
// if the parsed numbers are not the sequence they must be, the outline is `[]` — the app
// then hides Contents rather than ever showing a guessed number.

public enum BaniSectionKind: String, Sendable, Equatable {
    case salok, pauri, ashtapadi, chhant, verse, part

    /// How the contents row and the margin label name it.
    public var label: String {
        switch self {
        case .salok: return "Salok"
        case .pauri: return "Pauri"
        case .ashtapadi: return "Ashtapadi"
        case .chhant: return "Chhant"
        case .verse: return "Verse"
        case .part: return "Part"
        }
    }
}

/// One navigable section of a bani. `startSeq…endSeq` are `BaniLine.seq` values (the only
/// line identity the reader uses). `numberGm` is the verbatim printed digit(s); `number` is
/// its integer value for accessibility and ordering.
public struct BaniSection: Sendable, Equatable, Identifiable {
    public let kind: BaniSectionKind
    public let number: Int
    public let numberGm: String        // verbatim Gurmukhi digits, or "" for a salok/part with no printed number
    public let startSeq: Int
    public let endSeq: Int
    public let derivedFromText: Bool   // true = parsed from an extra-layer line's trailing ॥N॥
    public var id: Int { startSeq }

    public init(kind: BaniSectionKind, number: Int, numberGm: String,
                startSeq: Int, endSeq: Int, derivedFromText: Bool) {
        self.kind = kind; self.number = number; self.numberGm = numberGm
        self.startSeq = startSeq; self.endSeq = endSeq; self.derivedFromText = derivedFromText
    }

    /// "Pauri ੧੨ · 12" (or "Salok" / "Part 3" where there is no printed number).
    public var contentsLabel: String {
        if numberGm.isEmpty { return number > 0 ? "\(kind.label) \(number)" : kind.label }
        return "\(kind.label) \(numberGm) · \(number)"
    }

    /// The one-sentence VoiceOver label.
    public var accessibilityLabel: String {
        numberGm.isEmpty && number == 0 ? kind.label : "\(kind.label) \(number)"
    }
}

public enum BaniOutline {

    /// The navigable sections of a bani, or `[]` when none can be derived with certainty.
    public static func sections(for bani: Bani) -> [BaniSection] {
        let lines = bani.lines
        guard !lines.isEmpty else { return [] }
        let derived: [BaniSection]
        switch bani.summary.key {
        case "japji":
            derived = japji(lines)
        case "anand", "anand_short":
            derived = simplePauris(lines)
        case "sukhmani":
            derived = sukhmani(lines)
        case "asa_di_vaar":
            derived = asaDiVaar(lines)
        case "jaap", "chaupai", "savaiye", "savaiye_deenan", "shabad_hazare_p10":
            derived = extraVerses(lines)
        default:
            derived = []
        }
        if !derived.isEmpty { return derived }
        // Fallback: a multi-part bani (Rehras, Aarti) navigates by its printed line-groups.
        return bani.summary.nGroups > 1 ? parts(lines, count: bani.summary.nGroups) : []
    }

    /// The section a given `seq` sits in.
    public static func section(at seq: Int, in sections: [BaniSection]) -> BaniSection? {
        sections.last { $0.startSeq <= seq } ?? sections.first { seq <= $0.endSeq }
    }

    // MARK: number parsing (Gurmukhi digits only — U+0A66…0A6F)

    /// The integer value of a bare Gurmukhi-digit token, or nil if it holds any other scalar.
    public static func gurmukhiNumber(_ s: String) -> Int? {
        var value = 0
        var any = false
        for scalar in s.unicodeScalars {
            guard (0x0A66...0x0A6F).contains(scalar.value) else { return nil }
            value = value * 10 + Int(scalar.value - 0x0A66)
            any = true
        }
        return any ? value : nil
    }

    /// The trailing digit group(s) of an extra-layer line, read from the end. Sri Dasam Granth
    /// lines end `… ॥N॥` (Jaap) or `… ॥N॥M॥` (Savaiye, double numbering). Returns the
    /// verbatim digit tokens in printed order; the first is the local ordinal.
    public static func trailingNumbers(inExtraText text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        // Walk from the end; collect maximal runs of Gurmukhi digits that are fenced by dandas.
        let scalars = Array(text.unicodeScalars)
        var i = scalars.count - 1
        // skip trailing whitespace
        while i >= 0, scalars[i] == " " { i -= 1 }
        // must end on a danda to be a numbered line
        guard i >= 0, scalars[i].value == 0x0965 || scalars[i].value == 0x0964 else { return [] }
        while i >= 0 {
            let v = scalars[i].value
            if (0x0A66...0x0A6F).contains(v) {
                current.unicodeScalars.insert(scalars[i], at: current.unicodeScalars.startIndex)
                i -= 1
            } else if v == 0x0965 || v == 0x0964 {   // ॥ or ।
                if !current.isEmpty { tokens.insert(current, at: 0); current = "" }
                i -= 1
            } else {
                break
            }
        }
        return tokens
    }

    // MARK: strategies

    /// Japji Sahib: an opening salok, pauris ੧…੩੮, a closing salok. Every stanza closes on a
    /// single-marker line; the first and last such lines are saloks, the middle ones pauris
    /// whose printed marker must run 1…n.
    private static func japji(_ lines: [BaniLine]) -> [BaniSection] {
        let closers = lines.filter { $0.markers.count == 1 && gurmukhiNumber($0.markers[0]) != nil }
        guard closers.count >= 3 else { return [] }
        let middle = Array(closers.dropFirst().dropLast())
        // the middle markers must be exactly 1…count
        for (i, l) in middle.enumerated() where gurmukhiNumber(l.markers[0]) != i + 1 { return [] }
        var out: [BaniSection] = []
        var start = lines.first!.seq
        for (i, l) in closers.enumerated() {
            let isSalok = i == 0 || i == closers.count - 1
            out.append(BaniSection(kind: isSalok ? .salok : .pauri,
                                   number: isSalok ? 0 : i,
                                   numberGm: isSalok ? "" : l.markers[0],
                                   startSeq: start, endSeq: l.seq, derivedFromText: false))
            start = l.seq + 1
        }
        return out
    }

    /// Anand Sahib: every marked line closes a pauri numbered by its FIRST marker (1…n). The
    /// last pauri closes `॥੪੦॥੧॥` — two markers, the trailing one a composition count — so the
    /// pauri number is always `markers.first`, never the marker count.
    private static func simplePauris(_ lines: [BaniLine]) -> [BaniSection] {
        let closers = lines.compactMap { l -> (BaniLine, Int)? in
            guard let m = l.markers.first, let n = gurmukhiNumber(m) else { return nil }
            return (l, n)
        }
        guard closers.count >= 2 else { return [] }
        for (i, c) in closers.enumerated() where c.1 != i + 1 { return [] }
        var out: [BaniSection] = []
        var start = lines.first!.seq
        for (i, c) in closers.enumerated() {
            out.append(BaniSection(kind: .pauri, number: i + 1, numberGm: c.0.markers[0],
                                   startSeq: start, endSeq: c.0.seq, derivedFromText: false))
            start = c.0.seq + 1
        }
        return out
    }

    /// Sukhmani Sahib: 24 ashtapadis, each closed by a two-marker line `[੮, N]` and opened by
    /// its preceding salok. The section spans the salok through the ashtapadi so a jump lands
    /// on the salok that opens the reading.
    private static func sukhmani(_ lines: [BaniLine]) -> [BaniSection] {
        let closers = lines.enumerated().filter {
            $0.element.markers.count == 2 && gurmukhiNumber($0.element.markers[0]) == 8
        }
        guard closers.count >= 20 else { return [] }
        for (i, c) in closers.enumerated() where gurmukhiNumber(c.element.markers[1]) != i + 1 { return [] }
        var out: [BaniSection] = []
        var searchFrom = 0
        for (i, c) in closers.enumerated() {
            // start = the last ਸਲੋਕੁ header at or before this ashtapadi, after the previous one
            let salokIdx = lines[searchFrom...c.offset].lastIndex { $0.isHeader && $0.gurmukhi.hasPrefix("ਸਲੋਕੁ") }
            let startSeq = (salokIdx.map { lines[$0].seq }) ?? (out.last.map { $0.endSeq + 1 } ?? lines.first!.seq)
            out.append(BaniSection(kind: .ashtapadi, number: i + 1, numberGm: c.element.markers[1],
                                   startSeq: startSeq, endSeq: c.element.seq, derivedFromText: false))
            searchFrom = c.offset + 1
        }
        return out
    }

    /// Asa Di Vaar: 24 pauris. A pauri is the first numeric marker after a header whose text
    /// begins ਪਉੜੀ; the section starts at that header.
    private static func asaDiVaar(_ lines: [BaniLine]) -> [BaniSection] {
        var out: [BaniSection] = []
        var pauriHeaderSeq: Int?
        var expected = 1
        for l in lines {
            if l.isHeader && l.gurmukhi.hasPrefix("ਪਉੜੀ") { pauriHeaderSeq = l.seq }
            if let m = l.markers.first, let n = gurmukhiNumber(m), let h = pauriHeaderSeq {
                if n != expected { return [] }
                out.append(BaniSection(kind: .pauri, number: n, numberGm: m,
                                       startSeq: h, endSeq: l.seq, derivedFromText: false))
                expected += 1
                pauriHeaderSeq = nil
            }
        }
        return out.count >= 20 ? out : []
    }

    /// Sri Dasam Granth banis: each numbered line is a verse. Numbers are shown exactly as
    /// printed (Chaupai starts at ੩੭੭, not 1) but must be strictly consecutive from the first.
    private static func extraVerses(_ lines: [BaniLine]) -> [BaniSection] {
        var numbered: [(seq: Int, gm: String, n: Int)] = []
        for l in lines where !l.citation.isSGGS {
            let toks = trailingNumbers(inExtraText: l.gurmukhi)
            guard let first = toks.first, let n = gurmukhiNumber(first) else { continue }
            numbered.append((l.seq, first, n))
        }
        guard numbered.count >= 3 else { return [] }
        let base = numbered[0].n
        for (i, v) in numbered.enumerated() where v.n != base + i { return [] }
        var out: [BaniSection] = []
        var start = lines.first!.seq
        for v in numbered {
            out.append(BaniSection(kind: .verse, number: v.n, numberGm: v.gm,
                                   startSeq: start, endSeq: v.seq, derivedFromText: true))
            start = v.seq + 1
        }
        return out
    }

    /// Fallback for a curated multi-part bani (Rehras, Aarti): navigate by printed line-groups.
    private static func parts(_ lines: [BaniLine], count: Int) -> [BaniSection] {
        var out: [BaniSection] = []
        for g in 1...count {
            let group = lines.filter { $0.lineGroup == g }
            guard let first = group.first, let last = group.last else { continue }
            out.append(BaniSection(kind: .part, number: g, numberGm: "",
                                   startSeq: first.seq, endSeq: last.seq, derivedFromText: false))
        }
        return out.count > 1 ? out : []
    }
}
