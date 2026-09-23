# Astro Migration Plan — "Path A: Offline Monolith"

**Status:** PROPOSAL — awaiting your approval. **No code has been written; no existing file has been altered.** This document is the synthesis of three SME design passes (Build & Integration, UI/UX Components, Data Visualization), each grounded in the real `serve.py`, `index.html`, and the v2.1.0 API.

**Goal:** migrate the frontend from one hand-written `webapp/static/index.html` to an Astro source project that **compiles to static files served by the same zero-dependency Python `serve.py`**, keeping the app **100% offline and local** and at **full feature + aesthetic parity**.

---

## ✅ Decisions locked (2026-06-14)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Architecture | **MPA** — multiple real HTML routes (`/`, `/reader`, `/index`, `/themes`; `/insights` later) |
| 2 | Styling | **Keep the existing CSS** verbatim (no Tailwind port) — identical look, zero new dep |
| 3 | Gurmukhi font | **System font stack** (no bundled webfont) — zero download, guaranteed offline |
| 4 | Scope | **Astro shell first** at full parity; the analytics **Insights** view is a fast follow-up |

§1, §2, §4 below are written to these decisions. (§5 Tailwind/§6 Insights sections are retained for the future follow-up but are out of scope for the first migration.)

---

## 0. The non-negotiables (carried from the project's philosophy)

1. **100% offline — no CDN, ever.** Tailwind compiles at build time to static CSS; viz libraries are bundled from npm; fonts are local. Nothing is fetched from a network at runtime. (Today this is honored by inlining everything; the migration must preserve it.)
2. **Runtime stays Python-stdlib-only.** Astro/node/npm are **build-time only**. `serve.py` gains a static-file server but no new dependency.
3. **The `/api/*` surface and the search engine are untouched.** The frontend still talks to the same endpoints.
4. **Reversible.** A one-command rollback restores the current working app at any point.

---

## 1. Architecture: MPA (real routes) — and how shared state stays safe

The current app is a single-page app: five in-DOM views toggled by `view()`/`nav()`, sharing in-memory state (`META`, `curAng`, `raagCtx`, `mode`, `hlToks`, `_panelTrigger`, `searchReq`/`angReq`, `localStorage` prefs). **MPA (chosen)** makes each view a real page; the nav becomes real `<a>` links and the cross-view state moves out of memory. Done correctly this is robust **and** gains real URLs (bookmark an Ang, browser back/forward, deep links). Exactly how each shared piece is preserved so nothing regresses:

- **Routes:** `/` (Search) · `/reader` · `/index` · `/themes` · (`/insights` later) — each a real `*.html`. Nav = `<a href>` links in `Base.astro`; the active link is derived from `Astro.url.pathname` at build (no JS).
- **`META` (`/api/meta`):** fetched per page but cached in **`sessionStorage`** (one fetch per session); `/api/meta` is already server-cached → effectively free.
- **`curAng` / `raagCtx`:** carried in the **URL** — `/reader?ang=462&raag=ਆਸਾ`; the Reader reads `URLSearchParams` on load. This is the upgrade: Angs become shareable/bookmarkable and back/forward works.
- **Open shabad from a result:** the `#panel` modal stays **in-page** on `/` (no navigation); its "Open Ang" button links to `/reader?ang=N`.
- **`mode` / `hlToks` / results:** page-local to `/` — no cross-page need.
- **translit toggle, font size:** already `localStorage` → shared across pages; applied on load before paint (no flash).
- **`CLOSING_FIX`, `compTitle`, race guards, focus trap:** shared TS modules imported by whichever page needs them — single source, no duplication.

**Honest trade-off vs SPA:** MPA is a bit more porting (each page is its own entry; state moves to links/URL/localStorage) and a full reload occurs on view change (instant for a localhost static file). In return: idiomatic Astro, smaller per-page JS (the Reader never ships search code), real URLs, working history. The §9 parity checklist guards every state hand-off. **The `serve.py` patch (§4) therefore uses the full route→`.html` mapping** (a path with no extension, e.g. `/reader`, resolves to `reader.html`).

---

## 2. Directory structure

