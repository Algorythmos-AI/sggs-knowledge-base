import SwiftUI
import UIKit

// MARK: - "Ink & Saffron" design tokens
//
// The single color/typography/motion vocabulary for the app AND the widget extension
// (this file compiles into both targets — keep it dependency-free beyond SwiftUI/UIKit).
//
// Architecture: every color is a DYNAMIC provider resolved per trait collection —
// light/dark × normal/Increase-Contrast — so the palette is *designed* for all four
// legs, not auto-derived. Values are plain hex literals here and are pinned by
// ThemeContrastTests, which computes real WCAG ratios for every text/status token
// against its paired surface (≥4.5:1 text, ≥3:1 UI) across all accents and schemes.
// Change a value ⇒ the test tells you whether it still passes. No eyeballing.
//
// Dark surfaces are WARM INK (near-black warm browns), never pure black and never
// indigo — saffron and gold glow on warm ink, and the paper-and-ink metaphor of a
// granth carries through both schemes.

// MARK: hex plumbing

extension UIColor {
    /// 0xRRGGBB → opaque sRGB color.
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// Adaptive token: light/dark pairs with optional Increase Contrast overrides.
    init(light: UInt32, dark: UInt32, lightHC: UInt32? = nil, darkHC: UInt32? = nil) {
        self.init(UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHC = traits.accessibilityContrast == .high
            switch (isDark, isHC) {
            case (false, false): return UIColor(rgb: light)
            case (false, true):  return UIColor(rgb: lightHC ?? light)
            case (true, false):  return UIColor(rgb: dark)
            case (true, true):   return UIColor(rgb: darkHC ?? dark)
            }
        })
    }

    /// Adaptive token whose LIGHT leg aliases a system color (grouped-List screens stay
    /// native in light mode) while the DARK leg is a designed warm-ink value.
    init(lightSystem: UIColor, dark: UInt32, darkHC: UInt32? = nil) {
        self.init(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                let isHC = traits.accessibilityContrast == .high
                return UIColor(rgb: isHC ? (darkHC ?? dark) : dark)
            }
            return lightSystem.resolvedColor(with: traits)
        })
    }
}

// MARK: - Accent palettes (user-selectable; Soul Gold is the brand default)

/// A curated accent identity. Each palette carries every color a component needs so no
/// call site ever "adjusts" an accent ad hoc: `accent` for tint/icons/borders (≥3:1 vs
/// surfaces), `accentFill` for PROMINENT fills (buttons, selected pills, hero — bordered by
/// `accent`), `accentText` for accent-colored TEXT on surfaces (≥4.5:1), `onAccent` for
/// labels ON `accentFill` (≥4.5:1 vs the fill), and a two-stop hero gradient.
/// Values for `soul` mirror docs/brand/tokens.json (see docs/brand/gurbani-soul-brand-book.md).
/// Stored in @AppStorage("sggs_accent") by raw value; injected via \.palette.
enum AccentPalette: String, CaseIterable, Sendable, Identifiable {
    case soul, saffron, gold, indigo, teal
    var id: String { rawValue }

    static let storageKey = "sggs_accent"

    /// The brand default: what a reader who never chose an accent sees, what the
    /// AccentColor asset is pinned to, and what the fixed brand moments (launch, About,
    /// share card, widgets) use. A stored choice always wins over this.
    static let brandDefault: AccentPalette = .soul

    var label: String {
        switch self {
        case .soul: "Soul Gold"
        case .saffron: "Saffron"
        case .gold: "Gold"
        case .indigo: "Indigo"
        case .teal: "Teal"
        }
    }

    /// Fills, icons, tint. Light legs sit at ≥3:1 against the paper/card surfaces
    /// (light saffron is tuned to #E06E09 — 2% deeper than the web's #E8730C — precisely
    /// to clear 3:1 on the Reader's paper); dark legs are lifted so they read on warm ink.
    var accent: Color {
        switch self {
        case .soul:    Color(light: 0xA87900, dark: 0xFFBC0D, lightHC: 0x8A6100, darkHC: 0xFFC72C)
        case .saffron: Color(light: 0xE06E09, dark: 0xFF8F2E, lightHC: 0xA85108, darkHC: 0xFFA85C)
        case .gold:    Color(light: 0xB07D12, dark: 0xD9A93C, lightHC: 0x8F650E, darkHC: 0xE7BE63)
        case .indigo:  Color(light: 0x4A55C9, dark: 0x8B93F5, lightHC: 0x3A43A8, darkHC: 0xA7ADF8)
        case .teal:    Color(light: 0x0E7E74, dark: 0x3FC2B4, lightHC: 0x0A645C, darkHC: 0x67D1C6)
        }
    }

    /// PROMINENT fills (primary button, selected pill, hero, swatch). For Soul Gold this
    /// is the literal brand gold #FFBC0D, which is only 1.69:1 on white — so it is never
    /// used for tint/icons/text and always carries an `accent` border in light mode. Every
    /// other palette's fill IS its accent.
    var accentFill: Color {
        switch self {
        case .soul: Color(light: 0xFFBC0D, dark: 0xFFBC0D, lightHC: 0x8A6100, darkHC: 0xFFC72C)
        default: accent
        }
    }

    /// Accent used AS TEXT on app surfaces — darker (light) / lighter (dark) than the
    /// fill so it clears 4.5:1 on paper and ink alike.
    var accentText: Color {
        switch self {
        case .soul:    Color(light: 0x8A6100, dark: 0xFFBC0D, lightHC: 0x5C4100, darkHC: 0xFFC72C)
        case .saffron: Color(light: 0xA0530A, dark: 0xFFA24F, lightHC: 0x7E4108, darkHC: 0xFFB877)
        case .gold:    Color(light: 0x7E5A0C, dark: 0xE3BC5F, lightHC: 0x64470A, darkHC: 0xEDCD86)
        case .indigo:  Color(light: 0x4149B8, dark: 0xA7ADF8, lightHC: 0x333A96, darkHC: 0xBFC3FA)
        case .teal:    Color(light: 0x0B6B62, dark: 0x67D1C6, lightHC: 0x08544D, darkHC: 0x8DDCD4)
        }
    }

