# SGGS iOS — v1 Build Report (overnight autonomous build)

**Date:** 2026-06-27 · **Branch:** `ios-app-v1` (pushed, `2f86cb4`) · **Toolchain:** Xcode 26.5 / Swift 6 /
iOS 26.5 sim · **Status:** a running, **tested, audit-hardened** native SwiftUI app at web feature-parity,
with the device-fidelity loophole closed (pinned SQLite). 15/15 app tests + 6 kit parity suites green.
Engineering-complete; remaining items are **human-gated** (signing, real-device run, final icon art).

> Prime directive upheld: scripture is **byte-identical & read-only**; search/verify are **byte-for-byte**
> with the Python backend (golden-tested); `git diff -- corpus db` empty throughout.

---

## What shipped (v1)

A pure-native, **fully offline** iOS app (universal, iOS 17+, MV + `@Observable`, Swift 6 strict concurrency):
- **Search** — all 7 modes (auto / gurmukhi / roman / first-letters / theme / verify), `.task(id:)`
  debounce + cancel, related-theme chips, a **Verify-quote** verdict card (6 verdicts + confidence + Ang match).
- **Reader** — Ang-by-Ang (1–1430) with prev/next, Hukam draw, shabad grouping, raag header.
- **Index** — browse raags / sections / authors (meta-driven) → Reader.
- **Themes** — 54 concepts → tagged lines.
- **Random / Hukam** — complete Hukam unit (Vaar salok↔pauri expansion) in the shared composition sheet.
- **Saved verses** — bookmark to a **separate SwiftData store** (verbatim), swipe-delete.
- **Gurmukhi rendering** — bundled **Sant Lipi** font + the display-only **traditional-saroop** toggle
  (default on); **Copy / Share / Save / VoiceOver all emit verbatim Gurmukhi** (never the VS markup).
- **Launch integrity** — streamed SHA-256 == certified manifest + the `/api/health` invariants
  (Mool Mantar, FTS, verify→line 5), **fail-closed** (no scripture shown until the check passes).
- **Privacy** — no network, no analytics, no accounts; `PrivacyInfo.xcprivacy` = Data Not Collected;
  `ITSAppUsesNonExemptEncryption=NO`; zero entitlements.

## Architecture
`ios/Packages/GurbaniSearchKit` (Foundation-only fidelity core: RomanNorm, difflib, GurbaniText,
FTSQuery, SeekerLexicon, **VerifyEngine**, **SearchEngine** full waterfall, **CorpusReader**) ·
`GurbaniDB` (read-only SQLite) · `ios/App` (SwiftUI: `CorpusActor` is the single Sendable DB boundary;
`@MainActor` screen models; one root `.sheet`; typed `Router` + `sggs://` deep links).

## Fidelity proof (the point of the whole project)
The query-time layer was ported byte-for-byte and is pinned by the **`contract/`** golden vectors
(generated from the real Python functions), asserted by `swift test`:

| Suite | Vectors | Result |
|---|---|---|
| roman_norm | 24,719 | identical |
| difflib ratio | 49 | bit-exact (incl. 199/200/201 autojunk) |
| verify verdicts | 18 | identical (verdict, matched id, confidence, note) |
| search (all tiers incl. passage) | 43 | identical ordered result-ids (incl. the BM25 tie at 22378/26517) |
| reader (ang + hukam units) | 12 | identical (incl. the 104-line Maajh Vaar 399–409) |

In-app integration + XCUITest on the iOS 26.5 simulator: **8/8 green** — Ang-1 Mool Mantar, hukam unit,
theme search, verify→line 5; launch, Reader+Hukam, Search→shabad sheet, Verify→verdict.

## Self-audit (Phase K)
An independent adversarial code review found and we **fixed**: the 91 MB launch hash now runs off the
main thread; the integrity gate is **fully fail-closed** (shows a "verifying…" splash, never scripture,
until the check passes); the verify `@ang` parse is range-validated; Reader chevrons and the verdict
Ang-result got VoiceOver labels; the search debounce skips empty queries. The review **confirmed clean**:
the verbatim copy/share/save/VoiceOver invariant, no writes to the corpus DB, the actor concurrency
boundary, and no retain cycles.

## Finishing-line hardening pass (audit-driven, P1–P4 — commits `04e857c…2f86cb4`)
A senior-grade audit (five exploration passes, two deep-dives, two independent code reviews) then a
four-phase fix. **Loophole-closure table:**

