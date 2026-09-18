import Foundation
import GurbaniSearchKit

/// Pure resolution of a customised daily set against the live registry — the single source both
/// the home screen and the widget snapshot use, so they can never disagree. Never emits Gurmukhi;
/// it only orders and filters registry rows.
enum NitnemSets {
    /// The banis to show for a category, honouring the reader's plan (order + hidden) and falling
    /// back to the registry defaults when they have not customised it. Unknown keys are dropped;
    /// registry defaults added in a later app version are appended (idempotent).
    static func resolved(category: BaniCategory, plan: [NitnemSetEntry],
                         registry: [BaniSummary], rehrasVariant: String) -> [BaniSummary] {
        let defaults = registry.filter { $0.category == category && $0.isDefault }
            .sorted { $0.orderNo < $1.orderNo }
        guard !plan.isEmpty else { return defaults }

        func summary(forKey key: String) -> BaniSummary? {
            let matches = registry.filter { $0.key == key }
            if key == "rehras" {
                let want = NitnemPrefs.variant(for: "rehras", rehras: rehrasVariant)
                return matches.first { $0.variant == want } ?? matches.first { $0.isDefault } ?? matches.first
            }
            return matches.first { $0.isDefault } ?? matches.first
        }

        var result: [BaniSummary] = []
        var seen = Set<String>()
        for e in plan where !e.hidden {
            if let s = summary(forKey: e.key), !seen.contains(s.key) { result.append(s); seen.insert(s.key) }
        }
        let planKeys = Set(plan.map(\.key))
        for s in defaults where !planKeys.contains(s.key) && !seen.contains(s.key) {
            result.append(s); seen.insert(s.key)   // a new default the plan predates
        }
        return result
    }

    /// Library banis the reader could ADD to a category set: every default bani (any category)
    /// not already an entry in this set. Sorted by category then order for a calm picker.
    static func addable(to category: BaniCategory, plan: [NitnemSetEntry],
                        registry: [BaniSummary], rehrasVariant: String) -> [BaniSummary] {
        let present = Set(plan.map(\.key))
        // one row per key: the default (or the chosen rehras-variant) summary
        var byKey: [String: BaniSummary] = [:]
        for s in registry where s.isDefault || (s.key == "rehras" && s.variant == NitnemPrefs.variant(for: "rehras", rehras: rehrasVariant)) {
            if byKey[s.key] == nil { byKey[s.key] = s }
        }
        return byKey.values
            .filter { !present.contains($0.key) }
            .sorted { ($0.category.rawValue, $0.orderNo) < ($1.category.rawValue, $1.orderNo) }
    }
}
