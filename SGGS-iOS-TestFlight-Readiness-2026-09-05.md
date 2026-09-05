# SGGS iOS — TestFlight Readiness Report (2026-09-05)

**Build under review:** iOS app `org.sggs.app` **1.1.1 (3)** + widget `org.sggs.app.widgets` · web/server **v2.12.1** · bundled DB profile **personal** (`db_sha256 384f53a1…`, `scripture_sha256 0eff4bae…`, unchanged).
**Scripture:** byte-identical — `git diff -- corpus db ios/Resources` empty throughout; `/api/health` all-true; reconcile/golden not re-run (no corpus change; PyMuPDF not installed on this machine — the DB hash chain is the proof).

## 1. What was audited
Four exploration passes over every iOS source file, the Swift kit, all tests, CI, plists/entitlements/privacy manifest, and the web server + Astro frontend; then an adversarial review of every proposed fix against the code before applying it (three proposals were dropped or corrected as a result — see CHANGELOG). Everything applied is in `CHANGELOG.md` (iOS 1.1.1 / v2.12.1).

## 2. Verification results
| Gate | Result |
|---|---|
| Kit parity (vendored SQLite 3.51.0, 8 golden suites incl. 2,183 pahar + 24,719 roman_norm) | **17/17** after the Pahar guards and the verify-fold port |
| App unit tests (SGGSTests) | **33/33** (24 + 2 sheet-host latch + 4 SwiftData ladder incl. old-store upgrade gate + 1 watchdog + 2 line-level routing) |
| App UI tests (SGGSUITests) | see §2.1 — final run recorded there |
| Release gate `check_release_license.sh` | public profile OK · personal BLOCKED with `LICENSED: false` · OK with a `LICENSED: true` attestation · CI YAML parses; the CI step was simulated locally end-to-end |
| Web search harnesses (roundtrip 400 · casual 300 · chaos 10 attack files) | **byte-identical** to the pre-pass baseline |
| Web hostile-integer probes (9 routes) | 500 → **400/200**, zero tracebacks; cache headers correct |
| Live `/api/verify` vs regenerated golden | 17/17 in-band (the 18th, an empty claim, is a 400 at the HTTP layer as before) |
| Browser smoke (Claude Browser) | reader pin stores verbatim `੍ਯ੍ਯ` while the DOM shows the painted saroop; URL follows Ang/query; themes 54 tiles with Akāl/Kaal in "The Divine Reality"; constellation rapid-select → 1 SVG, 0 focusable stars; insights slider max 1 and table follows it (min PPMI 1.36 at 1.0); raag-clock `role=group`, 10 keyboard arcs, no inline `goReader(...,'…')`; composition modal is saroop-painted; drawer is a `dialog`; 404 page renders |

### 2.1 Final XCUITest run
Full `xcodebuild test` on iPhone 17 (iOS 26.5): **SGGSTests 30/30**; **SGGSUITests 21/22** in the full run, and the one failure (`testVerifyShowsVerdict`, a pre-existing test) **passed when rerun alone** — an order-dependent flake of the `.searchable` field after the horizontal pill drag, not a product defect (it passed in every earlier full run today). Every other test, including the five new ones and the Reader page-bar tests, is green.

### 2.2 Golden verify vectors that changed (W3 — verify fold now equals the indexed fold)
| Claim | Before | After |
|---|---|---|
| `pavan guru pani pita mata dharti mahat` | NOT_FOUND 0.4545 | **VERIFIED 1.0 → line 380, Ang 8** |
| `pavan guroo paanee pitaa maataa dharat mahat` | VERIFIED_EXACT (ratio 0.6957) | VERIFIED_EXACT (ratio 1.0) |
| `satgur kirpa` · `waheguru` | NOT_FOUND (no FTS hits) | NOT_FOUND (candidates now found, ratio 0.5 / 0.667, confidence 0) |
| `ਨਾਨਕ ਸੋਨੇ ਦੀ ਚਿੜੀਆ ਉਡ ਗਈ` · `ਨਾਨਕ ਨਾਮ ਚੜ੍ਹਦੀ ਕਲਾ` · `naam*` | NOT_FOUND with 0.43 / 0.53 / 0.22 "confidence" | NOT_FOUND, confidence **0** |
Python and Swift changed in the same commit; `VerifyParityTests` green on the regenerated contract.

