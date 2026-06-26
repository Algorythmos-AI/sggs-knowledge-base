import Foundation

/// Text helpers ported byte-identically from `webapp/verify.py`. All operate on Unicode
/// SCALARS (matching Python's code-point semantics), never Swift `Character` (graphemes).
public enum GurbaniText {

    /// _is_gurmukhi: any code point in the Gurmukhi block U+0A00…U+0A7F.
    public static func isGurmukhi(_ s: String) -> Bool {
        for u in s.unicodeScalars where (0x0A00...0x0A7F).contains(u.value) { return true }
        return false
    }

    /// _GURMUKHI_MATRAS — the vowel-sign / diacritic set stripped to form the skeleton.
    static let matras: Set<UInt32> = Set("ਾਿੀੁੂੇੈੋੌ੍ੰਂਃ਼ੱੑੵ".unicodeScalars.map { $0.value })

    /// _skeletonize: drop matras (keep consonants + spaces).
    public static func skeletonize(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        for u in s.unicodeScalars where !matras.contains(u.value) { v.append(u) }
        return String(v)
    }

    /// _PUNCT_RE = [॥।੦-੯|] : danda U+0965, single-danda U+0964, pipe U+007C, Gurmukhi digits U+0A66…U+0A6F.
    private static func isPunct(_ u: UInt32) -> Bool {
        u == 0x0965 || u == 0x0964 || u == 0x007C || (0x0A66...0x0A6F).contains(u)
    }

    /// _clean_gurmukhi: strip dandas/digits/pipe, collapse whitespace to single spaces.
    public static func cleanGurmukhi(_ s: String) -> String {
        var v = String.UnicodeScalarView()
        for u in s.unicodeScalars where !isPunct(u.value) { v.append(u) }
        return String(v).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// _roman_to_tn: lowercase, drop vowels a/e/i/o/u, collapse runs of identical chars.
    /// (Applied per whitespace-split word in verify.py.)
    public static func romanToTN(_ s: String) -> String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var out = ""
        var prev: Character? = nil
        for c in s.lowercased() where !vowels.contains(c) {
            if c != prev { out.append(c); prev = c }
        }
        return out
    }

    /// Code-point length (Python `len(str)`), not grapheme count — used by the fragment rule.
    public static func scalarCount(_ s: String) -> Int { s.unicodeScalars.count }

    /// Whitespace-split word count (Python `str.split()`).
    public static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace }).count
    }
}
