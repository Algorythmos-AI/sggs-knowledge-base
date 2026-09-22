# Runbook: App Store submission (go / no-go)

The order matters: the web pages must be live before the binary is submitted, and the binary must
be an **App Store channel** build. Nothing here is improvised — each step names the command or the
file that proves it. Audit and plan: 2026-09-20.

## 0. What cannot be undone
- There is **no binary rollback on iOS**. A bad release is fixed by a new build ([ios-hotfix](ios-hotfix.md)).
- The EU trader details (address, phone, email) become **public** once declared.
- The app name can be changed only with a new version once it has been submitted.

## 1. Machine-checkable gates (an agent or CI closes these)

| # | Gate | Proof |
|---|---|---|
| M1 | Trunk is green and released: `integration` → `main` by merge commit | `sggs-release` skill; `/api/health.commit == SHA`; tag cut after the verified deploy |
| M2 | `/privacy` and `/support` are live on production and name **Gurbani Soul** | `@smoke` specs in the deploy gate; `uptime` workflow green |
| M3 | Repo gates green on the RC commit | `python3 -m unittest webapp.tests.test_repo_gates` |
| M4 | The RC is an **App Store channel** build from green trunk | `make testflight TEAM_ID=… BUILD=N CHANNEL=appstore UPLOAD=1` — refuses a dirty tree, an off-trunk commit, red CI, Xcode < 26, or an unsigned Nitnem review |
| M5 | The ledger row is committed | `ios/testflight-builds.json` has the build with `channel: appstore`, `sdk: iphoneos26.x`; PR merged |
| M6 | This version may be submitted | `make appstore-preflight` exits 0 |
| M7 | Listing text is within limits and true | listing lint (part of M3); paste from `docs/ios/app-store-listing.md` only |

## 2. Owner gates (only a person can close these — record name + date in the build log)

| # | Gate | Where |
|---|---|---|
| H1 | Scholar review of the Nitnem non-SGGS text → `REVIEWED: true`, and `NitnemReview.extraTextReviewed = true` in the **same commit** | `ios/Resources/NITNEM-REVIEW.md`, `docs/nitnem/review-pack/` |
| H2 | G3 — Granthi / scholar acceptance of the ੴ icon treatment and the default saroop rendering | `docs/brand/gurbani-soul-brand-book.md` |
| H3 | G4 — legal / trade-dress clearance; the source edition's publisher noted; the ShabadOS 4.8.7 licence text recorded | brand book; `NOTICE.md` |
| H4 | Charter S (scripture fidelity) signed **on the RC build number** | `docs/ios/testflight-test-plan.md` |
| H5 | Hardware pass on the RC (below) | `ios/App/Tests/UI/A11Y_CHECKLIST.md` |
| H6 | App Store Connect forms (below) | `docs/ios/app-store-listing.md` |
| H7 | A monitored support address exists and is the one in the listing | [support-inbox](support-inbox.md) |
| H8 | Rulesets applied so the iOS `parity` + `app` checks are required | `scripts/gh/apply_rulesets.sh` |
| H9 | Submit for review; after approval, **Release** manually with 7-day phased release | App Store Connect |

