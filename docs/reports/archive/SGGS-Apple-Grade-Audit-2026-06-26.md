# SGGS Knowledge Base — "Apple-Grade" Audit & Hardening Pass

**Date:** 2026-06-26 · **Release:** v2.10.1 → **v2.11.0** · **DB:** unchanged (`db_sha256 cde0baa6…`)

> **Prime directive honoured.** Sri Guru Granth Sahib Ji is sacred scripture. Every change in
> this pass is on the **presentation / server-logic / docs** layers. The corpus, database, `/api`
> payloads, FTS index, and Copy-verse output are **byte-identical** — proven post-change by
> `reconcile.py` (char-exact, 1,643,385 chars), `golden_test.py` (all-pass), and `/api/health`
> (all-true). `git diff` touches **no** file under `corpus/` or `db/`.

---

## 1. Method

Three independent read-only audits (security/privacy, accessibility/UX/design, docs/perf/quality)
fanned out across the codebase; their load-bearing claims were then **verified against the actual
code** before any fix. Work proceeded in four phased units, each with its own verification gate and
a hard rule: *if `reconcile`/`golden` ever fail, stop and revert.* A clean baseline build confirmed
**zero drift** between `frontend/src` and the committed `webapp/static/` before editing.

### Headline
The app is **fundamentally solid**: parameterized SQL throughout, realpath path-traversal jail,
read-only `immutable` DB, central HTML escaping, localhost-only bind, **zero outbound calls / no
telemetry** (the offline-sovereign promise holds), and version strings + `db_sha256` already in
sync. This was a **polish-and-harden** pass, not a rescue.

### Audit accuracy note (findings corrected, not taken at face value)
Several initially-flagged "gaps" were **already handled** and were *not* re-done:
- Modal **focus trap**, Esc-to-close, focus save/restore — already present (`panel.ts:88–99`).
- Search mode chips already have full ARIA `radio` + arrow-key roving tabindex (`search.ts:16–26`).
- Theme-network nodes already keyboard-operable (`tabindex/role/aria-label/Enter/focus`, `analytics.ts:89–100`).
- `.t` transliteration hidden via `display:none` (already removed from the a11y tree).
- Skip-to-content link + a global `<h1>` already exist (`Base.astro:30,34`).
- The Trail dead-end already has a recovery action + breadcrumb back-nav (`trail.ts:98–102`).
- The "CRITICAL SQL injection" was **overstated** → parameterized; real impact was an HTTP 500 (below).

---

## 2. Findings & resolution

| # | Sev | Area | Finding | Status |
|---|-----|------|---------|--------|
| 1 | High | Robustness | `/api/verify?q=` with `"`/`*`/`(` → malformed FTS5 → **HTTP 500** leaking `OperationalError: unterminated string`. Latent twin: vowel-stripped translit tokens could form an empty `OR` → 500. | **Fixed** |
| 2 | Med | Info-leak | 500 responses returned the exception **type + message** to the client. | **Fixed** |
| 3 | Med | Validation | `/api/themes/network?min_ppmi=nan`/`inf` slipped past `max(min())` (NaN compares false) → silently empty graph. | **Fixed** |
| 4 | Low | Hardening | No `X-Content-Type-Options`/`X-Frame-Options`/`Referrer-Policy`. | **Fixed** |
| 5 | High | A11y | `<html lang="pa">` mis-marked the **entire English UI** as Punjabi; Gurmukhi verses untagged. | **Fixed** |
| 6 | Med | A11y | Pinch-zoom disabled by viewport; D3 charts ignored OS **reduce-motion**; flagship chart had no text alternative. | **Fixed** |
| 7 | Med | A11y | Pin touch target 28px; saroop-toggle label unclear. | **Fixed** |
| 8 | Med | UX | Thin search empty-state; no styled 404 page. | **Fixed** |
| 9 | Low | Hygiene | `webapp/static/_cmp/` stray dev artifacts untracked/unignored; `Validation-Report.md` stale (v1.5.0); `MASTER-INDEX` theme count stale (53). | **Fixed** |