```
SGGS-KnowledgeBase/
├── db/ … pipeline/ … webapp/            ← unchanged
├── frontend/                            ← NEW: the entire Astro project (build-time only)
│   ├── astro.config.mjs
│   ├── package.json
│   ├── tsconfig.json
│   ├── tailwind.config.mjs              ← only if we adopt Tailwind (see §5)
│   ├── scripts/sync-to-webapp.mjs       ← safe dist→static sync + backup + rollback
│   ├── public/
│   │   └── fonts/                        ← optional bundled Gurmukhi .woff2 (see §5)
│   ├── dist/                            ← `astro build` output (gitignored)
│   └── src/
│       ├── layouts/Base.astro            ← <html lang="pa">, head, header, nav, footer, skip-link, toast
│       ├── pages/                        ← MPA route pages, each → its own *.html:
│       │     index.astro (Search) · reader.astro · index-view.astro · themes.astro  (insights.astro later)
│       ├── components/                   ← AppHeader, AppNav, SearchBar, ModeChips, ResultsList,
│       │                                    ReaderToolbar, IndexTabs, QuickAccessGrid, RaagsGrid,
│       │                                    SectionsGrid, ThemesGrid, ShabadPanel, Toast, AnalyticsView
│       ├── scripts/                       ← plain TypeScript client modules (NO framework):
│       │   ├── app.ts                     ←   view switching, nav, keyboard, init
│       │   ├── api.ts                     ←   api(), guard(), meta() cache
│       │   ├── store.ts                   ←   localStorage wrapper
│       │   ├── search.ts                  ←   go(), doVerify(), hl(), lineCard(), syncMode()
│       │   ├── reader.ts                  ←   ang(), groupShabads(), toggleT(), fontSize()
│       │   ├── index-view.ts              ←   raags(), themes(), showRaagTab(), QUICK_ACCESS, CLOSING_FIX, fixSections()
│       │   ├── panel.ts                   ←   openPanel/closePanel/shabad/randomShabad, compTitle/titleBlock, focus trap
│       │   └── viz/                        ←   analytics viz, lazy-loaded (see §6)
│       │       ├── themeNetwork.ts
│       │       └── authorRadar.ts
│       └── styles/global.css              ← design tokens (the :root CSS vars) + base styles
└── webapp/static/                         ← serve.py serves this; sync target
    ├── index.html                         ← (Astro build replaces this; backed up to static.bak/)
    └── _astro/  (main.<hash>.css, app.<hash>.js, viz chunks, fonts)
```

---

## 3. `astro.config.mjs` (static, offline)

```js
import { defineConfig } from 'astro/config';
// import tailwind from '@astrojs/tailwind';   // only if §5 → Tailwind

export default defineConfig({
  output: 'static',                 // pure pre-rendered HTML, no SSR, no adapter
  build: {
    outDir: './dist',               // build to frontend/dist — NEVER directly at webapp/static (see GOTCHA-1)
    emptyOutDir: true,              // default; safe because outDir is dist/, not webapp/static
    assets: '_astro',
  },
  base: '/',                        // serve.py serves at root → absolute /_astro/* URLs must resolve at /
  trailingSlash: 'never',
  vite: { build: { assetsInlineLimit: 4096 } },
  // integrations: [tailwind({ applyBaseStyles: false })],  // if Tailwind adopted
});
```

**GOTCHA-1 (build-destructiveness):** `astro build` **wipes its `outDir` before every build**. If `outDir` pointed at `webapp/static/`, every build would delete the live app (including `index.html`) for the duration of the build. **Always build to `frontend/dist/`, then sync** (§7).

---

## 4. The `serve.py` static-file patch (stdlib-only, path-safe)

Today `_handle` serves `static/index.html` hardcoded for every non-`/api/` path. We need a **real static-file server** for `static/` (the route `.html` pages + `/_astro/*` hashed assets), while leaving `/api/*` and `/favicon.ico` exactly as they are.

**Add at module top (after imports):**
```python
import mimetypes
mimetypes.add_type('font/woff2', '.woff2')          # Python's built-in list omits these on macOS;
mimetypes.add_type('font/woff',  '.woff')            # without them browsers refuse to load the fonts
mimetypes.add_type('text/javascript', '.mjs')
mimetypes.add_type('application/manifest+json', '.webmanifest')
```
**Add next to `HERE = …`:**
```python
STATIC_ROOT = os.path.realpath(os.path.join(HERE, 'static'))   # canonical, symlinks resolved, computed once
```

**Replace the static branch of `_handle` (the `with open(... 'index.html')` lines) with a call to a new `_serve_static`, keeping the favicon + `/api/` branches first.** Core of `_serve_static`:

