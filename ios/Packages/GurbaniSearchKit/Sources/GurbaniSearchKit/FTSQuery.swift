import Foundation

/// FTS5 MATCH-expression builders ported from `webapp/verify.py` (incl. the v2.11.0 injection
/// hardening: strip `"`/`*`, quote each token as a literal, drop empties, never emit an empty
/// expression). Building the byte-identical MATCH string is what makes the FTS result set —
/// and therefore the candidate ordering — match the Python reference.
public enum FTSQuery {

    /// _fts_clean: neutralise FTS5 metacharacters in a single token.
    public static func clean(_ tok: String) -> String {
        tok.replacingOccurrences(of: "\"", with: "")
           .replacingOccurrences(of: "*", with: "")
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// _fts_phrase: a quoted phrase over the first `n` sanitised tokens; "" if none remain.
    public static func phrase(_ tokens: [String], column: String = "", n: Int = 4) -> String {
        let take = tokens.prefix(min(n, tokens.count))
        let words = take.map(clean).filter { !$0.isEmpty }
        if words.isEmpty { return "" }
        let phrase = words.joined(separator: " ")
        return column.isEmpty ? "\"\(phrase)\"" : "\(column): \"\(phrase)\""
    }

    /// _fts_or: OR of sanitised, individually-quoted literal tokens; "" if none remain.
    public static func or(_ tokens: [String], column: String = "") -> String {
        let quoted = tokens.map(clean).filter { !$0.isEmpty }.map { "\"\($0)\"" }
        if quoted.isEmpty { return "" }
        let joined = quoted.joined(separator: " OR ")
        return column.isEmpty ? joined : "\(column): (\(joined))"
    }
}
