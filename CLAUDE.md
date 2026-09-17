# CLAUDE.md — SGGS Knowledge Base

Guidance for AI agents (and humans) working in this repository.

---

## ⚠️ Prime directive: this is sacred scripture — never alter the text

This project is a knowledge base of **Sri Guru Granth Sahib Ji**, the living Guru of the Sikhs. Textual fidelity is the single most important rule and overrides everything else here.

- **Never edit, "correct," paraphrase, normalize, reorder, translate-in-place, or guess at any Gurmukhi text** in `corpus/sggs.jsonl`, `db/sggs.sqlite`, or `corpus/by-raag/`.
- If something in the scripture looks wrong, **flag it for human review — do not change it.** Add a note; never a "fix."
- The corpus is **verbatim** from the source PDF and is **proven char-for-char** by `pipeline/reconcile.py`. The only sanctioned text transforms are (a) PDF **visual→logical Unicode reordering** of the sihari (e.g. `ਿਕ੍ਰਪਾ → ਕ੍ਰਿਪਾ`) and (b) **3 logged** editorial Unicode-repair corrections (Angs 573, 586, 727) where the source font emitted impossible sequences. Any new transform must be logged the same way and reviewed.
- English translations are a **separate, labelled layer** (Dr. Sant Singh Khalsa via BaniDB/ShabadOS) — never blend them into the Gurmukhi, and never present a translation as the original.
- When answering Gurbani questions, follow `Answer-Protocol.md`: quote **verbatim**, cite the **Ang**, and clearly label any explanation as explanation.

---

## What this is

An **offline, "sovereign," zero-dependency** study app over the full Granth (Angs 1–1430). A reproducible pipeline extracts the PDF into a corpus, builds a SQLite/FTS5 database, and a Python stdlib server serves a prebuilt Astro multi-page UI (search, reader, themes, lineage, study trail, concept constellation, insights).

- **Current build:** `APP_VERSION = 1.1.3`, `APP_BUILT = 2026-09-17` (see `webapp/serve.py`). The traditional-saroop display toggle is **default-ON** as of v2.10.1 (reader can switch to verbatim).
- **Corpus:** 60,658 line records · 1,430 Angs · FTS5 full-text.
- **Source of record:** the user's `Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf` (1,483 pp), which lives **one level above this repo** (`../`), not inside it.

---

## Brand & domains (product identity — read before touching names/URLs)

Endorsed-brand architecture, set 2026-09-17 ahead of the first public TestFlight/App Store release:

- **Company:** **Algorythmos Pty Ltd** — the Australian legal entity that owns the IP, the Apple/Google developer accounts, and the infrastructure. Credited as an *endorsed brand* ("Built by Algorythmos"). Its strongest trademark asset is the coined word **"Algorythmos"** itself.
- **Consumer app (iOS/Android):** **Gurbani Soul** — the product users download. This is the App Store **Name**, the iOS on-device label (`CFBundleDisplayName`/`CFBundleName` = `Gurbani Soul`), the widget-group name, and the About-screen title. Positioning leads with **trust** ("verbatim, cited by Ang, never AI-invented"), not "AI".
- **Website / Knowledge Base (this repo):** stays **"Sri Guru Granth Sahib Ji — Knowledge Base"** — a *distinct, scholarly property* from the consumer app. Its page titles/header use the full scripture name. Do **not** rename the KB site to "Gurbani Soul".
- **Scripture citations, everywhere (web + app):** always the full **"Sri Guru Granth Sahib Ji · Ang N"**. "Gurbani Soul" names the *app*, never the *text*. Keep this separation.
- **Product domain:** **`gurbanisoul.com`** — registered 2026-09-17 at **Hostinger** (registrar), **2-year term, auto-renew on, WHOIS privacy on**. DNS is delegated to **Cloudflare** (account label *"Company-Domains"*), nameservers `jamie.ns.cloudflare.com` / `luke.ns.cloudflare.com`. The Cloudflare **Zone ID / Account ID live in the Cloudflare dashboard, not in this repo** — never paste them (or any API token) into tracked files.
  - Planned layout: `gurbanisoul.com` (marketing) · `docs.gurbanisoul.com` (sources / translation methodology / AI-safety — helps App Store review) · `api.gurbanisoul.com` (backend, on Algorythmos infra) · `www` redirect. Support/Privacy are **paths** on the apex (`/support`, `/privacy`), so one domain satisfies Apple's URL fields.
  - `.app` / `.ai` are optional **defensive** buys for later, not on the launch path. Until `gurbanisoul.com` is live, the App Store listing uses the existing KB URLs as interim Support/Privacy targets (see `docs/ios/app-store-listing.md`).
