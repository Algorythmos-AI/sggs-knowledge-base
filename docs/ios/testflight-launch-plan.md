# SGGS iOS — TestFlight → App Store launch plan

**Status:** TestFlight approved by Apple (2026-09-16). This document is the working plan from
"approved" to "live on the App Store". It has no dates on purpose: each phase has an entry gate
and an exit gate, and we move when the gate is met.

Companion documents:
- [TestFlight test plan](testflight-test-plan.md) — what testers do, on which devices, how feedback is triaged.
- [App Store listing](app-store-listing.md) — the draft metadata, privacy answers and review notes.
- [Readiness report (2026-09-05)](../../SGGS-iOS-TestFlight-Readiness-2026-09-05.md) — the audit this plan builds on.

---

## 0. Where the app stands today (evidence, not opinion)

| Area | State | Source |
|---|---|---|
| App target | `org.sggs.app` 1.1.3 + widget `org.sggs.app.widgets`, iOS 17+, iPhone + iPad, Swift 6 strict concurrency | `ios/App/project.yml` |
| Fidelity gate | Swift kit byte-parity with the Python source on the vendored SQLite 3.51.0, 8 golden suites (27,197 vectors); scripture hash `0eff4bae…` pinned in the release gate | `.github/workflows/ios.yml`, `contract/_meta.json` |
| Tests | kit 17/17 · unit 33 · UI 26 — all green in one uninterrupted simulator run | readiness report §2.5a |
| Launch integrity | fail-closed SHA-256 of the bundled DB against its manifest; the app refuses to show scripture on mismatch | `ios/App/Sources/Data/LaunchIntegrity.swift` |
| Privacy | no accounts, no network, no tracking; privacy manifest declares only UserDefaults + file-timestamp reasons; location optional, rounded, on-device | `PrivacyInfo.xcprivacy`, `Info.plist` |
| Crash evidence | MetricKit diagnostics written locally, count shown in More → About → Integrity | `CrashMonitor.swift` |
| Signing | `DEVELOPMENT_TEAM` empty in `project.yml` (by design — passed at archive time) | readiness §4.2 |
| Never done yet | a real-device install, widgets on hardware, VoiceOver on hardware, an upload to App Store Connect | readiness §4.5–4.7 |

### The one decision that shapes everything: which database ships

The bundled `personal` profile embeds Dr. Sant Singh Khalsa's English translation, which is
licensed for personal local study only. `ios/Resources/TRANSLATION-LICENSE.md` reads
`LICENSED: false`, so `pipeline/check_release_license.sh` **blocks** that artifact for
TestFlight and the App Store. This is deliberate and correct.

**Decision for launch: ship the `public` profile (Gurmukhi-only, with transliteration,
timing layer, analytics and everything else) to TestFlight and the App Store.** The app is
already capability-gated for it — the English toggle, English search mode and credit line
disappear when the `translations` table is absent, and `DegradationParityTests` pin that
behaviour. Pursue the written licence in parallel; when it is granted, fill the attestation,
flip `LICENSED: true` in the same commit, and the next build ships English as a point release.

Nothing else in the app is blocked on rights: the scripture is verbatim from the source
edition, Sant Lipi and Source Serif 4 (headings) are SIL OFL 1.1, and SQLite is public domain.

---

## 1. Phase A — Accounts, identifiers, signing (human, once)

Entry: Apple Developer Program membership active (Company/Organization membership for ALGORYTHMOS PTY LTD, active since 2026-09-16). Exit: a signed archive exists on a Mac.

Sign in to developer.apple.com and App Store Connect with the Apple ID that holds the membership — it is recorded in the private, git-ignored `apple-developer/` folder outside this repo, never here. The Team ID is on the Membership details page; it is passed on the command line at archive time and is not committed.

1. **App Store Connect → Apps → New App.** Platform iOS, bundle ID `org.sggs.app`, SKU
   `sggs-ios`, primary language English (UK or US — pick one and keep it), name per the
   [listing draft](app-store-listing.md) (check the name is free; have the fallback ready).
