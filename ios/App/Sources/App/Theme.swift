import SwiftUI

/// Brand tokens (mirrors the web's saffron/gold identity) + the Sant Lipi scripture font.
enum Brand {
    static let saffron = Color(red: 0xE8 / 255, green: 0x73 / 255, blue: 0x0C / 255)
    static let gold = Color(red: 0xB0 / 255, green: 0x7D / 255, blue: 0x12 / 255)

    /// The bundled Gurmukhi scripture font (variable; default instance). Scales with Dynamic Type.
    static func gurmukhi(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("SantLipi-ExtraLight", size: size, relativeTo: style)
    }
}
