import Foundation

// MARK: - Nitnem / Gutka bani registry (ADR-0006)
//
// A bani is an ORDERED LIST OF POINTERS. Lines from Sri Guru Granth Sahib Ji are the
// verbatim corpus (`lines.id`, cited by Ang). Text that is not in Sri Guru Granth Sahib Ji
// (Sri Dasam Granth, Ardaas) is a SEPARATE, labelled layer: it never carries an Ang, an
// English translation, a bookmark or a Spotlight entry. The citation enum makes that
// distinction a compile-time fact — there is no way to build an SGGS citation for an
// extra line, and `switch` over it must handle every source explicitly.

/// Where a bani line comes from and how it is cited. Exhaustive on purpose.
public enum BaniCitation: Sendable, Equatable, Hashable {
    /// Verbatim Sri Guru Granth Sahib Ji — cite "Sri Guru Granth Sahib Ji · Ang N".
    case sggs(ang: Int, lineId: Int, compId: Int)
    /// Sri Dasam Granth via the ShabadOS dataset — a separate layer, cited by Panna, never Ang.
    case dasam(panna: Int?, extraId: Int)
    /// Ardaas (SGPC Sikh Rehat Maryada wording) — a separate layer.
    case ardaas(extraId: Int)

    /// True only for scripture from Sri Guru Granth Sahib Ji.
    public var isSGGS: Bool { if case .sggs = self { return true } else { return false } }

    /// The SGGS line id when the line is scripture; nil for the extra layer.
    public var lineId: Int? { if case .sggs(_, let id, _) = self { return id } else { return nil } }

    /// The exact citation string the brand book requires. Never names the app.
    public var citation: String {
        switch self {
        case .sggs(let ang, _, _): return "Sri Guru Granth Sahib Ji · Ang \(ang)"
        case .dasam(let panna, _):
            if let panna { return "Sri Dasam Granth · Panna \(panna)" }
            return "Sri Dasam Granth"
        case .ardaas: return "Ardaas"
        }
    }

    /// The registry's source tag (mirrors /api/bani `source`).
    public var source: String {
        switch self {
        case .sggs: return "sggs"
        case .dasam: return "dasam"
        case .ardaas: return "ardaas"
        }
    }
}

/// One line of a bani in reading order. `seq` is the ONLY identity a UI may key on:
/// SGGS line ids and extra ids live in different namespaces and would collide.
public struct BaniLine: Sendable, Equatable, Identifiable {
    public let seq: Int
    public let lineGroup: Int
    public let gurmukhi: String
    public let translit: String
    public let isHeader: Bool
    public let isRahao: Bool
    /// The closing marker(s) of this line (e.g. ॥੧॥) when scripture carries them; [] otherwise.
    public let markers: [String]
    public let citation: BaniCitation
    /// Labelled English (Khalsa layer) — only ever non-nil for `.sggs` on the personal profile.
    public let en: String?
    public var id: Int { seq }
    public init(seq: Int, lineGroup: Int, gurmukhi: String, translit: String, isHeader: Bool,
                isRahao: Bool, markers: [String], citation: BaniCitation, en: String? = nil) {
        precondition(en == nil || citation.isSGGS, "English is only ever attached to SGGS lines")
        self.seq = seq; self.lineGroup = lineGroup; self.gurmukhi = gurmukhi; self.translit = translit
        self.isHeader = isHeader; self.isRahao = isRahao; self.markers = markers
        self.citation = citation; self.en = en
    }
}

/// Which part of the daily practice a bani belongs to (mirrors `banis.category`).
public enum BaniCategory: String, Sendable, CaseIterable {
    case nitnemMorning = "nitnem_morning"
    case nitnemEvening = "nitnem_evening"
    case nitnemNight = "nitnem_night"
    case popular = "popular"
    case ceremony = "ceremony"
}

/// A registry entry (mirrors /api/banis rows).
public struct BaniSummary: Sendable, Equatable, Identifiable, Hashable {
    public let key: String
    public let variant: String          // "" | "sgpc" | "taksal" | "kirtan"
    public let isDefault: Bool
    public let titleGm: String
    public let titleEn: String
    public let category: BaniCategory
    public let orderNo: Int
    public let nLines: Int
    public let nGroups: Int
    public let hasExtra: Bool           // contains non-SGGS text
    public let estimatedMinutes: Int?
    public let descriptionEn: String?
    public let sourceLabel: String
    /// Stable identity across variants: key + variant.
    public var id: String { variant.isEmpty ? key : "\(key)/\(variant)" }
    public init(key: String, variant: String, isDefault: Bool, titleGm: String, titleEn: String,
                category: BaniCategory, orderNo: Int, nLines: Int, nGroups: Int, hasExtra: Bool,
                estimatedMinutes: Int?, descriptionEn: String?, sourceLabel: String) {
        self.key = key; self.variant = variant; self.isDefault = isDefault; self.titleGm = titleGm
        self.titleEn = titleEn; self.category = category; self.orderNo = orderNo; self.nLines = nLines
        self.nGroups = nGroups; self.hasExtra = hasExtra; self.estimatedMinutes = estimatedMinutes
        self.descriptionEn = descriptionEn; self.sourceLabel = sourceLabel
    }
}

/// A resolved bani: its summary, the variants that exist for its key, and every line.
public struct Bani: Sendable, Equatable {
    public let summary: BaniSummary
    public let variants: [String]
    public let angFirst: Int?
    public let angLast: Int?
    public let lines: [BaniLine]
    public init(summary: BaniSummary, variants: [String], angFirst: Int?, angLast: Int?, lines: [BaniLine]) {
        self.summary = summary; self.variants = variants; self.angFirst = angFirst
        self.angLast = angLast; self.lines = lines
    }
    /// The Ang range as the brand book cites it, or the extra-layer label for a Dasam-only bani.
    public var citationRange: String {
        if let a = angFirst, let b = angLast {
            return a == b ? "Sri Guru Granth Sahib Ji · Ang \(a)" : "Sri Guru Granth Sahib Ji · Ang \(a)–\(b)"
        }
        return summary.hasExtra ? "Sri Dasam Granth · separate layer" : ""
    }
}

/// The /api/banis payload: `available` mirrors the capability bit for older DB builds.
public struct BaniList: Sendable, Equatable {
    public let available: Bool
    public let banis: [BaniSummary]
    public init(available: Bool, banis: [BaniSummary]) { self.available = available; self.banis = banis }
}