2. **Identifiers** (developer.apple.com → Certificates, Identifiers & Profiles):
   App IDs `org.sggs.app` and `org.sggs.app.widgets` with the **App Groups** capability; App Group
   `group.org.sggs` attached to both. Automatic signing creates the profiles.
3. **API key** (Users and Access → Integrations → App Store Connect API): role App Manager.
   Store the `.p8`, key ID and issuer ID in the `testflight` GitHub Environment as documented
   at the top of `.github/workflows/ios-testflight.yml`. Never paste a value into chat or a commit.
4. **First archive on a Mac** (this proves signing before CI is involved):
   ```bash
   git lfs pull
   make testflight TEAM_ID=<your Team ID> BUILD=1
   ```
   The script derives the public DB, runs the release gate, generates the project, archives with
   automatic signing, exports an `.ipa`, and then proves the version, build, widget version and
   the DB hash *inside* the archived `.app`. If it ends with `OK`, signing works.
5. **Build-number rule:** `CURRENT_PROJECT_VERSION` in `project.yml` stays at `1` as a floor;
   every upload passes `BUILD=N` explicitly and N only goes up within a marketing version. The archive
   script gates this before doing any work — `testflight_ledger.py check <version> <build> --strict`
   (run automatically on `SGGS_UPLOAD=1`) rejects a reused build number or a lower marketing version,
   and `make testflight-next` prints the next number. Each upload is recorded in the tracked ledger
   `ios/testflight-builds.json` (see [the build log](testflight-test-plan.md#7-build-log)); commit it.

## 2. Phase B — First device run (human, before any tester sees it)

Entry: Phase A archive. Exit: the "first-device checklist" is all green on one physical iPhone.

Install from Xcode (or the exported `.ipa` via Apple Configurator) and walk the checklist in
[test plan §2](testflight-test-plan.md#2-first-device-checklist-maintainer). The items that the
simulator cannot prove and that have never been seen on hardware:
- More → About → Integrity shows **Widget App Group available** (the simulator always says so).
- Both widgets render (Raag-now timeline, Hukam verse) and update after opening a Hukam in the app.
- `sggs://hukam` from Safari, Siri "Today's Hukam", Spotlight for a saved verse.
- Location prompt copy, denial path, and manual-entry fallback on the Raag Clock.
- Cold launch time with the 108 MB DB on the oldest device you own; the fail-closed screen is
  never seen on a good install.

Anything red here is fixed before Phase C. Nothing goes to testers with a known integrity failure.

## 3. Phase C — Internal TestFlight (up to 100 App Store Connect users, no Beta review)

Entry: Phase B green, build uploaded (`make testflight … UPLOAD=1` or the manual workflow).
Exit: the full charter set has been run on the device matrix with zero P0/P1 open.

1. Upload build N. Processing takes 10–30 minutes; the export-compliance question is already
   answered by `ITSAppUsesNonExemptEncryption = false` in `Info.plist`.
2. Create the internal group "SGGS core" and add the maintainers' Apple IDs. Enable automatic
   distribution so every processed build reaches the group.
3. Paste the "What to Test" text from [test plan §4](testflight-test-plan.md#4-what-to-test-text-per-build).
4. Run every charter in [test plan §3](testflight-test-plan.md#3-test-charters) across the
   [device matrix](testflight-test-plan.md#1-device-matrix). Charter S (scripture fidelity spot
   checks) is mandatory on every build and is signed by a named person.
5. Triage per [test plan §5](testflight-test-plan.md#5-feedback-triage). Fixes land through the
   normal flow (`sggs-ship` → `integration`), then a new build number — never a hot-edited archive.
6. After each fix build, re-run the charters the fix touched plus S; the full set again before
   moving to Phase D.

## 4. Phase D — External TestFlight (Beta App Review, public link)

Entry: Phase C exit. Exit: external feedback triaged, crash-free across the external population,
scholar sign-off recorded.

1. Create an external group "Sangat beta". The first external build goes through **Beta App
   Review** (usually under a day); fill the Beta App Information: description, feedback email,
   marketing URL, privacy policy URL, and the review notes from the [listing draft](app-store-listing.md#review-notes).
2. Enable the **public link**, cap it (start at 200), and share it with a Granthi/scholar circle
   and a few gurdwara-community testers. Ask for iPads, older iPhones, and VoiceOver users.
3. Ask every external tester to run the "10-minute path" in [test plan §4](testflight-test-plan.md#4-what-to-test-text-per-build)
   and to submit feedback through TestFlight's screenshot feedback, which lands in
   App Store Connect → TestFlight → Feedback with device and OS attached.
4. **Scholar review is a gate, not a nicety.** Two items in the readiness report are pending it:
   the app icon (brand-book concept A: gold ੴ in Sant Lipi on warm ink — see
   `docs/brand/gurbani-soul-brand-book.md` §5, gate G3) and the default-ON saroop rendering (Sant Lipi's inline addha-yayya
   is a legitimate but different typographic tradition from the printed Bir). Record the outcome
   in the build log; if the default changes, it is one line in `ios/App/Sources/Components/Saroop.swift`
   and the web `saroop.ts`, plus a CHANGELOG entry.
5. Watch App Store Connect → TestFlight → Crashes and the About → Integrity diagnostics count
   testers report. The exit standard is zero crashes attributable to the app across the matrix.

## 5. Phase E — App Store submission

Entry: Phase D exit and the release-candidate build already on TestFlight (the same build is
submitted — no new archive). Exit: "Ready for Sale".

1. **Repo release first.** The submitted build must correspond to a tagged release so the
   commit in `candidate-*.json` is a `main` commit: follow `sggs-release` (`integration → main`
   merge commit, verified production deploy, `vX.Y.Z` tag). iOS, web and API share one version
   (ADR-0004), so the App Store version equals the tag.
2. **App Store Connect → App Information / Version:** fill everything from the
   [listing draft](app-store-listing.md): name, subtitle, category Reference, description,
   keywords, support URL, privacy policy URL, age rating questionnaire (4+), App Privacy
   ("Data Not Collected"), content rights ("does not contain third-party content" is **false** —
   declare the source edition and Sant Lipi as documented), screenshots for 6.9", 6.5" and
   13" iPad, and the review notes.
3. **Select the TestFlight build**, enable **phased release** (7-day staged rollout, you can
   pause), and choose manual release after approval so the release note, the web release and
   the announcement go out together.
4. Submit. Expected review time is 24–48 hours. Common rejection risks and what is already in place:
   - 2.1 crashes/bugs — Phase C/D exit standard.
   - 4.2 minimum functionality — full offline reader, search, Hukam, widgets, Siri, Spotlight; far above the bar.
   - 5.1.1 data collection — nothing collected; location purpose string is explicit and optional.
   - 2.3 accurate metadata — screenshots must be from this build; no "beta" wording.
   - 5.2 intellectual property — the review notes state the text source and font licence;
     the English layer is absent from the public profile precisely so no rights question arises.
5. If rejected: reply in Resolution Center with the facts; fix through the normal flow if code is
   needed; a new build means a new build number and a fresh TestFlight pass of the touched charters.

## 6. Phase F — Launch and after

- **Release day:** press Release in App Store Connect, confirm the listing is live, check the
  production web release is the same version (`sggs-verify-prod`), then announce.
- **Monitoring** (there is no analytics by design): App Store Connect crash reports and
  ratings, TestFlight feedback for the beta groups (keep the internal group active for the next
  build), GitHub issues via the `bug` and `scripture-fidelity` templates.
- **Cadence:** every iOS change goes through the same loop — PR into `integration`, CI
  (`ios.yml` parity + app jobs), TestFlight build, charters touched + S, release. A DB change
  additionally goes through `sggs-rebuild-db` and produces a new `db_sha256`; the launch cache
  invalidates itself on the new bundle version.
- **Update safety:** SwiftData bookmarks migrate through `SavedLineSchemaV1`; any model change is
  a migration stage, and Charter U (update over an existing install) is mandatory for it.

---

## 7. Work list (repo)

Ordered; each item is a PR into `integration` unless marked human.

| # | Item | Owner | Status |
|---|---|---|---|
| 1 | Scripted archive/gate/export/upload path: `ios/tools/testflight_archive.sh`, `make testflight`, manual `ios-testflight.yml` | repo | in this PR |
| 2 | Test plan, device matrix, charters, triage rules, build log | repo | in this PR |
| 3 | App Store listing draft, privacy answers, review notes | repo | in this PR |
| 4 | Team ID, App IDs, App Group, API key, `testflight` environment secrets | human | open |
| 5 | First signed archive + first device run (Phase B checklist) | human | open |
| 6 | App icon: concept A (gold ੴ on warm ink) generated by `ios/tools/make_app_icon.swift`; scholar acceptance (brand-book gate G3) and palette legal clearance (gate G4) still required | human | open |
| 7 | Screenshots (6.9", 6.5", iPad 13") from the release-candidate build; store under `ios/AppStore/screenshots/` (git-ignored if large) | human | open |
| 8 | Support + privacy policy pages on the production site (`/support`, `/privacy`) — the listing needs public URLs | repo | built; live on the next release to `main` |
| 9 | Translation licence: pursue in parallel; on grant, fill the attestation and ship as a point release | human | open |
| 10 | Post-launch: migrate the loose readiness/build reports into `docs/reports/` | repo | open |

## 8. Risks and how they are handled

| Risk | Handling |
|---|---|
| Uploading the English-bundled DB by mistake | The script gates the exact artifact it bundles, then re-hashes the DB inside the archived `.app`; CI does the same on the manual workflow. |
| The archive replacing the developer's personal DB (app then fail-closes locally: "Scripture integrity check failed") | Fixed 2026-09-19: the script stages the shipping DB under `ios/App/build/stage-<ver>-<build>/` and archives from a temporary `SGGS-TestFlight.xcodeproj`; it never touches `ios/Resources/` and runs no tree-changing git command. `make ios-db-check` detects a mismatched pair (also after a branch switch / in a new worktree); `make ios-db-repair` fixes it. |
| Build-number collision on upload | Explicit `BUILD=N` per upload, recorded in the build log; `manageAppVersionAndBuildNumber=false` so Apple never silently renumbers. |
| Widgets empty on device (App Group mis-provisioned) | Visible in About → Integrity; Phase B item, blocking. |
| Cold-start integrity hash too slow on old hardware | Launch cache skips the 108 MB re-hash after the first verified launch; measure on the oldest device in Phase B. |
| Order-dependent XCUITest flake (`testVerifyShowsVerdict`) | Known, documented, passes alone; not a product defect, but keep it on the list for the next test-hygiene PR. |
| Scholar asks for verbatim rendering by default | One-line toggle default in `Saroop.swift`; no data change. |
| App name taken in App Store Connect | Fallback names in the listing draft. |
| Review asks about the scripture's provenance | Review notes state the source edition, the char-exact reconcile proof and the font licence. |

## 9. Definition of "ready to submit"

All of the following, recorded in the build log against one build number:
- Phase C charters all pass on the full device matrix; Charter S signed.
- Phase D: no app-attributable crash in TestFlight crashes; external feedback triaged to zero P0/P1.
- Scholar sign-off on icon and default rendering recorded.
- A11y hardware checklist (`ios/App/Tests/UI/A11Y_CHECKLIST.md`) completed on device.
- `candidate-<version>-<build>.json` shows `profile: public` (or `personal` with `LICENSED: true`), the tag's commit, and a DB hash equal to the manifest the release gate produced for that build (re-derivable from the tag's `db/sggs.sqlite`).
- Listing complete in App Store Connect; support and privacy URLs live.
