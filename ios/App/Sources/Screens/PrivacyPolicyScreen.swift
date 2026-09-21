import SwiftUI

/// The links the app exposes to the outside world. The two web URLs are the SAME ones entered in
/// App Store Connect as the Privacy Policy and Support URLs (docs/ios/app-store-listing.md), so a
/// repo gate asserts they never drift. Opening one hands the URL to Safari — the app itself still
/// makes no network request, so the "works fully offline" promise is intact.
enum AppLinks {
    static let privacy = URL(string: "https://sggs-knowledge-base.vercel.app/privacy")!
    static let support = URL(string: "https://sggs-knowledge-base.vercel.app/support")!
}

/// The in-app Privacy Policy (Guideline 5.1.1(i): reachable inside the app). Deliberately static
/// and offline — it renders in Airplane Mode, true to the app's promise — and mirrors the web
/// policy at AppLinks.privacy fact-for-fact. Update both together.
struct PrivacyPolicyScreen: View {
    var body: some View {
        List {
            Section {
                Text("We collect nothing. Here is exactly what that means.")
                    .font(Brand.heading(.title3))
                Text("This applies to the Gurbani Soul app for iPhone and iPad, including its widgets and Live Activity.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .inkRow()

            policy("The short version", [
                "No accounts. Nothing to sign up for, nothing to log in to.",
                "The app makes no network connections. It works fully in Airplane Mode.",
                "No analytics, no advertising, no tracking, no third-party SDKs.",
                "Everything you do — saved verses, settings, reading position, Nitnem progress and reminders — stays on your device.",
                "Location is optional, used only on your device, and never transmitted.",
            ])

            policy("What stays on your device", [
                "Saved verses are stored in the app's own database, and added to your device's Spotlight index so you can find them from Home Screen search; unsaving removes them.",
                "Settings (accent, transliteration, traditional rendering, last Ang read) are stored in the app's local preferences.",
                "Nitnem progress, your own sets and your reading journey are stored in the app's App Group container so the Nitnem widget can show them.",
                "Reminders are optional local notifications, scheduled on your device at times you choose. No push service is used and no device token is created.",
                "The reading Live Activity is optional and off by default. It runs on your device with no push updates and never shows a verse.",
                "Widgets read a small snapshot the app writes into its App Group container: the raag watch, a Hukam verse with its Ang, today's Nitnem progress, and — if you use solar mode — your clock-mode choice and your location rounded to about 1 km. Nothing leaves the device.",
            ])

            policy("Location", [
                "Location is used only by the Raag Clock's optional solar mode, and only after you tap “Use my location”.",
                "The fix is rounded to about 1 km before it is stored in the app's App Group container — shared only with the app's own widgets — and the raw position is never kept.",
                "You can enter a location manually instead, or deny the permission; the clock still works.",
            ])

            policy("Integrity & diagnostics", [
                "To verify the bundled scripture is unaltered, the app reads the database file's size and modification date. Nothing is displayed or transmitted.",
                "If the app ever crashes or hangs, iOS may hand it a diagnostic report, which the app writes to a local folder. You can see how many there are, share them via the system share sheet, or delete them under More → About & credits → Integrity. Nothing is sent unless you choose to share it.",
            ])

            Section {
                Text("Because the app collects no data, its App Store privacy label is “Data Not Collected.”")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Read the full policy online", destination: AppLinks.privacy)
                    .accessibilityIdentifier("privacyWebLink")
                Link("Support", destination: AppLinks.support)
                    .accessibilityIdentifier("supportWebLink")
            } footer: {
                Text("Opening a link hands it to Safari; the app itself makes no network requests.")
            }
            .inkRow()
        }
        .inkGroupedList()
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policy(_ title: String, _ points: [String]) -> some View {
        Section(title) {
            ForEach(points, id: \.self) { p in
                Label { Text(p) } icon: { Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tertiary) }
                    .labelStyle(.titleAndIcon)
            }
        }
        .inkRow()
    }
}
