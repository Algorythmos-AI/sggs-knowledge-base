import SwiftUI

/// The five-tab shell: Reader · Search · Clock · Explore · More.
/// Explore is the hub for the browse/insight surfaces (Index, Themes, Insights, Constellation, …)
/// so the daily-ritual surfaces keep the prime tab positions — mirrors the web navbar's reach
/// without burying anything two levels deep.
enum Tab: Hashable { case reader, search, clock, explore, more }

/// Typed navigation targets pushed onto a tab's stack (Explore hosts most of them).
enum Route: Hashable {
    case index
    case themes
    case lineage
    case insights
    case constellation
    case vaars
    case theme(String)
    case raagAng(name: String, ang: Int)
}

@MainActor @Observable
final class Router {
    var selectedTab: Tab = .search
    var readerAng: Int = 1
    var explorePath = NavigationPath()
    /// A deep-linked search query (sggs://search?q=…); SearchScreen consumes and clears it.
    var pendingSearchQuery: String?
    /// True once ANY explicit Ang navigation happened (deep link, intent, widget, in-app).
    /// The Reader's resume-last-Ang must not fire after this — `readerAng == 1` alone can't
    /// distinguish the untouched default from an explicit `sggs://ang/1`.
    private(set) var navigatedToAngExplicitly = false

    func openAng(_ n: Int) {
        navigatedToAngExplicitly = true
        readerAng = max(1, min(1430, n))
        selectedTab = .reader
    }

    func openExplore(_ route: Route) {
        selectedTab = .explore
        explorePath = NavigationPath([route])
    }

    /// A raag the Clock tab should focus when opened via deep link / Reader timing chip.
    var pendingClockRaag: String?

    func openClock(raag: String? = nil) {
        pendingClockRaag = raag
        selectedTab = .clock
    }

    /// The sggs:// deep-link table (widgets/App Intents/Spotlight route through here):
    ///   sggs://ang/1430 · sggs://theme/naam · sggs://shabad/123 · sggs://search?q=mercy ·
    ///   sggs://clock (optional /<raag-roman>)
    /// Out-of-range/malformed values are ignored (never crash on a hostile URL).
    func handle(_ url: URL, container: AppContainer) {
        guard url.scheme == "sggs" else { return }
        let host = url.host ?? ""
        let value = url.pathComponents.dropFirst().first ?? ""
        switch host {
        case "ang":
            if let n = Int(value), (1...1430).contains(n) { openAng(n) }
        case "clock":
            openClock(raag: value.isEmpty ? nil : value)
        case "theme":
            if !value.isEmpty {
                selectedTab = .explore
                explorePath = NavigationPath([Route.themes, Route.theme(value)])
            }
        case "shabad":
            if let c = Int(value), c > 0 { container.present(.shabad(compId: c)) }
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
