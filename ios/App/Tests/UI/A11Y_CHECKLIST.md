# Accessibility checklist (manual VoiceOver / Dynamic Type pass)

Automated coverage: XCUITests assert element existence + labels; this script covers what
only a human with assistive tech can judge. Run before any release-readiness sign-off.

## VoiceOver (Settings → Accessibility → VoiceOver, or triple-click side button)

1. **Search results** — swipe through results: each verse is ONE element; the Gurmukhi is
   spoken with Punjabi pronunciation, then "English translation: …", then "Ang N · raag ·
   author". The Actions rotor offers: Copy verse, Share, Save, Explore related. Activate
   (double-tap) opens the composition.
2. **Reader** — the raag banner reads first; the timing chip announces "Traditional singing
   time … Opens the Raag Clock". Headers are headings (rotor: Headings jumps between them).
   Jump-to-Ang and Reading options are reachable from the top bar.
3. **Raag Clock** — the dial is skipped entirely (decorative); the pahar LIST carries the
   full content ("2nd pahar of day, 9 AM–12 PM, 6 raags, current watch"). The detail sheet
   reads every claim with its badges and source.
4. **Lineage** — rows read "name, kind, era, N lines preserved"; hint switches between
   profile/compare modes. The compare sheet's radar is skipped; the Grid table reads the
   exact lifts per theme.
5. **Insights** — Network/Resonance canvases are skipped; the list alternatives carry the
   data. Contributors/Raags charts are Swift Charts (audio-graph rotor available).
6. **Sheets** — every sheet has a reachable Done/Cancel; no focus traps.

## Dynamic Type (Settings → Accessibility → Display & Text Size → Larger Text)

7. At **AX5**: Gurmukhi scales (Sant Lipi via `relativeTo: .body` + the size preference);
   check for matra clipping on Ang 1 and Ang 1430 — stacked vowel signs must not collide
   with the line above (GurmukhiText adds 0.55em line spacing headroom; if clipping appears
   at AX sizes, adjust lineSpacing per size class — NEVER scale glyphs non-uniformly).
8. Search pills, Clock now-card, Lineage rows: text wraps, nothing truncates to ellipsis
   that loses meaning, hit targets stay ≥ 44 pt.

## Other

9. **Reduce Motion** — the network graph never animates a live simulation (settled before
   display by design); the Clock dial has no continuous animation; sheets use system motion.
10. **Increase Contrast** — saffron-on-white chips remain legible (borderline ramp — audit
    each release; tokens live in Theme.swift).
11. **Copy fidelity** — Copy verse / Share put the VERBATIM Gurmukhi (+ "— Sri Guru Granth
    Sahib, Ang N" citation on Share) on the pasteboard, never the saroop display form.

Known deviations (deliberate):
- The transliteration is NOT in the VoiceOver label: it is redundant phonetics for a
  listener already hearing the Punjabi audio, and doubles verbosity. It stays visible
  on-screen as a reading aid.
