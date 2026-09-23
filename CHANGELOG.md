# Changelog — SGGS Knowledge Base

The format below (newest first) follows [Keep a Changelog](https://keepachangelog.com);
entries prior to v1.1.0 are the project's original prose style and are preserved verbatim.

## [Unreleased]

### Added
- **Asa Di Vaar as printed** — a second, non-default `printed` variant of the Vaar in Raag Asa
  (Sri Guru Granth Sahib Ji · Ang 462–475, 637 lines, twenty-four pauris with their saloks),
  alongside the existing `kirtan` form that keeps the chhants from Ang 448–451 interleaved. The
  Nitnem default is unchanged, so every existing reading position and deep link still resolves to
  the kirtan form.
- **Range-defined banis in the registry** (ADR-0006 §4) — a bani may be declared by our own line-id
  ranges instead of a ShabadOS membership list. Every range carries verbatim text anchors that
  `build_banis.py` and `guard_banis.py` re-check, so a corpus rebuild that shifted ids would fail
  the build rather than quietly point a bani at different verses.

### Data
- Registry only: 637 new pointer rows in `bani_lines`, one new row in `banis`. **Scripture, corpus
  and every pre-existing table are byte-identical** (`diff_scripture.py`: no column changed;
  `guard_scripture.py`: all 46 tables match the Step-0 baseline).

### gurbanisoul.com v2 — PR A: foundations (web/presentation, tests and docs only)
Scripture, corpus and DB byte-identical; no page-layout change yet (the story layouts land in PR B).
- **Light-first marketing site** — with no stored choice every marketing page renders light, even on
  a dark OS: `Marketing.astro` pre-paint defaults to `light`, `scripts/theme.ts` gains
  `setDefaultTheme()` (the Knowledge Base keeps `system`), `landing.ts` sets it before `initTheme()`,
  and the OS-appearance dark block is removed from `marketing.css`. An explicit choice still wins
  and is shared with the Knowledge Base. The theme cycle on marketing pages is now ☀ → ☾ → ◐.
- **`theme-color` follows the page** — `Seo.astro` takes `themeColor="auto"|"light"`; the marketing
  shell emits one `#themeColorMeta` that `applyTheme()` keeps in step (`#FBF7F0` / `#171412`).
- **One marketing footer** — `MarketingFooter.astro` (brand block + Product · Learn · Support · Legal
  columns in one `nav[aria-label="Footer"]`, data-driven credits from `IMAGE_CREDITS`) replaces the
  five hand-copied footers on Home, Features, The watch and the Learn pages. `/support` gains a
  `#contact` anchor for "Report a text error".
- **Design system building blocks** in `marketing.css` (additive): `--maxw` 1200, `--sec` /
  `--sec-thin` rhythm, `.h-story` / `.h-statement` / `.body-lg` / `.detail`, `.chapter-no`,
  `.gold-hair`, `.surface-paper` / `.surface-warm`, a real `.band` rule, dark-in-dark surfaces,
  `.story-grid` (12-col, 5/7 · 6/6 · 7/5 · 4/8, `.story--flip`, text-first on mobile), `.proof`,
  `.mosaic`, `.photo-band`, `--shadow-device`, motion-safe hover + `.reveal[data-delay]`.
- **Components** — `DeviceFrame` gains `kind="ipad"`, `frame={false}`, `eager`, `sizes` (iPhone
  output unchanged); new `PhotoBand`, `LegalPage` (sticky contents rail, not yet adopted) and
  `MarketingFooter`; `landing.ts` adds `wireTocActive()` and a motion-safe ≤12px hero-phone drift.
- **Imagery credits** — `IMAGE_CREDITS` entries now carry `file` (+ optional `url`, `source`);
  `frontend/src/covers.ts` (`LEARN_COVERS`) is ready for Learn covers; NOTICE.md credits the artwork.
- **Gates** — `test_imagery_is_credited` flipped for credited Unsplash photos (one credit per file,
  every maker on the page and in NOTICE.md, `https://unsplash.com/@` urls);
  `test_marketing_page_weight_budgets` (60 KB per marketing page, 48 KB per Learn page, 340 KB
  images); `test_marketing_pages_eager_discipline`; alt text on every marketing page;
  `test_marketing_pages_have_no_kb_shell`; `test_home_has_rhythm` (expected failure until PR B).
- **e2e** — new `photo-bands.spec.ts`; `landing.spec` proves the light default under a dark OS;
  `transitions.spec` makes the dark choice in one click.
- **Docs** — `docs/website/README.md` image policy rewritten for v2 (Unsplash licence facts,
  respectful selection, credit shape, file locations, budgets, shot pipeline).

---

## [1.3.4] — 2026-09-22 — gurbanisoul.com: a next-level marketing site

The public site becomes a real, **multi-page** marketing property for Gurbani Soul — redesigned,
SEO-ready, with a Learn section — while staying scripture-faithful (Gurmukhi-only on the web; every
quoted line generated **verbatim** from the corpus and gate-checked). Web/presentation, docs and
tests only; scripture, corpus and DB **byte-identical** to 1.3.3. Under the one-number policy,
iOS **1.3.4 (1)** is re-archived at the same version with no app-code change.

**Highlights**
- **Soul-Gold redesign + accessible nav** — dark-first editorial design; sticky nav with a mobile
  `<dialog>` menu (focus trap, Esc, scroll lock); theme toggle shared with the Knowledge Base.
- **Multi-page structure** — Home (hero + verse + overview grid + trust strip), **/features**, and
  **/watch** (the Raag Clock, properly composed with the live pahar/raags). Nav = real routes with
  path-based active state; ClientRouter page transitions. The Knowledge Base keeps its own name/theme.
- **Real hero + app screenshots** — a two-column hero on the owner's artistic rendering of Sri
  Harmandir Sahib at sunset (no saroop in frame), with a floating iPhone showing the real Reader; the
  device frames across the site use real public-profile screenshots.
- **Learn** — 8 evergreen articles for reach; scripture quoted only via a component that renders the
  verbatim DB line (build fails on drift), every explanation labelled per the Answer-Protocol. The
  article explanations passed a **Granthi review** (2026-09-22).
- **SEO / structured data / feeds** — canonical + Open Graph + `theme-color` + Smart App Banner
  scaffold; generated sitemap (hreflang) and RSS; build-time OG share cards; JSON-LD (Organization,
  WebSite+SearchAction, SoftwareApplication, Article, BreadcrumbList, FAQPage).
- **Privacy & security** — Vercel Web Analytics loaded only on `gurbanisoul.com` (no-op elsewhere,
  cookieless); an **enforced CSP** (proven zero-violation across every route first); an env-gated
  launch-notice sign-up that ships nothing until configured.


### Added — growth & polish (PR4)
- **Structured data (JSON-LD)** via `JsonLd.astro`: the landing (`/`) now emits **Organization**
  (Algorythmos Pty Ltd), **WebSite** (with a `SearchAction` → `/search?q={search_term_string}` on the
  canonical host) and **SoftwareApplication** (Gurbani Soul, iOS, `offers.price "0"`, no
  `aggregateRating`; `installUrl`/`url` added only once `APP_STORE_URL` is set); **`/support`** emits
  a **FAQPage** generated from the same data array that renders the visible `<h4>`/`<p>` FAQ, so the
  two can never diverge.
- **Launch-notice sign-up** (`Newsletter.astro` + `scripts/newsletter.ts`, wired through the
  idempotent `landing.ts` `init()`): **env-gated** on `PUBLIC_NEWSLETTER_FORM_URL` (Buttondown). Unset
  in CI/local/this build ⇒ **no section, no form, no Buttondown reference** in the built HTML. When
  set: email-only, `mode:'no-cors'` submit with an off-screen honeypot, inline confirmation/offline
  status, and a working no-JS native POST. Honest copy (a launch notice, not a "newsletter"), no
  tracking.
- **CSP is now enforcing.** `frontend/vercel.json` flips `Content-Security-Policy-Report-Only` →
  `Content-Security-Policy` (same directive string), gated on `frontend/e2e/csp.spec.ts` proving
  **zero** `securitypolicyviolation` events across **every** route (marketing + Knowledge Base +
  `/learn/*`) under the enforced header, on load and after theme-toggle / mobile-menu (46/46 green,
  desktop + mobile).
- **Gates**: `JsonLdInvariants` and `NewsletterPrivacy` (repo gates). `NoSecretsInFrontend` no longer
  forbids the `PUBLIC_NEWSLETTER_FORM_URL` env-var *name* (its *value*/host is covered by
  `NewsletterPrivacy`); `ExternalRequestAllowlist` allows the `schema.org` JSON-LD vocabulary URI.
- **e2e**: `csp.spec.ts`, `newsletter.spec.ts` (env-unset assertions + documented skip for the
  enabled path), `headers.spec.ts` (`@smoke`, remote-only; no-op locally).
- **Docs**: `docs/process/runbooks/newsletter.md`; Newsletter/JSON-LD/enforced-CSP sections in
  `docs/website/README.md`; `PUBLIC_NEWSLETTER_FORM_URL` listed in `docs/process/environments.md`.

Web/presentation, docs and tests only — scripture, corpus and DB byte-identical.

### Added — web foundations (PR1)
- **Shared SEO/social/PWA head** (`frontend/src/components/Seo.astro`) used by both the marketing
  shell and the Knowledge Base (`Base.astro`): canonical, Open Graph/Twitter, `theme-color`,
  `<link rel="manifest">`, and the `apple-itunes-app` Smart App Banner (once `APP_STORE_ID` is set).
- **Routes manifest** (`frontend/src/routes.ts`) driving a **generated sitemap**
  (`src/pages/sitemap.xml.ts`, fixed `lastmod`, self-referencing `en`/`x-default` hreflang) and an
  **RSS feed** (`src/pages/rss.xml.ts`, "Gurbani Soul — Learn", empty until PR3). Deleted the static
  `public/sitemap.xml`.
- **OG image cards** (`src/pages/og/[slug].png.ts`) rendered at build with satori + @resvg/resvg-js
  (gold ੴ, title in Source Serif 4, wordmark); byte-deterministic, ≤ 150 KB each.
- **Privacy-scoped analytics** (`frontend/src/components/Analytics.astro`): Vercel Web Analytics
  loaded only on `gurbanisoul.com`; a no-op everywhere else. `JsonLd.astro` helper added.
- **Design tokens for the web** (`frontend/src/theme.ts`, mirrored to `styles/marketing.css`), kept
  equal to `docs/brand/tokens.json` by the `WebThemeMatchesTokens` gate.
- **Fonts**: a Latin subset of **Source Serif 4** (`public/fonts/SourceSerif4-latin.woff2`, ≤ 130 KB,
  `scripts/subset-serif.sh`). **PWA**: `public/site.webmanifest` + `public/icons/*`
  (`scripts/gen-icons.mjs`).
- **Theme module** (`frontend/src/scripts/theme.ts`) extracted verbatim from `core.ts` so the
  toggle is shared; behaviour identical.
- **Security headers** (`frontend/vercel.json`): `Content-Security-Policy-Report-Only` (not yet
  enforcing), HSTS (preload), `Permissions-Policy`, `Cross-Origin-Opener-Policy`, and immutable
  cache for `/og` and `/icons`.
- **Config**: `@astrojs/mdx`, i18n scaffolding (`en`/`pa`, no default prefix, no `pa` pages yet),
  hover prefetch. **Deps**: `@astrojs/mdx`, `@astrojs/rss`, `satori`, `@resvg/resvg-js`, `sharp`
  (exact), and `@types/node` (dev).
- **Gates**: `SeoInvariants`, `SitemapInvariants`, `RssInvariants`, `ExternalRequestAllowlist`,
  `SmartBannerConsistency`, `NoSecretsInFrontend`, `WebThemeMatchesTokens` (repo gates) and
  `StaticRoutes` (`test_serve.py`). `Landing.astro` renamed to `Marketing.astro`.

Web/presentation, docs and tests only — scripture, corpus and DB byte-identical (`git diff -- corpus
db` empty). The landing and every Knowledge Base page render exactly as before.

## [1.3.3] — 2026-09-22 — gurbanisoul.com: landing page, canonical domain, great docs

Web, iOS links, ops and docs only — scripture, corpus and DB byte-identical to 1.3.2
(`git diff -- corpus db` empty).

### Added
- **Gurbani Soul landing page at `/`** (`frontend/src/pages/index.astro`, `layouts/Landing.astro`):
  hero with respectful Unsplash photography of Sri Harmandir Sahib, the Mool Mantar verse
  (generated verbatim from the DB, cited Ang 1), feature cards, a "Private by design" section, a
  Knowledge Base card, and a "Coming soon"/App-Store slot. The Knowledge Base search page moves to
  `/search` (old `/?q=…` bookmarks forward automatically); it keeps its own name and theme.
- **SEO + site config**: `astro.config.mjs site`, `frontend/src/site.ts` (`SITE_URL`,
  `SUPPORT_EMAIL`, `APP_STORE_URL`, photo credits), canonical/OG/Twitter tags, `robots.txt`,
  `sitemap.xml`, `og.jpg`, favicon.
- **New docs**: [`docs/website/README.md`](docs/website/README.md) (site architecture, domains &
  DNS, SEO, landing/brand rules, image policy, badge swap, gates). README rewritten to cover both
  the Knowledge Base site and the Gurbani Soul app, with live URLs, a production diagram and links
  to every runbook.
- **Gates**: `LandingPage` (verse verbatim vs. DB, honest copy, alt text, SEO head, page-weight
  budget), `SubmissionUrlsAreLive`, `test_app_links_use_the_canonical_host`, and `DocsHygiene`
  (the legacy `vercel.app` alias may be named only in the domain-topology docs). `@smoke`
  `frontend/e2e/landing.spec.ts`.

### Changed
- **Canonical public host is now `gurbanisoul.com`** everywhere: iOS `AppLinks` (Privacy/Support),
  the App Store listing URLs and contact (`support@gurbanisoul.com`), `deploy-production` /
  `uptime` / `sggs-verify-prod` targets (with a no-redirect directional guard and a landing check),
  `SECURITY.md`, `NOTICE.md`, `CLAUDE.md` and `docs/process/environments.md`. `www` and the legacy
  Vercel alias 308-redirect to the apex.
- `testflight_archive.sh` defaults `GITHUB_REPOSITORY` from the git remote so a local
  `make testflight … UPLOAD=1` no longer trips the CI-green check.

### Removed
- The superseded standalone `landing/` static site (its policy pages are now the Astro
  `/privacy` and `/support`; keeping a second copy risked a divergent policy).

### Data
- None. Scripture, corpus and DB unchanged from 1.3.2.

## [1.3.2] — 2026-09-22 — App Review readiness

Pre-submission pass for the first public App Store release. App display, web/API and docs only —
scripture, corpus and DB are byte-identical to 1.3.0 (`git diff -- corpus db` empty).

### Added
- **In-app Privacy Policy + Support** (More → Privacy Policy / Support). A static, offline policy
  that renders in Airplane Mode and mirrors the web page, with links to the live pages —
  Guideline 5.1.1(i), since the app prompts for Location and Notifications.

### Changed
- **App Store listing, review notes and privacy/support pages made accurate to the shipping app**:
  a working reviewer path (Hukam is in the Reader bar, Save is a long-press); integrity described
  as verified on install/update and re-checked on change (not "every launch"); the correct Siri
  phrase list ("Read a bani"; "Open Ang" is a Shortcuts action); solar-mode, widget and screen-label
  wording; the submission runbook (ASC version string, Mac/Vision Pro unticked, Pending Developer
  Release → Release) and NOTICE.md (fonts, SQLite).

### Fixed
- **`PrivacyInfo.xcprivacy`** now declares reason `1C8F.1` for the App Group `UserDefaults` suite
  shared with the widget extension.
- A failed scripture-database open shows a plain message instead of a raw Swift error string.

### Data
- None. Scripture, corpus and DB unchanged from 1.3.0.

## [1.3.1] — 2026-09-20 — App Store readiness hardening + Reader navigation fixes

A production-readiness pass ahead of the first public App Store submission (2026-09-20 audit).
Scripture, corpus and DB are byte-identical to 1.3.0 (`git diff -- corpus db` empty); this release
is display, web/API, tooling and docs only.

### Added
- **Executable repo gates** (`webapp/tests/test_repo_gates.py`, run by the required `python` check):
  crash-hygiene (no `try!`/`as!`, `print`/env-hooks only under `#if DEBUG`, no network code), the
  design-token gates (`withAnimation`, hex colours) that were prose before, Info.plist and
  privacy-manifest invariants, an App Store release attestation gate, and store-listing lint.
- **Field diagnostics** — About → Share / Delete the local MetricKit files (system share sheet, never
  automatic, so the "Data Not Collected" label stays true); the folder is capped at 50 and excluded
  from backup.
- **App Store release gate** — `make testflight … CHANNEL=appstore` and `make appstore-preflight`
  (`ios/tools/appstore_preflight.py`): an App Store build must be scholar-reviewed, built with the
  required Xcode/SDK, and come from a clean, green, on-trunk commit; the ledger records channel/toolchain.
- **Uptime workflow** — 15-min probe of production `/api/health` and the `/privacy` + `/support` App
  Store URLs; **runbooks** for submission go/no-go, iOS hotfix and the support inbox.

### Changed
- **Store listing** made accurate and linted: promotional text within 170 chars, no "audio"/"AI" claims,
  the Nitnem section and the correct widget count, ShabadOS attribution, and the App Store Connect
  sections (age rating, EU DSA trader, accessibility labels, territories).
- **Privacy & support pages** renamed to Gurbani Soul and updated for reminders, the Live Activity and
  Nitnem progress, with `@smoke` coverage.
- **Web API hardening** — a claim-length cap on `/api/verify`, a socket timeout, a bounded worker pool,
  `Cache-Control`/`ETag` on immutable scripture responses, HSTS and a query-free access log. Search
  behaviour is byte-identical.
- **PR CI now builds and tests iOS on Xcode 26** (the SDK that ships), not the runner default.

### Fixed
- **Nitnem reminders now actually alert** — a real permission prompt on the explicit toggle and a
  normal banner + sound (they were requested provisional and delivered passive, so they never showed).
- **The reading Live Activity now starts on a first read**, not only a resumed one, and its Lock-Screen
  banner deep-links back to the bani.
- **A failed `sqlite3_step` is now an error, never "no more rows"** — the 46 read loops could have
  returned a silently truncated Ang on a corrupt/IO error.
- **The open Ang re-renders in place on a theme change** (accent no longer stale until the next page turn).

### Data
- None. Scripture, corpus and DB unchanged from 1.3.0.

---

The remaining notes in this entry are the iOS Reader navigation work that was previously staged as
Unreleased and ships as part of 1.3.1.

### Reader navigation fix (iOS)

Fixes the Reader page-turn controls reported broken on TestFlight 1.3.0 (2): the bottom-bar
chevrons and the "Continues on Ang N" pill did nothing after the first tap, and the pill named the
current Ang instead of the next. Root cause: `AngPager` latched an "in transition" flag on an
animated programmatic page turn that `UIPageViewController` never cleared (its completion/delegate
callbacks are gesture-only), so every later programmatic navigation was parked while the title kept
advancing — title and page desynced.

- Reworked the pager around a pure, unit-tested `PagerSync` state machine and synchronous,
  non-animated `setViewControllers` wrapped in a `CATransition` (slide for ±1, fade otherwise). No
  correctness now depends on a UIKit completion callback; a 0.5 s watchdog + a runloop self-heal
  guarantee the visible page converges to the router's Ang.
- Chevrons now show their destination (`‹ 1181 · Hukam · 1183 ›`); every Ang before 1430 ends with
  a forward control ("Continues on Ang N+1", else "Next · Ang N+1") so the reader is never stranded
  and Sehaj focus has a tap-to-advance; VoiceOver announces each page turn; the Hukam button falls
  back to its glyph at large Dynamic Type sizes.
- Also fixed: an Ang deep link/intent no longer lands behind an open sheet; the bottom bar no longer
  vanishes on arriving at a previously-scrolled Ang; the page cache anchors on the current Ang (not a
  neighbour) so the "Continues on" pill can't disappear; resume-last-Ang goes through a documented
  `Router.resumeAng`.
- Tests: `PagerSyncTests` (incl. a 5,000-sequence convergence fuzz), `AngPagerHostedTests` (real
  `UIPageViewController`), and UI tests for the chevrons, the continuation pills, rapid taps, bounds,
  and navigation around sheets/backgrounding — each asserting the title AND the visible page agree.
  CI now uploads `.xcresult` bundles on failure. Scripture, corpus, DB, API untouched.

### Reader: blank Ang after a few page turns + a tappable "Ang N" title (iOS)

Fixes the Reader going permanently blank (grey skeleton, verses never appear) a few pages after a
jump — reported on TestFlight 1.3.0 (4) at Angs 352, 918, 1106. Two independent defects in
`ReaderModel`'s page cache: (1) the eviction anchor only moved when a page loaded *as current*, but a
swiped-to page mounts *before* it is current, so the anchor stayed on the last jump and the 4th swipe
evicted the very page it had just loaded; (2) a page that mounted while its Ang was being pre-warmed
hit the `inflight` guard, got nothing back, and — because the view sampled the cache once and never
observed it — sat on the skeleton forever.

- The eviction anchor now follows every Ang change via `ReaderModel.setCurrent` (driven by
  `router.readerAng`, swipe-settle included); eviction protects anchor ±2 and never drops the page it
  just cached. Loads are coalesced through one shared `Task` per Ang, so a page mounting mid-pre-warm
  awaits that load instead of skipping it; `ensure` returns the page it loaded rather than making the
  caller re-read the cache.
- `AngPageView` observes the cache (adopts a page that arrives by any route), retries once quietly on
  a failed read, then shows a real "Couldn't load Ang N · Try again" state instead of an endless
  skeleton, and logs the failure.
- The "Ang N" reader title is now a control (`angTitle`, with a chevron affordance): tap it to open
  Jump with the number pad already up and type where to go. The existing top-left button, progress bar
  and raag banner keep their unfocused open; `.navigationTitle` is unchanged.
- Tests: new `ReaderModelTests` (the swipe-run eviction regression, the pre-warm race, no-cache-on-
  failure + retry, eviction invariants, bounds, cancellation safety); `assertOnAng` now also requires
  the loaded content view (`angContent-N`) so no Ang can pass on a skeleton; new UI tests for an
  8-page swipe run after a jump and for the tappable title. Scripture, corpus, DB, API untouched.

### Jump-to-Ang sheet: genuinely editable number, working Go, no overlap (iOS)

Follow-up polish on the Jump sheet reported from TestFlight 1.3.0 (5)–(6):

- **The Ang number is now a real, editable field** — seeded with the current Ang and shown with a
  pencil affordance + an underline (brightening on focus). Tap it and the whole number selects, so a
  new Ang replaces it in one keystroke, or place the cursor to edit a digit / backspace. (Earlier
  builds put an *empty* field over the number, so it could only be retyped from blank, not edited —
  which read as "can't edit".)
- **One honest Go.** The pinned primary action restates the destination — **"Go to Ang N"** when the
  number differs from where you are, a dimmed **"You're on Ang N"** when there's nowhere to go, and
  **"Enter an Ang from 1 to 1430"** on an out-of-range entry. Removed the duplicate keyboard "Go"
  (which looked broken next to it); the keypad now shows a plain **Done** that only drops the keypad.
- **No more overlap.** The Go bar is now opaque (`Ink.canvas`) with a top divider, so the "Jump to a
  raag" card can no longer bleed through it, and it sits cleanly above the number pad.

Verified: app compiles; the Jump UI tests (steppers → Go label + landing, typed-Ang from the title,
progress-bar open, AX5 layout) pass. Display/navigation only — scripture, corpus, DB, API untouched.

## [1.3.0] — 2026-09-19 — Nitnem, next level (premium pass)

The daily-prayer (Nitnem) experience rebuilt end to end: a time-of-day paper home, derived
pauri/ashtapadi numbering with a Contents jump, reading settings and paper tones, a quiet
completion seal, a reading journey, Home-Screen and Lock-Screen widgets, hands-free auto-scroll,
gentle on-device reminders, customisable "My Nitnem" sets, and an opt-in reading Live Activity.
iOS display layer only — scripture, corpus, DB and API untouched (`git diff -- corpus db` empty).

### Added — Live Activity (opt-in)
- **Reading Live Activity** (More → Nitnem → Live Activity, default OFF): while you read a bani,
  the Lock Screen and Dynamic Island can show its title and a whole-percent progress bar — never a
  verse. It starts only after a genuine 20-second dwell, updates on a whole-percent change and at
  most every 10 seconds, ends on completion or leaving, carries a 20-minute stale date, and any
  activity left by a previous launch is swept on startup. No push, no server; the shared attributes
  live in the widget extension. Availability is gated on the opt-in and the system.


### Added — My Nitnem
- **Customisable daily sets** (More → Nitnem → My Nitnem): reorder the banis in the morning,
  Rehras or Sohila set, hide one, or add any bani from the library (e.g. Sukhmani Sahib in the
  morning). The home screen and the widgets both follow the customised set, and the completion
  rings and reminders count against it. Every bani stays in the library — hiding only affects the
  daily set. Edits live in a new `nitnem-plan.json` sibling file; the reading-history file is never
  migrated, so an older build can never lose progress. Unknown keys are dropped, a bani added in a
  later app version is appended, and the Rehras variant is honoured.


### Added — gentle reminders
- **Opt-in Nitnem reminders**: a quiet, local nudge for the morning banis, Rehras or Sohila at a
  time you choose (More → Nitnem → Reminders). Entirely on-device — no account, no network, no
  extra entitlement. Each enabled band schedules 14 dated, non-repeating notifications so a band
  you have already read stays silent; today's is dropped the moment you complete it. Copy carries
  no Gurmukhi, no counts and no emoji, delivery is passive (never interrupts your reading), and a
  tap opens Nitnem. Permission is asked only when you turn a reminder on; a denial snaps the toggle
  back with a link to Settings.


### Added — hands-free reading
- **Auto-scroll** in the bani reader: a play/pause control paces the page at Slow / Steady / Brisk
  (chosen in Reading settings), scaled by the Gurmukhi size so a larger font never reads faster.
  It drives the real scroll view from a display link, so lazy loading and progress saving keep
  working, and it **pauses the instant you touch the page**. It never auto-starts, reaching the end
  never marks a bani read, and it is hidden entirely under VoiceOver, Switch Control and Reduce
  Motion, and paused when a sheet opens, the app backgrounds, or you jump to a section.


### Added — widgets
- **Nitnem widgets** (Home Screen small/medium, Lock Screen circular/rectangular/inline): the
  bani to read now for the time of day, today's set progress as a gold ring, and the next
  unread bani in ink Sant Lipi — the same paper-and-gold vocabulary as the Hukam widget. Tapping
  opens the bani (`sggs://bani/<key>`). The widget never opens the corpus DB: it reads the
  App-Group snapshot (resolved sets, filled by the app) plus the live progress file, and reloads
  the moment a bani is marked read. Timeline entries at the band boundaries incl. the 03:00
  Nitnem-day rollover. `NitnemBand` moved to `Shared` (widget-safe).


iOS display layer only — scripture, corpus, DB and API untouched (`git diff -- corpus db` empty).

### Added
- **Time-of-day Nitnem home**: a paper hero with a faint gold glow and the day drawn as an arc
  (sun/moon at the present moment), a small-caps date eyebrow, a serif band title, larger
  completion rings, symboled section eyebrows, a per-row "last read" line, a calm skeleton on
  load, and a two-column iPad layout. `PaperGround` is now palette/intensity-parameterised and
  reused from the widget vocabulary.
- **Reader numbering & Contents**: pauri / ashtapadi / salok margin labels and a Contents sheet
  (jump to any pauri) derived only from the verbatim `markers` via the new `BaniOutline` (Kit).
  A `baniStanza` caption ("Pauri N of M") under the position bar.
- **Reading settings**: Gurmukhi size, line spacing (floor 0.40), and paper tone Paper / Warm /
  Night. New `Ink.paperWarm` token (contrast-proven) and a `gurmukhiLeading` environment.
- **Quiet completion**: a gold seal closes the ring on "mark as read", and a calm band-complete
  card ("The morning banis are complete.") when the whole set for the time of day is done.
- **Reading journey**: a quiet month record (from the data already stored) of the days the
  morning banis / Rehras / Sohila were completed, with a consecutive-days count. No badges,
  targets, or sharing. Reached from a home card and honours the locale's first weekday and DST.

### Changed / hardened
- **One clock, a 03:00 Nitnem day** (`NitnemClock`): Sohila read at 22:00 stays complete past
  midnight; the night band never splits. Used by the home, reader, and (later) widgets/reminders.
- **Positions survive a DB rebuild**: progress stores a verbatim anchor + line count and resumes
  by anchor when the registry changed, else the top; the progress file never overwrites a newer
  schema. `nitnem-progress.json` stays schema v1.
- Brand book §6 gains a **Glow** row (≤14% wash, distinct from the Explore-hero gradient) and a
  Reader-paper row. `docs/nitnem/spec.md` records the frozen identifiers.

## [1.2.1] — 2026-09-18 — Apple-clean clock face, readable raag list, Solar by default

iOS display + widget layer only — scripture, corpus, DB and API untouched (`git diff -- corpus db` empty).

### Changed
- **The clock in the pahar ring is now an Apple-style analog face**: a quiet surface, bold hour ticks
  with thin minute ticks on the rim, thin SF numerals 1–12, tapered white hour and minute hands, a small
  **day/date complication** ("SAT 19") and a ringed hub. On the app it carries a **thin gold seconds hand
  that sweeps smoothly** (≤30 fps); the hands are their own layer (`ClockHandsLayer`) so only they animate —
  the ring redraws once a minute. The sweep pauses when the screen is scrolled away, when the app is
  backgrounded, and under Reduce Motion (then it ticks once a second). Widgets show hour and minute hands
  (WidgetKit cannot animate) at the entry minute.
- **The current watch's raags moved out of the clipped hero chip row into a readable "Sung in this watch"
  list under the clock**: one row per primary raag, the Gurmukhi name (verbatim, ink Sant Lipi) over its
  roman form, the first Ang, the whole row a single tap into the Granth. A "All claims and sources for this
  watch" link opens the full detail sheet.
- **Solar is now the default** clock mode (the traditional, sun-accurate reckoning). A reader who never chose
  gets Solar; an explicit Fixed/Solar choice is always respected. With no stored location the clock shows the
  fixed watches plus a one-tap **"Use my location"** card (location is still requested only on that tap, or
  entered by hand; rounded to ~1 km, on-device, never sent). App, snapshot and widgets read one
  `SharedDefaults.defaultClockMode` constant.

### Fixed
- The digital time and pahar label moved from inside the clock face to a readout row beneath it, so the face
  stays uncluttered like a real watch.

## [1.2.0] — 2026-09-18 — Raag Clock v2: a real local clock inside the pahar dial

iOS display + widget layer only — scripture, corpus, DB and API untouched (`git diff -- corpus db` empty).

### Added
- **The dial is now a 24-hour clock face on the reader's own wall clock.** An hour ring (24 ticks,
  a major every 3 h) with cardinal numerals in the reader's hour cycle (`6 AM · 12 PM · 6 PM · 12 AM`,
  or `06 · 12 · 18 · 00` on a 24-hour device), and the **live local time in the dial's hollow** in
  Source Serif 4 — with the current watch and a countdown to the next one — so one glance answers
  "what time is it here, which pahar is that, which raags belong to it", anywhere in the world.
  Ticks on the minute boundary; redraws on a system time-zone or clock change. The readout is a
  real accessibility element (`clockNowReadout`); the painted face stays decorative.
