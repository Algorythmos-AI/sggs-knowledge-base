# SGGS iOS — TestFlight Readiness Report (2026-09-05)

**Build under review:** iOS app `org.sggs.app` **1.1.1 (3)** + widget `org.sggs.app.widgets` · web/server **v2.12.1** · bundled DB profile **personal** (`db_sha256 384f53a1…`, `scripture_sha256 0eff4bae…`, unchanged).
**Scripture:** byte-identical — `git diff -- corpus db ios/Resources` empty throughout; `/api/health` all-true; reconcile/golden not re-run (no corpus change; PyMuPDF not installed on this machine — the DB hash chain is the proof).

## 1. What was audited
Four exploration passes over every iOS source file, the Swift kit, all tests, CI, plists/entitlements/privacy manifest, and the web server + Astro frontend; then an adversarial review of every proposed fix against the code before applying it (three proposals were dropped or corrected as a result — see CHANGELOG). Everything applied is in `CHANGELOG.md` (iOS 1.1.1 / v2.12.1).

## 2. Verification results
| Gate | Result |
|---|---|
| Kit parity (vendored SQLite 3.51.0, 8 golden suites incl. 2,183 pahar + 24,719 roman_norm) | **17/17** after the Pahar guards and the verify-fold port |
| App unit tests (SGGSTests) | **30/30** (24 + 2 sheet-host latch + 4 SwiftData ladder incl. old-store upgrade gate) |
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