### 2.3 Found only by driving the simulator (not by any audit agent)
The Reader's Previous / Hukam / Next bar was invisible on iOS 26 — SwiftUI draws a `.bottomBar` toolbar under the floating tab bar inside a `TabView`. Baseline screenshot `ios/App/new_shots/light/reader.png` (12 Jul) shows the same. Replaced with a bottom safe-area capsule (`readerPageBar`). Lesson recorded: every button must be *seen* on the current OS, not just found by XCUITest.

## 2.4 Pre-merge audit pass (same day, second commit)
| Gate | Result |
|---|---|
| `git diff main...branch -- corpus/ db/ ios/Resources/sggs-ios.sqlite` | empty; bundled DB sha `384f53a1…` = manifest; `scripture_sha256 0eff4bae…` |
| `pipeline/timing/guard_scripture.py` (db/sggs.sqlite vs `audit/scripture-baseline.json`) | **GUARD PASS — all 46 pre-existing tables byte-identical; corpus unchanged; FKs clean** (output in the audit log) |
| Release-licence gate | public OK · personal BLOCKED without attestation · OK with it |
| Token grep gate (`Color(red:|hue:)`, system colours, hex outside DesignTokens; documented exclusions: decorative Canvas dial arcs in ClockScreen, PRNG seeds in InsightsViz) | 0 leaks |
| Motion gate (`withAnimation` outside Motion.swift) | 0 |
| ThemeContrastTests (4 accents × light/dark × contrast) | 6/6 |
| Kit parity | 17/17 |
| **One uninterrupted `xcodebuild test`** (iPhone 17, iOS 26.5, `SGGS_UITEST=1`) | **31 unit + 22 UI, 0 failures, 406 s** (attempt 3; attempts 1–2 exposed the test-side issues below, all fixed) |
| Dynamic Type AX3 (`accessibility-extra-extra-extra-large`) | **Bug found and fixed:** scripture inside `List` rows (search results, composition sheet) truncated with "…" because self-sizing cells under-measure the custom-font text with large line spacing; the Reader (LazyVStack) was unaffected. Fix: vertical `fixedSize` on `GurmukhiText` and the translit/English texts; Search idle guidance now scrolls. Verified by screenshots before/after. Lineage fixed-width labels replaced by min-widths; pills never wrap. |
| Sheet protocol race | `flushIfIdle()` watchdog on scene-active that can never present mid-dismiss (unit-tested: `testWatchdogNeverPresentsMidDismiss`); simulator rapid-fire `sggs://hukam` → `shabad/1` → `theme/naam` within 1 s: last modal shown, Done works, no stranded state |
| iPad (iPad Pro 11-inch M5 simulator, iPadOS 26.5, created locally) | Behavioural subset 6/6 (launch, search→shabad, Explore hub, Reader, sheet Done, Raag Clock). **Bug found and fixed:** after any search the top tab bar vanished for the rest of the search presentation — no way to leave the Search tab (screenshot `ipad_portrait_after_search.png`). Fix: `.searchPresentationToolbarBehavior(.avoidHidingContent)`. Regular-width caps added (Reader capsule 520 pt, Clock dial 420 pt, Explore grid 720 pt). Portrait + landscape capture set in the audit shots. Multi-scene remains off by design. |
| XCUITest resilience | `launchApp()` (env reset of resume-Ang/translit only — never the accent), `tearDown` terminates the app, tab switches verified by destination nav bar with retry, keyboard-focus verified before typing, context-menu retry, no `sleep`, no single-frame `.exists` after animations, Verify/English tests type first then switch mode |