- **A real wall clock in the hollow**: numerals 1–12, minute ticks, ink hour and minute hands and a
  gold hub, painted by the same renderer — the modern 12-hour clock and the eight Sikhi watches on
  one face, so the reader compares "4:08 pm" and "4th pahar of day" at a glance (the ring pointer and
  the hands are both driven by the same minute). Small widget faces show 12 · 3 · 6 · 9. Widgets get
  a timeline entry every minute for the first 3 h so the hands never lag.
- **Sunrise / sunset badges** on the day–night seam when Solar mode is live.
- **`PaharFormat`** (`ios/App/Shared/`): locale-aware time/window/countdown formatting on top of the
  byte-parity `Pahar` math (`fmt12`/`range` and the golden vectors are untouched). Windows are
  resolved through `Calendar` on the calendar day, so DST days render the real wall clock; wrap-safe.
- **`PaharDialRenderer`** (`ios/App/Shared/`): one Canvas face for the app and every widget family,
  brand tokens only (`accentFill` current watch with an `accent` stroke, `accent` hand, `accentDeep`
  day / `Ink.info` night, pahar 7 faint on purpose).
- **Raag Now widget, all families**: `systemSmall` (dial + live time), `systemMedium` (dial + time,
  window, chips, next-in), new **`systemLarge`** (full dial with numerals, chips, the eight watches),
  and new **lock-screen accessories** `accessoryCircular` (mono dial, `P4`), `accessoryRectangular`
  (watch · raags · next-in) and `accessoryInline`. The digital time and countdown use WidgetKit's
  live `Text(date, style:)` so they stay current between entries; the hand is refreshed on a 15-min
  cadence plus every pahar boundary (≤120 entries/24 h, wall-clock, DST-safe).
