import SwiftUI

/// Reader appearance settings, shared by the Ang Reader and the bani reader. Storage keys are
/// frozen (XCUITests wipe them). Line spacing has a floor of 0.40 — the documented minimum
/// that clears Sant Lipi's stacked matras and pairin at the largest sizes.
enum ReaderPrefs {
    static let leadingKey = "sggs_reader_leading"
    static let toneKey = "sggs_reader_tone"
    static let leadingDefault = 0.4
    static let leadingFloor = 0.4
    static let leadingCeil = 0.75
}

/// The three paper tones. "Night" forces the warm-ink dark scheme on the reader subtree only
/// (no new colours); "Warm" is a hue-shifted light paper that still clears every contrast pair.
enum ReaderTone: String, CaseIterable, Identifiable {
    case paper, warm, night
    var id: String { rawValue }
    var label: String {
        switch self {
        case .paper: return "Paper"
        case .warm: return "Warm"
        case .night: return "Night"
        }
    }
    /// The page surface. Night resolves through the forced dark scheme, so it uses `paper`.
    var surface: Color { self == .warm ? Ink.paperWarm : Ink.paper }
    var forcesDark: Bool { self == .night }
}

private struct GurmukhiLeadingKey: EnvironmentKey {
    static let defaultValue: CGFloat = CGFloat(ReaderPrefs.leadingDefault)
}
extension EnvironmentValues {
    /// The line-spacing multiple `GurmukhiText` applies (× the effective font size).
    var gurmukhiLeading: CGFloat {
        get { self[GurmukhiLeadingKey.self] }
        set { self[GurmukhiLeadingKey.self] = max(CGFloat(ReaderPrefs.leadingFloor), newValue) }
    }
}
