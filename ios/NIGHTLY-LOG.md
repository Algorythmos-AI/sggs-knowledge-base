# SGGS iOS — Nightly Build Log

## 2026-06-26 22:13 — disk crisis resolved
- Disk was 100% full (ENOSPC, could not spawn commands). Reclaimed ~23G (uv/npm/Xcode caches). Now 8.7Gi free.
- Resuming Phase 0 preflight.

## 22:19 — Phase A: passage_search
- Ported serve.py passage_search (fts_shabad + NSRegularExpression span over ASCII translit_norm + bubble).
- golden_search +4 vectors (1 resolves passage-match, 17 ids). Un-skipped passage in test.
- swift test: all 4 suites GREEN. Whole search waterfall now ported.

## 22:24 — Phase B: corpus reader endpoints
- CorpusReader (kit models + protocol) + SQLiteCorpusReader: fetchAng (majority raag/section, continued_from), fetchShabad, hukamUnit (ported hukam_package incl. Vaar salok/pauri expansion), randomSeedCompId, fetchMeta.
- golden_reader.ndjson (5 ang + 7 hukam seeds incl. Maajh Vaar 399-409 / 104 lines). ReaderParityTests GREEN.
- swift test: 5 suites green.

## 22:53 — Phase C: build-env hurdle
- Xcode 26.5 bundles iphonesimulator26.5 SDK; only iOS 26.4 runtimes were installed -> 0 destinations resolve. Deleted both 26.4 runtimes (freed 15.8G), downloading iOS 26.5 sim runtime (8.5GB, background).
- Disk had also hit 0 earlier; freed via uv/npm/Xcode caches. Now 38G free.
- Writing Phase D/E app code while runtime downloads; will build+screenshot when ready.

## 23:13 — Phases C/D/E: RUNNING NATIVE APP
- Resolved build env: installed iOS 26.5 sim runtime (Xcode 26.5 needs matching runtime).
- xcodegen project + Info.plist + PrivacyInfo; Sant Lipi ttf bundled; 91MB DB as resource.
- CorpusActor (Sendable boundary), LaunchIntegrity (sha+invariants, fail-closed), GurmukhiText+Saroop,
  Router/deep-links, Search (7 modes, .task debounce, verdict), Reader (Ang nav+Hukam), Index, Themes,
  More/About, single root ShabadSheet. BUILD SUCCEEDED; app launches; Search renders Gurmukhi; integrity PASSED.

## 23:23 — Phase F+J: functional tests GREEN
- Fixed test-install collision: dropped the PRODUCT_BUNDLE_IDENTIFIER cmdline override (it gave the
  embedded SwiftPM frameworks the app bundle id). Frameworks now get distinct ids.
- xcodebuild test on iOS 26.5 sim: 8/8 pass — 4 unit (ang/hukam/theme/verify vs bundled DB) +
  4 XCUITest (launch, Reader+Hukam, Search->shabad sheet, Verify->verdict). TEST SUCCEEDED.

## 23:28 — Phase H: Saved verses (SwiftData)
- SavedLine @Model in a SEPARATE writable store (never the corpus DB); modelContainer wired.
- LineRow Save action (verbatim); SavedScreen (@Query, swipe-delete); reachable from More.
- BUILD SUCCEEDED.

## 23:38 — Phase K: self-audit + report
- Independent adversarial review: fixed H1 (91MB hash off-main), H2 (fail-closed gate during check),
  verify @ang range-validate, Reader/verdict a11y labels, empty-query debounce skip. Confirmed clean:
  verbatim copy/share/save/VoiceOver, no corpus writes, actor boundary, no retain cycles.
- Rebuilt + full test: 8/8 green. Wrote SGGS-iOS-Build-Report-2026-06-27.md.
- v1 core COMPLETE: Search/Reader/Index/Themes/Hukam/Saved/Verify, font+saroop, integrity, offline.

