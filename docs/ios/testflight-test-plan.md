# SGGS iOS — TestFlight test plan

How the app is tested on TestFlight before App Store submission. The [launch plan](testflight-launch-plan.md)
says *when* each part runs; this file says *what* is run and how results are recorded.

Principles:
- **Scripture first.** Every build gets Charter S, signed by a named person. A rendering bug in a
  verse outranks any crash.
- **Real hardware, current OS.** The simulator has already been exhaustively driven (readiness
  report). TestFlight exists to find what only devices show: the Reader page bar under the iOS 26
  tab bar was found only by *looking* at a device-class screen.
- **A charter is a script with an expected result**, not "play with it". Free exploration is
  welcome on top, and is reported the same way.

---

## 1. Device matrix

Minimum set for the Phase C exit. Fill the "who" column from the tester roster.

| Slot | Device class | OS | Why | Who |
|---|---|---|---|---|
| 1 | Current flagship iPhone (6.9") | latest iOS 26.x | primary screenshots, Dynamic Island, floating tab bar | |
| 2 | Compact iPhone (SE-class or 6.1") | latest | small width: pills, capsule, keyboard overlap | |
| 3 | Oldest iPhone that runs iOS 17 (iPhone XS/XR class) | iOS 17.x | cold-start hash time, memory with a 108 MB DB, deployment floor | |
| 4 | iPhone on iOS 18.x | 18.x | the OS most of the sangat is on | |
| 5 | iPad (13" or 11") | latest iPadOS | regular-width caps, search-presentation toolbar, landscape | |
| 6 | Any iPhone with VoiceOver + AX5 text | latest | Charter A on hardware | |
| 7 | Any iPhone, non-English region/locale (pa-IN or hi-IN keyboard) | any | Gurmukhi keyboard input in search | |

Settings that must be exercised at least once each: dark mode, Reduce Motion, Bold Text,
Larger Accessibility Sizes (AX3+), Low Power Mode, location denied.

## 2. First-device checklist (maintainer)

Run on one physical iPhone before the first build reaches any tester. All must pass.

- [ ] Cold launch to the Reader with no integrity failure screen; note the launch time on the device.
- [ ] Second launch is visibly faster (launch cache hit); About → Integrity shows every check green.
- [ ] About → Integrity: **Widget App Group available**; diagnostics collected = 0.
- [ ] Add the Raag-now widget and the Hukam widget to the Home Screen; both render Gurmukhi in Sant Lipi (not a fallback font).
- [ ] Open a Hukam in the app; the Hukam widget shows that verse on its next refresh.
- [ ] Safari: `sggs://hukam` opens the app on a Hukam sheet; `sggs://ang/500` lands on Ang 500.
- [ ] Siri / Shortcuts: "Today's Hukam", "What raag is it now", "Open Ang" (with 1430) all work.
- [ ] Save a verse; Spotlight finds it by Gurmukhi and by transliteration; tapping opens the verse centred and highlighted.
- [ ] Raag Clock → Solar: location prompt shows the exact purpose string; deny → manual entry works; allow → sunrise/sunset shown.
- [ ] More: the **English translation toggle is absent** (public profile) and the About credits do not mention the English layer.
- [ ] Rotate to landscape in the Reader and the Clock; nothing clips; rotate back.
- [ ] Background the app for 10 minutes, return: state intact, no re-hash.

## 3. Test charters

Each charter: steps → expected. Report deviations with the charter letter, the build number, the
device slot, and a TestFlight screenshot. "P" = priority (see §5).

### S — Scripture fidelity (mandatory, signed, every build)
Compare against a printed Bir or a trusted second source. **Never "fix" the text in the app —
report it** via the `scripture-fidelity` issue template.
1. Ang 1: Mool Mantar begins `ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ` and Japji follows without a gap.
2. Ang 712: the composition sheet opens with the printed heading `ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ` above `ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥`.
3. Ang 1256: the repeated refrain appears twice — this is correct and must not be reported as a duplicate.
4. Ang 1400: `ਜਲ੍ਯ੍ਯਨ` / `ਧਰ੍ਯ੍ਯਉ` render with a single tucked addha-yayya when the saroop toggle is on, and verbatim doubled when off; **Copy** always yields the verbatim text (paste into Notes to check).
5. Ang 1430 (Raagmala): last lines present; Next is disabled at the end; Previous from Ang 1 is disabled.
6. Pick 5 random Angs (use the Hukam button 5 times) and read one full verse each against the source. Record the Angs.
7. Dandas `॥`, numerals `॥੧॥`, and `ਰਹਾਉ` markers are present and positioned as printed.
Expected: zero deviations. Sign: name, build, device, date in the build log.

### R — Reader
1. Jump to Ang via the field (1, 1430, 0, 1431, "abc") → 0/1431/"abc" rejected, others land.
2. Swipe page turn forwards and back 10 times quickly → no skipped or duplicated Angs; the "continues on Ang N" note matches.
3. Quit and relaunch → the Reader resumes on the last Ang.
4. Reading options: Sehaj focus, saroop toggle, transliteration toggle; each persists across relaunch.
5. Deep link `sggs://ang/263?line=11655` → the verse is centred, highlighted, chrome intact.
6. Dynamic Type AX3: no verse truncated with "…" anywhere (Reader, search rows, sheet).

### Q — Search
1. Gurmukhi: `ਨਾਮੁ` → results; first result opens a sheet scrolled to the tapped line with its Open button.
2. Roman: `waheguru`, `satgur kirpa`, `pavan guru pani pita` → sensible top results; the third finds Ang 8.
3. First letters: `ਸ ਨ ਕ ਪ` mode → Mool Mantar line among results.
4. Theme mode: `naam` → the Naam theme result set.
5. Hostile: `"`, `*`, 500-character string, emoji → no crash, an empty or reasonable state, the field stays usable.
6. Rapid mode-pill switching while typing → no stuck keyboard, no lost query.
7. No "English" mode pill is offered (public profile).

### H — Hukam and sheets
1. Hukam → a complete unit with heading; Done returns exactly where you were.
2. Open five Hukams in a row; Save one; it appears in Saved with the right Ang.
3. From a sheet, "Explore related" → Trail; back out cleanly; no stacked or stranded sheets.
4. Rotate while a sheet is open; sheet survives.

### C — Raag Clock
1. Fixed mode: the current pahar and raags match the readiness strings ("4th pahar of day · 3–6 PM" style).
2. Solar mode with location allowed: sunrise/sunset shown; with denied: note + manual entry.
3. Tap each pahar arc → claims sheet; "Where traditions disagree" opens Divergence.
4. `sggs://clock/nosuchraag` → note shown, current watch kept.

### E — Explore hub
1. Index → each major composition opens at the right Ang.
2. Themes → 54 tiles; Naam opens; a line tap opens its sheet.
3. Lineage → timeline filters; open a profile; compare two voices; the radar has a table alternative.
4. Insights → network, resonance, flow: each renders, and the list/table alternative is present.
5. Constellation → rapid-select several concepts → one SVG-equivalent view, no hang.
6. Vaars → 22 ballads; anatomy shows salok/pauri structure.

### V — Saved, Trail, Spotlight, Share
1. Save, unsave, re-save; Saved list order and count correct after relaunch.
2. Share a verse → the share card carries the Ang citation; image renders Gurmukhi correctly.
3. Trail: pin a verse; the pin's text is verbatim (paste check), not the saroop-painted text.
4. Spotlight finds only saved verses; unsaving removes it.

### W — Widgets, Siri, deep links
1. Both widgets in small/medium; timeline advances across a pahar boundary (check at the boundary time).
2. Widget tap → app opens on the relevant screen.
3. All four App Intents from Siri and from Shortcuts, including a parameterised "Open Ang 1430".
4. Every `sggs://` route in the readiness report: `hukam`, `ang/N`, `shabad/N?line=`, `theme/naam`, `clock/<raag>`, `search?q=`, `shabad/999999999` (not-found + Done).

### A — Accessibility (hardware)
Run `ios/App/Tests/UI/A11Y_CHECKLIST.md` end to end with VoiceOver, then:
1. AX5 text in Search, Reader, sheet, Clock list; nothing unreachable.
2. Reduce Motion: page turn and landing are instant; force layouts settle without animation.
3. Bold Text and Increase Contrast: accent contrast OK on all four accents (light and dark).
4. Keyboard focus and Full Keyboard Access on iPad.

### P — Performance and resilience
1. Cold launch time on slot 3 (record it); second launch faster.
2. Search p50 feels instant on slot 3 (type 10 queries).
3. Low storage warning state on the device: app still launches (it never writes the DB).
4. Kill during launch hash; relaunch → full re-verify, no corruption message.
5. Low Power Mode: no functional difference.

### U — Update over an existing install
1. Install build N, save 5 verses, set accent and toggles, resume Ang 700.
2. Install build N+1 over it via TestFlight.
3. Expected: saved verses intact, settings intact, resume Ang intact, About shows the new build, Integrity re-verified once (full hash) then cached.

### I — iPad
1. Portrait and landscape: Reader capsule ≤ 520 pt, Clock dial ≤ 420 pt, Explore grid ≤ 720 pt.
2. Search then leave Search: the top tab bar never vanishes.
3. Multitasking split view: the app is not resizable to a second scene (multi-scene is off by design) — confirm it just runs in one window.
4. External keyboard: arrows/Return in Search; Cmd-F focuses search if bound.

## 4. "What to Test" text (per build)

Paste into TestFlight → build → Test Details. Keep it under 4,000 characters.

> **SGGS build {build} — {one-line theme of the build}**
>
> This is a fully offline app for reading and searching Sri Guru Granth Sahib Ji. No account,
> no network, no tracking. Location is optional and stays on your device.
>
> **10-minute path:** open the app → read a page and turn it → search `ਨਾਮੁ` or `waheguru` →
> open a result → tap Hukam → save the verse → add the "Hukam" widget to your Home Screen →
> open More → About and tell us what Integrity says.
>
> **Please report:** anything in the Gurmukhi that looks wrong (tell us the Ang and the line —
> do not guess a fix), any crash, anything you could not read or reach with VoiceOver or large
> text, and anything that felt slow. Use TestFlight's screenshot feedback (take a screenshot,
> tap Share → Share Beta Feedback).
>
> **Known in this build:** {list or "none"}.

## 5. Feedback triage

Sources: TestFlight feedback (App Store Connect → TestFlight → Feedback, includes device/OS),
TestFlight crashes, GitHub issues (`bug`, `scripture-fidelity`), direct messages from the
scholar reviewers (transcribe into an issue the same day).

| Priority | Definition | Response |
|---|---|---|
| P0 | Any scripture rendering or text error; integrity failure on a good install; crash on launch | Stop the phase. Fix or root-cause before the next build. Scripture: never edit — flag for human review per CLAUDE.md. |
| P1 | Crash or hang in normal use; data loss (saved verses, settings); a screen unreachable with VoiceOver | Fix before the next phase. |
| P2 | Wrong but recoverable behaviour; visual defect on a supported device; performance clearly worse than the simulator budget | Fix before submission if small; otherwise document in "Known". |
| P3 | Polish, wording, wish list | Backlog with the `enhancement` label. |

Rules:
- Every report gets an issue with the build number and device slot, even if closed as duplicate.
- A fix is a PR into `integration` through `sggs-ship`; CI's iOS parity and app jobs must be green; then a new build number.
- A new build re-runs Charter S plus every charter the diff touched. The full matrix runs again before submission.
- Never weaken a test to get green; never skip Charter S.

## 6. Exit criteria

**Phase C (internal) → D (external):** every charter run on slots 1–6; zero open P0/P1; Charter S signed on the latest build.

**Phase D (external) → E (submission):** zero app-attributable crashes in TestFlight crashes for the
release-candidate build; all external P0/P1 closed; scholar sign-off on icon and default rendering
recorded; A11y checklist done on hardware; Charter U passed from the previous build to the candidate.

## 7. Build log

Every upload is recorded in the machine-readable ledger **`ios/testflight-builds.json`** — the
archive script appends a row automatically on `SGGS_UPLOAD=1`, and a Transporter upload is added
with `python3 ios/tools/testflight_ledger.py record ios/App/build/candidate-<version>-<build>.json --force`.
The ledger is the source of record and the pre-flight gate: `testflight_ledger.py check <version> <build> --strict`
rejects a reused build number or a marketing-version downgrade **before** an archive runs, so Apple's
"CFBundleVersion already used" rejection can't cost you a 20-minute upload. Commit the ledger with the
release. Charter-S sign-off stays a human step in [§6](#6-exit-criteria).