## 2.5 Reader & Shabad UX pass (third commit, 2026-09-06)
Scroll-anchoring method: **Reader** — `ScrollView.scrollPosition(id:anchor: .center)` bound to a landing id with `LazyVStack.scrollTargetLayout()`: the requested verse is set as the page's *initial* scroll position before the page loads and re-asserted once the page-turn insertion has settled. Two `ScrollViewReader.scrollTo` variants were dropped by that transition (a proxy also cannot address rows a lazy stack has not created), and an interim eager `VStack` made accessibility snapshots stall for minutes (two Reader XCUITests took 13–15 min in an otherwise green run) — so the final shape is lazy rows + `scrollPosition`, which resolves ids the layout has not materialised. Same-Ang re-landing uses nil-then-set on the binding, and every landing re-asserts the position once the page-turn insertion has settled (0.35 s; instant under Reduce Motion) because a position set during the animated insert was observed not to take on iOS 26.5. A `landingInProgress` guard keeps the ambient chrome from reading the programmatic scroll as "reading down" (the same guard exists on the web as `landingUntil`). **Sheet** — `List` + `ScrollViewReader` two-pass `scrollTo` (unanimated → materialise the lazy row; next main-queue turn animated `anchor: .center`), highlight via `FocusHighlight` (accent 0.18, 1.6 s), VoiceOver focus via `@AccessibilityFocusState` 0.4 s after the scroll. Web: `element.scrollIntoView({ block: 'center' })` (smooth unless reduced motion) for the Reader; explicit `#panel.scrollTop` arithmetic for the modal (the fixed panel is the scroller, not the window). Components updated: `AppContainer` (presentation model), `ShabadSheet`, `ReaderScreen`/`ReaderModel`, `Router`, `SpotlightIndex`, `FocusHighlight` (new), six call-site screens; web `core.ts`, `reader.ts`, `panel.ts`, `studytrail.ts`, `trail.ts`, `global.css`. Browser-verified: `/reader?ang=263&line=11655` focuses the verse (activeElement) with the flash and keeps the URL; ArrowRight paging paints from cache with no "Loading" hint and drops `line` from the URL; Ang 262 shows "continues on Ang 263", Ang 263 shows "continues from Ang 262"; search card → modal scrolled/focused on the tapped line, its Open button carries `data-go-line`. (The embedded browser pane was hidden during the chrome-hide check — `requestAnimationFrame` does not run there — so that behaviour was verified by code review and on iOS in the simulator.)
Evidence (audit shots dir): **AX2** (`accessibility-extra-extra-large`) — `ax2_search_idle.png`, `ax2_search_results.png` (verses wrap fully), `ax2_reader_landed.png` (deep-linked verse centred, chrome intact), `ax2_sheet.png` (landed sheet; footer "Open Ang 2 in Reader" wraps inside its capsule); text size restored to `large`. **iPad Pro 11" (iPadOS 26.5)** — behavioural subset incl. the new landing test 6/6, landscape capture set `ipad_final_landscape_*.png`. **Deep links** — `sggs://ang/2?line=49` and `sggs://shabad/3?line=49` land on the verse (`land_lazy.png`).
Invariant: `git diff --stat -- corpus/ db/ pipeline/ webapp/serve.py webapp/verify.py ios/Packages` empty (recorded at commit time).

#### 2.5a Final matrix on the final code (2026-09-06)
Kit 17/17 · unit **33/33** · UI **26/26** in **one uninterrupted `xcodebuild test`** (510 s, no test over 60 s) on iPhone 17 / iOS 26.5 with `SGGS_UITEST=1` (Debug scheme; the reset is `#if DEBUG`). Two earlier attempts on the same day: attempt 1 hit a 60 s accessibility-snapshot stall in `testReaderChromeReturnsOnScrollUp` (25/26); attempt 2 was 26/26 but two Reader tests took 13–15 min — traced to the interim eager `VStack` and fixed by returning to `LazyVStack` with `scrollPosition(id:)`. Token/motion gates 0; Release settings 1.1.1 (3) automatic signing on both targets; privacy manifest `C617.1` + `CA92.1`.

## 2.6 Licence attestation — current state
`ios/Resources/TRANSLATION-LICENSE.md` reads **`LICENSED: false`**. Consequently `pipeline/check_release_license.sh ios/Resources/sggs-ios.manifest.json` reports **RELEASE GATE: BLOCKED** for the English-bundled (personal) profile — by design — while the public profile passes. Only the rights holder's written licence, recorded in that file by the user, flips this. Nothing in this pass claims otherwise.

