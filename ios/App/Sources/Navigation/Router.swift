import SwiftUI

enum Tab: Hashable { case search, reader, index, themes, more }

/// Typed navigation targets pushed onto a tab's stack.
enum Route: Hashable {
    case theme(String)
    case raagAng(name: String, ang: Int)
}

@MainActor @Observable
final class Router {
    var selectedTab: Tab = .search
    var readerAng: Int = 1
    var indexPath = NavigationPath()
    var themesPath = NavigationPath()

    func openAng(_ n: Int) {
        readerAng = max(1, min(1430, n))
        selectedTab = .reader
    }

    /// Parse a deep link (sggs://ang/1430, sggs://theme/naam, sggs://shabad/123).
    func handle(_ url: URL, container: AppContainer) {
        guard url.scheme == "sggs" else { return }
        let host = url.host ?? ""
        let value = url.pathComponents.dropFirst().first ?? ""
        switch host {
        case "ang": if let n = Int(value) { openAng(n) }
        case "theme": if !value.isEmpty { themesPath.append(Route.theme(value)); selectedTab = .themes }
        case "shabad": if let c = Int(value) { container.presentation = .shabad(compId: c) }
        default: break
        }
    }
}
