# The website — gurbanisoul.com

The public web property is one Astro static site (`frontend/`) served on the product domain
**`gurbanisoul.com`**. It carries two distinct things, deliberately kept separate (see
[Brand & domains](../engineering/brand.md)):

- **`/`** — the **Gurbani Soul** landing page: the marketing home for the iOS app.
- **everything else** (`/search`, `/reader`, `/themes`, `/lineage`, `/insights`, the raag clock,
  `/privacy`, `/support`, …) — the **Sri Guru Granth Sahib Ji Knowledge Base**, the scholarly
  study site. It keeps its own name, header and theme; the landing has its own layout.

Both are built by `astro build` into `frontend/dist/`, synced to `webapp/static/`, and served by
the stdlib Python server locally and by Vercel in production. There is no second site and no
second copy of the policy pages — `/privacy` and `/support` are Astro pages under
`frontend/src/pages/`, and they are the single source of truth for the App Store URLs.

---

## Domains & DNS

| Host | Role | Serves |
|---|---|---|
| `gurbanisoul.com` | **canonical** apex | the site (200, no redirect) |
| `www.gurbanisoul.com` | alias | **308** → apex |
| `sggs-knowledge-base.vercel.app` | legacy Vercel alias | **308** → apex |

- **Registrar:** Hostinger (2-year term, auto-renew on, WHOIS privacy on).
- **DNS:** delegated to **Cloudflare** (account label *Company-Domains*), nameservers
  `jamie.ns.cloudflare.com` / `luke.ns.cloudflare.com`. The apex/`www` records are
  **CNAME → Vercel, DNS-only (grey cloud, not proxied)** — Vercel terminates TLS and issues the
  certificate, and HSTS is on. We do **not** proxy through Cloudflare (it would double-terminate
  TLS and hide Vercel's own caching/headers).
- **Zone ID / Account ID / API tokens** live in the Cloudflare dashboard only — never in this repo.

**Canonical rule.** The apex is canonical. `<link rel="canonical">`, `og:url` and the sitemap all
use bare `https://gurbanisoul.com/…`. `www` and the old `*.vercel.app` alias 308-redirect to it, so
there is exactly one indexable host. This is asserted at release time by
`sggs-verify-prod` (a no-redirect guard on `/`, `/privacy`, `/support`) and continuously by
`uptime.yml`.

### Email
`support@gurbanisoul.com` is a **Cloudflare Email Routing** address forwarding to the owner's
mailbox (Cloudflare adds the MX + SPF records; a `p=reject` DMARC TXT is set on `_dmarc`). It is the
public contact in the App Store listing, `SECURITY.md`, and the privacy/support pages. See
[runbook: support-inbox](../process/runbooks/support-inbox.md).

---

## SEO

`frontend/astro.config.mjs` sets `site: 'https://gurbanisoul.com'`; `frontend/src/site.ts` holds
`SITE_URL`, `SUPPORT_EMAIL`, `APP_STORE_URL`, `APP_STORE_ID`, and the photo-credit list. The head
SEO/social/PWA block is a shared component, **`frontend/src/components/Seo.astro`** (used by both
`Marketing.astro` and the Knowledge Base's `Base.astro`). Every page emits:

- `<link rel="canonical">` and `og:url` built from `SITE_URL` + the path (bare apex host);
- `description`, `og:title/description/type/image/site_name`, `twitter:card=summary_large_image`;
- `theme-color` — the Knowledge Base (`themeColor="auto"`) gets one per OS colour scheme; the
  light-first marketing shell (`themeColor="light"`) gets a single `#themeColorMeta` that
  `scripts/theme.ts` keeps in step with the *page* theme; `apple-mobile-web-app-title`, `<link rel="manifest">`, an SVG
  favicon, and — once `APP_STORE_ID` is set — the `apple-itunes-app` Smart App Banner.

`og:image` defaults to the page's OG card (`/og/<slug>.png`, see **OG images** below).
`frontend/public/robots.txt` points crawlers at the canonical host and names `/sitemap.xml`, which
is now **generated** (see **Routes, sitemap & RSS**). `Base.astro` derives its canonical/OG from
`Astro.url.pathname` so every Knowledge Base page is self-consistent without per-page props.

The `SeoInvariants` gate checks every built page's canonical/description/`og:image`(exists on disk)/
`theme-color`, and that any `hreflang` alternate is `en`/`x-default` and self-referential (no `/pa/`).

### Routes, sitemap & RSS

- **`frontend/src/routes.ts`** is the single manifest of public routes (`{ path, lastmod,
  changefreq, priority, og }`). It must list **exactly** the pages that build to HTML — the
  `SitemapInvariants` gate compares the sitemap's `<loc>` set to the built HTML route set. `lastmod`
  is a **fixed** ISO date (never `Date.now()`) so the sitemap is byte-deterministic.
- **`frontend/src/pages/sitemap.xml.ts`** emits `/sitemap.xml` over the manifest, each URL
  self-referencing its `en` + `x-default` hreflang alternates (no `pa` pages ship yet).
- **`frontend/src/pages/rss.xml.ts`** emits `/rss.xml` ("Gurbani Soul — Learn") with an **empty**
  item list for now; PR3 fills it. `RssInvariants` checks it parses and links to the site.
- The old `frontend/public/sitemap.xml` was deleted (Astro forbids a public file colliding with a
  page route).

### OG images

`frontend/src/pages/og/[slug].png.ts` renders each 1200×630 card at build with **satori**
(HTML/CSS → SVG) + **@resvg/resvg-js** (SVG → PNG): warm-ink background, a gold ੴ, the title in
Source Serif 4, the "Gurbani Soul" wordmark, a thin gold rule. `getStaticPaths` returns one card per
distinct `og` slug in `routes.ts` (at least `home` and `knowledge-base`). satori needs **static**
(non-variable) TTFs, so `frontend/src/og/fonts/` holds pinned instances (`*-og.ttf`) of Source
Serif 4 and Sant Lipi with their OFL licences; only the single ੴ glyph is Gurmukhi (satori has no
Indic shaping). Cards are byte-deterministic and each ≤ 150 KB. `public/og.jpg` remains a hero crop
for any fixed-image use.

### Analytics

`frontend/src/components/Analytics.astro` is an `is:inline` loader that injects
`/_vercel/insights/script.js` **only** when `location.hostname` matches `/(^|\.)gurbanisoul\.com$/`
— a true no-op on serve.py, localhost and staging. There is **no** `@vercel/analytics` import and no
third-party host. Vercel Web Analytics must also be **enabled in the Vercel project** (owner action)
for data to be collected; until then the loader simply fetches nothing. The `ExternalRequestAllowlist`
gate proves the marketing HTML/JS only references an approved host set and that the insights loader
is always behind the hostname guard.

### Structured data (JSON-LD)

Emitted through **`frontend/src/components/JsonLd.astro`**, which serialises the object and escapes
`<` so the payload can never break out of its `<script type="application/ld+json">`.

- **Landing (`/`)** carries three nodes (`src/pages/index.astro` frontmatter): an **Organization**
  ("Algorythmos Pty Ltd", logo `/icons/icon-512.png`, a customer-support `contactPoint`), a
  **WebSite** ("Gurbani Soul") with a `SearchAction` targeting `/search?q={search_term_string}` on
  the canonical host, and a **SoftwareApplication** ("Gurbani Soul", iOS, `ReferenceApplication`,
  `offers.price "0"`, publisher → the Organization by `@id`). There is deliberately **no
  `aggregateRating`** (we have no ratings). `installUrl`/`url` are added only once `APP_STORE_URL`
  is set.
- **`/support`** carries a **FAQPage** generated from the same `faqs` array that renders the visible
  `<h4>` question / `<p>` answer block, so the structured data can never drift from the page. The
  `JsonLdInvariants` gate parses every block, checks the landing's three types (and the
  SearchAction host), and checks that every FAQPage `name` is a visible `<h4>`.

### Newsletter (launch notice) — env-gated

**`frontend/src/components/Newsletter.astro`** renders a quiet launch-notice sign-up **only** when the
build-time env var `PUBLIC_NEWSLETTER_FORM_URL` (the Buttondown embed endpoint) is set. It is **unset
in CI, locally, and in the current build**, so the section — and any Buttondown reference — is
**absent from the built HTML**. When set, it renders a single `<input type="email" name="email"
required>`, a ghost-gold submit, an off-screen honeypot (`hp_name`), an honest one-line note ("One
short email when the app is on the App Store. No tracking, unsubscribe any time.") and a
`data-nl-status` live region. Progressive enhancement lives in **`frontend/src/scripts/newsletter.ts`**
(wired by the idempotent `landing.ts` `init()`, view-transition safe): the honeypot short-circuits to
a no-op; otherwise it POSTs **only** the `email` field with `mode:'no-cors'` and shows an inline
confirmation, or an offline/error hint. With JS off, the native POST reaches Buttondown's own
confirmation page. The URL is **never** a literal in `src` (`NewsletterPrivacy` gate); set it in the
Vercel Production + Preview envs — see [runbook: newsletter](../process/runbooks/newsletter.md).

### Security headers

`frontend/vercel.json` adds, on top of the existing `nosniff` / `X-Frame-Options: DENY` /
`Referrer-Policy`:

- **`Content-Security-Policy`** — **enforcing as of PR4.** Directive string:
  `default-src 'self'`, inline script/style allowed, `img-src 'self' data:`, `font-src 'self'`,
  `connect-src`/`form-action` add `https://buttondown.com` (the launch-notice sign-up), `frame-ancestors
  'none'`, `base-uri 'self'`, `object-src 'none'`. The flip from `-Report-Only` to enforcing was
  gated on proof: `frontend/e2e/csp.spec.ts` loads **every** route in `routes.ts` (marketing AND
  Knowledge Base, `/learn/*` included) under the enforced header — injected via `page.route` — and
  asserts **zero** `securitypolicyviolation` events on load, after toggling the theme, and after
  opening the mobile menu (46/46 green, desktop + mobile). The directive string is unchanged from
  the Report-Only version; only the header key changed. If a future page needs a new origin, add it
  to the directive, re-run `csp.spec.ts` to zero, and only then ship.
- **`Strict-Transport-Security`** (2-year, `includeSubDomains; preload`),
  **`Permissions-Policy`** (`camera=(), microphone=(), geolocation=(self), payment=()`), and
  **`Cross-Origin-Opener-Policy: same-origin`**.
- Long-lived immutable `Cache-Control` for `/og/:path*` and `/icons/:path*`.

### Fonts & PWA

- **Sant Lipi** (SIL OFL 1.1) — the bundled Gurmukhi webfont, `unicode-range`-scoped, shared with
  the Knowledge Base; declared in `marketing.css` (rule copied from `global.css`).
- **Source Serif 4** (SIL OFL 1.1) — a Latin subset for headings (Brand.heading), regenerated by
  `frontend/scripts/subset-serif.sh` into `frontend/public/fonts/SourceSerif4-latin.woff2`
  (≤ 130 KB; licence at `/fonts/OFL-SourceSerif4.txt`). Declared in `marketing.css` and wired into
  the heading stack in PR2 (this PR keeps the page pixel-identical).
- **PWA**: `frontend/public/site.webmanifest` (name/short_name, warm-ink theme/background,
  `display: standalone`) and `frontend/public/icons/` (192, 512, maskable-512, apple-touch),
  regenerated deterministically by `frontend/scripts/gen-icons.mjs` (a gold ੴ on warm ink).

---

## The landing page (`/`)

- **Layout:** `frontend/src/layouts/Marketing.astro` (renamed from `Landing.astro` in the PR1
  web-foundations pass) — its own shell, brand tokens as CSS variables in
  `frontend/src/styles/marketing.css` (mirrored, typed, in `frontend/src/theme.ts`, which the
  `WebThemeMatchesTokens` gate keeps equal to `docs/brand/tokens.json`), a **light-first** pre-paint
  theme script (no stored choice → light, whatever the OS; an explicit choice is shared with the
  Knowledge Base, which keeps its `system` default), the shared `MarketingFooter`, `<Seo>`, `<Analytics>`, Sant Lipi + a serif heading stack, a skip link, `lang="pa"` on
  Gurmukhi, and `prefers-reduced-motion` respected.
- **Page:** `frontend/src/pages/index.astro` — hero, the verse band, six feature cards,
  "Private by design", a Knowledge Base card, and the App Store slot.
- **Brand rules are law** (`docs/brand/gurbani-soul-brand-book.md`): gold leads on warm paper/ink;
  `#FFBC0D` only as a **bordered** fill in light mode (free in dark); gold *text* only via
  `accentText` (`#8A6100`); **red never** on the landing; Gurmukhi always ink-coloured Sant Lipi;
  **never a gold mark on a red square**. `python3 scripts/brand/contrast_report.py` must exit 0
  after any colour change.
- **Scripture is never typed by hand.** The verse shown on `/` is generated from the verified DB by
  `scripts/gen_landing_verse.py` into `frontend/src/generated/landing-verse.json`, and the
  `LandingPage` gate compares the rendered `lang="pa"` line byte-for-byte to
  `SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1`. Citation is always
  "Sri Guru Granth Sahib Ji · Ang N".
- **Honest copy.** The listing lint's forbidden list applies here too: no "AI" except
  "never AI-generated", no "beta", nothing the app does not do.

---

## Image policy

The v2 site (2026-09) is **light-first** with warm-ink bands and three kinds of imagery: the
owner's **original artwork** (the hero), **Unsplash photographs** (photo bands, Learn covers), and
**real app screenshots**. Everything is self-hosted through `astro:assets` — the CSP is
`img-src 'self' data:`, so nothing is ever hot-linked from `images.unsplash.com`.

### Unsplash photographs — licence facts
- Used under the [Unsplash License](https://unsplash.com/license): free for commercial and
  non-commercial use, modification permitted, no permission needed, attribution appreciated but not
  required — **we credit anyway**, on every marketing page and in `NOTICE.md`.
- The licence does **not** allow selling unaltered copies or compiling Unsplash photos into a
  competing service, and it carries **no model or property releases** — which is why faces and
  identifiable people are excluded below.
- Keep the photo's Unsplash page URL in the PR description so the licence can be re-checked.

### Respectful selection (owner approves every pick in the preview)
Briefs: Sri Harmandir Sahib at dawn / reflected at night · Gurdwara marble inlay detail · Nishan
Sahib against the sky · Punjab wheat or mustard field · gold-leaf / brass texture · a single diya at
dusk · an empty parikrama. Criteria:
- devotional light and architecture only; **no** saroop being handled, **no** identifiable faces,
  **no** crowds, **no** watermarks or text in frame;
- ≥ 2400 px wide originals, warm palette; treatment is a baked −10 % saturation + warm white balance
  only — on the page a warm-ink scrim, never a gold tint, grain or duotone;
- a photo **never** sits beside Gurmukhi (bands carry one serif statement ≤ 22 ch + one sub-line).

### Where files live
- **Photographs + artwork:** `frontend/src/assets/landing/` — `unsplash-<handle>-<subject>.jpg`
  (EXIF stripped, ≤ 2400 w). **Every file here is counted by the credit gate.**
- **Learn covers:** mapped slug → import in `frontend/src/covers.ts` (`LEARN_COVERS`), not
  `site.ts` (which every layout imports and the credit gate parses).
- **App screenshots:** `frontend/src/assets/app/<device>-<screen>[-variant]-<appearance>.png`,
  recorded in `frontend/src/assets/app/SHOTS.md` (see *Shot pipeline*).

### Credit shape
One `IMAGE_CREDITS` entry per file in `frontend/src/site.ts` (artwork entry first):
```ts
{ who: "Photographer Name", what: "Sri Harmandir Sahib reflected at dawn",
  url: "https://unsplash.com/@handle", file: "unsplash-handle-harmandir-dawn.jpg", source: "Unsplash" }
```
- `url` is the photographer's profile on the **bare host** `https://unsplash.com/@<handle>`
  (the `ExternalRequestAllowlist` gate allows `unsplash.com`, never `images.unsplash.com`).
- An entry **without** `url` is original artwork ("Artwork: …, made for Gurbani Soul.").
- `MarketingFooter.astro` renders the credits from this list on every marketing page:
  "Photographs: {who} / Unsplash, … (Unsplash License)." appears only when photos exist.
- Add the same name + profile link to [`NOTICE.md`](../../NOTICE.md) → "Website imagery".

The `LandingPage.test_imagery_is_credited` gate enforces all of it: exactly one credit per file in
`assets/landing/`, every `who` in the built `index.html` **and** in `NOTICE.md`, an "Artwork"
credit, and — once any photo has a `url` — "Unsplash" on the page and every `url` matching
`https://unsplash.com/@<handle>`. `photo-bands.spec.ts` checks each `.photo-band img` has alt text
and loads lazily, and that the footer names each linked photographer.

### Rendering & budgets
- Components: `PhotoBand.astro` (full-bleed `<Picture>` AVIF+WebP 640–1600 w, `sizes="100vw"`,
  q55, lazy, warm-ink scrim, `data-theme="dark"`); `DeviceFrame.astro` (`kind="iphone"|"ipad"`,
  `frame={false}` for frame-less editorial shots, `eager` for the hero phone only).
- Home: at most **2** `loading="eager"` images (hero artwork + hero phone) and exactly **one**
  `fetchpriority="high"` (the artwork, the LCP); any hero preload must reuse the rendered AVIF
  srcset. Every other page: nothing eager. Everything else lazy + `decoding="async"`.
- Budgets (gate-enforced): Home / Features / The watch / Privacy / Support HTML ≤ **60 KB** each;
  each Learn page ≤ **48 KB**; no served AVIF/WebP variant > **340 KB**. Targets: hero ≤ 1920 w AVIF
  q55–60 ≤ 220 KB · photo bands ≤ 1600 w q55 ≤ 180 KB · iPhone frames WebP ≤ 80 KB · iPad
  AVIF+WebP ≤ 250 KB (drop to 1400 w rather than raise the gate).

### Adding a photo
1. Download the approved Unsplash original into `frontend/src/assets/landing/` as
   `unsplash-<handle>-<subject>.jpg`; strip EXIF; resize to ≤ 2400 w.
2. Add its `IMAGE_CREDITS` entry (`who`, `what`, `url`, `file`, `source: "Unsplash"`) and the
   photographer to `NOTICE.md`.
3. Use it through `PhotoBand` / `<Picture>` with an alt that names the place.
4. `cd frontend && npm run build:deploy` twice (byte-identical), then
   `python3 -m unittest discover -s webapp/tests` and `npx playwright test photo-bands landing`.

### Shot pipeline (app screenshots)
Captured from the Simulator, never mocked; every file is recorded in `SHOTS.md` (raw SHA-256,
device, iOS version, commit, deep link, environment).
1. Dedicated simulators ("SGGS iPhone 17 Pro", "SGGS iPad Pro 13"), one booted at a time; a Debug
   build with `-derivedDataPath` in the scratchpad.
2. The **public** DB swapped into a *throwaway copy* of the built `.app` — never into
   `ios/Resources`.
3. `xcrun simctl status_bar … override --time 9:41`, `xcrun simctl ui … appearance light|dark`,
   `SIMCTL_CHILD_SGGS_CLOCK_NOW=581 SGGS_CLOCK_MODE=fixed SGGS_CLOCK_NO_COORDS=1`.
4. Deep links (`sggs://ang/1`, `ang/712` on iPad landscape, `search?q=…`, `nitnem`, `bani/japji`,
   `clock`, `theme/naam`) — and **`sggs://shabad/<compId>` for a deterministic Hukam**, never the
   random `sggs://hukam`. Widgets come from the snapshot unit tests (`SGGS_WIDGET_SNAPSHOT_DIR`).
5. Honest state only: a sparse reading-journey grid is fine; fabricated progress never is.
6. Processing via `frontend/scripts/prep-shots.mjs` (sharp, lanczos3, palette PNG, metadata
   stripped, idempotent): iPhone → 900 w, iPad landscape → 1600 w, widgets 2×, accent crops 900×420.

---

## Swapping in the App Store badge (after approval)

Until the app is approved, `APP_STORE_URL` in `frontend/src/site.ts` is `''` and the hero shows a
"Coming soon to the App Store" chip (`data-app-store="coming-soon"`). After approval:
1. Download the official badge from Apple's App Store Marketing Tools (needs the app ID) into
   `frontend/public/img/app-store-badge.svg`.
2. Set `APP_STORE_URL` to the App Store product URL.
3. `npm run build && npm run sync` — the hero swaps the chip for the linked badge automatically.

---

## Adding a page
Create `frontend/src/pages/<name>.astro` using `Base.astro` (Knowledge Base) or `Marketing.astro`
(Gurbani Soul). Add its route to `frontend/src/routes.ts` (the sitemap and OG default derive from
it — the `SitemapInvariants` gate fails if the manifest and the built HTML routes disagree). If it
is a nav destination, add it to the `Base.astro` nav with a `data-path`. Build + sync.

---

## What protects the site
- **Repo gates** (`webapp/tests/test_repo_gates.py`, run by the required `python` check):
  `LandingPage` (verse verbatim, honest copy, alt text, SEO head, page-weight budget),
  `SubmissionUrlsAreLive`, `InAppLinksMatchTheListing`, and `DocsHygiene` (this doc set is the only
  place the legacy `vercel.app` alias may be named); plus the PR1 web-foundations gates
  `SeoInvariants`, `SitemapInvariants`, `RssInvariants`, `ExternalRequestAllowlist`,
  `SmartBannerConsistency`, `NoSecretsInFrontend`, and `WebThemeMatchesTokens`; plus the PR4
  growth/polish gates `JsonLdInvariants` (structured data on `/` and `/support`) and
  `NewsletterPrivacy` (no Buttondown literal in `src`; no form/host in the env-less build).
  `StaticRoutes` in `test_serve.py` covers serve.py's static resolver + content types.
- **`@smoke` Playwright** (`frontend/e2e/landing.spec.ts`, run in the production deploy gate against
  `https://gurbanisoul.com`): landing renders, verse present, exactly one App-Store slot, canonical
  host, axe serious/critical = 0.
- **`uptime.yml`**: `/` (200 + "Gurbani Soul"), `/search`, `/privacy`, `/support` on the canonical host.
- **`sggs-verify-prod`**: after each release, proves the running commit and the no-redirect guard.