```python
def _serve_static(self, url_path):
    rel = url_path.lstrip('/').rstrip('/')
    if rel == '':
        rel = 'index.html'                       # '/' → index.html
    resolved = os.path.realpath(os.path.join(STATIC_ROOT, rel))
    # PATH-TRAVERSAL GUARD: resolved must descend from STATIC_ROOT.
    # Use STATIC_ROOT + os.sep (NOT bare startswith) so '/a/static2' can't masquerade as '/a/static'.
    if resolved != STATIC_ROOT and not resolved.startswith(STATIC_ROOT + os.sep):
        return self._static_error(403, 'Forbidden')
    # MPA route mapping: an extensionless URL like /reader maps to reader.html.
    if not os.path.isfile(resolved) and os.path.splitext(rel)[1] == '':
        alt = resolved + '.html'
        if alt.startswith(STATIC_ROOT + os.sep) and os.path.isfile(alt):
            resolved = alt
    if not os.path.isfile(resolved):
        return self._static_error(404, 'Not Found')          # real 404, never a silent index.html fallback
    ct, _ = mimetypes.guess_type(resolved)
    ct = ct or 'application/octet-stream'
    if ct.startswith('text/') and 'charset' not in ct:
        ct += '; charset=utf-8'
    try:
        with open(resolved, 'rb') as fh: body = fh.read()
    except OSError:
        return self._static_error(404, 'Not Found')
    norm = resolved.replace(os.sep, '/')
    cache = ('public, max-age=31536000, immutable' if '/_astro/' in norm        # hashed → forever
             else 'no-store' if resolved.endswith('.html')                       # html → always revalidate
             else 'public, max-age=3600')
    self.send_response(200)
    self.send_header('Content-Type', ct); self.send_header('Content-Length', str(len(body)))
    self.send_header('Cache-Control', cache); self.end_headers()
    if self.command != 'HEAD': self.wfile.write(body)
```
`_static_error` sends a tiny plain-text status (also HEAD-aware). `do_GET`/`do_HEAD` are unchanged.

**Why not route static through the existing `_respond`?** `_respond` hardcodes `Cache-Control: no-store`; hashed assets need `immutable`. `_serve_static` sends headers directly (a two-line copy), so no existing call site is touched.