    /// Label color ON an accent fill (selected pills, prominent buttons). Warm accents
    /// take ink text (the Apple-yellow-badge move — also the only way saffron passes AA);
    /// cool accents take white in light. In dark every fill is lifted, so ink wins.
    /// Under Increase Contrast the warm LIGHT fills go deeper (see `accent`), where ink
    /// can no longer clear 4.5 — the label flips to white there, verified by test.
    var onAccent: Color {
        switch self {
        case .soul, .saffron, .gold:
            return Color(light: 0x2B1A05, dark: 0x2B1A05, lightHC: 0xFFFFFF, darkHC: 0x2B1A05)
        case .indigo:
            return Color(light: 0xFFFFFF, dark: 0x11133A)
        case .teal:
            return Color(light: 0xFFFFFF, dark: 0x062A26)
        }
    }

    /// The second hero-gradient stop (deeper partner hue; used with `accentFill`).
    var accentDeep: Color {
        switch self {
        case .soul:    Color(light: 0xFFB81C, dark: 0xC08B00, lightHC: 0x6E4E00, darkHC: 0xD9A200)
        case .saffron: Color(light: 0xB07D12, dark: 0xD9A93C)   // saffron → gold: the brand ramp
        case .gold:    Color(light: 0x8A5E0B, dark: 0xB08A2E)
        case .indigo:  Color(light: 0x36349B, dark: 0x6D6FD6)
        case .teal:    Color(light: 0x0A5C68, dark: 0x2E9AA8)
        }
    }

    /// Signature hero gradient — used in exactly a few hero moments (Hukam/now cards,
    /// Explore header, share-card rule). Restraint is the premium signal.
    var heroGradient: LinearGradient {
        LinearGradient(colors: [accentFill, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Subtle wash for selected-but-not-prominent states (chip backgrounds, highlights).
    var wash: Color { accent.opacity(0.14) }
}

// MARK: - \.palette environment injection

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: AccentPalette = .brandDefault
}

extension EnvironmentValues {
    /// The active accent palette. RootView reads @AppStorage("sggs_accent") and injects it
    /// here once — components read the environment, so an accent change re-renders the tree
    /// without any .id() resets (navigation state survives).
    var palette: AccentPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Fixed (non-accent) tokens

/// Surfaces, status colors, hairlines: shared by every accent. Light legs alias system
/// colors where a List owns the background (native feel, zero light-mode churn); dark
/// legs are the designed warm-ink ramp.
enum Ink {
    // MARK: surfaces
    /// Screen canvas behind custom (non-List) layouts.
    static let canvas = Color(lightSystem: .systemGroupedBackground, dark: 0x151210)
    /// Cards that draw their own background.
    static let card = Color(lightSystem: .secondarySystemGroupedBackground, dark: 0x1E1A17)
    /// Raised elements on a card (stat tiles, chips).
    static let raised = Color(lightSystem: .tertiarySystemGroupedBackground, dark: 0x282320)
    /// The Reader's page — warm paper in light, deep ink in dark (the hero surface).
    static let paper = Color(light: 0xFBF7F0, dark: 0x171412, lightHC: 0xFFFFFF, darkHC: 0x0E0C0A)
    /// Hairline borders (replaces shadows in dark, where shadows die on ink).
    static let hairline = Color(UIColor { traits in
        let hc = traits.accessibilityContrast == .high
        return traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: hc ? 0.22 : 0.12)
            : UIColor(white: 0, alpha: hc ? 0.16 : 0.08)
    })

    // MARK: status (replaces every raw .green/.red/.blue/.purple in Screens/Components)
    /// Verified / positive.
    static let positive = Color(light: 0x27703F, dark: 0x5BC98C, lightHC: 0x1E5731, darkHC: 0x7DD9A6)
    /// Failed / not-found / destructive.
    static let negative = Color(light: 0xB33528, dark: 0xFF7A6B, lightHC: 0x8E2A20, darkHC: 0xFF9C8F)
    /// Informational / linked.
    static let info = Color(light: 0x2A63C9, dark: 0x7FB0FF, lightHC: 0x2050A5, darkHC: 0xA3C6FF)
    /// Special / categorical (Vaars, divergence traditions).
    static let special = Color(light: 0x6D3FBF, dark: 0xB79AF2, lightHC: 0x58309C, darkHC: 0xCDB6F7)
}

// MARK: - Elevation

/// Shadow tokens. Dark mode intentionally has NO shadow — cards get an Ink.hairline
/// border instead (Phase-3 Card applies scheme-appropriately).
enum Elevation {
    /// Card resting shadow (light scheme only).
    static let cardShadowColor = Color.black.opacity(0.06)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 2
    /// Floating sheet/hero shadow (light scheme only).
    static let heroShadowColor = Color.black.opacity(0.12)
    static let heroShadowRadius: CGFloat = 20
    static let heroShadowY: CGFloat = 8
}

// MARK: - Motion

/// The app's two animation curves. EVERY animation routes through the Reduce-Motion-aware
/// helpers in Components/Motion.swift — never call withAnimation directly in screens.
/// Springs stay ≤0.3 s so XCUITest waitForExistence never flakes.
enum Motion {
    static let spring = Animation.snappy(duration: 0.28)
    static let gentle = Animation.smooth(duration: 0.22)
}
