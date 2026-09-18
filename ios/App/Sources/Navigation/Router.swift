import SwiftUI

/// The five-tab shell: Nitnem · Reader · Search · Explore · More.
/// Nitnem (the daily reading) and Reader keep the prime positions; Explore is the hub for the
/// browse/insight surfaces (Index, Themes, Insights, Constellation, Raag Clock, …) so nothing
/// is buried two levels deep.
enum Tab: Hashable { case nitnem, reader, search, explore, more }

/// Typed navigation targets pushed onto a tab's stack (Explore hosts most of them; the
/// Nitnem stack hosts `.bani`).
enum Route: Hashable {
    case index
    case themes
    case lineage
    case insights
    case constellation
    case vaars
    case clock
    case theme(String)
    /// A bani from the Nitnem registry, by its stable key (variant is a user setting).
    case bani(String)
}

@MainActor @Observable
final class Router {
    var selectedTab: Tab = .nitnem
    var readerAng: Int = 1
    var explorePath = NavigationPath()
    var nitnemPath = NavigationPath()
    /// A deep-linked search query (sggs://search?q=…); SearchScreen consumes and clears it.
    var pendingSearchQuery: String?
    /// True once ANY explicit Ang navigation happened (deep link, intent, widget, in-app).
    /// The Reader's resume-last-Ang must not fire after this — `readerAng == 1` alone can't
    /// distinguish the untouched default from an explicit `sggs://ang/1`.
    private(set) var navigatedToAngExplicitly = false
    /// The verse the Reader should scroll to (and highlight) once the requested Ang is on screen.
    /// Always overwritten by `openAng` — a stale id must never land a later navigation.
    var pendingReaderLineId: Int?

    func openAng(_ n: Int, lineId: Int? = nil) {
        navigatedToAngExplicitly = true
        pendingReaderLineId = (lineId ?? 0) > 0 ? lineId : nil
        readerAng = max(1, min(1430, n))
        selectedTab = .reader
    }

    /// A raag the Clock should focus when opened via deep link / Reader timing chip.
    var pendingClockRaag: String?

    /// The Raag Clock lives under Explore: select the tab and put the clock on top of its stack.
    func openClock(raag: String? = nil) {
        pendingClockRaag = raag
        selectedTab = .explore
        explorePath = NavigationPath([Route.clock])
    }

    /// Open a bani in the Nitnem tab (deep link, intent, "Next bani").
    func openBani(key: String) {
        guard Router.isValidBaniKey(key) else { return }
        selectedTab = .nitnem
        nitnemPath = NavigationPath([Route.bani(key)])
    }

    /// Same allowlist as the API: lowercase ascii, digits, underscore, 1–32 chars.
    static func isValidBaniKey(_ key: String) -> Bool {
        !key.isEmpty && key.count <= 32 && key.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
    }

    /// The sggs:// deep-link table (widgets/App Intents/Spotlight route through here):
    ///   sggs://ang/1430[?line=Y] · sggs://theme/naam · sggs://shabad/123[?line=Y] ·
    ///   sggs://search?q=mercy · sggs://clock (optional /<raag-roman>) · sggs://nitnem ·
    ///   sggs://bani/<key>
    /// `line` lands on that verse (scrolled + highlighted). Out-of-range/malformed values are
    /// ignored (never crash on a hostile URL).
    func handle(_ url: URL, container: AppContainer) {
        guard url.scheme == "sggs" else { return }
        let host = url.host ?? ""
        let value = url.pathComponents.dropFirst().first ?? ""     // path only — the query is excluded
        let line: Int? = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "line" })?.value.flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }
        switch host {
        case "ang":
            if let n = Int(value), (1...1430).contains(n) { openAng(n, lineId: line) }
        case "clock":
            openClock(raag: value.isEmpty ? nil : value)
        case "nitnem":
            selectedTab = .nitnem
            nitnemPath = NavigationPath()
        case "bani":
            openBani(key: value)
        case "theme":
            if !value.isEmpty {
                selectedTab = .explore
                explorePath = NavigationPath([Route.themes, Route.theme(value)])
            }
        case "shabad":
            if let c = Int(value), c > 0 { container.present(.shabad(compId: c, focusLineId: line)) }
        case "hukam":
            container.present(.hukam)
        case "search":
            let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "q" })?.value ?? ""
            if !q.isEmpty {
                pendingSearchQuery = q
                selectedTab = .search
            }
        default: break
        }
    }
}
