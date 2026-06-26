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
