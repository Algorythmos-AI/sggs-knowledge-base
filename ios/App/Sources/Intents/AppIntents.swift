import AppIntents
import Foundation
import UIKit

/// Siri / Shortcuts / Spotlight entry points. Every intent routes through the app's sggs://
/// deep-link table (Router.handle) — one navigation surface, no parallel code paths.

struct DrawHukamIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Hukam"
    static let description = IntentDescription("Draw a complete Hukam unit and read it verbatim.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // OpenURLIntent is iOS 18+; on the 17.0 target we open in-process (openAppWhenRun
        // guarantees the app is foregrounded before perform runs)
        await UIApplication.shared.open(URL(string: "sggs://hukam")!)
        return .result()
    }
}

struct WhatRaagNowIntent: AppIntent {
    static let title: LocalizedStringResource = "What raag is it now"
    static let description = IntentDescription("Open the Raag Clock at the current watch.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await UIApplication.shared.open(URL(string: "sggs://clock")!)
        return .result()
    }
}

struct SearchGurbaniIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Gurbani"
    static let description = IntentDescription("Search the Granth by word, sound, first letters or theme.")
    static let openAppWhenRun = true

    @Parameter(title: "Query") var query: String

    @MainActor
    func perform() async throws -> some IntentResult {
        var comps = URLComponents(string: "sggs://search")!
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        await UIApplication.shared.open(comps.url!)
        return .result()
    }
}

struct OpenAngIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Ang"
    static let description = IntentDescription("Open the Reader at a specific Ang (1–1430).")
    static let openAppWhenRun = true

    @Parameter(title: "Ang", inclusiveRange: (1, 1430)) var ang: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        await UIApplication.shared.open(URL(string: "sggs://ang/\(ang)")!)
        return .result()
    }
}

struct SGGSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: DrawHukamIntent(),
                    phrases: ["Today's Hukam in \(.applicationName)",
                              "Draw a Hukam in \(.applicationName)"],
                    shortTitle: "Today's Hukam", systemImageName: "sparkles")
        AppShortcut(intent: WhatRaagNowIntent(),
                    phrases: ["What raag is it now in \(.applicationName)",
                              "Show the raag clock in \(.applicationName)"],
                    shortTitle: "Raag now", systemImageName: "clock")
        AppShortcut(intent: SearchGurbaniIntent(),
                    phrases: ["Search Gurbani in \(.applicationName)"],
                    shortTitle: "Search Gurbani", systemImageName: "magnifyingglass")
    }
}