**Security / correctness, exhaustively covered:** path traversal (`../`, `%2e%2e`, symlink escape — all defeated by `realpath` + `+ os.sep` prefix check); the `static2` prefix-substring false-positive; `/` and missing files (real 404, no SPA-fallback that would hide errors); HEAD; query strings (`urlparse` already splits them off); `.woff2`/`.mjs` MIME on macOS; `PermissionError`→403; module-level `STATIC_ROOT` is thread-safe. Range/gzip intentionally skipped (local loopback). *(Full per-case table lives in the build SME's notes; reproduced in the appendix on request.)*

---

## 5. Styling: the Tailwind question (an honest decision for you)

The task asks to "integrate Tailwind." But the current design system is a **hand-tuned, premium, tiny CSS-variable system** (`--bg/--card/--saffron/--gold/--ink…`, full dark-mode via `prefers-color-scheme`, the Gurmukhi `.gm` stack, `--gsize`/`--nav-h` runtime vars, the focus/touch/reduced-motion a11y). Two honest paths:

- **Path 5A — Keep the existing CSS (recommended for the migration itself).** Move the `<style>` block into `src/styles/global.css` verbatim. **Zero aesthetic risk, zero new build dependency, preserves every token.** Astro fully supports plain CSS. We can adopt Tailwind incrementally *later*.
- **Path 5B — Port to Tailwind now (as requested).** The UI SME produced the exact `tailwind.config` token map (every colour → `bg/card/saffron/gold…` with `dark:` variants, `darkMode:'media'`, the radii/shadow/z-index scale, the `.gm` → `font-gm` stack). Compiles to one static CSS at build — still 100% offline. But it is a real re-authoring of 740 lines and carries visual-diff risk.

`--gsize` and `--nav-h` **must remain CSS variables** either way (they're mutated at runtime by `fontSize()`/`syncToolbarTop()`).

**Gurmukhi font (separate sub-decision):**
- **5-Font-A (default):** keep the **system font stack** (Mukta Mahee / Gurmukhi MN / Noto Sans Gurmukhi…). Zero download, guaranteed offline, renders great on Mac/iOS/Android.
- **5-Font-B:** bundle **Noto Sans Gurmukhi** as a local `.woff2` in `public/fonts/` (subset ~180 KB) for pixel-consistent rendering on Windows. **`@font-face src` must point at the local file — never `fonts.googleapis.com`.**

**My recommendation:** Path **5A + Font-A** for the migration (de-risk: identical look, no Tailwind/Font porting), then adopt Tailwind and/or a bundled font as a *separate, reviewable* follow-up. But this is your call (see §10).

---

## 6. Interactivity & the analytics visualizations

**Client strategy: plain bundled TypeScript modules — no UI framework.** Astro is "zero-JS by default"; this app's interactivity is ~400 lines of already-correct vanilla JS. Porting it 1:1 into TS modules (bundled/minified/tree-shaken by Astro's Vite) is the lightest, lowest-risk path — lighter than Preact/Solid islands or Alpine, and it keeps the search/reader experience at ~0 KB framework overhead.

**Behaviors that need careful 1:1 porting (regression-sensitive):** the `searchReq`/`angReq` race guards (module-level, not function-local); the `#panel` focus trap + `_panelTrigger` focus-return; the `guard()` async wrapper; `CLOSING_FIX`/`fixSections()` (shared by reader chip **and** sections grid — single source, no duplication); the Japji `compTitle` special-case (`section==='ਜਪੁ'` → M1); the closing-section Ang ranges (1364–1376 Kabir, 1377–1384 Farid — verbatim constants); `syncToolbarTop` (prefer `ResizeObserver`); roving-tabindex on mode chips + index tabs; delegated click/keydown handlers; localStorage prefs. *(The UI SME produced an exhaustive 90-item feature-parity checklist — see §9.)*

**The analytics views (v2.1.0 data) — a new "Insights" view (`#v-analytics`), lazy-loaded.** Because we're SPA, the two charts live in a sixth view whose viz code + libraries load via **dynamic `import()` only when the user first opens Insights** — so the search/reader bundle stays tiny.

| Viz | Source endpoint | Real shape (verified) | Library | Notes |
|---|---|---|---|---|
| **Theme-network force graph** | `/api/themes/network?limit=1000` | 53 nodes, 1,260 edges (default 200 by PPMI ≈ 44 nodes) | **d3-force + d3-selection/-drag/-zoom (à-la-carte) ≈ 24 KB gz**, **Canvas** render | node size = degree, edge width = PPMI, opacity = Jaccard, colour = theme family; hover/click-focus a concept; PPMI slider (client-side filter); start focused on `concept=naam` then "explore full" |
| **Author stylometric radar** | `/api/analytics/author?author=…` | 12-dim theme fingerprint (lift); **M1 vs M5 share 0 of top-12** | **Chart.js v4 radar, tree-shaken ≈ 28 KB gz** | use a **fixed union axis-set** (concepts appearing in ≥2 authors) with lift=1.0 baseline ring; overlay 2 authors; stylometry scalars (MATTR, hapax…) as a side stat-table, never a ranking |

**Total viz bundle ≈ 52 KB gz**, both from npm, fully offline, no CDN/telemetry (MIT/ISC). *(Rejected: ECharts ~360 KB, Cytoscape ~131 KB — too heavy for a sovereign offline app.)*

**Data-fetching: client-side `fetch` at runtime** (the local server is always up when the app is used; live data, no build coupling, survives DB rebuilds). The endpoints already degrade gracefully (`{edges:[], note:'analytics tables not present…'}`), so each view renders **loading / empty-note / server-unreachable-retry / rendered** states. Every chart shows the API's `note` ("descriptive only, never a ranking of scripture").

---

## 7. Build → sync → cutover (safe & reversible)

```bash
# ── one-time scaffold (no impact on the live app) ──
cd SGGS-KnowledgeBase && mkdir frontend && cd frontend
npm create astro@latest . -- --template minimal --typescript strict --no-git --skip-houston
# (+ npm i @astrojs/tailwind tailwindcss   ← only if §5 → Tailwind)
# author astro.config.mjs, src/, scripts/sync-to-webapp.mjs as specified

# ── iterate (live app untouched; dev server proxies /api → :7777) ──
npm run dev            # http://localhost:4321

# ── build + offline audit ──
npm run build
grep -rE "cdn|unpkg|jsdelivr|fonts\.googleapis|https?://" dist/ && echo "!! external ref — FIX" || echo "offline-clean ✓"

# ── patch serve.py (review diff first), syntax-check ──
git -C .. diff webapp/serve.py
python3 -m py_compile ../webapp/serve.py && echo "serve.py syntax OK"

# ── cutover: backup + sync (atomic backup; rsync --delete clears stale hashed chunks) ──
npm run sync           # renames webapp/static → webapp/static.bak, rsyncs dist/ → webapp/static/

# ── validate the live app ──
python3 ../webapp/serve.py &     # then:
curl -s localhost:7777/api/health | python3 -m json.tool        # "ok": true
for p in / /_astro nonexistent ../../etc/passwd; do curl -s -o /dev/null -w "$p → %{http_code}\n" "localhost:7777/$p"; done
#   / → 200 · /_astro(dir) → 404 · nonexistent → 404 · traversal → 403
# then open http://localhost:7777 and run the §9 parity checklist by hand

# ── ROLLBACK (instant, if anything fails) ──
mv ../webapp/static ../webapp/static.broken && mv ../webapp/static.bak ../webapp/static
git -C .. checkout webapp/serve.py        # if the server patch is the problem
```
`scripts/sync-to-webapp.mjs` performs the atomic `static → static.bak` rename, then `rsync -a --delete dist/ webapp/static/` (Node `cpSync` fallback if no rsync), and supports `--rollback`. `frontend/dist/` and `frontend/node_modules/` go in `.gitignore`.

---

## 8. What ships in git

- **New:** the whole `frontend/` source tree (NOT `dist/` or `node_modules/`), the `serve.py` patch, this plan.
- **Changed at cutover:** `webapp/static/` (Astro output replaces `index.html`, adds `_astro/`). The current `index.html` is preserved at `webapp/static.bak/` and in git history.
- **Unchanged:** `db/`, `pipeline/`, `webapp/verify.py`, every `/api/*` handler, the search engine.

---

## 9. Feature-parity checklist (must all pass before declaring done)

The UI SME produced a 90-item checklist covering: shell/chrome (lang=pa, skip-link, nav `aria-current`, footer `#ver`, toast, reduced-motion, dark palette); **Search** (autofocus, 7 mode chips as a keyboard radiogroup, highlight, result cards + meta chips, related-theme links, "More", race guard, Verify `@ang` verdicts, card keyboard activation); **Reader** (sticky toolbar + `syncToolbarTop`, Ang nav, translit toggle, font-size, ←/→ keys, context chips, **closing-section chip correction**, raag banner, continued-from pill, `groupShabads`, `.invoc`/`.rahao`/EN rendering, boundary-disabled endnav, race guard); **Index** (3-tab keyboard tablist, Quick-Access 6 tiles, raags/sections grids, **`CLOSING_FIX`**, routing on tile click); **Themes** (6 categories, titleCase, explore arrows); **Panel/Hukam** (focus trap, focus return, Esc/backdrop/× close, `compTitle` Japji case, `comp_type` intentionally hidden, "Another" guard); **A11y** (all roles/aria, focus-visible saffron, 44px touch targets); **prefs/init** (localStorage translit+font, meta cache, init order). This checklist becomes the acceptance gate; I'll run it (curl + a live browser pass) before sign-off.

---

## 10. Decisions I need from you before building

1. **SPA confirmed?** (single page, shared state preserved — my strong recommendation). vs. MPA (separate routes; needs state serialization).
2. **Styling:** **5A keep the existing CSS** (de-risk, identical look — my recommendation) vs. **5B port to Tailwind now** (as originally specced; a real re-author).
3. **Gurmukhi font:** **Font-A system stack** (recommended) vs. **Font-B bundle Noto woff2** (Windows-consistent).
4. **Analytics viz scope:** include the theme-network + author-radar **Insights view in this migration**, or land the Astro shell first and add Insights as a fast follow-up? (The +52 KB viz libs only load when Insights is opened either way.)

---

## 11. Risk register (top gotchas)

1. **`outDir` wipes the live app** if pointed at `webapp/static/` → always build to `dist/` + sync (§3, §7).
2. **Path traversal** in the static server → `realpath` + `STATIC_ROOT + os.sep` guard, real 404s, no SPA-fallback (§4).
3. **MIME on macOS** (`.woff2`/`.mjs` missing) → `mimetypes.add_type` at init (§4).
4. **Hidden CDN references** (a Tailwind Play CDN, a Google-Fonts `@import`, a viz lib loading a worker from unpkg) → the `grep` offline-audit gate in the build step (§7).
5. **Stale hashed chunks** accumulating in `static/_astro/` → `rsync --delete` (§7).
6. **Regression in subtle behaviors** (race guards, focus trap, `CLOSING_FIX`, `compTitle`) → the §9 parity checklist + the careful-porting list (§6).
7. **`Cache-Control` for HTML** must be `no-store` (HTML references hashed assets that change each build) (§4).

---

### Bottom line

This is a low-risk, reversible migration: an Astro **source** refactor that compiles to the same offline static bundle, served by a **carefully hardened** stdlib static-file patch, with the DB/API/search engine and the entire premium dark aesthetic preserved — plus a lazy-loaded Insights view to finally visualize the v2.1.0 analytics. **Nothing has been built or changed yet.** Tell me your calls on §10 and I'll execute it step by step with validation gates at each stage.