### H5 — hardware pass (signed RC build, real devices)
- [ ] Oldest supported iPhone on iOS 17.x: **first** launch after install — note the seconds spent on "Verifying scripture integrity…" (budget: under 5 s; the app stays responsive throughout).
- [ ] Turn a Nitnem reminder on → the system permission prompt appears → at the chosen time a **banner with sound** arrives; tapping it opens Nitnem.
- [ ] Live Activity: More → turn it on → open a bani, stay 20 s, lock the device → progress shows; tapping the Lock Screen banner returns to that bani; it ends when the bani is left.
- [ ] Reader: scroll down an Ang, swipe to the next, swipe back — is the scroll position kept? (Record the answer; the pager's neighbour handling is untouched pending this check.)
- [ ] Change the accent in Themes, return to the Reader — the open Ang uses the new accent at once.
- [ ] iPad: portrait + landscape, Split View ⅓ and ½, Stage Manager resize.
- [ ] `A11Y_CHECKLIST.md`: VoiceOver, largest accessibility text size, Reduce Motion, Increase Contrast, Bold Text.
- [ ] Widgets (all three) populate after the first app launch; More → About → Integrity shows "Widget App Group available".
- [ ] Airplane Mode for the whole session: nothing degrades.
- [ ] Storage almost full: the app launches and reads; saving a verse fails gracefully.

### H6 — App Store Connect
- [ ] Name available; subtitle, promo text, keywords, description pasted from the listing doc.
- [ ] Support / Marketing / Privacy URLs = the **"Submit this"** column (they must resolve today).
- [ ] App Privacy: **Data Not Collected**.
- [ ] Age rating questionnaire → 4+. Read the live form; answer what it asks.
- [ ] **New app record / version**: create the App Store version with the string **exactly matching
      the binary's `MARKETING_VERSION`** (a new app record defaults to 1.0; the build is not
      selectable until the version string matches). Select the processed build once it leaves
      "Processing".
- [ ] **App Information**: Primary category Reference, Secondary Education; Content Rights.
- [ ] Content rights: **Yes, contains third-party content, and I have the rights** (list from the doc).
- [ ] Export compliance: answered by `ITSAppUsesNonExemptEncryption = false`.
- [ ] EU DSA trader status declared and verified (the contact details become public).
- [ ] Accessibility labels: declare only what H5 proved.
- [ ] Availability: all territories. Price: free. Agreements: nothing pending under Business.
- [ ] **Untick "Make this app available on Mac" and "… on Apple Vision Pro"** — both are ON by
      default. The app is iPhone/iPad only (`TARGETED_DEVICE_FAMILY "1,2"`) and is never tested on
      those platforms; a broken Mac/visionOS run is a 2.1 rejection on a surface we never shipped.
- [ ] App Review Information: contact name, **phone**, email; review notes pasted; no sign-in.
- [ ] Screenshots retaken from the RC (`ios/AppStore/README.md` checklist). Mandatory display sizes
      today: **iPhone 6.9"** and — because the app supports iPad — **iPad 13"**; 6.5" iPhone is
      optional. **Confirm the live requirement in the upload UI on the day** (Apple changes it).
- [ ] Version release: **manual**, phased release **on**.
- [ ] After approval the version sits at **"Pending Developer Release"** — it is NOT live. Open the
      version page and press **Release** to start the 7-day phased rollout; record the timestamp.

## 3. Re-check on submission day
Apple changes these without notice — read <https://developer.apple.com/news/upcoming-requirements/>:
minimum Xcode/SDK (and raise `MIN_XCODE_MAJOR` in `ios/tools/testflight_archive.sh` +
`MIN_SDK_MAJOR` in `ios/tools/appstore_preflight.py` together), the age-rating questions, whether
accessibility labels have become mandatory.

## 4. If App Review rejects
Read the cited guideline, reply in Resolution Center with the specific evidence (the review notes
already explain offline use, location, notifications and the Live Activity). A metadata-only
rejection is fixed in App Store Connect and in `docs/ios/app-store-listing.md` **in the same sitting**
— the doc and the listing must never diverge. A binary rejection goes through the normal
ship → release → `CHANNEL=appstore` loop with the next build number.

## 5. After release — halt criteria (decided in advance)
Pause the phased release (App Store Connect → the version → Pause Phased Release) if any of:
- an integrity-gate false positive in the field ("Scripture integrity check failed" on a clean install);
- a wrong-text report **confirmed against the printed Bir** by a person;
- a crash or hang reported by more than one user on the same screen, or an Organizer crash rate
  that is clearly above the previous build's.
Then follow [ios-hotfix](ios-hotfix.md). Weekly during the rollout: Xcode Organizer crashes and
hangs → symbolicate with the dSYM UUIDs recorded in the candidate JSON → issue → decide.
