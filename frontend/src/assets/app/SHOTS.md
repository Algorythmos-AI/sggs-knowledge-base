# Gurbani Soul — marketing screenshots

Captured 2026-09-23 · worktree `wt-pra` @ `1197e2b` (feat/site-v2-foundations, iOS 1.3.4 build 1, Debug) · Xcode 26.5 · iOS 26.5 simulator runtime.
All shots use the **public** (Gurmukhi-only) DB profile (`db_sha256 f30a2fc0…`, `profile: public`), swapped into a copy of the built app; the in-app integrity check passed (About shows all green). No English translation layer appears anywhere.
Status bar overridden to 9:41, full battery/signal. Env = `SIMCTL_CHILD_*` launch variables. Nothing is mocked: progress shown (Japji read today, Live Activity 1%) was produced by using the app.

| name | device | iOS | appearance | deep link / steps | env | raw sha256 | compId |
|---|---|---|---|---|---|---|---|
| iphone-reader-light | iPhone 17 Pro | 26.5 | light | sggs://ang/1 | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `be801551601ed762a2e04f736c17527d3e6cde53b1a6e2446c9742ea3ad02d45` |  |
| iphone-search-roman-light | iPhone 17 Pro | 26.5 | light | sggs://search?q=naam (Auto mode) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `e05a4690aca38201afb0bf5b0cd1ab250ff49ba2e0afaa3d2f18d8bd5c79688c` |  |
| iphone-search-first-letters-light | iPhone 17 Pro | 26.5 | light | Search → First letters pill → typed `s s n h j s l v` (→ ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ…, Ang 1; the keyboard auto-capitalised the first s) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `67c85e25bbb9a17195f31e361ba4eb100ed5edcecdb2ae7aa16d79e96cef8768` |  |
| iphone-verify-verdict-light | iPhone 17 Pro | 26.5 | light | Search → Verify pill → pasted `ਆਦਿ ਸਚੁ ਜੁਗਾਦਿ ਸਚੁ ॥` → Verified 100% | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `e225ff628df74eaa244359b80683558cdb8577195a92b1a24732ee5a49a8af33` |  |
| iphone-hukam-light | iPhone 17 Pro | 26.5 | light | sggs://shabad/29 (Dhanasari M1 "Aarti", Ang 13) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `2eee73bf712b898d795c0a7fd0a1f68f141c3af766a4c6db738018a93ffbea93` | 29 |
| iphone-nitnem-light | iPhone 17 Pro | 26.5 | light | sggs://nitnem (after Japji genuinely marked read today in-app) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `e56195281dfa8e0eb5e99f9f914600f8a1b8906555ddf66a8d3b83e349ad8ced` |  |
| iphone-bani-japji-light | iPhone 17 Pro | 26.5 | light | sggs://bani/japji, scrolled ~180pt | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `98bfc074e37522cc806cbf6f313aee78616c69e21f9ea7cd61fabb51c136cb95` |  |
| iphone-nitnem-journey-light | iPhone 17 Pro | 26.5 | light | Nitnem → Reading journey (honest: only Japji read; the calendar counts a full set, so no day is filled) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 (+ SGGS_AUTOSCROLL_PPS=3000 on that launch, unused — completed via jump-to-end + "Mark as read today") | `a7e93ec1bbf13c80a949b32c27722f3f2a8f59b88beb47783fabe8ead4c83294` |  |
| iphone-themes-light | iPhone 17 Pro | 26.5 | light | Explore → Themes | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `e220c8776e3f3fefa0401f8b72c46fd27f96ddd482a347fdc61ff51f0288bfb1` |  |
| iphone-lineage-light | iPhone 17 Pro | 26.5 | light | Explore → Lineage | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `093450873aee85839d8e36779bc7d8874a29ec66511c3ea6da8aac9d5af6dece` |  |
| iphone-insights-light | iPhone 17 Pro | 26.5 | light | Explore → Insights (Contributors tab) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `85048ac592170f65afd0def5308fbb280e4304faf874519b899b0486207f5637` |  |
| iphone-constellation-light | iPhone 17 | 26.5 | light | Explore → Constellation (Theme: Naam) — Recaptured 2026-09-23 after #120: shows concept display names ("Dukh Sukh"), not raw ids. iPhone 17 sim, iOS 26.5, build `ec222c1` (Debug, bundled DB), `testCaptureScreens` shot, status bar overridden to 9:41; this screen shows no translation text, so the DB profile does not change it | status bar 9:41 | `f7c50235dff6e39fcc6e75f7004ec6bf7a7df4efc088f5b55fad6091fdcc74ca` |  |
| iphone-index-light | iPhone 17 Pro | 26.5 | light | Explore → Index | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `fadfc1ee0c3d31f70056b5bbe3a2216770cf5ed75dd8d96ac7d4b79f6357f273` |  |
| iphone-about-light | iPhone 17 Pro | 26.5 | light | More → About & credits (ad-hoc signed copy so the App Group row is green) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `ce1079a0dfccc808c50caa814ed60f88778b926d55909f2451178d75c4b5310a` |  |
| iphone-more-display-light | iPhone 17 Pro | 26.5 | light | More, scrolled to Display (accent swatches) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `b53fbc06ca82e47866a43824cae82e744da8ec765b956b30018993b1a534c32f` |  |
| iphone-saroop-on-light | iPhone 17 Pro | 26.5 | light | sggs://ang/1400?line=59566 (ਜਲ੍ਯ੍ਯਨ line), Traditional saroop ON (default) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `9286181cc09a3036407298dc8c3b7eaa4367f0d0ad4445d3f9d24b0b0f8b764f` |  |
| iphone-saroop-off-light | iPhone 17 Pro | 26.5 | light | same deep link + landing after More → Display → Traditional saroop OFF (reset ON afterwards) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `afc9667501bed3cec5e6dc5f38e285def68abc1946e98d32cbef05755bfb30fc` |  |
| iphone-pahar-divergence-light | iPhone 17 Pro | 26.5 | light | sggs://clock → "See every disagreement" → Where traditions disagree | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `fe0af8ba270c340039560f2077316ddbad7f3cd10fc7153a9da5806d1ae2f4e0` |  |
| iphone-live-activity-island-light | iPhone 17 Pro | 26.5 | light | More → Live Activity ON (drag the switch), sggs://bani/japji, scroll, wait >20 s, HOME → Dynamic Island (1%, real progress) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `6e7b47a151c628da8e0a4dd79bcc805b86a8df640af67fe89cdd05e7d0b86e27` |  |
| iphone-live-activity-lock-light | iPhone 17 Pro | 26.5 | light | LOCK ×2 → Lock Screen; accepted the one-time "Allow Live Activities" prompt, then shot | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `282cfe4b3f899a26d3b88c447208c5ad9d708c2cdcc91a408b337f8c639e54cf` |  |
| iphone-live-activity-card | iPhone 17 Pro | 26.5 | light | **derived** from `iphone-live-activity-lock-light` (sharp `extract` 0,1450 900×260 — the Live Activity card only; the simulator's status bar / date are cropped away), palette PNG | — | (derived) |  |
| accent-soul | iPhone 17 Pro | 26.5 | light | More → Display → Accent swatch 1 (Soul, default) → sggs://ang/1; top 900×700 band | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `be801551601ed762a2e04f736c17527d3e6cde53b1a6e2446c9742ea3ad02d45` |  |
| accent-saffron | iPhone 17 Pro | 26.5 | light | swatch 2 → sggs://ang/1; top band | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `642fb3da53ef3a6c20a880ea78a04becfabfb5d3b35358778f2de323985eef2c` |  |
| accent-gold | iPhone 17 Pro | 26.5 | light | swatch 3 → sggs://ang/1; top band | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `b3cde3ea364acb3896c024b3ca3ab306902d46ca6d8cbe794835aa406323884a` |  |
| accent-indigo | iPhone 17 Pro | 26.5 | light | swatch 4 → sggs://ang/1; top band | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `bdc03f80bc9e7e37ca6c63683d3d6be18e815a743878de147ad9b6963aa5e9f5` |  |
| accent-teal | iPhone 17 Pro | 26.5 | light | swatch 5 → sggs://ang/1; top band (accent reset to Soul afterwards) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `6583f11a5f8513abde16d85c7495dc90c65fd40f3a1039ffa5570ef8c8a64d61` |  |
| iphone-reader-dark | iPhone 17 Pro | 26.5 | dark | sggs://ang/1 | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `c286289ba536e8f0de03b0785a1ff18df44b14390bb2f5241a0d94c736e15861` |  |
| iphone-clock-dark | iPhone 17 Pro | 26.5 | dark | sggs://clock | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `9a23c974daa474cf9cefc6145c19807c41ef1535f4395bae37ae03ea92596c6f` |  |
| iphone-constellation-dark | iPhone 17 | 26.5 | dark | Explore → Constellation (Theme: Naam) — Recaptured 2026-09-23 after #120: shows concept display names ("Dukh Sukh"), not raw ids. iPhone 17 sim, iOS 26.5, build `ec222c1` (Debug, bundled DB), `testCaptureScreens` shot, status bar overridden to 9:41; this screen shows no translation text, so the DB profile does not change it | status bar 9:41 | `71e4bb1cc48706ac7f83ae8153cbf27d21d606dbd1b7e6b2a08a2e5b466d7dee` |  |
| iphone-clock-solar-dark | iPhone 17 Pro | 26.5 | dark | sggs://clock → "Use my location" → Allow While Using App; sim location 31.62,74.88 (Amritsar) | CLOCK_NOW=581 · CLOCK_MODE=solar · TZ=Asia/Kolkata (so the Amritsar sun-times read in local time) | `c6987ff166e07ff28fecefcc200a890fa7c6dafe2df468694980d74696ee7882` |  |
| ipad-reader-landscape-light | iPad Pro 13" (M5) | 26.5 | light | Landscape. Ang **705** (not 712): frame polled with `simctl io screenshot` while the repo UI test `testRapidChevronTapsStayInSync` navigated (deep link 700 → 5× Next); settled frame, rotated 270° | SGGS_UITEST=1 (test launch) | `d69eddfef8aab07d9af30bc1ea9170c28da78afddeaabcac9f8a20f52cbd7d25` |  |
| ipad-nitnem-landscape-light | iPad Pro 13" (M5) | 26.5 | light | Landscape. Cold launch (Nitnem is the default tab = sggs://nitnem target) | CLOCK_NOW=581 · CLOCK_MODE=fixed · CLOCK_NO_COORDS=1 | `3f7de8725f6f54738fab3c99ba02d06eea934d5399d3d1e97423b030e613f3b8` |  |
| ipad-explore-landscape-light | iPad Pro 13" (M5) | 26.5 | light | Landscape. Settled frame polled during repo UI test `testExploreHubReachesEverySurface`; rotated 270° | SGGS_UITEST=1 (test launch) | `d192dabd3c54f285d945033ec7c850ccfd092aebfed2420c8eebfac2916bba29` |  |

## Widgets (`final/widgets/`)

Rendered by unit tests through `ImageRenderer` (scale 3) with `TEST_RUNNER_SGGS_WIDGET_SNAPSHOT_DIR`, native size, palette-PNG re-encoded:
- `raagnow-*` — `WidgetRenderTests` (every family, fixed + solar, light + dark; fixture pahar→raag table, 16:40 on 2026-09-18).
- `nitnem_*` — `NitnemWidgetRenderTests` (every family, "next"/"done" states from the test fixture — **illustrative states, not a real reader's progress**).
- `hukam-{medium,large}-{light,dark}` — **new** `ios/App/Tests/Unit/HukamWidgetRenderTests.swift`. The verse is real: drawn exactly as the app draws its widget snapshot (`hukamUnit(seed: 29)` on the bundled DB, first non-header line — ਗਗਨ ਮੈ ਥਾਲੁ ਰਵਿ ਚੰਦੁ ਦੀਪਕ ਬਨੇ ਤਾਰਿਕਾ ਮੰਡਲ ਜਨਕ ਮੋਤੀ ॥, Ang 13). Because `HukamView` lives in the widget-extension target (not importable from SGGSTests), the test renders a line-for-line mirror of its body built from the same shared components; the citation truncates to "Sri Guru Granth Sahib Ji · An…" at medium/large width exactly as the shared `Citation` does in the real widget.

## Not captured
- `iphone-saved-light` — skipped (Saved verses would be the empty state).
- iPad Reader is Ang 705, not 712 (see row).

## Widgets shipped to the site (curated)
Only clean renders are used: `widget-hukam-medium-*`, `widget-nitnem-{medium,small}-*` (the render
test's sample "next bani" state), `widget-raagnow-small-*`. **Not shipped:** Hukam **large** (citation
truncates to "Sri Guru Granth Sahib Ji · An…" — an app bug, being fixed separately) and Raag Now
**medium/large** ("next watch in 4 days, 18 hrs" — countdown bug under investigation), and the light
lock-screen accessory renders (near-blank on a black background). Re-render once the fixes land.
