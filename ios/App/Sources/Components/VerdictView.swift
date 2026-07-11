import SwiftUI
import GurbaniSearchKit

/// Quotation-verification result: a clearly-labelled verdict (by meaning, not just colour),
/// confidence, and the canonical line when found.
struct VerdictView: View {
    let result: VerifyResult
    /// English of the canonical line (display layer; nil when absent or on the public profile).
    var en: String? = nil
    var onOpenAng: (Int) -> Void = { _ in }

    private var base: String { result.verdict.components(separatedBy: "+").first ?? result.verdict }
    private var color: Color {
        if base.hasPrefix("VERIFIED") { return .green }
        if base == "NOT_FOUND" { return .red }
        return Brand.gold
    }
    private var headline: String {
        switch base {
        case "VERIFIED_EXACT", "VERIFIED": return "Verified"
        case "VERIFIED_PARTIAL": return "Verified (fragment)"
        case "PROBABLE": return "Probable match"
        case "AMBIGUOUS": return "Ambiguous"
        default: return "Not found"
        }
    }
    private var angA11y: String {
        if result.verdict.contains("ANG_MATCH") { return " The cited Ang matches." }
        if result.verdict.contains("ANG_MISMATCH") { return " The cited Ang does not match." }
        return ""
    }
    private var explanation: String {
        if base.hasPrefix("VERIFIED") { return "This is scripture, verified against the canonical corpus." }
        if base == "NOT_FOUND" { return "No such line found in Sri Guru Granth Sahib. Treat the quote as unverified." }
        return "A close match was found — compare carefully below."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: base.hasPrefix("VERIFIED") ? "checkmark.seal.fill"
                      : (base == "NOT_FOUND" ? "xmark.seal.fill" : "questionmark.diamond.fill"))
                    .foregroundStyle(color)
                VStack(alignment: .leading) {
                    Text(headline).font(.headline)
                    Text(String(format: "confidence %.1f%%", result.confidence * 100))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if result.verdict.contains("ANG_MATCH") { Label("Ang ✓", systemImage: "checkmark").font(.caption).foregroundStyle(.green) }
                else if result.verdict.contains("ANG_MISMATCH") { Text("Ang ✗").font(.caption).foregroundStyle(.red) }
            }
            Text(explanation).font(.subheadline).foregroundStyle(.secondary)

            if let g = result.gurmukhi, let ang = result.ang {
                Divider()
                Text("Canonical line").font(.caption).foregroundStyle(.tertiary)
                LineRow(gurmukhi: g, translit: "",
                        meta: ["Ang \(ang)", result.raag, result.author].compactMap { $0 }.joined(separator: " · "),
                        en: en) {
                    onOpenAng(ang)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.35)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline). \(explanation)\(angA11y)")
    }
}
