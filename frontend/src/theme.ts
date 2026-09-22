// theme.ts — Soul-Gold design tokens for the Gurbani Soul marketing site, as a plain object.
//
// The hex values are the light + dark legs of docs/brand/tokens.json (soul.* + surfaces.*); the
// `WebThemeMatchesTokens` gate in webapp/tests/test_repo_gates.py asserts they stay in step, so
// tokens.json remains the single source of truth. marketing.css mirrors these onto CSS variables;
// the OG image endpoint reads them for its palette. `ink` follows the brand book's warm ink (it is
// not a tokens.json surface); `red` is brand.red — reference only, never text and never beside
// Gurmukhi (see docs/brand/gurbani-soul-brand-book.md §3.1).
export const theme = {
  light: {
    paper: "#FBF7F0",      // surfaces.paper[0]
    paperWarm: "#FDF6E3",  // surfaces.paperWarm[0]
    card: "#FFFFFF",       // surfaces.card[0]
    ink: "#201A12",        // warm ink (brand book)
    accentFill: "#FFBC0D", // soul.accentFill[0] — bordered fill only in light
    accent: "#A87900",     // soul.accent[0] — borders/icons
    accentText: "#8A6100", // soul.accentText[0] — gold words
    onAccent: "#2B1A05",   // soul.onAccent[0]
    red: "#DA291C",        // brand.red[0] — fill-only, reference
  },
  dark: {
    paper: "#171412",      // surfaces.paper[1]
    paperWarm: "#171412",  // surfaces.paperWarm[1]
    card: "#1E1A17",       // surfaces.card[1]
    ink: "#F3ECDD",        // warm ink (brand book)
    accentFill: "#FFBC0D", // soul.accentFill[1]
    accent: "#FFBC0D",     // soul.accent[1]
    accentText: "#FFBC0D", // soul.accentText[1]
    onAccent: "#2B1A05",   // soul.onAccent[1]
    red: "#DA291C",        // brand.red[1] — fill-only, reference
  },
} as const;

export type ThemeTokens = typeof theme.light;
export default theme;