- **Widgets follow the app's Fixed/Solar choice.** `sggs_clock_mode` and the rounded solar
  coordinates moved to the App-Group `UserDefaults` suite (`SharedDefaults`, one-time migration from
  `.standard`); the snapshot also carries `clockMode`/`solarLat`/`solarLon` (optional; older
  snapshots decode). Polar day/night or no coordinates → fixed clock, exactly as in the app.
- Unit tests `PaharFormatTests` (12/24-h, midnight wrap, DST spring-forward/fall-back, JS tz sign,
  polar/degenerate sun, dial geometry round-trip) and `RaagNowTimelineTests` (entry-at-own-date,
  cadence/boundary/budget, DST boundaries, solar fallback, legacy snapshot decode).

### Changed
- Every pahar window on the Clock (hero line, the eight watches, detail sheets) is rendered in the
  reader's locale and 12/24-hour setting (Foundation's narrow no-break space normalised to a plain
  space). `testRaagClock` pins `en_US` via launch arguments so the load-bearing
  `"4th pahar of day  ·  3–6 PM"` string is identical on every simulator, and asserts the new readout.
- The "now" pointer lives in the pahar band only (root pip at the inner edge) — it never crosses
  the hollow, which belongs to the readout. NOON/MIDNIGHT labels are replaced by the numerals.
- Widget description: "Your local time on the 24-hour Raag Clock — the current watch and its raags.
  Follows the app's Fixed/Solar setting."

### Fixed
- The dial no longer uses ad-hoc HSB colours; it is on the brand tokens in both schemes (dark stays
  warm ink). Numerals are inset so they never clip the canvas on narrow phones.

## [1.1.5] — 2026-09-18 — Premium widgets

iOS display layer only — scripture, corpus, DB and API untouched (`git diff -- corpus db` empty).

### Changed
- **Widgets redesigned to the brand system** (Hukam verse, Raag now): warm paper ground with a
  faint gold light, a small-caps gold eyebrow, the ੴ signature, scripture in ink Sant Lipi with
  room to breathe, the citation set in Source Serif 4 as the full *Sri Guru Granth Sahib Ji ·
  Ang N*, and raag chips that show the verbatim Gurmukhi raag name over its roman form. The
  snapshot gains `paharRaagsGurmukhi` (optional; older snapshots still decode). Source Serif 4
  is now bundled in the widget extension. Scripture in the widgets stays verbatim and ink.

## [1.1.4] — 2026-09-18 — Header-detector fix (DB rebuilt) + Gurbani Soul brand system

Gurbani Soul brand system for the iOS app (display layer only — scripture, corpus, DB and API
untouched; `git diff -- corpus db` empty). Governed by `docs/brand/gurbani-soul-brand-book.md`;
`docs/brand/tokens.json` is the palette source of truth and `scripts/brand/contrast_report.py`
proves every pair across light / dark / Increase Contrast.

### Added
- **Soul Gold** accent palette, now the default for readers who never chose one (a stored choice
  is kept; Saffron, Gold, Indigo, Teal unchanged). Brand gold `#FFBC0D` is a *fill-only* token
  (`accentFill`, always bordered) because it measures 1.69:1 on white; tint, icons and borders use
  `#A87900` in light mode.
- **Source Serif 4** (SIL OFL 1.1) for navigation titles and hero headings only; body stays the
  system face and Gurmukhi stays Sant Lipi. `BrandFontTests` pins registration and scaling.
- App icon **concept A** — gold ੴ on warm ink, flat, no red — and a re-tinted launch logo.
- `Ink.base` and the `inkGroupedList` / `inkPlainList` / `inkRow` helpers.

### Changed
- **Reader typography (display only — text, ids, copy/share/search and VoiceOver stay verbatim).**
  A centred 640-pt reading column on iPad; verses spaced as units (tighter wrapped lines, more
  air between verses); a hairline + heading where a new shabad opens; the ੴ invocation set at
  full verse size; a quiet accent rule beside the ਰਹਾਉ line; and a closing `॥੧॥` / `॥ ਰਹਾਉ ॥`
  can no longer wrap onto a line of its own (WORD JOINER-guarded spaces — Sant Lipi's U+00A0
  has zero advance, so a no-break space would have closed the gap before the danda).
  `VerseTypographyTests` prove the display form reduces to the verbatim line.

### Fixed
- Dark mode no longer drops to pure black on Search, More, About, Saved, Trail, Divergence,
  Constellation, Vaars, Insights and the integrity-failure view — all sit on warm ink.