- **Availability caveats that were verified (Sep 2026, non-authoritative — re-check before spend):** no App Store/Play app named "Gurbani Soul" and no matching company/trademark found. Trademark note: "Gurbani AI" would be descriptive→generic and weak; **India has a religious-susceptibilities bar (TM Act s.9(2)(b))** on Sikh/scriptural terms plus active Akal Takht scrutiny of AI-Gurbani tools — file logos/composites, prioritise protecting "Algorythmos", and get professional clearance in AU/US/India before filing.
- **Visual identity (iOS app) — governed by `docs/brand/gurbani-soul-brand-book.md`** (set 2026-09-18). `docs/brand/tokens.json` is the palette source of truth; `python3 scripts/brand/contrast_report.py` must exit 0 after any colour change. Default accent is **Soul Gold** (`AccentPalette.brandDefault`). The literal brand gold `#FFBC0D` is **`accentFill` only** (prominent fills, always with an `accent` border) — it is 1.69:1 on white, so never use it for text, icons, tint or links; use `accent` / `accentText`. Brand red `#DA291C` is fill-only (badges), never text and never beside Gurmukhi. Headings use **Source Serif 4** via `Brand.heading` (navigation titles + hero lines only); Gurmukhi is always ink-coloured Sant Lipi. Dark mode is warm ink everywhere — new List screens use `inkGroupedList()`/`inkPlainList()`/`inkRow()`. **Never** make a gold mark on a red square (another company's trade dress). Gates G3 (scholar) and G4 (legal) are open before App Store submission. The website keeps its own theme.
- **Internal identifiers are unchanged and must stay so:** bundle ids `org.sggs.*`, App Group `group.org.sggs`, URL scheme `sggs://`, Xcode targets, npm `sggs-frontend`, the DB filename, and the SKU `sggs-ios`. The brand is a display layer; none of these track it.

---

## Run it

```bash
# easiest: double-click  "Start SGGS App.command"
cd webapp && python3 serve.py        # stdlib only; no pip install needed
# → http://localhost:7777   (override port with SGGS_PORT)
```

The server needs `db/sggs.sqlite` to exist. That DB is **~104 MiB (109 MB) and tracked via Git LFS** — run `git lfs pull` after cloning or the app won't start.

## Rebuild from the PDF

```bash
bash pipeline/rebuild_all.sh [path-to-source-pdf]   # default: ../Siri-Guru-...pdf
```

This gates on `reconcile.py` (must be char-exact) and `golden_test.py`, then builds the base DB + search/variants/English **and** (as of 2026-06-19) the Insight-Engine tables — `rebuild_all.sh` now runs `ml_analytics_builder.py`, `build_semantic_vectors_lite.py`, `build_resonance.py`, and `build_vaars.py`, so a fresh rebuild populates Insights / Lineage / Trail / Constellation / Vaar. (`build_semantic_vectors_lite.py` ships **exact sparse TF-IDF cosine** for `line_neighbors` — header-excluded, verbatim-twin de-duplicated, 0.30 min-cosine floor, true-cosine scores [`source='tfidf-exact-cosine-lite'`, 2026-06-19]; it needs **scipy** at build time. Full MiniLM line embeddings remain a separate upgrade. The Trail/Reader surface neighbour scores as calibrated *relatedness bands*, not a raw %.)

`pipeline/build_db.py` now stamps `meta.version` from `webapp/serve.py:APP_VERSION` (no longer hardcoded `'1.4.0'`), and the install step re-syncs `MANIFEST.json` `version`/`db_sha256` to the freshly built DB. (Validated 2026-06-19 by a full `rebuild_all.sh` run: reconcile char-exact, golden all-pass, `enrich_v2` applied, vaars=22 / vaar_units=1423, additive-integrity OK.)

**Toolchain:** `serve.py` = Python 3 stdlib only. The pipeline needs **PyMuPDF** (`import fitz`); the lite semantic builder also needs **numpy + scipy**. The UI source is in `frontend/` (Astro + Tailwind v4, Node); its build output is synced into `webapp/static/`. `node_modules/`, `dist/`, and `webapp/static.bak/` are git-ignored.

---

## Repository map

```
corpus/sggs.jsonl          # machine-readable corpus (verbatim) — the data source of truth
corpus/by-raag/*.md        # human-readable, one file per raag/bani (generated)
db/sggs.sqlite             # SQLite + FTS5 (Git LFS); opened READ-ONLY by the app
pipeline/                  # PDF → corpus → DB + enrichment + tests
  sggs_pipeline.py         #   parse, fix_text (visual→logical), translit, roman_norm
  build_corpus.py          #   PDF (pages 54–1483) → Angs 1–1430 → sggs.jsonl
  reconcile.py             #   PROVES corpus == PDF, character for character
  golden_test.py           #   canonical structural checks (gate)
  build_db.py              #   jsonl → base SQLite + FTS5 + by-raag markdown
  build_variants.py / enrich_*  # phonetic search variant index
  *_harness.py             #   roundtrip / casual-quote / chaos search harnesses
  rebuild_all.sh           #   one-command rebuild: PDF → corpus → full DB incl. analytics/vaars
  bhatt_attribution.json   #   per-Bhatt Swaiyye attribution (signature evidence)
webapp/serve.py            # stdlib HTTP server + JSON API (read end-to-end before editing)
webapp/verify.py           # quotation-verification engine (Layer 3)
webapp/static/             # prebuilt Astro MPA (served); static.bak/ = local backup, ignore
frontend/                  # Astro UI source (build → static/)
validation/                # audit_*, qa_angs_*, e2e/canonical/external, concepts_*.json
MANIFEST.json CHANGELOG.md README.md Answer-Protocol.md  # docs (NOTE: several lag the code)
```

---

## Data model (`lines` table / JSONL record)

Each record is one display line:

`id` · `ang` (1–1430) · `pdf_page` · `raag` · `section` (bani) · `author` · `comp_type` · `ghar` · `comp_id` (groups a shabad/unit) · `line_no` · `is_rahao` · `is_header` · `markers` (e.g. `॥੧॥`) · `gurmukhi` (verbatim, with dandas) · `text` (clean) · `translit` · `translit_norm` (phonetic fold, **DB-built**, not in JSONL) · `fl_g`/`fl_r` (first letters, Gurmukhi/roman) · `skeleton` (matra-stripped).

DB also has: `fts`/`fts_en`/`fts_shabad`/`fts_tri`, `translations`, `variants`, `canon_tokens`, `raags`/`sections`/`authors`, `concepts`/`concept_lines`, `word_freq`, analytics (`*_analytics`, `theme_network`, `theme_fingerprint`, `author_resonance`, `vaars`/`vaar_units`, `*_neighbors`), `meta`.

---

## API quick reference (`webapp/serve.py`)

`/api/search?q=&mode=&limit=&offset=` (modes: `auto`,`gurmukhi`,`roman`,`english`,`first`,`theme`) · `/api/ang/{1..1430}` · `/api/shabad/{comp_id}` · `/api/random` (complete Hukam unit) · `/api/verify?q=&ang=` · `/api/word?w=` · `/api/meta` · `/api/health` · `/api/themes/network` · `/api/analytics/{author,raag,progression,resonance,vaars,vaar,constellation}` · `/api/related` · `/api/line_concepts` · `/api/neighbors`.

`/api/health` is the fast integrity check (asserts 60,658 lines, 1,430 distinct Angs, FTS works, verbatim Mool Mantar, ≥560 `ੴ`, live verify). Use it after any DB change.

---

## Versioning convention (important)

- **`APP_VERSION` in `webapp/serve.py` is the source of truth** for the running build. Bump it on every search-logic/UI release.
- The UI footer reads `/api/meta → meta.version`, which returns `APP_VERSION`. The DB's own build version is returned separately as `db_version` and is **not** shown in the UI. This decoupling is intentional: a search-only patch shouldn't force a re-commit of the ~104 MiB LFS DB.
- Keep `MANIFEST.json`, `README.md`, `CHANGELOG.md`, and `MASTER-INDEX.md` in step when you bump (synced to 1.1.0 on 2026-09-15).

---

## Conventions & gotchas (don't break these)

- **`roman_norm` is duplicated** in `webapp/serve.py` and `pipeline/sggs_pipeline.py` and **must stay byte-identical** — the query-time fold has to match the indexed fold or search silently breaks. Edit both together.
- **Search is a deliberate waterfall** (exact FTS → seeker lexicon → variant index → English → cross-line passage → skeleton-blob), BM25-ranked with weighted columns. Don't reorder tiers or change weights without re-running the harnesses; small changes shift ranking corpus-wide.
- **DB is opened `mode=ro&immutable=1` + `query_only`.** The app must never write. All writes happen in the pipeline.
- **Security invariants to preserve:** FTS column allowlist + `_fts_clean` (strip `"`/`*`); parameterized SQL everywhere; realpath path-traversal jail in `_resolve_static`; central HTML-escape helper in the front-end (all scripture/API text is escaped before `innerHTML`). Don't introduce string-built SQL or unescaped `innerHTML`.
- **Vaar attribution:** a Vaar's **pauris** take the Vaar's author (`vaar_author`) even though the interleaved **saloks** carry other Gurus' `ਮਃ` headers. Detect the 22 Vaars by **title headers** (`ਵਾਰ` + `ਕੀ`/`ਧੁਨੀ`), not by pauri-run structure (structural detection over-/under-counts).
- **Raag spans** are computed as the longest contiguous run where a raag is the Ang's majority — liturgical occurrences elsewhere must not drag a raag's start. After `POST_RAAG_ANG = 1353` the Granth leaves the raag framework (saloks, swaiyye, Mundavani, Raagmala); raag is cleared and sections are header-detected.
- **`comp_id` groups a whole composition, heading run included.** A run of consecutive heading lines (a raag/title line, the ੴ invocation, a `ਸਲੋਕੁ ਮਃ` label) shares the `comp_id` of the composition it opens (fixed v1.1.0, `build_corpus.py` post-pass 1b) so `/api/shabad/{comp_id}` and the iOS `fetchShabad` return the printed heading. The run adopts its **last** heading's id, so **no body line's `comp_id` ever changes** and the vacated ids become **permanent gaps** (distinct comps 4,706; `max(comp_id)` 5,380; `comp_id` 1 is a gap — the Mool Mantar folds into Japji, `comp_id` 2). Three closing rubrics (`ਜੁਮਲਾ`, `ਦੁਤੁਕੇ`, `ਏਹੁ ਸਲੋਕੁ ਆਦਿ ਅੰਤਿ ਪੜਣਾ` — `TRAILING_RUBRICS`) belong to the *preceding* unit and stay one-line comps, flagged for scholarly review. Any rebuild that touches the corpus must pass `pipeline/verify_regroup.py` (only `comp_id`/`line_no` may change; scripture byte-identical).
- **Deploys are CI-gated (v1.1.1+).** Production is deployed only by `.github/workflows/deploy-production.yml` after every required check on the exact SHA passes (Render hook `ref=SHA` → `/api/health.commit` must equal the SHA → web built unaliased + `@smoke` → promote → public smoke → tag). Never deploy by hand from a dirty tree; never tag before a verified deploy. Release PRs `integration→main` are **merge commits**. See `docs/process/runbooks/deploy.md`.
- **`comp_type` is known-mislabeled** in places (Japji tagged `ਰੁਤੀ/ਵਾਰ`; many shabads tagged `ਪਉੜੀ`); it's suppressed at the display layer. Don't rely on it for logic; prefer `comp_id`/`section`.
- **Japji (385 lines) has `author = null`** (the print has no per-line `ਮਹਲਾ`), so author filters for Guru Nanak miss Japji. Known/deferred.
- **`corpus/by-raag/` is regenerated but the directory is not cleared first** — stale files from a prior run can linger (two numbering schemes currently coexist). Clear before regenerating.
- **`db/sggs.sqlite` is Git LFS.** Don't commit it as a plain blob; don't bloat the repo with `node_modules`/`dist` (they're git-ignored — keep it that way).

---

## Delivery SOP — how work reaches users (read before shipping)
**Environments:** `integration` = trunk → auto-deploys **staging** (`sggs-staging.vercel.app`, API `sggs-api-staging.onrender.com`, SSO-protected). `main` = **production** (`sggs-knowledge-base.vercel.app`, API `…onrender.com`). Both deploy **only** through CI (`deploy-staging.yml` / `deploy-production.yml`); the platforms' own git auto-deploys are OFF and Render auto-deploy is OFF. Never deploy by hand except a documented pipeline-outage hotfix.

**The loop (use the skills below; do not improvise it):**
1. **Ship** (`sggs-ship`): branch from `integration` (`fix/…`, `feat/…`), run local gates, open a PR into `integration`, watch CI green. Corpus/DB change? Use **sggs-rebuild-db** first (scripture proofs). You cannot merge — hand the user the exact `--admin` command (one line, no comments).
2. The user merges → the push auto-deploys **staging**. Review on `sggs-staging.vercel.app` (open logged in to Vercel).
3. **Release** (`sggs-release`): preflight → PR `integration→main` as a **merge commit** (never squash — `main` must stay a descendant of `integration`) → the merge runs the gated production deploy → verify with **sggs-verify-prod** and confirm the `vX.Y.Z` tag.

**Invariants:** a deploy is verified by the running **commit** (`/api/health.commit`), not just the version. The release tag is cut only after a verified deploy. Secrets live in GitHub Environments (`production`/`staging`) — never type or echo a value; if one is pasted into chat, treat it as leaked and have the user rotate it. Full detail: `docs/process/runbooks/deploy.md`, `docs/process/branching.md`, ADR-0005.

## Delivery skills (`.claude/skills/`)
Use these instead of improvising the flow — they bundle tested scripts and the gotchas learned shipping v1.1.x:
- **sggs-ship** — branch → local gates → PR into `integration` → watch CI → hand the user the merge command.
- **sggs-release** — preflight → release PR `integration→main` (merge commit) → watch `deploy-production` gate by gate → verify → tag.
- **sggs-verify-prod** — prove what production serves (commit identity, health, Ang 712 heading, Vercel deployment).
- **sggs-rebuild-db** — scripture-safe corpus/DB rebuild with byte-level diff, re-baseline, guard, contract, iOS DBs.

## iOS TestFlight / App Store (2026-09-16: TestFlight approved)
Plan and gates live in `docs/ios/` (`testflight-launch-plan.md`, `testflight-test-plan.md`, `app-store-listing.md`). Build candidates **only** with `make testflight TEAM_ID=… BUILD=N` (`ios/tools/testflight_archive.sh`) or the manual `ios-testflight.yml` workflow: both derive the DB profile, run `check_release_license.sh` on the exact artifact, and prove the DB hash inside the archived `.app`. Default profile is **`public`** (Gurmukhi-only) because the English layer is `LICENSED: false`; never hand-edit `project.yml`'s team/build for an upload. Every build gets the scripture-fidelity charter (Charter S) signed before testers see it. **Build numbers** are per marketing version and monotonic: `CURRENT_PROJECT_VERSION` stays at the floor `1`, each upload passes `BUILD=N` (`make testflight-next` prints the next), and the archive script gates + records it in the tracked ledger `ios/testflight-builds.json` (`ios/tools/testflight_ledger.py`) — commit the ledger with the release. The About-screen UI test reads the built version from the test bundle's Info.plist, never a hardcoded literal, and `check_versions.py` enforces both invariants.

## Verify your changes

- Data/DB change → `python3 webapp/serve.py` then check `http://localhost:7777/api/health` (all checks `true`), and re-run `pipeline/reconcile.py` + `pipeline/golden_test.py`.
- Search change → run the harnesses in `pipeline/` (`roundtrip_harness.py`, `casual_quote_harness.py`, `chaos_harness.py`) and confirm no regressions.
- Never mark scripture-touching work "done" without a human reviewing any text-level diff.

---

## Current state / known issues

See **`../SGGS-KnowledgeBase-Audit-2026-06-16.md`** (static audit) and **`../SGGS-Live-Verification-2026-06-19.md`** (live pass). As of the 2026-06-19 live verification, scripture integrity is **proven** (reconcile char-exact, golden all-pass, 1,430 Angs gap-free, 60,658 lines), the footer/version bug is fixed, and the **Ang 1256 "duplicate" is a confirmed legitimate refrain — do NOT de-duplicate it.** Released through **v2.9.3** (2026-06-19): `MANIFEST.json` re-certified against the shipped DB; `APP_VERSION`/`version` synced to 2.9.3 across serve.py/README/MASTER-INDEX/MANIFEST/CHANGELOG; `build_db.py` version no longer hardcoded; `rebuild_all.sh` now builds the analytics/vaar/semantic tables — **validated by a full green rebuild on 2026-06-19** (reconcile char-exact, golden all-pass, vaars=22). **v2.9.3** fixes the Concept Constellation hang on large concepts by adding a `concept_lines(line_id)` index — all 8 tabs and the full ML/analytics layer (theme network, stylometry, resonance, raag streamgraph, Vaars, semantic neighbors) verified live in-browser. Still open: `Validation-Report.md` lags, analytics-chart accessibility (mouse-only D3 charts), one line with empty `translit_norm` (id 35328, Ang 829 — fixes on next rebuild), and the source-faithful `ਓ ੁ`/isolated-matra rows (Angs ~695–699, 1354/1358/1387) flagged for scholarly review. **v2.9.4** (2026-06-19) adds the Lineage ("The Contributors") redesign, plain-language Insights captions, and the Semantic Trail accuracy+UX upgrade — `line_neighbors` rebuilt as **exact sparse-cosine** (header-excluded, verbatim-twin-deduped, 0.30 floor, true-cosine scores; `source='tfidf-exact-cosine-lite'`, needs scipy at build) with relatedness-band UX, Ang-labeled breadcrumb, current-verse pin/copy, and a fixed dead-end state; `MANIFEST.db_sha256` re-certified to the rebuilt DB (`4d00e571…`). Scripture byte-identical (analytics/UI layers only). **v2.9.5** (2026-06-19) — audit-driven Insights accuracy (`../SGGS-Insights-Audit-2026-06-19.md`): theme-tag curation (`kaam`/`moh` tightened, `simran`/`krodh` widened, **`akal_kaal` split into `akal`+`kaal`** → concepts 53→54), `author_resonance` refreshed against the v2.9.4 neighbors, full-edge theme-network render (opens at min-PPMI 0.7, slider reveals all ~1,255), and a hardened `build_shabad_neighbors` matmul (`np.errstate`+`nan_to_num`). PPMI/Jaccard recompute re-confirmed exact (0 mismatches); SME-graded tag changes (zero regressions). `MANIFEST.db_sha256` → `cde0baa6…`. Scripture byte-identical. **v2.10.0** (2026-06-20) bundles the **Sant Lipi** Gurmukhi webfont (SIL OFL 1.1, 27.8 KB variable WOFF2 at `frontend/public/fonts/`; `@font-face` + prepended to `--font-gm` in `global.css`, `unicode-range`-scoped to the Gurmukhi block; license at `/fonts/OFL.txt`) so the Granth renders identically on every device, plus a **"traditional saroop" toggle** (header **ਯ** `#saroopBtn`; `frontend/src/scripts/saroop.ts`) — **default-ON since v2.10.1** (reader can toggle to verbatim; an explicit choice is stored in `localStorage` and respected) that collapses the doubled subjoined-ya `੍ਯ੍ਯ`/single `੍ਯ` to Sant Lipi's tucked addha-yayya. **Display-only**: the Variation-Selector markup is injected into rendered glyphs *only* — the corpus, DB, API, FTS search, and Copy-verse stay verbatim, and a `copy`-event interceptor strips the selectors from selected text. `db_sha256` unchanged (`cde0baa6…`), corpus unchanged — UI/presentation layer only, no DB rebuild. **Do not** route the saroop markup into stored text, search, or `/api`. **v2.10.1** (2026-06-20) makes saroop the **default** rendering: `init()` applies it via `reflect()` **without** writing `localStorage`, so the default only applies to readers who never toggled, while an explicit choice (`sggs_saroop` = `'0'`/`'1'`) is stored and respected. To change the default, flip `let ON` in `saroop.ts`. **Fidelity caveat** (verified by direct PDF comparison at Ang 1400 — `ਜਲ੍ਯ੍ਯਨ`, `ਧਰ੍ਯ੍ਯਉ`): the text stays verbatim and the saroop fixes the ya *count* (doubled→one), but Sant Lipi draws that ya **inline, after** the consonant, whereas the source printed Bir tucks it as a **deep subscript under** the consonant (so `ਜਲ੍ਯ੍ਯਨ` prints like *ਜਲੂਨ*) — so it is **NOT** a pixel match to that Bir. Sant Lipi's inline addha-yayya is the accepted Shabad-OS / Sikh-tech standard (a legitimate but *different* typographic tradition); the exact deep-subscript pairin-ya exists only in **license-blocked** fonts (Gurbani Akhar / K. Thind, all-rights-reserved) — an exact match would require written permission for those or a commissioned OFL font. Pending a Granthi/scholar's review. See `../SGGS-Gurmukhi-Display-Font-Plan-2026-06-20.md`. **v2.11.0** (2026-06-26) is an "Apple-grade" hardening + accessibility pass (display/server/docs only; scripture byte-identical, no DB rebuild, `db_sha256` unchanged `cde0baa6…`) — see `SGGS-Apple-Grade-Audit-2026-06-26.md`. Highlights: `verify.py` FTS tokens are now sanitised+quoted with a central empty-`MATCH` guard (fixes a crafted-`"`/`*` `/api/verify` **HTTP 500** that also leaked the exception type — 500s now return a generic body), `min_ppmi` clamped with `math.isfinite`, and `nosniff`/`X-Frame-Options: DENY`/`Referrer-Policy: no-referrer` on every response; a11y — `<html lang="en">` with `lang="pa"` on the Gurmukhi verse containers, pinch-zoom re-enabled, D3 charts honour `prefers-reduced-motion` (force layout settles synchronously) and the theme-network now ships a keyboard/screen-reader **data-table** alternative; UX — richer search empty-state + a styled `404.astro` served by `serve.py`; hygiene — `webapp/static/_cmp/` git-ignored, `Validation-Report.md` banner-flagged superseded, `MASTER-INDEX` theme count corrected 53→54. Re-verified: reconcile char-exact, golden all-pass, `/api/health` all-true, search byte-identical vs baseline. **v2.12.1 / iOS 1.1.1** (2026-09-05) — pre-TestFlight hardening pass (scripture byte-identical, no DB rebuild, `db_sha256` unchanged `b513da34…`; details in `CHANGELOG.md` and `SGGS-iOS-TestFlight-Readiness-2026-09-05.md`). New invariants to preserve: (1) **`webapp/romannorm.py` is now the single Roman fold** — `serve.py` re-exports it and `verify.py` imports it; it must stay byte-identical to `pipeline/sggs_pipeline.py:roman_norm` (the 24,719-vector `contract/golden_roman_norm` proves it); (2) every integer query parameter in `serve.py` goes through `_int()` (never a bare `int()`); (3) the Study-Trail pin reads verbatim text from `data-gm` (API model), **never** from rendered `.g` text (the saroop painter rewrites it) — `/api/lines?ids=` exists to repair old pins; (4) iOS: `AppContainer.sheetHosted` must be true before `present()` may enter the swap path (RootView sets it on TabView appear/disappear); the SwiftData ladder destroys the bookmarks store only on a **second** consecutive failure; `SavedLineSchemaV1` is the versioned schema — future model changes go in as a migration stage; (5) the iOS release gate accepts an English-bundled build only with `LICENSED: true` in `ios/Resources/TRANSLATION-LICENSE.md` (CI negative/positive-tests it with `SGGS_LICENSE_ATTESTATION`). Load-bearing XCUITest strings are listed in the plan/readiness report — change UI copy with the suite open. **v1.0.0** (2026-09-06) resets iOS/web/API version strings to a unified baseline ahead of the first public TestFlight/production release — metadata/docs only, no code, corpus, or DB change; `git diff -- corpus db` empty.
```
