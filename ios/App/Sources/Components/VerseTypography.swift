import SwiftUI

/// Display-only typographic refinements for scripture lines. NOTHING here touches the stored
/// text: every transform is applied to the rendered string alone, is reversible by deleting
/// U+2060 WORD JOINER (pinned by VerseTypographyTests), and is never used for copy, share,
/// save, search, Spotlight or VoiceOver — those always read the verbatim line.
enum VerseTypography {
    /// A real space kept between two zero-width WORD JOINERs: the gap is drawn by Sant Lipi's
    /// own space glyph (its U+00A0 has ZERO advance, which would close the gap before a danda),
    /// while UAX #14 LB11 forbids a break on either side of a joiner.
    static let unbreakableSpace = "\u{2060} \u{2060}"

    /// A closing marker run — dandas, verse/pada numerals, ਰਹਾਉ — must never wrap onto a line of
    /// its own (an orphaned "॥੩॥" reads as a stray verse). Bind the run, and the word before
    /// it, with joiner-guarded spaces. Visible characters and spacing are unchanged; only the
    /// break opportunity moves.
    static func bindingClosingMarkers(_ line: String) -> String {
        var tokens = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard tokens.count > 1 else { return line }
        var firstMarker = tokens.count
        while firstMarker > 0, isMarker(tokens[firstMarker - 1]) { firstMarker -= 1 }
        guard firstMarker < tokens.count, firstMarker > 0 else { return line }
        let tail = tokens[(firstMarker - 1)...].joined(separator: unbreakableSpace)
        tokens.removeSubrange((firstMarker - 1)...)
        tokens.append(tail)
        return tokens.joined(separator: " ")
    }

    private static func isMarker(_ token: String) -> Bool {
        if token == "ਰਹਾਉ" { return true }
        guard !token.isEmpty else { return false }
        return token.unicodeScalars.allSatisfy { s in
            s == "॥" || s == "।" || (0x0A66...0x0A6F).contains(s.value) || (0x30...0x39).contains(s.value)
        }
    }

    /// TEMPORARY display guard. The corpus `is_header` flag is wrong for ~150 verses: the
    /// pipeline's header detector fires on a composition-type WORD inside a verse (ਵਾਰ in
    /// "ਲਖ ਵਾਰ", ਅਨੰਦੁ in "ਮਹਾ ਅਨੰਦੁ"), so those verses were drawn as centred headings. Until the
    /// corpus flag is rebuilt, a flagged line is styled as a heading only if it is short or
    /// carries a real heading signal. Styling only — text, ids and grouping are untouched.
    static func rendersAsHeading(_ line: String, flaggedHeader: Bool) -> Bool {
        guard flaggedHeader else { return false }
        let tokens = line.split(separator: " ").map(String.init)
        // a bare label — "ਪਉੜੀ ॥", "॥ ਜਪੁ ॥" — is one or two words once the markers are set aside
        if tokens.filter({ !isMarker($0) }).count <= 2 { return true }
        // a verse closes with a danda; a label that does not is a heading
        if !line.hasSuffix("॥") { return true }
        if tokens.contains("ਬਾਣੀ") { return true }          // whole word: ਗੁਰਬਾਣੀ is not a label
        return headingSignals.contains { line.contains($0) }
    }

    /// Words that only occur in attribution/structure labels. Audited against all 5,380 flagged
    /// lines (2026-09-18): ~230 verses lose the heading style, no known heading does. This is a
    /// stop-gap; the real fix is the corpus flag (see the pipeline's detect_header).
    private static let headingSignals = ["ਮਹਲਾ", "ਮਹਲੇ", "ਮਃ", "ੴ", "ਰਾਗੁ", "ਘਰੁ", "ਕੀ ਵਾਰ",
                                         "ਜੀਉ ਕੀ", "ਜੀ ਕੀ", "ਜੀਉ ਕੇ", "ਜੀ ਕੇ", "ਕਬੀਰ ਜੀ", "ਪਦੇ",
                                         "ਵਧੀਕ", "ਪੜਣਾ", "ਰਵਿਦਾਸ ਜੀਉ", "ਭੀ ਸੋਰਠਿ ਭੀ"]

    /// The ੴ invocation is scripture of the first rank — it is set at full verse size in ink,
    /// never reduced like a raag/author label.
    static func isInvocation(_ line: String) -> Bool { line.hasPrefix("ੴ") }

    /// Comfortable measure for a scripture column; wider screens centre the column.
    static let readingColumn: CGFloat = 640
}

/// A heading line (raag · mahala · ghar label, or the ੴ invocation): centred, ink, verbatim.
struct VerseHeading: View {
    let verbatim: String
    var body: some View {
        let invocation = VerseTypography.isInvocation(verbatim)
        GurmukhiText(verbatim: verbatim, size: invocation ? 22 : 19,
                     weight: invocation ? .regular : .semibold)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    /// Constrain to the reading measure and centre it (no effect on iPhone widths).
    func readingColumn() -> some View {
        frame(maxWidth: VerseTypography.readingColumn).frame(maxWidth: .infinity)
    }
}