## 3. Load-bearing UI strings (do not change without the XCUITest suite open)
"What raag is it now?", "4th pahar of day  ·  3–6 PM", "30 voices · 12th–17th century", "MAJOR COMPOSITIONS — QUICK ACCESS", "Explore the Granth", "Related verses", "Strongest pairs", "Strongest resonances", "Anatomy in reading order", "Theme emphasis (lift)", "lines preserved", "Accent", "Show English translation", "Where traditions disagree", "Deliberately silent", "Explore related", "Open", "Done", "Hukam", "Save", "Saved verses", "About & credits", "No saved verses", "Search the Granth", "Roman"; nav titles Search/Index/Themes/Vaars/Constellation/More/Saved, "Ang N" and "Hukam · Ang N"; identifiers `mode_*`, `insights_*`, `index_*`, `jumpToAng`, `angField`, `goToAng`, `divergenceLink`, `compareVoices`, `searchIdle`, `aboutVersion`, `retryButton`, `unknownRaagNote`, accent labels.

## 4. Human-gated — must be done by you before uploading
1. **Apple Developer Program**: confirm the membership is *active* (enrolment `9RL2RGCQSJ`, order `W1582299895` was "Pending" on 12 Jul). Nothing below works until it is.
2. **Signing**: in App Store Connect / developer.apple.com register App IDs `org.sggs.app` and `org.sggs.app.widgets`, create App Group `group.org.sggs` and attach it to both; put your Team ID into `ios/App/project.yml` (`DEVELOPMENT_TEAM` under the **Release** config of *both* targets), then `xcodegen generate`.
3. **Translation licence**: when the written licence is in hand, fill `ios/Resources/TRANSLATION-LICENSE.md` and set `LICENSED: true` in the same commit. Until then the release gate blocks this build by design (`pipeline/check_release_license.sh ios/Resources/sggs-ios.manifest.json`).
4. **Archive & upload** (from `ios/App`, after 2):
   ```bash
   xcodebuild -project SGGS.xcodeproj -scheme SGGS -configuration Release -destination "generic/platform=iOS" -archivePath build/SGGS.xcarchive archive -allowProvisioningUpdates
   ```
   then `xcodebuild -exportArchive -archivePath build/SGGS.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates` with an `ExportOptions.plist` of `method = app-store-connect`, `teamID = <yours>`; upload with Transporter or `xcrun altool --upload-app` / an App Store Connect API key. Bump `CURRENT_PROJECT_VERSION` for every subsequent upload.
5. **First real-device run** (never done): install via Xcode, then check More → About → Integrity shows "Widget App Group available" (the simulator always says available), add both widgets, open `sggs://hukam` from Safari.
6. **Granthi / scholar review**: placeholder app icon (ੴ), default-ON saroop rendering (Sant Lipi inline addha-yayya — see `../SGGS-Gurmukhi-Display-Font-Plan-2026-06-20.md`).
7. **On-device accessibility pass**: `ios/App/Tests/UI/A11Y_CHECKLIST.md` items that need VoiceOver/AX5 on hardware.
8. **App Store Connect record**: category Reference (also in the bundle), age rating, privacy questionnaire (no data collected, location on-device only — matches `PrivacyInfo.xcprivacy`), screenshots.

## 4b. Simulator click-through (iPhone 17, iOS 26.5)
Search idle guidance · Reader with visible Previous/Hukam/Next capsule (resume-last-Ang to 1429 honoured) · Reader page turn · Hukam sheet → Done returns to Reader · `sggs://ang/500` · `sggs://clock/nosuchraag` (note shown, current watch kept) · `sggs://theme/naam` (pushes Themes → Naam with a working Back) · `sggs://shabad/999999999` ("Composition not found" + Done) · `sggs://hukam` (XCUITest, live system open). **No iPad simulator is installed on this Mac** — the iPad layout (multi-scene deliberately off) was not exercised; do it on hardware or install an iPad runtime.

## 5. Deferred (documented, not blocking)
- `CorpusActor` operations are not cancellable mid-query (measured worst case 19 ms; fine today, revisit if heavier analytics land).
- Trail/Cluster → Shabad replaces the sheet (breadcrumb is lost) — intentional single-root-sheet design; watch for TestFlight feedback.
- Web: `min_ppmi` API clamp at 1.0 kept (slider aligned to it) rather than widened, to keep the Python↔Swift contract untouched.
- `contract/_meta.json` now records the host generator's Python 3.14 / SQLite 3.53 — informational only; `db_sha256` unchanged.
