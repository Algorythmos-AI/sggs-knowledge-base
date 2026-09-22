# The website — gurbanisoul.com

The public web property is one Astro static site (`frontend/`) served on the product domain
**`gurbanisoul.com`**. It carries two distinct things, deliberately kept separate (see
[CLAUDE.md → Brand & domains](../../CLAUDE.md)):

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
- `theme-color` per colour scheme, `apple-mobile-web-app-title`, `<link rel="manifest">`, an SVG
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

### Security headers

`frontend/vercel.json` adds, on top of the existing `nosniff` / `X-Frame-Options: DENY` /
`Referrer-Policy`:

- **`Content-Security-Policy-Report-Only`** (not enforcing yet — it reports violations so the policy
  can be tuned before it is switched to an enforcing `Content-Security-Policy` in a later PR):
  `default-src 'self'`, inline script/style allowed, `img-src 'self' data:`, `font-src 'self'`,
  `connect-src`/`form-action` add `https://buttondown.com` (the future newsletter), `frame-ancestors
  'none'`, `base-uri 'self'`, `object-src 'none'`.
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
  `WebThemeMatchesTokens` gate keeps equal to `docs/brand/tokens.json`), the shared pre-paint theme
  script, `<Seo>`, `<Analytics>`, Sant Lipi + a serif heading stack, a skip link, `lang="pa"` on
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

Photography of Sri Harmandir Sahib is sourced from **Unsplash** under the
[Unsplash License](https://unsplash.com/license) (commercial use and modification permitted, no
permission required; attribution appreciated — and we credit anyway).

**Selection criteria (respectful imagery):** warm devotional light and architecture only; **no**
images of the saroop being handled, and **no** identifiable faces (Unsplash carries no model
releases). Originals live in `frontend/src/assets/landing/` (≤ 2400 w, EXIF stripped).

**Rendering & budget:** use `astro:assets` `<Picture formats={['avif','webp']}
widths={[480,800,1200,1600]} sizes=…>`; the hero is `loading="eager" fetchpriority="high"` with a
`<link rel="preload">`, everything else lazy; give a dominant-colour background so there is no
layout shift. Budgets (enforced by the `LandingPage` gate): no served AVIF/WebP variant over
**340 KB**; built `index.html` ≤ **60 KB**.

**Credits.** Every photographer is credited in the landing footer (`Landing.astro`) and in
[`NOTICE.md`](../../NOTICE.md) → "Website imagery". Add a credit whenever you add a photo — the
`LandingPage` lint fails if an image lacks alt text.

### Adding a photo
1. Download the Unsplash original into `frontend/src/assets/landing/`, strip EXIF.
2. Reference it through `<Picture …>` with real, descriptive `alt` text.
3. Add the photographer (name + Unsplash profile link) to the footer credits and `NOTICE.md`.
4. `cd frontend && npm run build && npm run sync`; confirm no variant exceeds the budget.

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
  `SmartBannerConsistency`, `NoSecretsInFrontend`, and `WebThemeMatchesTokens`.
  `StaticRoutes` in `test_serve.py` covers serve.py's static resolver + content types.
- **`@smoke` Playwright** (`frontend/e2e/landing.spec.ts`, run in the production deploy gate against
  `https://gurbanisoul.com`): landing renders, verse present, exactly one App-Store slot, canonical
  host, axe serious/critical = 0.
- **`uptime.yml`**: `/` (200 + "Gurbani Soul"), `/search`, `/privacy`, `/support` on the canonical host.
- **`sggs-verify-prod`**: after each release, proves the running commit and the no-redirect guard.