- ~230 verses were drawn as centred bold headings mid-shabad (the corpus `is_header` flag
  fires on a composition-type word inside a verse — ਵਾਰ, ਅਨੰਦੁ, a leading raag name). A display
  guard now styles them as verses in the Reader and the shabad sheet; the corpus flag itself
  (which also splits those shabads' `comp_id`) is tracked separately.
- iPad Raag Clock: the dial floated in ~700 pt of empty space; content is now a centred column.
- The Appearance picker kept its previous tint after an accent change.
- The hero gradient's deep end now holds 4.5:1 under its label in Increase Contrast.

### Data — header detector fix (metadata only; scripture byte-identical, DB rebuilt)
- `detect_header` no longer takes a verse for a heading when it merely contains a
  composition-type word (ਵਾਰ, ਅਨੰਦੁ, ਪਉੜੀ, ਗੁਣਵੰਤੀ, ਵਣਜਾਰਾ, ਰੁਤੀ …), starts with a raag name
  (ਆਸਾ ਮਨਸਾ …, ਬਸੰਤੁ ਹਮਾਰੈ …), or matches a Bhagat name qualified only by a *substring*
  (ਜੀ inside ਜੀਵਨ/ਬਾਜੀ, ਵਾਰ inside ਉਰਵਾਰ/ਗਵਾਰੁ). Those signals now need a short label line,
  a title printed without ॥, an attribution (ਮਹਲਾ/ਮਹਲੇ/ਮਃ/ੴ/ਰਾਗੁ/ਘਰੁ/ਕੀ ਵਾਰ), a whole-word
  label (ਬਾਣੀ, …ਪਦੇ, ਇਕਤੁਕੇ) or the honorific ਜੀ/ਜੀਉ directly after the name. `ਸੁੰਦਰੁ` is
  dropped from the Bhagat table (no heading in the print names Baba Sundar; the entry only
  ever matched verses in M4/M5 shabads). Bare `ਰਾਗ` + raag name (Raagmala verse) is weak.
- Result: **233 verses** `is_header` 1→0 (5,380 → 5,147 headers); no line becomes a header.
  Shabads those false headers had split are whole again (distinct comps 4,706 → 4,527, e.g.
  Ang 396 `comp_id` 1484 rejoins 1482; Japji is one composition). Every `comp_id` a demoted
  verse used to open is **burned as a permanent gap** (5377–5380 among them), so no other
  composition's id moves: no `comp_id` increases, no gap is reused, no heading changes id.
  `comp_type` corrects on 18,178 lines (the false headers had been overwriting it —
  the known Japji ਰੁਤੀ/ਵਾਰ mislabel), `author` on 232 lines (Baba Sundar → M4/M5; stale
  Vaar-author on Angs 1279/1416; Kabir/Namdev → M5 on Angs 1192/1376), `ghar` on 7.
  `raag` and `section` unchanged on every line. Full before/after list for scholar review:
  `validation/header-fix-review/`.
- Gates: `reconcile.py` char-exact, golden suite (+22 detector checks) all-pass,
  `diff_scripture.py` shows only the columns above changed, `verify_regroup.py --invariants`
  updated to the 4,527 comps.
- `build_vaars.py`: a Vaar now ends at any Bhagat-bani section heading (`ਬਾਣੀ ਭਗਤ…`), not
  only Basant's — the Ramkali (Satta & Balwand) and Malar Vaars had been ending by accident
  on verses mis-flagged as ਪਟੀ headers. Malar Ki Vaar regains its 28th pauri and two saloks
  (vaar_units 1,423 → 1,426); the other 21 Vaars are unit-for-unit identical.
- Re-baselined: `audit/scripture-baseline.json`, `contract/*` (Homebrew python 3.14), `MANIFEST`
  `db_sha256` → `f8135f62…`, iOS manifests (`scripture_sha256` **unchanged** `0eff4bae…`),
  `variants` pin 79,666 → 79,840 (built from `is_header=0` lines). Harnesses: round-trip
  99.3 % / 100 % (unchanged); casual-quote within seed noise of the old DB.
- iOS: the `rendersAsHeading` display guard stays until this DB ships in the app bundle.

### Pending before App Store submission
- Brand-book gates **G3** (Granthi/scholar acceptance of the ੴ icon treatment) and **G4**
  (professional clearance of the gold-and-red palette; no Arches/Token-like lockup is used).

## [1.1.3] — 2026-09-17

Brand architecture set ahead of the first public TestFlight → App Store release: the consumer
**app** becomes **Gurbani Soul**, built by **Algorythmos Pty Ltd** (endorsed brand); the scholarly
**website/Knowledge Base** stays *Sri Guru Granth Sahib Ji — Knowledge Base*; and scripture inside
the app is always cited by its full name, *Sri Guru Granth Sahib Ji · Ang N*. Display/metadata
only — scripture, the DB (`db_sha256` unchanged), and all bundle identifiers are untouched
(`git diff -- corpus db` empty).

### Changed
- **App (iOS/Android) product name → `Gurbani Soul`.** iOS on-device label
  (`CFBundleDisplayName`/`CFBundleName`) and widget-group name → `Gurbani Soul` (12 chars, fits
  under the icon); About screen → "Gurbani Soul" + "Built by Algorythmos", still crediting the
  scripture as *Sri Guru Granth Sahib Ji*.
- **App Store listing** (`docs/ios/app-store-listing.md`) rebranded to Gurbani Soul: Name,
  keyword-dense subtitle, trust-led promotional text + description opening (verified, cited, never
  AI-invented), keyword field, About/footer credit, and `gurbanisoul.com` URL targets.
- In-app **scripture citations** (verse-card, share/copy, Spotlight, verify verdict) keep the full
  **Sri Guru Granth Sahib Ji** wording — they cite the text, not the app.
- **Website / Knowledge Base** page titles, site header and Study-Trail export header → full
  *Sri Guru Granth Sahib Ji* (the KB is a distinct property from the Gurbani Soul app); the
  Raag-Clock and divergence tabs no longer abbreviate to "SGGS".
- **iOS build-number hygiene.** New tracked ledger `ios/testflight-builds.json` +
  `ios/tools/testflight_ledger.py` are now the source of record for every App Store Connect upload.
  `ios/tools/testflight_archive.sh` gains a pre-work gate (step 0b): it runs `check_versions.py`
  and refuses a reused CFBundleVersion or a marketing-version downgrade **before** archiving, then
  records the upload on `SGGS_UPLOAD=1`. `make testflight-next` prints the next build number;
  `ios.yml` fails if a committed `Info.plist` drifts from the XcodeGen spec.

### Fixed
- `testAboutShowsVersion` no longer hardcodes the version string (it was pinned to a stale
  `1.1.1+1`, then hand-edited to `1.1.3+1`). The `SGGSUITests` bundle now carries the app's
  `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in its own `Info.plist`, and the test reads the
  built version from it — so it passes for any archive/build number and can't silently rot.
  `check_versions.py` now also enforces the `CURRENT_PROJECT_VERSION` floor and bans `x.y.z+n`
  literals in the UI tests (8 version strings → 10 checks).

## [1.1.2] — 2026-09-16 — TestFlight launch kit + support/privacy pages

### Added
- **TestFlight → App Store launch kit** (docs/CI/tooling only; no code, corpus or DB change):
  `docs/ios/testflight-launch-plan.md` (phased plan with entry/exit gates),
  `docs/ios/testflight-test-plan.md` (device matrix, test charters incl. the mandatory
  scripture-fidelity charter, triage rules, build log) and `docs/ios/app-store-listing.md`
  (metadata, privacy answers, review notes).
- `ios/tools/testflight_archive.sh` + `make testflight`: derives the chosen DB profile
  (default `public`, Gurmukhi-only), runs `check_release_license.sh` on that exact artifact,
  generates the project, archives with the Team ID and build number passed on the command
  line, exports or uploads to App Store Connect, then proves the version/build/widget version
  and the DB hash *inside* the archived `.app`.
- `.github/workflows/ios-testflight.yml`: manual (`workflow_dispatch`) upload on a hosted
  macOS runner through the same script, keyed by an App Store Connect API key in the
  `testflight` environment.

- **`/support` and `/privacy` pages** (`frontend/src/pages/support.astro`, `privacy.astro`) — the
  public Support URL and Privacy Policy URL the App Store listing requires; linked from the site
  footer. Every privacy statement is checked against the code (no network, no analytics, location
  rounded and on-device, local diagnostics only, hosting-provider server logs disclosed).

### Data
- None. Scripture, corpus and DB unchanged (`db_sha256` 883f6f80…).

### Versions
- `APP_VERSION` 1.1.2 · `MANIFEST.json` 1.1.2 · iOS `MARKETING_VERSION` 1.1.2 · built 2026-09-16.

## [1.1.1] — 2026-09-15 — Deploy foundations

### Added
- `/api/meta` and `/api/health` report `commit` (the running build's source SHA, from
  `RENDER_GIT_COMMIT`), so a deploy is verified by identity, not just by version.
- `.github/actions/lfs-db`: the 108 MB database is fetched through an oid-keyed cache in
  every CI job, so repeated runs stop spending Git LFS bandwidth.
- `scripts/release/release_notes.py`: shared, tested CHANGELOG-section extractor.
- Playwright remote mode: `PLAYWRIGHT_BASE_URL` (+ Vercel protection-bypass header) runs
  the `@smoke` heading tests against any deployed URL.

### Changed
- Release PRs `integration → main` are merge commits; `main` no longer requires linear
  history (squash/rebase releases made the branches diverge). Documented in branching.md.
- `render.yaml` is staging-only with `autoDeploy: false`, so linking the Blueprint can never
  create a duplicate production service.
- `release.yml` is a manual fallback; releases will be cut after a verified deploy.
  The auto back-merge PR is removed (a `GITHUB_TOKEN` PR can never pass required checks).
- Frontend pins `engines.node 22.x` so Vercel builds on the same Node as CI.

### Fixed
- Old release-notes regex could run past the version's section into older prose entries.

### Data
- None. Scripture, corpus and DB unchanged (`db_sha256` 883f6f80…).

## [1.1.0] — 2026-09-15 — Composition heading fix (header-run regroup)

### Fixed
- **The composition sheet (web + iOS) now shows the printed heading.** Opening a
  shabad — e.g. Ang 712 — previously showed only `ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥` and the
  verses, dropping the title line `ਟੋਡੀ ਮਹਲਾ ੫ ਘਰੁ ੨ ਚਉਪਦੇ`. Root cause: the
  corpus extractor gave every heading line its own `comp_id`, so a title line
  followed by a separate ੴ invocation became a one-line "orphan" composition
  that `/api/shabad/{comp_id}` (and the iOS `fetchShabad`) never fetched. Now a
  run of consecutive heading lines opens ONE composition together with the body
  it introduces (`pipeline/build_corpus.py` post-pass 1b).
- **Pin button no longer overlaps long Gurmukhi verses** in the composition sheet
  (`.haspin .g` reserves 48px for the 36px pin control).

### Changed
- The composition sheet drops its synthesized raag/section title when the real
  heading row is present, so the title is never shown twice (web `panel.ts`, iOS
  `ShabadSheet` renders heading rows centred, like the Reader).
- `/api/shabad/{comp_id}` returns **404** for an unknown or now-vacated `comp_id`
  instead of an empty sheet.
- Bani-forms derivation (`derive_bani_forms.py`) and Vaar detection
  (`build_vaars.py`) choose the title across the whole heading run — 495 shabads
  now surface their form/genre (`shabd_poetic_genre` 57→67); Vaar count unchanged
  (22 / 1423 units).

### Data
- **Scripture byte-identical.** 60,658 lines, 1,430 Angs; reconcile char-exact vs
  the source PDF; every field except `comp_id`/`line_no` is byte-for-byte
  unchanged (proven by `pipeline/verify_regroup.py`, and independently at the
  JSONL level). 674 heading lines folded; distinct compositions 5,380 → 4,706
  (vacated `comp_id`s become permanent gaps — no body line or saved bookmark
  changes id). `db_sha256` `883f6f80…`; scripture hash `0eff4bae…` unchanged.
- Contract vectors regenerated (reader/timing/analytics changed; search / verify /
  roman-norm / difflib / pahar **unchanged**). iOS bundles rebuilt (both profiles),
  Swift golden-parity 17/17. `audit/scripture-baseline.json` re-recorded.

### Added
- `pipeline/verify_regroup.py` — mechanical old-vs-new proof (release gate: only
  `comp_id`/`line_no` may change; scripture and text-derived tables identical).
- `pipeline/api_superset_check.py` — integration proof that every composition
  serves its exact lines, headings appear, and gap ids 404.

### Versions
- `APP_VERSION` 1.1.0 · `MANIFEST.json` 1.1.0 · built 2026-09-15.


## v1.0.0 — Unified Production Baseline & TestFlight Release
Version-unification pass: iOS, web, and API version strings reset to a single `1.0.0` baseline (iOS build 1) ahead of the first public TestFlight/production release. Metadata and documentation only — no corpus, DB, or search-logic change (`git diff -- corpus db` empty). Consolidates the recently landed pre-TestFlight hardening work now shipping under this baseline: Reader/sheet layout hardening (AX3 Dynamic Type truncation fix, scene-active watchdog), iOS 26 tab bar UX polish (bottom-bar controls moved out from under the floating glass tab bar; iPad search-presentation tab bar fix), precision deep-link/verse routing (`sggs://ang`, `sggs://shabad`, Spotlight, Study Trail — every entry point lands scrolled to and highlighting the exact verse), and full test-suite stabilization (kit 17/17, 33 unit, 26/26 UI tests green in one uninterrupted run).
- **Versions.** `APP_VERSION` 1.0.0 / `MANIFEST.json` 1.0.0 (`db_sha256`/`corpus_sha256` unchanged), iOS `MARKETING_VERSION` 1.0.0 build 1, README/MASTER-INDEX/CLAUDE.md in step.

## iOS 1.1.1 + web v2.12.1 — 2026-09-05 — pre-TestFlight hardening pass (scripture byte-identical; no DB rebuild)
Full-project audit before the first TestFlight build: four audit agents over every iOS source, the Swift kit, tests, CI, plists and the web server/frontend, then an adversarial review of each proposed fix before it was applied. Everything below is verified: kit 17/17 (golden contract), app 30 unit + 22 UI, search harnesses byte-identical to the pre-pass baseline, `/api/health` all true, `git diff -- corpus db ios/Resources` empty.
- **iOS release blockers.** `PrivacyInfo.xcprivacy` now declares the file-timestamp required-reason API (`C617.1`) that `LaunchIntegrity` uses every launch (was an ITMS-91053 on upload). The single root sheet could **latch shut for the whole session** when a `present()` arrived before the TabView mounted (cold launch from a widget/Spotlight/`sggs://` link during the integrity check, or an integrity re-verify under an open sheet) — `AppContainer.sheetHosted` + host appear/disappear hooks; two new `HardeningTests`. The SwiftData bookmarks ladder no longer **destroys saved verses on the first open failure**: persistent → in-memory (nothing lost) → destroy only on a second consecutive failure (`sggs_saved_store_fail_count`); `SavedLineSchemaV1: VersionedSchema` + migration plan adopted before any user data exists (`SavedStoreLadderTests`, incl. an upgrade gate against the store an older build created). `MARKETING_VERSION` 1.1.1 / build 3, Release-config signing slot (`DEVELOPMENT_TEAM` to fill), `LSApplicationCategoryType`, `SGGS_CLOCK_NOW` test hook now `#if DEBUG`.
- **Licence coherence.** `ios/Resources/TRANSLATION-LICENSE.md` attestation (`LICENSED: false` until the written Khalsa-translation licence is recorded); `check_release_license.sh` passes an English-bundled build only with `LICENSED: true` (`SGGS_LICENSE_ATTESTATION` override); CI tests both directions; NOTICE.md and the DB-builder warning name TestFlight explicitly.
- **iOS P1 found by driving the simulator.** On iOS 26 the Reader's `.bottomBar` toolbar (Previous · Hukam · Next) was drawn *underneath* the floating glass tab bar — invisible to users (the July baseline screenshots show the same; a UI test that "tapped Hukam" was actually landing on the tab bar). The page controls now live in a bottom `safeAreaInset` capsule that lays out above the tab bar; Reader tests re-run green.
- **iOS correctness/UX.** Explore/Index captions derive their counts from the bundled data (never hard-coded facts); About shows version+build, the widget App-Group availability and the local diagnostics count, and credits the English layer; Search idle state shows guidance per mode instead of a blank pane; every failed load has **Try again**; "Composition not found" instead of "Ang 0"; Trail load honours cancellation; dead `Route.raagAng`/`openExplore` removed; theme-network slider clamped to the query's `[0,1]` with an honest empty state; Clock deep link to an unknown raag says so; widget timeline resolves pahar boundaries as wall-clock times (no DST drift); public `Pahar.label`/`dayOfYear` range-guarded. Five new XCUITests (search idle, saved-verse round trip, sheet Done returns to origin, About version, live `sggs://hukam` deep link).
- **Web P0.** The Study-Trail pin captured `textContent` of the saroop-painted DOM, so display-only Variation-Selector markup leaked into `localStorage` and the exported study trail/JSON (and echo-card pins stored empty text). Pins now carry `data-gm` from the API model; new `/api/lines?ids=` restores verbatim text for any previously corrupted pin on load. Saroop painter now also covers the composition modal and the drawer.
- **Web server.** Every integer parameter goes through `_int()` (length-capped, `OverflowError` → 400) — huge ids/offsets used to 500 and tear down the thread's DB connection; `OverflowError` added to the 400 tuple as a backstop. `verify.py` now folds Roman claims with the **same `roman_norm`** that built `translit_norm` (moved to `webapp/romannorm.py`, re-exported by `serve.py`; identity proven on all 24,719 golden inputs) — a loosely spelled Roman line now verifies instead of NOT_FOUND; a whole-line match is no longer mislabelled PARTIAL; NOT_FOUND reports confidence 0. `contract/golden_verify` regenerated against the iOS DB (7 vectors changed, all listed in the readiness report) and ported to `VerifyEngine.swift` in the same commit. Fonts/`contributors.json` get sane cache headers.
- **Web UI.** Stale `akal_kaal` theme key replaced by `akal`+`kaal` (Akāl was silently dropped from "The Divine Reality"); "53 concepts" → 54; unguarded chart loads on Insights/Constellation now render an honest error line; request tokens stop duplicate SVGs on rapid select changes; loading placeholders clear on error; `markPins` reflects pinned state after every re-render; `history.replaceState` keeps `?ang=`/`?q=` shareable and Back on-page; a11y: dial is a `group` (its arcs are reachable again), study-trail drawer is a `dialog` with a focus trap, constellation stars no longer 360 tab stops; escape-helper bypasses closed and inline `goReader(...,'name')` string-building replaced by `data-go-*` delegation; network table follows the PPMI slider.
- **Pre-merge audit (second commit).** `guard_scripture.py` GUARD PASS recorded; one uninterrupted 31-unit + 22-UI green run; **AX3 Dynamic Type bug fixed** — scripture in List rows truncated with "…" at accessibility sizes (vertical `fixedSize` on `GurmukhiText`/translit/English; Search idle view scrolls; Lineage fixed-width labels → min-width). Scene-active `flushIfIdle()` watchdog that cannot present mid-dismiss (+ unit test). Search field placement `.always` so it can never collapse behind the pill row. **iPad bug fixed:** after a search the tab bar stayed hidden for the whole search presentation (no way to leave Search) — `searchPresentationToolbarBehavior(.avoidHidingContent)`. iPad regular-width caps: Reader capsule 520 pt, Clock dial 420 pt, Explore grid 720 pt. XCUITest resilience helpers (launch env reset, tab-switch verification, keyboard-focus check, context-menu retry) and the iPad-capable `tab()` helper; capture test gains an env-gated landscape mode.
- **Reader & Shabad UX (third commit).** *Precision routing:* every verse tap (Search, Themes, Saved, Constellation, Trail, Reader, Spotlight, `sggs://shabad/C?line=Y`) opens the composition **scrolled to and highlighting that verse** (`Presentation.shabad(compId:focusLineId:)`; sheet: two-pass `ScrollViewReader` landing in the `List`; Reader: `scrollPosition(id:)` + `LazyVStack.scrollTargetLayout()` with the verse set as the page's initial position and re-asserted after the page-turn transition settles (proxy-based scrolling was dropped by that transition; an eager `VStack` made accessibility snapshots stall — both verified in the simulator); `FocusHighlight` accent wash fading over 1.6 s; VoiceOver focus moved to the verse after the sheet settles). "Open Ang N in Reader" is now an always-visible footer on the sheet that opens the Ang **of the focused verse** (compositions span Angs — it used to open the composition's first Ang, so the Reader could never land on a verse from a later page) (it used to be the last row — unreachable without scrolling a 385-line composition) and, like `sggs://ang/N?line=Y`, lands the Reader on the same verse (`Router.pendingReaderLineId`, always overwritten; landing runs from the page's `onAppear` and on pending-id change so the same-Ang case works). Web: `/reader?ang=X&line=Y|comp=Z` scrolls (`scrollIntoView` centre, reduced-motion aware) + `.verse-focus` flash + programmatic focus; the composition modal scrolls **its own** `#panel` scroller to the tapped line and its "Open Ang N" carries the line; every "open →" (pins, echoes, trail) passes the line. *Immersive reading:* ambient chrome — Reader nav bar/page capsule (iOS) and nav + toolbar (web) slide away while reading downwards and return on any upward scroll, at the top, on a page turn, key press, or top-edge pointer; never for VoiceOver/Switch Control, never while a modal/drawer is open, instant under Reduce Motion. Adjacent Angs are prefetched (iOS `ReaderModel.pages` ×5, web `angCache` ×6 via raw fetch — no toast on failure) so page turns never show a spinner; a fixed-height **"Continues on Ang N+1"** pill (derived strictly from the next page's `continued_from`, never from the last line's comp_id) joins the existing "Continues from" pill. *State hardening proofs:* new XCUITests `testSearchResultOpensShabadAtLine`, `testReaderChromeReturnsOnScrollUp`, `testDeepLinkAngBeatsResume` (control relaunch resumes 1430, linked launch lands on 7), `testRapidTapsNeverStrandSheets`; unit tests for `?line=` parsing and Spotlight line ids. Presentation layer only — no DB/pipeline/search/verify/kit change.
- **Versions.** `APP_VERSION` 2.12.1 / `MANIFEST.json` 2.12.1 (`db_sha256` unchanged `b513da34…`), README/MASTER-INDEX/CLAUDE.md in step. Human-gated: Developer Program activation + Team ID, App Group provisioning, translation licence (`LICENSED: true`), Granthi review of icon/saroop, on-device A11Y pass, store metadata.

## iOS 1.1.0 — 2026-07-12 — "Ink & Saffron" premium pass: hardening + designed light/dark + accent system (iOS app only; web/scripture untouched)
- **Correctness first (9 verified app-layer bugs fixed, each with regression tests where testable):** "Ang 0" share cards from shabad/theme/saved rows (line identity now plumbed everywhere; card share refuses to render uncited; Save + Explore-related restored inside sheets); iPad multi-window state mirroring (multi-scene disabled until navigation is per-scene); widget target shipped without the Sant Lipi font, a privacy manifest, or a matching `CFBundleShortVersionString` (App Store rejection); root-sheet swap race stranding modals (explicit dismiss-in-flight flag); `sggs://ang/1` hijacked by resume-last-Ang; stale-response races on Constellation/Progression; launch-integrity hash could **crash** (uncatchable ObjC exception) instead of failing closed on a corrupt bundle; `SavedScreen` `@Query` crash when the bookmarks store is unavailable; `CLLocationManager` re-created on every ClockScreen init.
- **Design system (`ios/App/Shared/DesignTokens.swift`, compiled into app + widgets):** four curated accents (Saffron default / Gold / Indigo / Teal) with per-scheme fill/text/on-fill/gradient legs; warm-ink dark ramp (never pure black; light mode keeps native system surfaces); status tokens replace ~30 raw `.green/.red/.blue/.purple/.white`; **WCAG contrast is a unit test** (`ThemeContrastTests`: 4 accents × 2 schemes × 2 contrast modes, ≥4.5:1 text / ≥3:1 fills, asset↔code parity). Accent picker in More → Display (`@AppStorage sggs_accent` → `\.palette` environment). Light saffron tuned `#E8730C→#E06E09` to clear 3:1 on paper.
- **Premium UI:** Reader hero (paper/ink canvas, gold continues-capsule, directional page-turn with no spinner flash, validated jump input); Explore hub hero gradient + pressable cards; Clock ember-wash now-card + AX-safe mode picker + range-validated manual coordinates; one `ModePill` component replaces six copy-pasted pill patterns; Card v2 (shadow in light / hairline in dark); branded ੴ empty states; motion layer gated on Reduce Motion (`Components/Motion.swift`, ≤0.3 s springs); glass-tab-bar clearance on iOS 26.
- **Widgets/share/launch/icon:** widgets get brand identity + honest empty-state copy + font actually bundled; share cards render scheme-correct paper/ink with gradient rule + gold citation; launch screen is paper/ink with a saffron-tinted ੴ at real 1x/2x/3x (+ dark variants); deterministic app-icon generator (`ios/tools/make_app_icon.swift`) produces light/dark/tinted 1024s (ੴ in Sant Lipi on the saffron→gold ramp).
- **Verification:** kit 17/17 · app 41/41 (24 unit incl. 6 hardening + 6 contrast, 17 UI incl. new accent-persistence test) on iPhone 17 sim; perf budgets green; grep gates (no raw colors / no `withAnimation` outside Motion / no hex outside DesignTokens); light+dark screenshot sets captured and reviewed vs pre-pass baseline; `git diff -- corpus db ios/Packages` empty — **scripture byte-identical**. Branch `ios-premium-v2`. Human-gated as before: signing/TestFlight, Granthi saroop review.

## v2.12.0 — 2026-07-11 — Raag Timing Knowledge Layer + Bani Forms metadata (additive; scripture byte-identical, proven)
- **Timing as attributed claims, never facts** (`Raag_Timing_Knowledge_Layer.md`): 7 NEW tables (`timing_sources`, `raag_timing_claims`, `shabd_raag_map`, `shabd_musical_markers`, `shabd_structural_form`, `shabd_poetic_genre`, `timing_migrations`). 46 seeded claims — 32 primary pahar placements across all 31 raags (majority Gurmat Sangeet convention, pahar 1 = 6–9 AM … 8 = 3–6 AM; **pahar 7 deliberately empty**), 5 **disputed variants** (Gauri, Tilang, Gaund, Ramkali, Kedara), 2 seasonal (Basant/Malhar), 7 ceremonial (Anand Karaj, Ghorian/Alahunian, Antim Sanskar, Rehras & Kirtan Sohila, Asa di Var, Rehras/So Dar) — every row citing a `timing_sources` entry; divergence is preserved with citations, never adjudicated. Seed is idempotent (INSERT OR IGNORE vs a COALESCE unique index).
- **Bani forms derived from verbatim headings only** (`pipeline/timing/derive_bani_forms.py`): shabd→raag map for all 5,380 compositions, musical markers (ghar ੧–੧੭, partaal, rahao/rahao-dooja, all **9 traditional dhunni vaars**, jati marks incl. ਦਖਣੀ/ਸੁਧੰਗ/ਜਤਿ), structural forms, and heading-stated poetic genres. `comp_type` (known-mislabeled) is never trusted — kept only as a hint in `source_label`; unknowns stay NULL, never guessed. No `lavan` genre by design (ਲਾਵ is never a heading; it lives as the Anand-Karaj ceremonial claim).
- **Integrity machinery**: Step-0 checksum-verified backup + committed per-table baseline (`audit/scripture-baseline.json` — rows + data SHA-256 + schema SHA-256 of all 46 pre-existing tables); whitelist-enforced transactional migration runner with a **proven** DROP-only rollback; `guard_scripture.py` standing gate (**PASS: all 46 tables byte-identical after migrate+seed+derive**); 21/21 layer gate tests; additive stage 7b in `rebuild_all.sh`; MANIFEST re-stamped (`db_sha256` → `b513da34…`) with a `scripture_baseline` pointer.
- **API** (`serve.py` 2.12.0): `/api/timing/clock|raag|divergence`, `/api/forms?comp_id=`, `meta.timing_available` — all additive, degrading to `{"available": false}` on DBs without the layer.
- **UI**: **/raag-clock** (SVG 24-h dial — day/night themed arcs, glowing current pahar + live hand, ghosted† variants, dark "quiet hours" pahar 7 with its note, Basant/Malhar seasonal ring, keyboard-focusable markers with cited tooltip, screen-reader table twin, "What raag is it now?" widget with fixed-clock + solar NOAA modes and next-pahar countdown); **/divergence** (side-by-side conflicting claims with tradition/confidence badges + citations, card layout on mobile); **reader timing chip** (dashed metadata chip beside the raag chip, toolbar "timing" switch, default ON, `show_timing`). Pure `pahar.js` with a 47-case Node gate (boundaries, midnight wrap, DST wall-clock, NOAA invariants, polar guard).
- **Fidelity**: scripture proven byte-identical by the committed baseline (guard PASS); corpus `72c86816…` unchanged; `/api/health` all-true. New tables are additive; the DB file-hash change is the documented, guarded consequence.

## v2.11.0 — 2026-06-26 — "Apple-grade" hardening & accessibility pass (display/server/docs only; scripture byte-identical)
- **Server robustness (`webapp/serve.py`, `webapp/verify.py`).** Fixed a crafted-input crash: a `"`/`*`/`(` in `/api/verify?q=` produced a malformed FTS5 expression → **HTTP 500** (it leaked `OperationalError: unterminated string`). `verify.py` now sanitises and quotes each FTS token as a literal and drops empties, with a central empty-MATCH guard in `_fts_query` (this also closes a latent empty-`OR` 500 from vowel-stripped translit tokens). 500 responses now return a generic body (full detail stays on stderr) instead of leaking the exception type. `/api/themes/network?min_ppmi=` is clamped to `[0,1]` with a `math.isfinite` guard (NaN/inf previously slipped through and returned empty edges). Added `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` to all responses.
- **Accessibility.** `<html lang>` corrected to `en` (the UI is English prose) with `lang="pa"` now marking the actual Gurmukhi verse containers (reader / search / panel / trail) so screen readers pronounce scripture correctly; pinch-zoom re-enabled (`maximum-scale=5, user-scalable=yes`); OS **reduce-motion** now honoured for the D3 charts (force layout settles synchronously instead of animating; chord transitions become instant); a **keyboard/screen-reader data-table** text alternative was added under the theme-co-occurrence chart (the documented "mouse-only charts" gap); larger pin touch targets; clearer saroop-toggle label.
- **UX.** Friendlier search empty-state (echoes the query + suggested themes + Index link) and a styled **404 page** (`serve.py` serves it for unknown paths).
- **Repo/docs.** Stray display-fidelity artifacts (`webapp/static/_cmp/`) git-ignored; `Validation-Report.md` banner-flagged as superseded; `MASTER-INDEX` theme count corrected (53 → 54).
- **Fidelity.** No DB rebuild — `db_sha256` unchanged (`cde0baa6…`), corpus `72c86816…`. `reconcile.py` char-exact (1,643,385) + `golden_test.py` all-pass + `/api/health` all-true re-verified; search results byte-identical vs the pre-change baseline. Presentation/server/docs layers only.

## v2.10.1 — 2026-06-20 — Traditional saroop is now the default rendering (display-only)
- **Traditional-saroop toggle now defaults to ON.** The Granth renders in the original saroop (the single tucked addha-yayya for the doubled subjoined-ya) out of the box, matching the printed Bir's wording; the **ਯ** header toggle still switches to the verbatim two-glyph form, and an explicit reader choice is stored in `localStorage` and respected on return. Initial state is applied without persisting, so the default can be changed later without overriding readers who never toggled.
- Still **display-only / scripture byte-identical**: the stored corpus, DB, API, FTS search, and Copy-verse remain verbatim (`db_sha256` unchanged `cde0baa6…`, corpus `72c86816…`); the variation-selectors never reach stored text, search, or the clipboard. No DB rebuild. Reversible (toggle off, or flip the default in `saroop.ts`).

## v2.10.0 — 2026-06-20 — Authentic Gurmukhi display font (Sant Lipi) + opt-in traditional-saroop toggle (display-only)
- **Bundled the Sant Lipi webfont** (SIL OFL 1.1; 27.8 KB variable WOFF2 at `frontend/public/fonts/`, `@font-face` + prepended to `--font-gm` in `global.css`, preloaded in `Base.astro`) so the Granth renders identically on every device instead of falling back to whatever Gurmukhi font each OS happens to ship. `unicode-range` scopes it to the Gurmukhi block (+ dandas + VS), so transliteration/English keep the system Latin font even inside a `.gm` element. Verified full coverage of all **67 corpus codepoints (zero tofu)**; license shipped at `/fonts/OFL.txt`.
- **Opt-in "traditional saroop" toggle** (header **ਯ**, default **OFF**; `frontend/src/scripts/saroop.ts`): a DISPLAY-ONLY transform that renders the source-faithful doubled subjoined-ya `੍ਯ੍ਯ` (and single `੍ਯ`) as Sant Lipi's tucked addha-yayya via Variation-Selector markup injected **only** into the rendered glyphs. The stored corpus, DB, API, FTS search, and **Copy verse** all use verbatim Unicode; a `copy`-event interceptor strips the selectors from any selected text, so the clipboard is always verbatim. Sihari-on-yayya and pairin haha/rara/vava are left plain. State persisted in `localStorage`; re-applied to dynamically-rendered scripture via a `MutationObserver`.
- **Scripture byte-identical — presentation layer only.** `db_sha256` unchanged (`cde0baa6…`), corpus sha256 unchanged (`72c86816…`); no DB rebuild (UI-only release, version decoupled from DB). Validated by a Phase-0 feasibility spike + SME QA (coverage, transform correctness on all 9 cases, clipboard/search safety). **Fidelity note:** Sant Lipi's addha-yayya is the accepted Shabad-OS rendering — *inline*, not the deep subscript of some printed Birs — which is exactly why the toggle ships opt-in, pending a Granthi/scholar's review.

## v2.9.5 — 2026-06-19 — Insights accuracy: theme-tag curation + faithful network/radar (audit-driven, live-verified)
- **Theme tagging curated** (`validation/concepts_*.json`, from `../SGGS-Insights-Audit-2026-06-19.md`): `kaam` dropped ਕਾਮਣਿ ("bride") + ਕਾਮਿ ("of no use") → 473→320 verses; `moh` dropped the pronoun ਮੋਹਿ → 810→471; `simran` gained the ਧਿਆਨ/dhyaan + ਅਰਾਧਿ/ਆਰਾਧਿ family → 1,255→2,128 (large recall gap closed); `krodh` gained the full-vowel ਕਰੋਧ spelling → 211→229; the conflated **`akal_kaal` split into `akal` (the Eternal) + `kaal` (death/time)** — `kaal` now correctly clusters with jam/mukti. Independent SME re-grade: every change improved precision/recall with **zero regressions** (control concepts byte-identical). Concepts 53→54; `ml_analytics_builder.py` integrity gate updated.
- **Resonance refreshed** (`build_resonance.py`) so the Cross-Contributor chord matches the v2.9.4 exact-cosine `line_neighbors` (it had been built against the older neighbor graph; the shrink was uniform, so rankings were unaffected).
- **Theme-network render** (`analytics.ts` + `serve.py`): now fetches the full edge set and opens at min-PPMI 0.7 (~470 strongest links), with the slider revealing **all ~1,255** bonds down to 0 (caption discloses it); the **radar caption** is clarified so the ×-multiple reads off the ring labels.
- **`build_shabad_neighbors`** hardened: the cosine matmul is wrapped in `np.errstate` + `np.nan_to_num` so a stray non-finite value can never reach the top-K (silences a benign float32 BLAS warning).
- **Audit findings re-confirmed**: theme-network PPMI/Jaccard recompute matched the DB exactly (0 mismatches); fingerprints/stylometry/raag/vaars correct; rendering faithful. `MANIFEST.db_sha256` → `cde0baa6…`. **Scripture byte-identical** — analytics/UI layers only; reconcile char-exact, integrity gate green.

## v2.9.4 — 2026-06-19 — Lineage redesign · Insights clarity · Semantic Trail accuracy + UX (live-verified)
- **Semantic Trail / "closest verses by meaning" engine rebuilt for accuracy.** `pipeline/build_semantic_vectors_lite.py` now computes **exact sparse TF-IDF cosine** (the lossy 128-d random projection is gone), **excludes header/label lines**, **de-duplicates verbatim-English twins**, applies a **0.30 min-cosine floor**, and stores **true cosine** as `score` (`line_neighbors_source = 'tfidf-exact-cosine-lite'`). An independent SME re-grade found NEW **better on 21/32** stratified seeds (same on 9, worse on 2 — minor list-shortening). Whole-corpus it removed **21,346 verbatim-twin** neighbour rows and **all header-label** neighbours, and eliminated OLD's **4,929 impossible >1.0** "scores" (random-projection artifacts; NEW is true cosine ∈ [0.30, 1.0]). Cross-Granth traversal preserved (98% cross-shabad, 88% cross-raag). Build-time dep: **scipy**. Full audit + before/after: `../SGGS-Trail-Audit-2026-06-19.md`.
- **Trail / Reader UX.** Raw "%" replaced with calibrated **relatedness bands** (Strong / Related / Faint echo); honest dead-end state ("this verse stands apart" + a "Begin a new trail" button) instead of a contradictory heading; **Ang-labeled breadcrumb** with reset; **Pin + Copy** on the current verse (Pin wired into the Study Trail FAB); English line-clamp for tidy, even cards.
- **Lineage ("The Contributors") redesign.** Magazine-style hero with live stats, an interactive kind-legend filter, three views (Timeline / By tradition / Most Bani), medallioned era-banded cards, rich profile panels (composition stats, signature themes, distinctive words), and a Compare-two-voices feature.
- **Insights clarity.** Plain-language captions (tech + non-tech) across all analytics charts and the Constellation / Themes / Trail / Lineage intros.
- **`load_translations.py`** now records the true `meta.translations_en` count (58,039).
- **Provenance:** `MANIFEST.db_sha256` re-certified to the rebuilt DB (`4d00e571…`); the change is the additive `line_neighbors` table only. **Scripture byte-identical throughout** — every change lives in the analytics/UI layers; reconcile char-exact, golden all-pass. Verified live in-browser (light + dark).

## v2.9.3 — 2026-06-19 — Concept Constellation performance fix (live-verified in browser)
- **Bug (found by a live browser walkthrough of all 8 tabs):** the Concept Constellation hung on "Loading…" for the **default** concept (`satguru`, 6,319 verses) — the request never returned (no error). Smaller concepts (e.g. `vahiguru`, 82 verses) rendered instantly and correctly.
- **Root cause:** the per-concept cluster query self-joins `concept_lines` on `line_id` (`co.line_id=cl.line_id`), but `concept_lines` was indexed only on `concept` — so the join degraded to ~O(n²) on large concepts.
- **Fix:** added `CREATE INDEX idx_cl_line ON concept_lines(line_id)` in `pipeline/build_db.py` (now baked into every `rebuild_all.sh`) and to the shipped DB. Constellation now renders `satguru` instantly into 9 thematic sub-constellations — confirmed live. All other tabs (Search, Reader, Index, Themes, Lineage, Trail, Insights) and the full ML/analytics layer (theme-network/PPMI, stylometry, resonance, raag streamgraph, Vaars, semantic neighbors) verified working.

## v2.9.2 — 2026-06-19 — post-2.9.1 maintenance: provenance re-certified, docs/version synced, rebuild script completed
- **Live verification pass (2026-06-19)** confirmed scripture integrity against the *running* system: `reconcile.py` char-exact (1,643,385 chars), `golden_test.py` all-pass, all 1,430 Angs gap-free, 60,658 lines, `/api/health` 6/6 green, search modes correct (Anand Sahib→Ang 917, baba farid→Ang 1377), p50 1.8 ms. The **Ang 1256 "ਵੈਦ ਨ ਭੋਲੇ ਦਾਰੂ ਲਾਇ" recurrence is a confirmed legitimate refrain** (verified in-DB — three occurrences with different end-markers — and against two external publishers); it is NOT a duplicate and must not be de-duplicated. Full report: `../SGGS-Live-Verification-2026-06-19.md`.
- **Provenance fixed:** the shipped DB had drifted from `MANIFEST.json` (analytics/vaars built 06-14/06-15, after the 06-13 manifest). `MANIFEST.json` `db_sha256` re-certified to the on-disk DB (`5be9aa…`, the freshly rebuilt DB), `version` → 2.9.2.
- **Version hygiene:** `serve.py` `APP_VERSION` → 2.9.2, README badge + `MASTER-INDEX.md` synced to v2.9.2, and MASTER-INDEX's wrong "60,193" line count corrected to **60,658**; `build_db.py` now stamps `meta.version` from `webapp/serve.py:APP_VERSION` (no longer hardcoded `'1.4.0'`).
- **Reproducible rebuild completed:** `rebuild_all.sh` now also runs the v2.0 structural enrichment (`enrich_v2.py --apply` → `stanza_index`/`pada_total`/`source_category`) and the Insight-Engine builders (`ml_analytics_builder.py`, `build_semantic_vectors_lite.py`, `build_resonance.py`, `build_vaars.py`), so a from-scratch rebuild reproduces the full shipped DB (analytics/vaars/neighbors). *Script edits passed QA review but have not been run end-to-end (no shell) — validate on the next real rebuild.*
- **Known/deferred:** one line with empty `translit_norm` (id 35328, Ang 829 — fixes on next rebuild); source-faithful `ਓ ੁ` / isolated-matra rows in the Sahaskriti zone flagged for scholarly review (corpus is char-exact to the source PDF); analytics D3 chord/streamgraph remain mouse-only (a11y).

## v2.2.0–v2.9.1 — 2026-06-14/15 — Astro UI + Insight Engine Phases 2–3 (consolidated; CHANGELOG had lagged)
- **UI migrated to an Astro multi-page app** (offline monolith) + premium Tailwind v4 redesign + path-safe static server.
- **v2.3.0** Phase 2: offline semantic vectors (`line_neighbors`) + Insights dashboard (D3 / Chart.js) + Related Verses.
- **v2.4.0** Semantic Trail + Contributor Timeline (Lineage). **v2.5.0** Cross-Contributor Resonance Map (D3 chord; `author_resonance`).
- **v2.6.0** Raag Theme-Progression streamgraph + Sehaj focus mode. **v2.7.0** AI-powered Cross-Reference Study Trail.
- **v2.8.0** Vaar Anatomy (`vaars`/`vaar_units`) + Majh pauri fix + repo hygiene. **v2.8.1** Study-Trail localStorage + analytics a11y.
- **v2.9.0** Concept Constellation + network-graph keyboard a11y + Maru-M5 ordinal pauri fix. **v2.9.1** Constellation filter by author + raag.
- (Reconstructed from git history on 2026-06-19; per-release detail is in the commit log. These releases were search-untouched/additive; scripture byte-identical throughout.)

## v2.1.0 — 2026-06-13 — Insight Engine Phase 1: offline analytics (additive DB; search untouched)
- **From search engine to insight engine** — a 3-agent SME design pass (ML methodology / domain-ethics / architecture+vector) produced a statistically rigorous, respectful analytics layer. All computation is **offline** in `pipeline/ml_analytics_builder.py`; the live server gains only cached `SELECT`s and **zero** new runtime dependencies. Full design: `ML_Analytics_Engine.md`.
- **The data is purely additive.** The builder copies the DB, **adds 7 tables**, and asserts every existing table (`lines`, `fts*`, `variants`, `translations`, `concepts`, `concept_lines`) is **content-hash identical** — verified. `serve.py`'s search path is untouched. (This release does change `db/sggs.sqlite`: `db_sha256` → `9f629b90…`, +<0.5 MB.)
- **Shipped tables:** `theme_network` (theme co-occurrence by **PPMI + Jaccard** — raw counts are base-rate biased, so this surfaces real associations like kaam↔krodh and anhad↔shabad, not just frequent ones), `theme_fingerprint` (per author/raag theme **emphasis as lift**), `author_analytics`/`raag_analytics` (**MATTR** vocabulary richness, hapax, word/line structure), `author_distinctive_terms` (**Monroe log-odds** distinctive English words), `shabad_neighbors` (**related shabads** by IDF-weighted theme-profile cosine), `analytics_meta` (provenance + caveats).
- **The sentiment decision (important).** The domain/ethics SME demonstrated that generic sentiment (VADER/TextBlob) mislabels **~47%** of devotional lines and *inverts* the most sacred idioms — scoring "dying while alive → liberation" as the **most negative line in the corpus**, and *bhau*/awe and *viraha*/longing as negative. **No sentiment model ships.** Affect is expressed through the corpus's own verified themes (anand→joy, prem_pyar→devotion, maran_jeevan→detachment, bhau→awe, bhana→surrender, nimrata→humility). Nothing ranks or judges scripture.
- **New endpoints (additive, cached, graceful):** `/api/themes/network`, `/api/analytics/author`, `/api/analytics/raag`, `/api/related` — each carries a `note` framing it as descriptive, never a judgement.
- **Vector search:** a feasibility report (`Vector_Search_Feasibility_Report.md`) concludes that live semantic search needs the transformer at runtime (breaks the stdlib-only server), so the sovereign-fit path is **offline-precomputed neighbors**. Phase 1 ships theme-grounded related-shabads; a MiniLM line-level semantic upgrade (+9 MB, zero runtime deps) is a documented one-command Phase-2 regen.
- **Validation:** existing tables content-identical; search canonical spot-check unchanged; **chaos 175/200** held; all endpoints 200; build ~2 s (2,520 edges, 2,265 fingerprints, 45,430 neighbor rows). Footer `APP_VERSION` → 2.1.0.

## v2.0.8 — 2026-06-13 — Index page: tabbed sub-navigation (frontend; DB byte-identical)
- **Problem:** the Index view stacked all three grids (Major Compositions, The 31 Raags, Banis & closing sections) vertically — ~40 large cards, so reaching the Nitnem/closing banis meant a long scroll.
- **Fix — a client-side tab/pill sub-navigation** that toggles between the three, eliminating the scroll. The three existing grids were wrapped in tabpanels (`#tab-major` / `#tab-raags` / `#tab-sections`); a pill row (`#raagTabs`, reusing the search page's `.modes` chip styling) toggles them via a small `showRaagTab(key)` that sets `display` on the panels and `.on`/`aria-selected`/`tabindex` on the pills. Default view = **Major Compositions**. **Guardrail honoured: the data arrays (`QUICK_ACCESS`, `CLOSING_FIX`) and every card render template are byte-identical — only display visibility was added** (the grids `#quickOut`/`#raagsOut`/`#sectionsOut` are unchanged, just wrapped).
- **Top nav label** renamed "Raags" → "Index" (the `data-v="raags"` route is unchanged) to reflect that the view holds the whole structural index, not only the 31 raags.
- **Accessibility (proper WAI-ARIA tabs):** `role="tablist"`/`tab`/`tabpanel`, `aria-selected`, `aria-controls`, `aria-labelledby` linking each panel to its tab, roving `tabindex`, and keyboard support — Enter/Space activate, Arrow keys move focus **and** activate ("follows focus", since switching is just a display toggle). Two parallel SME reviews (a11y/UX + functional/no-regression) returned SHIP; both shipped nits (arrow auto-activate, aria-labelledby) were applied. The new `#raagTabs` handlers are id-scoped and don't collide with the search `#modes` chips.
- **Frontend only** (`index.html`); `serve.py` changed one line (version). DB byte-identical (`db_sha256` f0a64f78), never staged. Validated: JS `node --check` clean, tags balanced, toggle logic simulated (exactly one panel visible, active pill tracks), live HTTP 200 with all markers, card routing unaffected (event bubbles through the wrappers), 0 search impact. Footer `APP_VERSION` → 2.0.8.

## v2.0.7 — 2026-06-13 — Raags page: Bhagat-Salok section fix + Major-Compositions Quick Access (frontend; DB byte-identical)
- **Reported flaw — the "Banis & closing sections" grid showed "ਚਉਬੋਲੇ — Angs 1363–1384" (815 lines), erroneously swallowing two standalone sections.** Ground-truthed: the section-header lines ARE present and correct in the text (`ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀਉ ਕੇ` at Ang 1364, `ਸਲੋਕ ਸੇਖ ਫਰੀਦ ਕੇ` at Ang 1377), but the `lines.section` metadata column (and therefore the aggregated `sections` table) carried "ਚਉਬੋਲੇ" forward across both, so one row absorbed all three.
- **STEP 1 — closing sections corrected at the display layer** (`CLOSING_FIX` in `index.html`): the swallowed row is split back into **ਚਉਬੋਲੇ (1363–1364, 24 lines)**, **ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀ (1364–1377, 494 lines)**, **ਸਲੋਕ ਭਗਤ ਫਰੀਦ ਜੀ (1377–1384, 298 lines)** — line counts ground-truthed against the header-bounded id ranges (24+494+298 = 816 ≈ the 815 it had swallowed). The corrected array drives both the grid render and the click-routing (kept index-aligned). The Reader's section chip for Angs 1364–1384 gets the same correction so a click lands on a page whose chip matches the card.
- **STEP 2 — new "Major Compositions — Quick Access" grid above the Raags grid.** Six routing cards for the most-sought banis that live structurally *inside* a raag (so they don't belong in "closing sections" and were previously buried): **ਸੁਖਮਨੀ ਸਾਹਿਬ → Ang 262**, **ਆਸਾ ਕੀ ਵਾਰ → 462**, **ਅਨੰਦੁ ਸਾਹਿਬ → 917**, **ਬਾਵਨ ਅਖਰੀ → 250**, **ਸਿਧ ਗੋਸਟਿ → 938**, **ਓਅੰਕਾਰੁ (Dakhni) → 929**. Every Ang verified against the composition's section-header line in the corpus. Cards route via a new `data-ang` delegated handler; keyboard-accessible (role=button, tabindex, Enter/Space) like the existing tiles.
- **Frontend only** (`index.html`); `serve.py` changed by one line (version stamp). DB byte-identical (`db_sha256` f0a64f78), never staged. Validated: JS `node --check` clean, tags balanced, live HTTP 200 with all new markers present, all 6 routing Angs + the 1363/1364/1377 section Angs return valid pages, 0 canonical search regressions (engine untouched). Footer `APP_VERSION` → 2.0.7.
- **Root-cause note / optional follow-up:** the underlying defect is in `lines.section` (and the derived `sections` table), which is *not* an FTS-indexed column — so a targeted `UPDATE` to re-tag Angs 1364–1376 as Salok Kabir and 1377–1384 as Salok Farid, then rebuilding the `sections` aggregation, would fix this at the data layer with **no FTS/search impact**. Deferred to keep the DB byte-identical per the project convention; the display-layer fix above makes the UI correct in the meantime.

## v2.0.6 — 2026-06-13 — Proactive hardening: 4-agent corpus QA fleet (query-side only; DB byte-identical)
- **Moved from reactive patching to proactive corpus-wide hardening.** A read-only 4-agent QA fleet (lexicon coverage, phonetic fold-gaps, hukam/passage boundaries, adversarial seeker queries) swept the corpus for latent loopholes before users hit them. Every proposed fix was ground-truthed against the DB and gated against "do no harm" (chaos ≥175/200, exact round-trip ≥99.3%, 0 canonical regressions). Full write-up: `Proactive_Hardening_Report_v2.0.6.md`. DB unchanged (`db_sha256` f0a64f78), never staged.
- **Shipped — modern pronoun/particle/compound/named-figure lexicon layer (12 entries, all canon-verified, 0 hijack):** `mein`/`me`→ਮਹਿ/ਵਿਚਿ, `ye`→ਇਹੁ/ਏਹ, `main`→ਮੈ/ਹਉ, `inka`→ਤਿਨ, `jivan`→ਜੀਵਨੁ, `mua`→ਮੂਆ, `keertan`→ਕੀਰਤਨ, `raidas`→Bhagat ਰਵਿਦਾਸ (was **0 results**), `waheguruji`→ਵਾਹਿਗੁਰੂ, `sachkhand`→ਸਚ ਖੰਡ (was 0 results; now Ang 8), `kirtan sohila`→ਸੋਹਿਲਾ. With the v2.0.5 का/के/की postpositions this completes the modern function-word class — a handful of words that recur on tens of thousands of lines.
- **Shipped — boundary DEFECT-1:** the Hukamnama complete-unit window was ±9 comps; exactly one Vaar (Maajh, comps 399–409 at Ang 141) has a 10-comp Salok run before its Pauri, so a seed at the run's head returned a lone salok. Widened to ±15. Proven safe by a full before/after diff over all 4,703 body comps — **exactly 2 comps change (399, 409), both fragment→complete**; everything else byte-identical, 0 over-merges.
- **Found but deliberately deferred (documented, not shipped):** `jiu`→`jeeu` (false-friend with ਜਿਉ "as", risks 562 lines — skipped); DEFECT-2 Vaar-salok interposition (~0.26%, root cause is the `comp_type` mislabel — 74 of 116 `ਵਾਰ`-typed comps are real >8-line compositions, so a query-side merge would over-collect; needs the DB `comp_type` correction); not-in-corpus intercepts for Dasam/greeting phrases (needs a confidence-floor design, not a brittle blocklist — flagged as the top next item); `god` English false-friend (needs a tier reorder). Caught and discarded several agent errors: hallucinated `waaste`/`vaste` entries (don't exist) and dead targets `jio`/`rehraas`/`japu`/`japajee` (0 lines).
- **Validation:** 0 canonical regressions; chaos 175/200; round-trip exact 99.3%/100% pass@3 (0 miss), casual 98.4%/99.7%; casual-quote battery 98.1%/99.8%; `/api/health` 6/6; hukam sweep over 5,380 comps = 0 over-merges/0 crashes, seed 399 fixed (4→93 lines). Footer `APP_VERSION` → 2.0.6.

## v2.0.5 — 2026-06-13 — Modern postposition layer for casual-quote search (search-logic only; DB byte-identical)
- **Reported bug — `jamuna ka kul khel kelio` returned a short decoy (Ang 651) instead of the line the user was quoting — FIXED.** The verbatim line is **Ang 1403** (`…jamunaa kai kool khel khelio jin gi…`). (Ground-truthing corrected the brief: the line is on Ang 1403, not 1195, and the word is `kool`, not `kooli`.)
- **Root cause (ground-truthed, not the surface diagnosis).** Aspirates are *already* folded — `roman_norm` collapses `kh→k` and voices `k→g`, so `kelio` and `khelio` **both** fold to `gl` today; a "query-side aspirate swap" would have been dead code. The real failure is the **opposite**: the fold is so coarse that `kul`, `khel`, `kelio` all collapse to `gl` and the Hindi postposition `ka` collapses to a weak 1-char `g` and drops out — so the 5-word quote degenerated to "`jmn` AND `gl`", which thousands of lines satisfy, and BM25 floated a short unrelated line to #1.
- **The systematic fix — a modern postposition layer (closed class) in `SEEKER_LEXICON`.** The Hindi/Punjabi function words का/के/की/कउ/को (`ka`/`ke`/`ki`/`kau`/`ko`) are mapped to the Gurbani spellings the corpus actually uses (`kai`/`kaa`/`ke`/`kee`/`kau`/`ko`). This restores a **strong exact-translit discriminator** for the word the fold was throwing away — `jamunaa kai kool khel khelio` now out-scores the decoy. These five words recur on tens of thousands of lines, so this lifts the whole "casual quote" class, not one query. Additive OR-alternatives only (the canonical fold stays in every token's group), so matching can't regress.
- **Why not "in the database for all lines".** The DB-level lever is `roman_norm`, and it *already* handles aspirates — the gap is coarseness, not a missing fold rule. Making the fold finer would need a full re-migration (translit_norm + norm_blob + FTS rebuild) and would trade away the hard-won 99.3% / 175-chaos precision to chase a fold that's coarse *by design*. The correct, lower-risk lever for a closed function-word class is the query-side lexicon. (A tier-reorder to let the in-order passage tier win for quotes was evaluated and **declined** — the lexicon already drove the casual-quote battery to 0 fails, and reordering carries the documented passage-ranking regression risk.)
- **New permanent harness:** `pipeline/casual_quote_harness.py` measures this class corpus-wide — sample real lines, type them as a casual modern fragment-quote (modern postpositions + dropped aspirates + shortened vowels), check top-1/top-3. This is the "loop over all the lines" regression guard for the class.
- **Validation:** target `jamuna ka kul khel kelio` → **Ang 1403 #1** (variant-match); a second same-class case `gur ka bai ujal haumai mal` → **Ang 121 #1**; casual-quote battery **98.8% pass@1 / 100% pass@3 (0 fails)**, up from 1 fail; regression gate **0 canonical ranking regressions**; chaos **175/200** (parity); round-trip **exact 99.3% / 100% pass@3**, **casual 98.4% / 99.7%** (all unchanged); bare `kul`/`ka`/`ke` queries verified not hijacked. An independent fresh-eyes SME reviewer ran 15+ realistic multi-word queries containing these tokens — verdict **SHIP**, no regression, no collision (canonical form always present in the OR group). Footer `APP_VERSION` → 2.0.5; DB byte-identical (`db_sha256` unchanged f0a64f78), not re-committed.

## v2.0.4 — 2026-06-13 — Overnight hardening pass: 6-agent audit + fixes (code only; DB byte-identical)
- **A six-dimension read-only SME audit fleet** (backend/security, search precision-recall, data integrity, frontend/a11y, API contract, performance) swept the whole app for loopholes. Findings were triaged into a no-break fix plan and shipped in four validated batches. Full detail: `Audit_Report.md`. The DB (`db/sggs.sqlite`) is untouched — `db_sha256` unchanged (f0a64f78…).
- **Batch 1 — backend hardening (no ranking change).** `/api/search` now clamps `limit`/`offset` (a negative `limit` was `LIMIT -1` in SQLite = a full-corpus dump of 5,662+ rows); `/api/word` strips `"`/`*` (a bare quote crashed the FTS `MATCH` with an HTTP 500); `api()` guards an empty path and a missing `ang`/`shabad` id (clean 400 instead of an `IndexError`); `HAVE_FTS` is initialised for **every** endpoint (`/api/word` returned `[]` on a fresh server); `fts_query` strips `*` on all terms; `search_fts`/`search_like` take a column allowlist; `term_concepts` uses a double-checked lock (TOCTOU on the lazy concept index under threads); `hukam_package` guards an empty-corpus draw; `blob_search` skips only absurd 15+ token pastes (DoS bound).
- **Batch 2 — search quality (0 chaos regressions).** The phonetic-fold tier now **excludes header lines** — `bihaagarhaa` folds to the same `vhgr` as `vaahiguroo`, so raag/author captions polluted `waheguru ji` (#2/#3) and `jio prabh` (#3); now gone. `baba farid` resolved to a vrata line because `baba` is a honorific that drops to one token (so honorific-drop never fired) — added a `baba farid`→`phareed` bigram; `maaya`→`maaiaa`, `kya`→`kiaa` (a 1-char weak fold was dropping the distinctive token). `variant_search` now **dedupes identical OR-groups** so a repeated mantra (`satnam waheguru satnam waheguru`) no longer inflates the all-but-one threshold and crashes into the junk blob tier — it now returns the ਵਾਹਿਗੁਰੂ line.
- **Batch 3 — API consistency + perf (additive).** `/api/search` attaches English translations for **every** mode (roman/gurmukhi/theme/first/variant previously returned none); `related_themes` is always present; `/api/verify` now returns `comp_id` + `section` so the UI can open the full shabad from a verified line; `/api/meta` is cached (drops the ~50 ms concept-count join from every page load).
- **Batch 4 — frontend a11y / robustness / XSS.** Dialog focus management + Tab focus-trap + `aria-labelledby`; mode chips are a real keyboard radiogroup; result/verify cards are keyboard-activable; `aria-live` results, labelled Ang input, `aria-current` nav, skip link, `lang="en"` on English text; `go()` request-stamp race guard (no stale results); loading states; "Another" spam guard; boundary nav labels; `esc()` also escapes `>`/`"`, related-theme links moved off inline handlers; dynamic `--nav-h` so the sticky reader toolbar clears the wrapping nav on phones; 44px touch targets; Japji title shows "Guru Nanak Dev Ji (M1)" instead of a blank byline.
- **Validation (every batch).** In-process regression gate (canonical query set frozen — 0 ranking regressions across all four batches); chaos **175/200** (parity held); full-corpus round-trip **exact 99.3% pass@1 / 100% pass@3**, **casual 98.4% / 99.7%** (≥ baseline); live HTTP smoke test (page + every endpoint 200, the `word?w="` 500 fixed); JS `node --check` clean. DB sha256 verified byte-identical. Footer `APP_VERSION` → 2.0.4.
- **Deliberately deferred (documented, not shipped):** the comp_type source mislabels and Japji NULL-author / refrain-translation gaps are DB-layer items requiring a re-migration (the title/byline already work around them in the display layer); the all-but-one OR-fallback perf cap (correctness > ~40 ms on a local app); a light-mode saffron contrast tweak (exact values in `Audit_Report.md`, left to your call since the app is dark-mode-primary).

## v2.0.3 — 2026-06-12 — Shabad modals show a real composition title (frontend; DB unchanged)
- **Reported flaw — the random/Hukam modal showed "Random shabad · Ang N" and the invocation but no composition title.** The actual title header (e.g. ਸਲੋਕ ਮਹਲਾ ੪) sits at a section's start, outside the seed unit, so it isn't in the returned package.
- **Fix:** a `compTitle()` helper synthesizes a title from the metadata every line already carries — works for ALL shabads regardless of whether a title header is in the unit. The random modal and the composition modal now lead with a styled header: **Gurmukhi descriptor** (raag, e.g. ਧਨਾਸਰੀ / ਆਸਾ / ਗਉੜੀ; or the section, e.g. ਸਲੋਕ ਵਾਰਾਂ ਤੇ ਵਧੀਕ / ਜਪੁ) above a **muted line** of author + Ang (e.g. "Guru Arjan Dev Ji (M5) · Ang 673").
- `comp_type` is deliberately excluded from the title — the source mislabels it for some compositions (Japji as ਰੁਤੀ, shabads as ਪਉੜੀ), so surfacing it would print wrong forms. Raag/section + author are reliable.
- Frontend only (`index.html`); no API/DB change. Footer → 2.0.3.

## v2.0.2 — 2026-06-12 — Hukamnama returns complete structural units (endpoint refactor; DB unchanged)
- **Reported flaw — "Hukam-style random" returned fragments** (e.g. on Ang 951, a lone `Salok Mahala 3` ending `॥੧॥` with no Pauri). Root cause: `/api/random` fetched a single random `comp_id`, but — exactly as the v2.0 checksum audit found — `comp_id` isolates a Vaar's Saloks from its concluding Pauri.
- **Fix:** new `hukam_package()` expands a random seed to its **complete liturgical unit**:
  - *Vaar* — a Salok attaches to its concluding **Pauri**, and a Pauri gathers all the **Saloks that precede it** (back to the prior Pauri, never across it). Ang 951 now returns the full Salok(s) + Pauri ending `॥੧੦॥`.
  - *Standard shabad* — already one `comp_id` holding all Padas + Rehao, returned whole (verified: Sukhmani/Asatpadi/Anand shabads return every pada and the Rehao, with no cross-shabad bleed).
  - *Composite banis* (Gatha, Patti, Dakhni Onkar, Sahaskriti, Salok M9, Thitee) — deliberately **not** merged across comps; each returns its own comp, so the scan can never run away. A ±9-comp window hard-bounds expansion.
- **Validation:** corpus-wide over all 5,380 comps — 1,447 multi-comp units, **0 over-merges, 0 fragmented Vaar Saloks, 0 crashes**; 500+ vaar-salok seeds all include their Pauri; search/FTS/DB untouched (isolated to `/api/random`). Three SME passes (structural analysis, implementation, fresh-eyes QA — verdict SHIP). Footer → 2.0.2.
- Known pre-existing DB-encoding quirk (not a regression): a few `ਸਲੋਕੁ`-typed comps at Ang 141–143 embed a Pauri section, yielding one larger (but theologically coherent) Vaar unit; 0.15% of comps.

## v2.0.1 — 2026-06-12 — Themes page: theological exploration hub (frontend; DB unchanged)
- The Themes view was a flat alphabetical grid of raw DB keys (`akal_kaal`, `ik_onkar`). Rebuilt into a categorized hub:
  - **Human-readable Title Case** — `akal_kaal` → "Akal Kaal", `ik_onkar` → "Ik Onkar" (underscores stripped, each word capitalized).
  - **Six theological sections** with elegant headers + subtitles: The Divine Reality · The Human Condition & Illusions · The Five Vices · The Path & Praxis · Virtues & Divine Attributes · Spiritual States. All 53 corpus concepts are assigned (verified: 0 uncategorized, 0 duplicates), with a "More Themes" safety bucket so a theme can never be dropped.
  - **Polished cards** — whole card clickable (reuses the existing saffron-border + lift hover), flex-column layout that pins an **"Explore N lines →"** count cue to the bottom (N from a new `n_lines` count per concept, added to `/api/meta` via `concept_lines` COUNT). Keyboard (Enter/Space) + focus-visible + `role="heading"` section labels for screen-reader navigation; light-mode contrast fix on the cue.
- Backend change is additive only (one extra aggregated field in `/api/meta`); search tiers, FTS, and the DB are untouched. An SME design/a11y reviewer verified correctness, routing, escaping, and grouping (verdict: SHIP). Footer → 2.0.1.

## v2.0.0 — 2026-06-12 — Structural enrichment + Double-Confirmation checksum (additive, zero-data-loss)
- **The DB now understands structure, not just text.** Three columns added to `lines` via `ALTER TABLE … ADD COLUMN` (additive — no drop, no rebuild): `stanza_index` (running pada number within a shabad), `pada_total` (padas per shabad), `source_category` (Gurus / Bhagats / Bhatts / Other). Derived entirely from data already in the DB (the `markers` Ank field, `author`) — no re-parse, no guessing. `is_rahao` and `comp_type` already existed and were reused as-is (not rebuilt). The API now returns these fields for the UI to use.
- **Double-Confirmation checksum** (`pipeline/enrich_v2.py`): the terminal Ank `॥N॥…` of each shabad is cross-checked against the padas actually indexed. Of 3,688 stanza-groups: **3,159 CLEAN** (pada==count exact), **527 STRUCTURAL** (Vaar/Japji/Thitee/astpadi cumulative regimes where the simple rule doesn't apply by design), **2 ANOMALY** — both manually verified as legitimate ਛੰਤ+salok composites at Ang 81. Net: the pada numbering is fully internally consistent, corroborating the v1.x char-exact reconciliation. A naive "॥4॥ ⇒ 4 stanzas else FATAL" rule was deliberately *not* shipped — it false-alarms on 3 of SGGS's 4 numbering regimes; the auditor is comp_type-aware and classifies instead.
- **Zero-data-loss, search untouched.** FTS5 is external-content over 6 fixed columns, so ADD COLUMN doesn't affect it — verified byte-for-byte: lines 60,658; FTS ਨਾਮੁ 3,293 / `vhgr` 29; fts_shabad 4,703; variants 79,666; translations 58,039 — all identical before/after. Migration built on a `/tmp` copy then copied into `db/` (SQLite can't create/modify on the mounted folder). Search regression 11/11, chaos 175/200 — unchanged. An independent SME reviewer verified zero-loss + correctness (verdict: SHIP).
- Full detail: `Schema_v2_Migration_Report.md`. Footer + DB meta → 2.0.0. (This release changes `db/sggs.sqlite`; `db_sha256` updated in MANIFEST.)

## v1.9.5 — 2026-06-12 — Graceful all-but-one matching + subjoined-h + casual lexicon (search-logic only; DB unchanged)
- **Reported bug — `Tum Karoh Daya Mere Sai` returned the wrong line (Ang 170) instead of Ang 673 (ਤੁਮ੍ਹ ਕਰਹੁ ਦਇਆ ਮੇਰੇ ਸਾਈ) — FIXED.** Root-caused to the strict per-token AND being brittle: (a) the line's word is `tumh` (ਤੁਮ੍ਹ, subjoined ਹ) → fold `dmh`, but the user types `tum` → `dm`; (b) `sai` resolved to a rare canonical `sai`, but the line has `saaee`, so the `sai` group matched nothing and **zeroed the whole AND**, dumping the query into a worse tier.
- **The systematic fix (this is the important one): a graceful all-but-one fallback in `variant_search`.** When the strict AND of every token group returns nothing, the engine now re-ranks candidates by **how many groups they satisfy** and accepts lines matching ≥ N−1 tokens — so one casual/uncovered word can no longer zero out a multi-word query. A line matching every token still wins; the fallback only runs when the strict AND already failed, so exact-match precision is untouched. This is why chaos robustness jumped **164 → 175 / 200**.
- **Subjoined-h twin** in `fold_match_alts`: the index keeps the aspiration (`tumh`→`dmh`, `cheenhe`→`cnh`) that casual typing drops (`tum`→`dm`, `chine`→`cn`); the helper now inserts an `h` after a nasal/l so the short query fold reaches the aspirated index fold. Exact folds only — `hamra dhara har` still returns Ang 366 #1.
- **Casual lexicon**: `sai`/`sain`/`saeen`/`saai` → `saaee`/`saaeen` (Lord/Master), `karoh`/`karo` → `karah`. Casual short forms that previously resolved to the wrong canonical.
- **The honest metric.** The old round-trip harness typed each line's *exact* transliteration back (trivially matches our own index — 99.3%). The harness now also simulates **how users actually type** (drop subjoined-h, `saaee`→`sai`, shorten vowels, casual verb forms). On that realistic test the corpus went from **pass@1 95.8% / pass@3 97.5% → 97.8% / 99.5%**; the exact round-trip stays 99.3% / 99.96% (1 line of 55,277 outside top-3).
- **Validation:** core regression 17/17; chaos **175/200 (88%, +11)**; clean round-trip 99.3% pass@1; casual round-trip 97.8% pass@1 / 99.5% pass@3; two SME subagents (recall + fresh-eyes reviewer, verdict SHIP). Footer `APP_VERSION`→1.9.5. DB byte-identical, not re-committed.

## v1.9.4 — 2026-06-11 — Modern-spelling recall + passage line-bubbling + full-corpus harness (search-logic only; DB unchanged)
- **Reported bug — `kanthe rah gaya ram` returned a buried passage block instead of Ang 1372 (ਕਾਂਠੈ ਰਹਿ ਗਇਓ ਰਾਮੁ) at #1 — FIXED.** Two independent causes, both addressed:
  - *Recall:* `gaya` and `gaio` fold identically, but the variant engine had generated `gaya`→[`gaiaa`,`gaaiaa`,`gaeeaa`] and **never `gaio`**, so the per-token AND failed on the canonical line and the query fell through to the passage tier. Added a **modern spoken-verb lexicon** mapping casual Hindi/Punjabi perfectives to their Gurbani canonical forms: `gaya`→[`gaio`,`gaiaa`], `hua`→[`hoaa`,`hoiaa`], `raha`→[`rahio`,`rahiaa`], `kaha`→[`kahio`,`kahiaa`], `kiya`/`kia`→[`keeaa`,`keeo`], `aaya`, `diya`, `liya`, `bhaya`, `paya`, … (every target verified present in the corpus). The query now resolves at the line-level `variant-match` tier and returns Ang 1372 at #1.
  - *Passage line-bubbling:* when a quote did legitimately hit the passage tier, lines from a matched shabad were returned **chronologically**, so in a long Salok block (one comp_id spanning dozens of lines) the real hit sank below preceding verses (the reported #6). Lines are now ranked so the line carrying the in-order quote (`_seq`), then by fold-hit count, bubbles to the **absolute top**, with context following in reading order. Cross-line couplets (Ang 410) still surface both tuks in order. This is a general fix for every passage query, not just this one.
- **Initial-vowel-confusion twin** (`fold_match_alts`): `roman_norm` keeps the leading vowel and canonical long `oo`/`ee` fold to head `o`/`e`, but users type the short `u`/`i` (`oopar`~`upar`, `ootam`~`utam`). The variant/mixed tiers now add the head-swapped exact fold (`o`↔`u`, `e`↔`i`) as an alternative — exact, never prefix, so precision is preserved (`hamra dhara har` still returns Ang 366 #1, 1142 absent).
- **New full-corpus round-trip harness** (`pipeline/roundtrip_harness.py`): types every line's own transliteration (and an aggressive modern-spelling perturbation) back as a query and checks it returns at #1/top-3, bucketed by comp_type and Ang range. Result: **exact round-trip pass@1 99.4%, pass@3 100%** over the corpus; **aggressive-perturbation pass@1 97.7%, pass@3 98.9%** (up from 96.6%/97.7% before the vowel twin). This is the objective "every line in SGGS resolves when a user types it" metric.
- **Validation:** core regression 15/15; chaos 164/200 (82%, +1 vs v1.9.3, continuing 159→162→163→164); two SME subagents (modern-spelling recall + fresh-eyes pre-commit reviewer, verdict SHIP). Footer `APP_VERSION`→1.9.4. DB byte-identical, not re-committed.

## v1.9.3 — 2026-06-11 — Exact-fold precision + per-line passage scoring (search-logic only; DB unchanged)
- **Reported regression — `hamra dhara har` returned Ang 1142 (`teerath hamaraa har ko naam`) at #1 instead of Ang 366 (`hamaaraa dharhaa har rahiaa samaaee`) — FIXED.** Root cause: the v1.9.2 typo-tail patch left an FTS **prefix wildcard** on fold-skeletons in the line-level tiers (`translit_norm:"<fold>" *`). A 2–3-char skeleton prefix-matches hundreds of unrelated words: `dhara`→`dr` wrongly prefix-matched `teerath`→`drd`, and BM25 floated the shorter line to #1. Fix: **exact folds** (`translit_norm:"<fold>"`) in `variant_search` and `mixed_search`. Verified the true line survives because `dharhaa` folds to exactly `dr`; `teerath`=`drd` no longer matches and is removed entirely. (Ground-truthed against `roman_norm`; an SME audit confirmed all 294 words folding to `dr` are covered by `canon_tokens`/`variants`, so recall is carried by curated layers, not a blunt wildcard.)
- **Passage tier upgraded to per-line span scoring (a genuine correctness gain, surfaced while recovering the 2 chaos queries the precision fix cost).** Span is now measured **within each line** (a quote normally sits inside one line), falling back to whole-shabad scoring only for true cross-line couplets (Ang 410). This stops one incidental short-fold hit elsewhere in a long shabad from inflating the span and sinking the real line. LIMIT 40→60 so a true line in a long shabad isn't truncated out of the candidate window. Recovers `jaisee aag udar mah…` (Ang 921, was span 3495/rank #4) and `kah naanak jau piyar seegaaree` (Ang 372, was bm25 rank #58); couplet/jasodh unchanged.
- **Two most-searched seeker terms fixed** (pre-existing fold collisions found by the precision audit): `darshan` (folds to `drsn` = *trisanaa*, thirst — the opposite meaning) now routes to `darasan`; `sewa`/`seva` (fold `sv`, dominated by *sabh*) route to `sevaa`. Pure SEEKER_LEXICON additions, no DB change.
- **Validation: core regression 22/22; chaos 163/200 (82%, +1 vs v1.9.2)** — net improvement, zero regressions. Two SME subagents (precision auditor + recall/QA) plus a fresh-eyes pre-commit reviewer (verdict: SHIP, no blockers). UI footer now reflects the running build: `APP_VERSION`→1.9.3, `APP_BUILT`→2026-06-11, surfaced via `/api/meta` (DB `db_version` preserved separately; DB byte-identical).

## v1.9.2 — 2026-06-11 — Passage tier: span-ranked, regression-fixed (search-logic only; DB unchanged)
- **Reported regression — `kahat ma jasodh jise dahi bhaat kahe` must return Ang 1402 (Bhatt Gayand) at #1 — FIXED.** Root cause: the query word `jise` folds to `js`, but the canonical line has `jisahi` → `jsh`; exact-fold AND in the token waterfall broke, and the passage tier then ANDed scattered tokens across junk shabads. Fix: prefix-fold alternatives (`translit_norm: "fn" *`) in the token waterfall and `mixed_search`, so a one-character typo tail still resolves at the **line level** — the query now returns Ang 1402 at #1 via `variant-match`, never reaching the passage tier.
- **Passage tier hardened with a true relevance signal.** Two bugs found and fixed while validating the above against the full regression + 200-query chaos suite:
  - *Candidate-window bug:* prefixing 2–3-char fold skeletons (`jvd`/`mr`/`dr`) in the shabad-level MATCH matched 176 shabads and pushed the true couplet (Ang 410) from bm25 rank #20 to #42 — outside the window. → passage MATCH uses **exact folds** (the discriminating filter); typo-tail queries already resolve earlier at the waterfall tier.
  - *Ranking bug:* the old density score counted 1-char folds (`j`/`h`/`s`), rewarding long shabads for incidental hits and sinking the short true couplet. → rerank by the **span of the tightest in-order match** (non-greedy): a genuine quote keeps its words contiguous (Ang 410 spans ~19 chars; coincidental scatters span hundreds). Span cleanly ranks the true couplet #1.
- The prefix-aware in-order **seq-gate** stays (passage abstains — returns nothing — rather than emit junk when no in-order match exists).
- **Validation: core regression 17/17; chaos 162/200 (81%, +3 vs v1.9.1)** — the span metric is strictly better than the old density hack (acoustic_dyslexic 9→12). Zero regressions. Release stamp moved to a code constant (`APP_VERSION`) so a search-only patch needs no 86 MB DB re-commit; `db_sha256` is byte-identical to v1.9.x.

## v1.9.1 — 2026-06-11 — Chaos-tested (10-agent red team + auto-fix loop)
- 200 adversarial queries across 10 extreme behaviors (voice dictation, honorific hallucination, bilingual blending, keyboard smashing…): **36% → 80% pass** in 3 fix rounds, 13/13 core regression. Full report: `QA_Resolution_Report.md`; attack sets + per-query results: `validation/chaos/`.
- Patches: mixed-script per-token search; early honorific-drop retry; English-suffix stripping; t/d + p/v voicing fold (column re-migration); `norm_blob` + skeleton-blob desperate tier; synonym lexicon (rabb, dard, dil…); passage tier re-ranking by in-order fold sequence + prefix density (fixes BM25 mush from voicing folds); tier order passage>fold-full.
- Honest known limits documented: English-homophone dictation (3/20), r/l-n/m acoustic swaps (rejected as precision-destroying), >40%-corrupted smashes.

## v1.9.0 — 2026-06-11 — Generalized Phonetic Matrix
- **Root cause of `jeevat jo mara ha duttar so tara ha` → 0: the quote is a COUPLET spanning two ॥-lines (Ang 410)** — no per-line AND could ever match it. New **passage tier**: shabad-level FTS (4,703 shabads) catches quotes crossing line boundaries and returns the relevant lines of the top shabads. Both tuks now surface together.
- **Generalized rules** R17 (terminal ai→a: marai→mara) and R18 (nasal-anchor strip: haan→haa→ha), +9k variants → **79,666 total**; 2-char veto exemption for refrain particles.
- **Token waterfall v3**: every query token gets a full OR-group — variants ∪ canonical (new `canon_tokens` table, all 24,676 corpus tokens — fixes words that had no variants losing their exact alternative) ∪ lexicon phrases (satnam→"sat naam") ∪ long-vowel twin (ki↔kee) ∪ nasal-trim (main→mai) ∪ phonetic fold — so no single token can poison a phrase. Weak (1-char-fold) tokens are skipped, killing junk-query false positives.
- **Trigram FTS index** built (SQLite 3.37, per spec mandate); 300-char input guard (400); battery: 2 fresh SME agents, 26 GOOD/8 WEAK/0 BAD → all 8 WEAKs fixed same-session; final suite 19/20 (1 = correct ਸ੍ਵਾਮੀ-spelling result), p95 ~40ms.

## v1.8.0 — 2026-06-11 — Full-corpus enrichment (the bulletproof release)
- **Root cause of `nij bhakti sheelbanti naar` → 0 results: FIXED deterministically** before any LLM call — R16 ਬ/ਵ swap (+10,238 variants), k↔g Sanskrit voicing in the fold (bhakti≡bhagatee), punctuation/danda sanitation (`naar.` ≡ `naari ॥`), terminal-vowel retry, and a HYBRID multi-token AND (per-token: variants→translit, else fold→translit_norm) so one stubborn token can't kill a query.
- **Full-corpus LLM sweep — 100% of the 21,701-word vocabulary** via the resumable block orchestrator (`pipeline/enrich_orchestrator.py`, 29 blocks × 750, prepare/status/merge, idempotent): 29 Worker agents proposed ~2,400 loanword/deep-typo variants; the deterministic Supervisor purged duplicates/English/canonical with full audit (`enrichment/qa_log.jsonl`); **1,059 novel LLM variants merged → 70,604 total** (rule 69,455 · llm 1,059 · typo 90).
- shakti/kripa/darshan/maya/yogi/narayan/vidya/jagannath/sandhya/lila… all resolve; 19/20 battery (1 = richer-than-expected lexicon output), zero regressions.

## v1.7.1 — 2026-06-11 — LLM typo-enrichment pass (Worker→Supervisor)
- Sam's Worker/Supervisor agent pipeline executed for the one class rules can't derive: **common_typo** on the top-500 words. Worker proposed 344; Supervisor purged 245 with full audit trail (`validation/variant_qa_log.jsonl`: 227 duplicate — evidence the rule engine already covers them — 11 canonical, 4+1 English, 2 implausible); **99 approved, 90 loaded** (rebuild-safe input `pipeline/variants_typo.jsonl`, rtype='typo').
- swami→ਸੁਆਮੀ, nanakji→ਨਾਨਕ, gurbani→ਗੁਰਬਾਣੀ now resolve; compounds added to the lexicon (satnam→ਸਤਿ ਨਾਮੁ, onkar→ਓਅੰਕਾਰ).
- Docs reconciled: variant rules spec amended to BFS depth 3 (implementation reality; wahiguru needs 3 composed rules).

## v1.7.0 — 2026-06-11 — Phonetic Variant Engine
- **Precomputed romanization-variant index** (Sam's Worker/Supervisor design, productionized): 59,227 variants for 29,241 words from a 15-rule weighted engine (BFS depth 3), built deterministically in 0.7s. LLM agents repositioned to rule-design + adversarial review (2 SME agents; 6 blocking changes applied).
- **Lowercase-vocabulary English veto**: real-English collisions purged (372) while reverentially-capitalized Gurbani loans (Kirtan, Amrit, Naam) stay searchable; canonical-translit collisions purged (6,232).
- New `variant-match` query tier (exact → lexicon → variants → English → fold → theme); single-FTS-expression AND with ≤3 fan-out per token. wahiguru/kirtan/hukum/kartaa/nirbhau/darsan/prabhu all resolve; 22/22 battery, 0 regressions.
- Design doc: `03_Phonetic-Variant-Engine.md`; specs in `validation/`.

## v1.6.1 — 2026-06-11 — seeker-grade search (SME-validated)
- **Any natural word now resolves professionally.** SME battery of 73 seeker queries found 18 failures (yashoda→nothing, mercy→ਮੋਰਚਾ "rust", krishna→ਕਿਰਸਾਣੁ "farmer"…); all 18 fixed, zero regressions (26-check suite).
- **Phonetic-fold v2** on the Roman tier, both index and query: y/j (yashoda≡jasodaa), sh/s, aspirate digraphs (kh gh ch jh th dh bh ph rh), z/j, glide-y (gyan≡giaan), w/v.
- **English-translation search tier** (`fts_en` over all 58,039 SSK lines) + explicit "English" mode — meaning-search like *compassion mercy* now works.
- **Curated seeker lexicon** (36 entries): common English/Hindi words route to corpus terms or themes (mercy→ਦਇਆ/ਕਿਰਪਾ, death→ਕਾਲ, ego→theme:haumai, farid→ਫਰੀਦ, sita→ਸੀਤਾ, dhru→ਧ੍ਰੂ…). Tier order: exact → lexicon → English → fold → theme (fold is last resort, killing its false positives).

## v1.6.0 — 2026-06-11 — FULL English layer
- **Complete English translation layer: 58,039 lines (95.7% of the corpus — effectively every translatable line, headers included)** from the ShabadOS open database (release 4.8.7, `database.sqlite`, gitignored), Dr. Sant Singh Khalsa's translation. Replaces the partial v1.5.0 API ingest; Anand Sahib and Sukhmani gaps fully closed (918: 36/36, 920: 35/35, 296: 49/51).
- New `pipeline/shabados_ingest.py`: AnmolLipi-ASCII → Unicode converter (vowel composition, vishraam stripping, nukta folding, sihari reordering) validated at **97.26% character-exact** against our corpus — doubling as a second-source cross-verification of our extraction. Alignment: 96.9% exact/skeleton, 1,318 fuzzy, only 102 unmatched (their two-tuks-per-line liturgy variants).
- Fidelity gate: 200 random stored translations byte-equal to source — 0 mismatches.

## v1.5.0 — 2026-06-10 (overnight build)
- **English translation layer (first external source)**: 2,587 lines of Dr. Sant Singh Khalsa's English, ingested via BaniDB/GurbaniNow APIs (personal use, attributed) by a 10-agent fleet. Coverage: Japji Sahib + So Dar/So Purakh/Sohila (Angs 1-13) complete; Sukhmani Sahib (262-296) ~90%; Anand Sahib (917-922) partial (API truncation; re-pass listed). Stored in a separate `translations` table with per-line match-quality — never mixed with scripture; shown labeled "EN ·" in Reader, shabad panel, and search cards. Alignment QA: 12/12 correct, fidelity vs source 5/5 character-exact, 99% exact-match alignment (30 edition-variant lines documented).
- **/api/health** — one-call self-test (line counts, Angs, FTS, Mool Mantar, ੴ count, verify engine, translation count).
- **Search-term highlighting** in result cards; loading states; footer attribution for the EN source.
- `sources` table begins the multi-source registry (source, attribution, license, ingest date).

## v1.4.0 — 2026-06-10
- **Layer-3 runtime verification**: `/api/verify?q=…&ang=…` + "Verify quote" search mode. Cascade exact→normalized→skeleton→roman-norm→fuzzy; verdicts VERIFIED_EXACT / VERIFIED / PROBABLE / AMBIGUOUS / NOT_FOUND with Ang cross-check and confidence. 7/7 adversarial tests, <14 ms.
- **BM25 relevance ranking** on all search modes (FTS5 weighted columns; fallback to id-order on ancient SQLite).
- **Related-theme hints**: Gurmukhi searches surface matching themes from the 53-concept index (measured +73%…+1,003% recall vs single-term).
- Governance: `MANIFEST.json` (sha-256 of corpus and DB), this changelog; Answer-Protocol now requires machine verification of quotes.
- `02_Sovereign-Architecture-Assessment.md`: truth assessment of the 5-layer sovereign architecture + rights-checked corpus-expansion menu.

## v1.3.0 — 2026-06-10
- Per-Bhatt Swaiyye attribution (603 lines, signature-verified). Vaar pauris carry the Vaar's author (206 fixed; ordinal ਮਹਲੇ ਪਹਿਲੇ titles parsed). Double-click launcher; version stamp.

## v1.2.x — 2026-06-10
- Full audit round: char-for-char source reconciliation (1,643,385 chars exact); ॥ ਜਪੁ ॥ enclosing dandas; orphan marker merge; split-vowel re-attachment; Sahaskriti repairs; invocation metadata adoption; Satta & Balwand + Bhatts authorship; server hardening (400/HEAD/favicon/conn-reset); frontend hardening (delegation, toasts, race guard, a11y).

## v1.1.x — 2026-06-10
- Raag-opening pages restored (480 ੴ invocations split into proper headers; ੴ count = 568 exact). True raag spans (majority-contiguous; ਗੂਜਰੀ 489–526). Reader redesign (shabad grouping, sticky toolbar, translit toggle, font size, keyboard, dark mode). Spelling-tolerant Roman search (waheguru → ਵਾਹਿਗੁਰੂ).

## v1.0.0 — 2026-06-10
- Initial build: 1,430 Angs extracted with proven visual→logical corrections; SQLite FTS5 KB; 53-theme concept index; zero-dependency local web app; golden suite + canonical validation + adversarial red-team.
