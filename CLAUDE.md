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

- **Current build:** `APP_VERSION = 2.10.0`, `APP_BUILT = 2026-06-20` (see `webapp/serve.py`).
- **Corpus:** 60,658 line records · 1,430 Angs · FTS5 full-text.
- **Source of record:** the user's `Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf` (1,483 pp), which lives **one level above this repo** (`../`), not inside it.

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
- Keep `MANIFEST.json`, `README.md`, `CHANGELOG.md`, and `MASTER-INDEX.md` in step when you bump (synced to 2.10.0 on 2026-06-20).

---

## Conventions & gotchas (don't break these)

- **`roman_norm` is duplicated** in `webapp/serve.py` and `pipeline/sggs_pipeline.py` and **must stay byte-identical** — the query-time fold has to match the indexed fold or search silently breaks. Edit both together.
- **Search is a deliberate waterfall** (exact FTS → seeker lexicon → variant index → English → cross-line passage → skeleton-blob), BM25-ranked with weighted columns. Don't reorder tiers or change weights without re-running the harnesses; small changes shift ranking corpus-wide.
- **DB is opened `mode=ro&immutable=1` + `query_only`.** The app must never write. All writes happen in the pipeline.
- **Security invariants to preserve:** FTS column allowlist + `_fts_clean` (strip `"`/`*`); parameterized SQL everywhere; realpath path-traversal jail in `_resolve_static`; central HTML-escape helper in the front-end (all scripture/API text is escaped before `innerHTML`). Don't introduce string-built SQL or unescaped `innerHTML`.
- **Vaar attribution:** a Vaar's **pauris** take the Vaar's author (`vaar_author`) even though the interleaved **saloks** carry other Gurus' `ਮਃ` headers. Detect the 22 Vaars by **title headers** (`ਵਾਰ` + `ਕੀ`/`ਧੁਨੀ`), not by pauri-run structure (structural detection over-/under-counts).
- **Raag spans** are computed as the longest contiguous run where a raag is the Ang's majority — liturgical occurrences elsewhere must not drag a raag's start. After `POST_RAAG_ANG = 1353` the Granth leaves the raag framework (saloks, swaiyye, Mundavani, Raagmala); raag is cleared and sections are header-detected.
- **`comp_type` is known-mislabeled** in places (Japji tagged `ਰੁਤੀ/ਵਾਰ`; many shabads tagged `ਪਉੜੀ`); it's suppressed at the display layer. Don't rely on it for logic; prefer `comp_id`/`section`.
- **Japji (385 lines) has `author = null`** (the print has no per-line `ਮਹਲਾ`), so author filters for Guru Nanak miss Japji. Known/deferred.
- **`corpus/by-raag/` is regenerated but the directory is not cleared first** — stale files from a prior run can linger (two numbering schemes currently coexist). Clear before regenerating.
- **`db/sggs.sqlite` is Git LFS.** Don't commit it as a plain blob; don't bloat the repo with `node_modules`/`dist` (they're git-ignored — keep it that way).

---

## Verify your changes

- Data/DB change → `python3 webapp/serve.py` then check `http://localhost:7777/api/health` (all checks `true`), and re-run `pipeline/reconcile.py` + `pipeline/golden_test.py`.
- Search change → run the harnesses in `pipeline/` (`roundtrip_harness.py`, `casual_quote_harness.py`, `chaos_harness.py`) and confirm no regressions.
- Never mark scripture-touching work "done" without a human reviewing any text-level diff.

---

## Current state / known issues

See **`../SGGS-KnowledgeBase-Audit-2026-06-16.md`** (static audit) and **`../SGGS-Live-Verification-2026-06-19.md`** (live pass). As of the 2026-06-19 live verification, scripture integrity is **proven** (reconcile char-exact, golden all-pass, 1,430 Angs gap-free, 60,658 lines), the footer/version bug is fixed, and the **Ang 1256 "duplicate" is a confirmed legitimate refrain — do NOT de-duplicate it.** Released through **v2.9.3** (2026-06-19): `MANIFEST.json` re-certified against the shipped DB; `APP_VERSION`/`version` synced to 2.9.3 across serve.py/README/MASTER-INDEX/MANIFEST/CHANGELOG; `build_db.py` version no longer hardcoded; `rebuild_all.sh` now builds the analytics/vaar/semantic tables — **validated by a full green rebuild on 2026-06-19** (reconcile char-exact, golden all-pass, vaars=22). **v2.9.3** fixes the Concept Constellation hang on large concepts by adding a `concept_lines(line_id)` index — all 8 tabs and the full ML/analytics layer (theme network, stylometry, resonance, raag streamgraph, Vaars, semantic neighbors) verified live in-browser. Still open: `Validation-Report.md` lags, analytics-chart accessibility (mouse-only D3 charts), one line with empty `translit_norm` (id 35328, Ang 829 — fixes on next rebuild), and the source-faithful `ਓ ੁ`/isolated-matra rows (Angs ~695–699, 1354/1358/1387) flagged for scholarly review. **v2.9.4** (2026-06-19) adds the Lineage ("The Contributors") redesign, plain-language Insights captions, and the Semantic Trail accuracy+UX upgrade — `line_neighbors` rebuilt as **exact sparse-cosine** (header-excluded, verbatim-twin-deduped, 0.30 floor, true-cosine scores; `source='tfidf-exact-cosine-lite'`, needs scipy at build) with relatedness-band UX, Ang-labeled breadcrumb, current-verse pin/copy, and a fixed dead-end state; `MANIFEST.db_sha256` re-certified to the rebuilt DB (`4d00e571…`). Scripture byte-identical (analytics/UI layers only). **v2.9.5** (2026-06-19) — audit-driven Insights accuracy (`../SGGS-Insights-Audit-2026-06-19.md`): theme-tag curation (`kaam`/`moh` tightened, `simran`/`krodh` widened, **`akal_kaal` split into `akal`+`kaal`** → concepts 53→54), `author_resonance` refreshed against the v2.9.4 neighbors, full-edge theme-network render (opens at min-PPMI 0.7, slider reveals all ~1,255), and a hardened `build_shabad_neighbors` matmul (`np.errstate`+`nan_to_num`). PPMI/Jaccard recompute re-confirmed exact (0 mismatches); SME-graded tag changes (zero regressions). `MANIFEST.db_sha256` → `cde0baa6…`. Scripture byte-identical. **v2.10.0** (2026-06-20) bundles the **Sant Lipi** Gurmukhi webfont (SIL OFL 1.1, 27.8 KB variable WOFF2 at `frontend/public/fonts/`; `@font-face` + prepended to `--font-gm` in `global.css`, `unicode-range`-scoped to the Gurmukhi block; license at `/fonts/OFL.txt`) so the Granth renders identically on every device, plus an **opt-in, default-OFF "traditional saroop" toggle** (header **ਯ** `#saroopBtn`; `frontend/src/scripts/saroop.ts`) that collapses the doubled subjoined-ya `੍ਯ੍ਯ`/single `੍ਯ` to Sant Lipi's tucked addha-yayya. **Display-only**: the Variation-Selector markup is injected into rendered glyphs *only* — the corpus, DB, API, FTS search, and Copy-verse stay verbatim, and a `copy`-event interceptor strips the selectors from selected text. `db_sha256` unchanged (`cde0baa6…`), corpus unchanged — UI/presentation layer only, no DB rebuild. **Do not** route the saroop markup into stored text, search, or `/api`. Fidelity note: Sant Lipi's addha-yayya is the accepted Shabad-OS form (inline), not the deep subscript of some printed Birs — hence the toggle is opt-in pending a Granthi/scholar's review (`../SGGS-Gurmukhi-Display-Font-Plan-2026-06-20.md`).
```
