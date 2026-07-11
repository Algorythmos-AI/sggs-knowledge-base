import SwiftUI

/// The five-tab shell: Reader · Search · Explore · More (+ Clock when the Raag Clock lands).
/// Explore is the hub for the browse/insight surfaces (Index, Themes, Insights, Constellation, …)
/// so the daily-ritual surfaces keep the prime tab positions — mirrors the web navbar's reach
/// without burying anything two levels deep.
enum Tab: Hashable { case reader, search, explore, more }

/// Typed navigation targets pushed onto a tab's stack (Explore hosts most of them).
enum Route: Hashable {
    case index
    case themes
    case insights
    case constellation
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

    func openAng(_ n: Int) {
        readerAng = max(1, min(1430, n))
        selectedTab = .reader
    }

    func openExplore(_ route: Route) {
        selectedTab = .explore
        explorePath = NavigationPath([route])
    }

    /// The sggs:// deep-link table (widgets/App Intents/Spotlight route through here):
    ///   sggs://ang/1430 · sggs://theme/naam · sggs://shabad/123 · sggs://search?q=mercy
    /// Out-of-range/malformed values are ignored (never crash on a hostile URL).
    func handle(_ url: URL, container: AppContainer) {
        guard url.scheme == "sggs" else { return }
        let host = url.host ?? ""
        let value = url.pathComponents.dropFirst().first ?? ""
        switch host {
        case "ang":
            if let n = Int(value), (1...1430).contains(n) { openAng(n) }
        case "theme":
            if !value.isEmpty {
                selectedTab = .explore
                explorePath = NavigationPath([Route.themes, Route.theme(value)])
            }
        case "shabad":
            if let c = Int(value), c > 0 { container.present(.shabad(compId: c)) }
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