### What each fix actually does
- **#1** `verify.py`: each FTS token is sanitised (`"`/`*` stripped) and wrapped as a **quoted
  literal** so any embedded operator is inert; empty tokens are dropped; a central guard in
  `_fts_query` never issues an empty/invalid `MATCH`. Quoting plain words does **not** change match
  semantics (verify never uses prefix `*`) — search results are unchanged (proven by golden diff).
- **#2** generic `{"error":"internal server error"}` to the wire; full traceback still on stderr.
- **#3** `try float → math.isfinite → clamp [0,1]`.
- **#4** three headers added to every response path (`_respond`/`_serve_static`/`_static_error`).
- **#5** `<html lang="en">` + `lang="pa"` on the real Gurmukhi verse containers (reader/search/panel/trail).
- **#6** `maximum-scale=5, user-scalable=yes`; `prefersReducedMotion()` gate — force layout settles
  **synchronously** (no animation) and chord transitions become instant when reduce-motion is set;
  a `<details>` **data-table** (top-50 theme co-occurrences, escaped) sits under the network chart.
- **#7** pin 28→36px (echo 26→32px); explicit saroop `aria-label`.
- **#8** empty-state echoes the (escaped) query + suggested themes + Index link; `404.astro` built
  and served by `serve.py` for unknown paths.
- **#9** `_cmp/` git-ignored; Validation-Report banner; MASTER-INDEX 53→54.

#### Notable bug caught *during* implementation
The data-table threw `e.split is not a function` at runtime: `d3.forceLink` **mutates** edge
`source`/`target` from string ids to node objects once the simulation runs, so `titleCase(edge.source)`
received an object. Fixed by normalising (`typeof x==='string' ? x : x.id`). Caught via a headless
browser smoke test, root-caused from the console, fixed, and re-verified — it would not have shown
up in a static review.

---

## 3. Deferred (recommended, not auto-applied — risk/judgment)

- **Full D3 keyboard nav** of edges/ribbons/streamgraph — the data-table covers the WCAG need at far
  lower risk; full edge-traversal is a large rewrite.
- **Strict Content-Security-Policy** — the UI relies on inline `onclick`/`onchange` + an inline
  pre-paint theme script; a strict CSP breaks them without a nonce/refactor pipeline.
- **`analytics.js` ≈ 265 KB (full D3 + Chart.js)** — code-splitting by chart is worthwhile but
  carries visual-regression risk on the charts; do as a focused, separately-verified pass.
- **gzip in the stdlib server** — negligible value on localhost.
- **Design-token consolidation** (spacing/type scale, button hierarchy) — broad restyle churn.
- **Scripture-text review items** (per `docs/engineering/known-issues.md`): empty `translit_norm` id 35328 / Ang 829; the
  `ਓ ੁ` & isolated-matra rows (~695–699, 1354/1358/1387). **Text layer — left to a Granthi/scholar; never auto-edited.**

---

## 4. Verification evidence

| Gate | Result |
|------|--------|
| `pipeline/reconcile.py` (char-exact corpus vs PDF) | **RECONCILED — 1,643,385 == 1,643,385** |
| `pipeline/golden_test.py` | **ALL GOLDEN TESTS PASS** |
| `/api/health` | `ok:true`, all 6 checks true |
| Search regression (5 modes vs pre-change golden) | **0 diffs** |
| `/api/verify` crafted `"` / `* ` / `( ` / `***` | **200** (was 500); empty → 400 |
| `min_ppmi=nan`/`inf` | **200 with full edge set** (was empty) |
| Security headers (`curl -I`) | nosniff · DENY · no-referrer present |
| Runtime (headless): analytics charts + data-table | 51 nodes / 468 links / radar; table 50 rows |
| Runtime: reader `lang`, search empty-state, 404 | `html=en`, verse `lang=pa`; rich empty-state; styled 404 |
| Scripture/DB guard (`git diff -- corpus db`) | **empty (untouched)** |

**Files changed:** `webapp/serve.py`, `webapp/verify.py`, `frontend/src/{layouts/Base.astro,
styles/global.css, scripts/{core,reader,search,panel,trail,analytics}.ts}`, new
`frontend/src/pages/404.astro`, regenerated `webapp/static/`, and docs (`MANIFEST.json`, `README.md`,
`MASTER-INDEX.md`, `CHANGELOG.md`, `Validation-Report.md`, `.gitignore`). **No** `corpus/` or `db/` file changed.