## 03:23 — Phase L (v1.1): Semantic Trail
- Ported /api/neighbors (line_neighbors line-tier -> shabad_neighbors composition fallback) into kit+DB+actor.
- golden_reader +5 neighbor vectors (both tiers); ReaderParityTests asserts ids+cosine scores: BYTE-IDENTICAL.
- TrailScreen: relatedness BANDS (not raw 
## Phase L (v1.1): Semantic Trail
- Ported /api/neighbors (line_neighbors line-tier -> shabad_neighbors composition fallback) into kit+DB+actor.
- golden_reader +5 neighbour vectors (both tiers); ReaderParityTests asserts ids + cosine scores: BYTE-IDENTICAL.
- TrailScreen: relatedness BANDS (not a raw percentage), breadcrumb walk, pin+open, "not a ranking of scripture" note.
  Entry via LineRow "Explore related"; second root sheet. Full test 10/10 green. Branch pushed (095b5f4).

## Phase M (v1.1): Insights (Swift Charts)
- Ported analytics endpoints: author_analytics, raag_analytics, theme_network (AnalyticsSource protocol).
- golden_reader +3 analytics vectors (authors/raags/theme_net); ReaderParityTests asserts names+counts+mattr+ppmi: BYTE-IDENTICAL.
- InsightsScreen (More tab): Contributors + Raags bar charts (Swift Charts) + stylometry/detail lists +
  Theme connections (PPMI co-occurrence). "Descriptive, never a ranking" captions; a11y labels.
- Clean build + full test: 11/11 green (added testInsights). Insights screenshot verified.

## Phase N (v1.1): Concept Constellation
- Ported /api/analytics/constellation (parameterized concept+author+raag; co-theme bucketing; stable top-9).
- golden_reader +3 constellation vectors (naam/hukam/seva): total + cluster co-themes + counts + top-cluster
  verse ids — BYTE-IDENTICAL incl. the stable sort order.
- ConstellationScreen: native deterministic RADIAL MAP (centre theme + co-theme bubbles sized by sqrt(n),
  connecting lines), theme menu picker, tap bubble -> cluster verses sheet. "Descriptive, never a ranking."
- Clean build + full test: 12/12 green (added testConstellation). Screenshot verified (naam: simran 682…).

## P1 (finishing-line): PIN SQLite 3.51.0 — device-fidelity loophole closed
- Vendored official SQLite 3.51.0 amalgamation as a CSQLite C target (SQLITE_ENABLE_FTS5 + flags);
  removed linkedLibrary("sqlite3"); repointed GurbaniDB import SQLite3 -> import CSQLite.
- PROOF: all 5 kit parity suites byte-identical on the vendored engine (search bm25 order, verify,
  reader, neighbors, analytics, constellation) + app unit integration tests green. FTS5/unicode61/bm25
  now identical on every device, not the host system SQLite. sqlite version surfaced in About.
- App UI test run hit a sim-only flake ("Timed out loading Accessibility", unrelated) — rebooting sim.

## P2 (finishing-line): correctness & robustness
- ONE root Presentation enum {shabad,hukam,trail,cluster} + single .sheet(item:); removed the 2 root
  sheets + ConstellationScreen's nested sheet. In-sheet opens use present()/pendingPresentation +
  RootView onDismiss chaining (reliable swap; presenting during a dismiss is dropped by SwiftUI).
- Idempotent LineRow.save (FetchDescriptor existence check + rollback) — no @unique crash on re-save.
- UserMessage helper → friendly errors everywhere (no raw \(error) leak).
- Lifecycle: SearchModel in .task; ReaderModel cancellation guard; InsightsModel loaded-on-empty;
  Constellation max(n,0); Saroop literal scalar (no force-unwrap); SavedScreen onDelete do/catch.
- Reader shows "Continues from Ang N". Regression UI test (Trail→Open swaps to shabad). 13/13 green.

## P3 (finishing-line): polish, a11y & placeholder brand assets
- Settings expanded: transliteration toggle, Gurmukhi size slider (18–32, scales all scripture via
  GurmukhiText), appearance picker (system/light/dark via root .preferredColorScheme). Wired through
  GurmukhiText/LineRow. Verbatim-copy invariant preserved.
- Haptics on Save (success) + Hukam (light). Reader "continues from Ang N".
- Placeholder AppIcon (white ੴ on saffron, 1024 → all sizes) + AccentColor (saffron) + launch screen
  (ੴ on saffron). developmentLanguage pa→en. SQLite version shown in About.
- Verified: icon on home screen; dark-mode + AX5 layout holds; 14/14 tests green (+testSettingsControls).
- PLACEHOLDER icon flagged for reverent final art + Granthi review.

## P4 (finishing-line): tests, CI & independent re-review
- Adversarial search vectors (empty / " / * / SQL-ish / 200×ੴ / 300×a) — byte-identical to Python on the
  vendored engine. testOverLongQueryRejected (>300 throws, =300 ok) matches serve.py. golden_search=50.
- Launch-perf guard: streaming SHA-256 of the 91MB DB completes in 0.045s (<5s budget).
- CI: .github/workflows/ios.yml — LFS pull → build_ios_db.py → manifest db_sha256 check → swift test on
  the VENDORED SQLite (fidelity gate on every push/PR).
- Independent re-review of the P1–P3 diff: found 1 real bug (LineRow "Explore related" bypassed present()
  → dropped sheet from inside ClusterSheet) + 2 latent (double-present race, Router deeplink). All fixed.
- Full suite 15/15 green; kit parity 6 suites.

## P5 (full-parity plan, Phase 0–1): DB profiles, English kit layer, reliability, CI app gate
- DB now builds in two PROFILES (build_ios_db.py --profile personal|public): personal (bundled)
  keeps translations+fts_en per NOTICE.md w/ build-time license warning; public stays Gurmukhi-only
  as a git-ignored artifact. Both carry the v2.12.0 timing tables (previous bundle predated them).
  Scripture checksum gate unchanged; scripture_sha256 identical across profiles.
- Contract grew 3 suites: golden_timing (83) + golden_analytics (56) + golden_pahar (2,183 from
  the real pahar.js under TZ=UTC; the 47-case gate is now a cross-language contract). Generator
  gained --suites= with merge-safe _meta.json.
- English layer live in the kit at byte parity: search_en tier (explicit 'english' mode + auto
  waterfall position after variant, before honorific-drop), attach_translations on ang/shabad/
  line-neighbors (NOT hukam — web parity), optional `en` on SearchLine/ReaderLine/Neighbor.
  golden_search 62 (8 english w/ results), golden_reader 27 w/ per-line ens asserted verbatim.
  New DegradationParityTests (4) pin the public profile to today's EN-less behavior. Kit 10/10.
- Reliability: SwiftData container now built explicitly w/ fallback ladder (persistent →
  recreate → in-memory → nil) + degraded banner + Save hidden when nil — the .modelContainer(for:)
  fatalError launch path is gone. Launch-hash cache (UserDefaults fingerprint: sha+size+mtime+
  bundle version+manifest sha) skips the ~100MB streaming SHA when unchanged; structural checks
  still run every launch; failures clear the cache (fail-closed unchanged; threat model in-file).
  IntegrityFailView gained a Verify-again retry. LaunchCacheTests (3) cover hit/miss/garbage.
- CI: new `app` job — xcodegen → build-for-testing → SGGSTests + SGGSUITests on a resolved
  simulator; parity job builds BOTH profiles. Local: 18/18 app tests green (8 unit + 10 UI),
  zero app-source warnings under Swift 6 strict concurrency.

## P6 (full-parity plan, Phase 2–6): nav restructure, English UI, Clock, Reader parity, Lineage/Insights/Vaars
- Tabs → Reader · Search · Clock · Explore · More; Explore hub hosts Index/Themes/Lineage/Insights/
  Constellation/Vaars as stack-less Routes. Theme tokens (spacing/radius/Card/StatTile) + echoBand
  moved to WEB thresholds (0.65/0.45 — the old badge used 0.60). sggs:// grew search?q= + clock/<raag>.
- English UI: capability-gated (CorpusCapabilities from sqlite_master) — LineRow renders the labelled
  en under the verse (optional end-to-end; 330 verses legitimately lack it), search pills gain an
  English mode, verify shows the canonical line's translation, More gains the toggle.
- Raag Clock: Canvas dial (day/night arcs, current-pahar glow, beads, silent P7, now-hand) +
  accessible pahar LIST as the content path; fixed/solar modes (opt-in CoreLocation rounded ~1km
  on-device only + manual entry + polar fallback); per-pahar claims sheet; DivergenceScreen.
  Injectable clock (SGGS_CLOCK_NOW) for deterministic tests.
- Reader parity: jump-to-Ang (field+slider), swipe page-turn, reading-options menu, Sehaj focus,
  resume-last-Ang, dashed timing chip → Clock deep link. BUG caught by boundary test: SwiftUI
  LocalizedStringKey interpolation rendered "Ang 1,430" — all Ang interpolations now String()-wrapped.
- Lineage: century timeline (kind filters, volume bars — "never importance" stated), full profiles
  (stylometry StatTiles, signature themes by lift, distinctive-term chips), ⇄ compare two voices
  (Canvas radar + accessible Grid table). Insights grew Network (seeded deterministic ForceLayout,
  settled off-main pre-frame; list alternative always present), Resonance chord (Canvas + list),
  Flow streamgraph (Swift Charts stacked areas per concept along the raag). VaarsScreen: 22 ballads
  → salok/pauri anatomy (verbatim from tables; cross-voice structure explained).
- Contract catch: author_analytics.top_themes is [{concept,lift}] not [String] — TopTheme model.

## P7 (full-parity plan, Phase 7–9): a11y, native layer, QA gate
- A11y: LineRow = one combined VoiceOver element (Punjabi Gurmukhi → English → Ang) with
  Copy/Share/Save/Explore as accessibility actions; Share carries the Ang citation; manual
  script in Tests/UI/A11Y_CHECKLIST.md (incl. the deliberate translit-out-of-label deviation).
- Native layer: GurbaniPahar split into a dependency-free SPM product; SGGSWidgets extension
  (Raag-now pahar timeline + Hukam verse) reading only the <50KB App-Group snapshot the app
  writes post-integrity (verified in-sim: verbatim verse + correct pahar raags); App Intents/
  Siri ("Today's Hukam", "What raag is it now", "Search Gurbani", "Open Ang") all via sggs://;
  CoreSpotlight for SAVED verses only; ImageRenderer share cards.
- QA: check_release_license.sh (public OK / personal BLOCKED — negative-tested in CI); fuzz
  suite (1,000 seeded hostile queries, no crash) + 24,719-input roman_norm drift check
  (finding: the fold is deliberately NOT idempotent — matches Python; single-application
  equality is the correct property); perf budgets as asserts (search p50 20ms, ang fetch 2ms,
  worst-case progression 19ms, full network-layout settle 126ms — all far under budget);
  MetricKit local-only crash collection (QA exit = zero diagnostics); CI paths now include
  pahar.js + contributors.json (new app inputs).
- Suites at close: kit 17/17 · app 28/28 (12 unit + 16 UI) · release gate green both ways.