| Loophole (real) | Severity | Fix | Proof |
|---|---|---|---|
| App linked the **system SQLite** → FTS5 `unicode61`/`bm25` order could drift across iOS versions | **High (fidelity)** | **Pinned** SQLite by vendoring the official **3.51.0 amalgamation** (`CSQLite` C target, `SQLITE_ENABLE_FTS5`); removed `linkedLibrary("sqlite3")` | All golden parity suites byte-identical on the vendored engine = the device guarantee |
| Two/three competing root `.sheet`s → a sheet **dropped** when opening a shabad from inside Trail/Cluster | High | One `Presentation` enum + one `.sheet`; in-sheet opens `present()` (queue) + `onDismiss` flush | New regression UI test (Trail→Open swaps cleanly) |
| `LineRow` **"Explore related"** still bypassed `present()` (re-review catch) | Med | Routed through `present()` | 15/15 suite |
| Re-saving a verse hit `@unique` (swallowed by `try?`) | Med | Idempotent save (FetchDescriptor + rollback) | suite |
| Raw `\(error)` shown to users | Med | `UserMessage` friendly copy | — |
| Over-long / hostile queries | Low | confirmed Swift mirrors Python's `>300`/punct guards | adversarial vectors + `testOverLongQueryRejected` |
| Misc: model-init race, missing cancellation/empty guards, NaN, hidden `continued_from`, `pa` dev-lang | Low | all fixed | suite |

Also added: launch-perf guard (91 MB SHA in **0.045 s**), a **CI fidelity gate** (`.github/workflows/ios.yml`:
LFS → build DB → manifest check → `swift test` on the vendored engine), Settings (translit / Gurmukhi-size
/ appearance), haptics, a placeholder **ੴ App Icon** + launch screen, and About now shows the pinned SQLite
version. **Tests: 15/15 app + 6 kit parity suites green; verified dark-mode + accessibility-XL layout.**

## Build-environment notes (resolved autonomously)
- Disk hit 0 (ENOSPC blocked all commands) → reclaimed ~23 G of regenerable caches.
- Xcode 26.5 ships the **iphonesimulator26.5** SDK but only iOS 26.4 runtimes were present → zero build
  destinations. Removed the stale 26.4 runtimes and installed the iOS 26.5 simulator runtime.
- Fixed a test-install collision (a `PRODUCT_BUNDLE_IDENTIFIER` override had given both embedded SwiftPM
  frameworks the app's bundle id).

## v1.1 progress (post-v1, same branch)
- ✅ **Semantic Trail** — `/api/neighbors` ported byte-identical (line + composition tiers, golden-tested
  on ids + cosine scores); TrailScreen with relatedness **bands** (never a raw % or ranking of scripture),
  breadcrumb walking, pin/open.
- ✅ **Insights** — `author_analytics` / `raag_analytics` / `theme_network` ported byte-identical
  (golden-tested on names, counts, mattr, PPMI). Native **Swift Charts**: Contributors & Raags bar
  charts + stylometry/detail lists + Theme-connections (PPMI co-occurrence), all under More.
- ✅ **Concept Constellation** — `/api/analytics/constellation` ported byte-identical (total, co-theme
  clusters, counts, top-cluster verse ids incl. the stable top-9 order). Native deterministic **radial
  map** (centre theme + co-theme bubbles sized by √count), tap → cluster verses.
  **12/12 app tests green**; kit parity 5 suites (incl. 23 reader/analytics golden vectors).

## Deferred to v1.1+ (logged, not bugs)
- The **resonance chord / author-radar** visualizations and the **Lineage** narrative depth (the
  remaining web surfaces; data endpoints are straightforward ports when prioritized).
- **English translation** layer (licensing — see *NOTICE.md*; Gurmukhi-only by design for v1).
- **Pinned SQLite via GRDBCustomSQLite** (device-fidelity hardening; the system SQLite is 3.51.0 == the
  web reference on this machine, and parity is golden-proven).
- Font weight: ships the variable font's default (ExtraLight); consider instancing a Medium for body.

## Needs the human (can't be done unattended)
- Apple Developer Program enrolment + signing (`DEVELOPMENT_TEAM`); a **real-device** run.
- **App Icon artwork** (reverent; Granthi/scholar-reviewed) — none shipped yet.
- App Store metadata, screenshots, age rating; TestFlight submission.
- (Future) written license for the English translation before any EN release.

## How to build / run / test
```
# DB + golden vectors (Python):  python3 pipeline/build_ios_db.py ; python3 pipeline/gen_golden_vectors.py ios/Resources/sggs-ios.sqlite
# Fidelity tests:                cd ios/Packages/GurbaniSearchKit && swift test
# App build + UI tests:          cd ios/App && xcodegen generate && \
#   xcodebuild -project SGGS.xcodeproj -scheme SGGS -destination 'platform=iOS Simulator,id=<iOS26.5 sim>' test CODE_SIGNING_ALLOWED=NO
```

Progress log: `ios/NIGHTLY-LOG.md`. Commits on `ios-app-v1` (Phase 0 → K).
