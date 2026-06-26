import Foundation

/// Display-only "traditional saroop" transform, ported from frontend/src/scripts/saroop.ts.
/// Collapses runs of the subjoined-ya (VIRAMA+YA, single or doubled) to one tucked addha-yayya
/// (VS1 + YA), EXCEPT when a sihari immediately follows (Sant Lipi can't shape that). NEVER applied
/// to stored/searched/copied text — only at render. `stripVS` removes the selectors for copy/share.
enum Saroop {
    private static let VIRAMA: UInt32 = 0x0A4D
    private static let YA: UInt32 = 0x0A2F
    private static let SIHARI: UInt32 = 0x0A3F
    private static let VS1 = "\u{FE00}"

    static func toTraditional(_ s: String) -> String {
        // fast path: nothing to do unless a subjoined-ya is present
        guard s.unicodeScalars.contains(where: { $0.value == YA }) else { return s }
        let cp = Array(s.unicodeScalars)
        var out = String.UnicodeScalarView()
        var i = 0
        while i < cp.count {
            if cp[i].value == VIRAMA, i + 1 < cp.count, cp[i + 1].value == YA {
                // consume the whole (VIRAMA YA)+ run
                var j = i
                while j + 1 < cp.count, cp[j].value == VIRAMA, cp[j + 1].value == YA { j += 2 }
                if j < cp.count, cp[j].value == SIHARI {
                    for k in i..<j { out.append(cp[k]) }     // leave plain (sihari follows)
                } else {
                    out.append(contentsOf: VS1.unicodeScalars)
                    out.append(Unicode.Scalar(YA)!)
                }
                i = j
            } else {
                out.append(cp[i]); i += 1
            }
        }
        return String(out)
    }

    /// Remove Variation Selectors (U+FE00–FE0F) — the verbatim form for copy/share/VoiceOver.
    static func stripVS(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.filter { !(0xFE00...0xFE0F).contains($0.value) }))
    }
}
