import Foundation

/// Raag-Timing knowledge layer read models (serve.py /api/timing/*, /api/forms — DB v2.12.0).
/// These are attributed scholarly CLAIMS with citations, never facts: divergent traditions
/// coexist as rows, disagreement is preserved scholarship, not error. Metadata about raags
/// only — never scripture. Every surface degrades to `available == false` when the layer is
/// absent (public/older DB builds).

/// One cited timing claim. Used by the clock (with raag identity) and by per-raag /
/// divergence views (raag identity on the parent, these fields nil'd appropriately).
public struct TimingClaim: Sendable, Equatable {
    public let raagName: String?     // clock rows carry raag identity; per-raag claims don't
    public let roman: String?
    public let firstAng: Int?
    public let seq: Int?
    public let claimType: String     // primary | variant | seasonal | ceremonial
    public let pahar: Int?           // 1–8; nil for seasonal/ceremonial claims
    public let timeStart: String?
    public let timeEnd: String?
    public let season: String?
    public let occasion: String?
    public let confidence: String    // consistent | majority | disputed
    public let notes: String?
    public let sourceName: String
    public let tradition: String     // gurmat_sangeet | hindustani
    public let sourceURL: String?
    public init(raagName: String?, roman: String?, firstAng: Int?, seq: Int?, claimType: String,
                pahar: Int?, timeStart: String?, timeEnd: String?, season: String?, occasion: String?,
                confidence: String, notes: String?, sourceName: String, tradition: String, sourceURL: String?) {
        self.raagName = raagName; self.roman = roman; self.firstAng = firstAng; self.seq = seq
        self.claimType = claimType; self.pahar = pahar; self.timeStart = timeStart; self.timeEnd = timeEnd
        self.season = season; self.occasion = occasion; self.confidence = confidence; self.notes = notes
        self.sourceName = sourceName; self.tradition = tradition; self.sourceURL = sourceURL
    }
}

/// /api/timing/clock — every claim, grouped by claim_type, in raag-seq order.
public struct TimingClock: Sendable, Equatable {
    public let available: Bool
    public let primary: [TimingClaim]
    public let variant: [TimingClaim]
    public let seasonal: [TimingClaim]
    public let ceremonial: [TimingClaim]
    public init(available: Bool, primary: [TimingClaim] = [], variant: [TimingClaim] = [],
                seasonal: [TimingClaim] = [], ceremonial: [TimingClaim] = []) {
        self.available = available; self.primary = primary; self.variant = variant
        self.seasonal = seasonal; self.ceremonial = ceremonial
    }
    /// Primary-claim raags active in fixed-clock pahar p (pahar.js raagsForPahar).
    public func raags(forPahar p: Int) -> [TimingClaim] { primary.filter { $0.pahar == p } }
}

/// /api/timing/raag?name= — one raag's claims (looked up by gurmukhi name or roman).
public struct RaagTiming: Sendable, Equatable {
    public let available: Bool
    public let raag: String
    public let roman: String?
    public let firstAng: Int?
    public let claims: [TimingClaim]
    public init(available: Bool, raag: String, roman: String?, firstAng: Int?, claims: [TimingClaim]) {
        self.available = available; self.raag = raag; self.roman = roman
        self.firstAng = firstAng; self.claims = claims
    }
}

/// /api/timing/divergence — raags where traditions disagree (variant claims, or multiple
/// pahars from multiple sources; a same-source multi-pahar row is an extension, not a dispute).
public struct TimingDivergence: Sendable, Equatable {
    public struct Entry: Sendable, Equatable, Identifiable {
        public let raag: String
        public let roman: String?
        public let firstAng: Int?
        public let claims: [TimingClaim]
        public var id: String { raag }
        public init(raag: String, roman: String?, firstAng: Int?, claims: [TimingClaim]) {
            self.raag = raag; self.roman = roman; self.firstAng = firstAng; self.claims = claims
        }
    }
    public let available: Bool
    public let raags: [Entry]
    public init(available: Bool, raags: [Entry]) { self.available = available; self.raags = raags }
}

/// /api/forms?comp_id= — a composition's musical/structural metadata (derived ONLY from
/// headings present in the verified text; nil means the heading states no form — never guessed).
public struct ShabadForms: Sendable, Equatable {
    public let available: Bool
    public let compId: Int
    public let raagName: String?
    public let firstAng: Int?
    public let ghar: Int?
    public let partaal: Bool?
    public let hasRahao: Bool?
    public let hasRahaoDooja: Bool?
    public let dhunni: String?
    public let jati: String?
    public let form: String?         // pada | ashtpadi | solahe | chhant | vaar | pauri | salok
    public let padaCount: Int?
    public let genre: String?        // barah_maha | patti | … (23 heading-derived genres)
    public let sourceLabel: String?
    /// true when the comp exists in shabd_raag_map (a `forms: None` miss keeps available=true).
    public let mapped: Bool
    public init(available: Bool, compId: Int, raagName: String? = nil, firstAng: Int? = nil,
                ghar: Int? = nil, partaal: Bool? = nil, hasRahao: Bool? = nil,
                hasRahaoDooja: Bool? = nil, dhunni: String? = nil, jati: String? = nil,
                form: String? = nil, padaCount: Int? = nil, genre: String? = nil,
                sourceLabel: String? = nil, mapped: Bool = false) {
        self.available = available; self.compId = compId; self.raagName = raagName
        self.firstAng = firstAng; self.ghar = ghar; self.partaal = partaal
        self.hasRahao = hasRahao; self.hasRahaoDooja = hasRahaoDooja; self.dhunni = dhunni
        self.jati = jati; self.form = form; self.padaCount = padaCount; self.genre = genre
        self.sourceLabel = sourceLabel; self.mapped = mapped
    }
}
