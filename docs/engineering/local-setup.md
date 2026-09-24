# Local setup, repository map & API

Running, rebuilding and navigating the project on a developer machine.

## What this is

An **offline, "sovereign," zero-dependency** study app over the full Granth (Angs 1–1430). A reproducible pipeline extracts the PDF into a corpus, builds a SQLite/FTS5 database, and a Python stdlib server serves a prebuilt Astro multi-page UI (search, reader, themes, lineage, study trail, concept constellation, insights).

- **Current build:** `APP_VERSION = 1.3.5`, `APP_BUILT = 2026-09-23` (see `webapp/serve.py`). The traditional-saroop display toggle is **default-ON** as of v2.10.1 (reader can switch to verbatim).
- **Corpus:** 60,658 line records · 1,430 Angs · FTS5 full-text.
- **Source of record:** the user's `Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf` (1,483 pp), which lives **one level above this repo** (`../`), not inside it.

## Run it

```bash
# easiest: double-click  "Start SGGS App.command"
cd webapp && python3 serve.py        # stdlib only; no pip install needed
# → http://localhost:7777   (override port with SGGS_PORT)
```

Run one service of the platform split from the same code with `SGGS_MODULES=search` (or any comma list of `reader,search,verify,insights,knowledge`; default `all`) and point it at its own database slice with `SGGS_DB=/path/slice.sqlite`. In split mode the server refuses to start unless the database holds every table the enabled contexts declare. `/healthz` (liveness) and `/readyz` (200 only when every declared table is present) are the platform health checks.

The server needs `db/sggs.sqlite` to exist. That DB is **~104 MiB (109 MB) and tracked via Git LFS** — run `git lfs pull` after cloning or the app won't start.

## Rebuild from the PDF

```bash
bash scripts/data/fetch_translations.sh            # private English inputs, checksum-verified
bash pipeline/rebuild_all.sh [path-to-source-pdf]   # default: ../Siri-Guru-...pdf
```

This gates on `reconcile.py` (must be char-exact) and `golden_test.py`, then builds the base DB + search/variants/English **and** (as of 2026-06-19) the Insight-Engine tables — `rebuild_all.sh` now runs `ml_analytics_builder.py`, `build_semantic_vectors_lite.py`, `build_resonance.py`, and `build_vaars.py`, so a fresh rebuild populates Insights / Lineage / Trail / Constellation / Vaar. (`build_semantic_vectors_lite.py` ships **exact sparse TF-IDF cosine** for `line_neighbors` — header-excluded, verbatim-twin de-duplicated, 0.30 min-cosine floor, true-cosine scores [`source='tfidf-exact-cosine-lite'`, 2026-06-19]; it needs **scipy** at build time. Full MiniLM line embeddings remain a separate upgrade. The Trail/Reader surface neighbour scores as calibrated *relatedness bands*, not a raw %.)

`pipeline/build_db.py` now stamps `meta.version` from `webapp/serve.py:APP_VERSION` (no longer hardcoded `'1.4.0'`), and the install step re-syncs `MANIFEST.json` `version`/`db_sha256` to the freshly built DB. (Validated 2026-06-19 by a full `rebuild_all.sh` run: reconcile char-exact, golden all-pass, `enrich_v2` applied, vaars=22 / vaar_units=1423, additive-integrity OK; **1,426 units since v1.1.4** — Malar Ki Vaar regained its 28th pauri.)

**Reproducible builds.** The rebuild is deterministic: every date written into the DB and
`MANIFEST.json` comes from `pipeline/build_clock.py`, pinned by `SOURCE_DATE_EPOCH` (defaults to
the HEAD commit time), set-ordered inserts are sorted, and neighbour rankings break score ties by
id. The same commit + PDF + toolchain produces identical content in every table. Prove it with
`python3 scripts/data/compare_builds.py A.sqlite B.sqlite` (uses the scripture guard's own
per-table hash; exit 0 only if all tables match). The source PDF must match
`validation/reconcile-attestation.json` (`SGGS_ALLOW_NEW_PDF=1` for a reviewed new edition).

**Toolchain:** `serve.py` = Python 3 stdlib only. The pipeline needs **PyMuPDF** (`import fitz`); the lite semantic builder also needs **numpy + scipy**. The UI source is in `frontend/` (Astro + Tailwind v4, Node); its build output is synced into `webapp/static/`. `node_modules/`, `dist/`, and `webapp/static.bak/` are git-ignored.

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
webapp/serve.py            # composition root: build identity, ROUTES table, HTTP layer, startup
webapp/sggs/               # bounded contexts: core (DB handle + shared state), search, reader,
                           #   verification, insights, knowledge — each becomes a service in the split
webapp/verify.py           # quotation-verification engine (Layer 3)
webapp/static/             # prebuilt Astro MPA (served); static.bak/ = local backup, ignore
frontend/                  # Astro UI source (build → static/)
validation/                # audit_*, qa_angs_*, e2e/canonical/external, concepts_*.json
MANIFEST.json CHANGELOG.md README.md Answer-Protocol.md  # docs (NOTE: several lag the code)
```

## API quick reference (`webapp/serve.py`)

`/api/search?q=&mode=&limit=&offset=` (modes: `auto`,`gurmukhi`,`roman`,`english`,`first`,`theme`) · `/api/ang/{1..1430}` · `/api/shabad/{comp_id}` · `/api/random` (complete Hukam unit) · `/api/verify?q=&ang=` · `/api/word?w=` · `/api/meta` · `/api/health` · `/api/themes/network` · `/api/analytics/{author,raag,progression,resonance,vaars,vaar,constellation}` · `/api/related` · `/api/line_concepts` · `/api/neighbors`.

`/api/health` is the fast integrity check (asserts 60,658 lines, 1,430 distinct Angs, FTS works, verbatim Mool Mantar, ≥560 `ੴ`, live verify). Use it after any DB change.

## iOS DB pair (local development)

The app bundles `ios/Resources/sggs-ios.sqlite` (**git-ignored**) + `sggs-ios.manifest.json` (**tracked**, personal profile) and fail-closes at launch — "Scripture integrity check failed", no tabs, XCUITests/unit tests red — whenever the DB does not hash to the manifest. The DB survives branch switches and is absent from a fresh worktree, so run **`make ios-db-check`** at session start, after any branch switch, and in every new worktree; **`make ios-db-repair`** rebuilds the personal DB (`make doctor` runs the check too). The check is read-only: a *FAIL* means the app is broken; a *WARN* means the pair is consistent but the manifest differs from HEAD — **never commit that manifest unless it is an intentional DB re-baseline** (`sggs-rebuild-db`). The committed `db_sha256` is reproduced by bare `python3` (Homebrew, SQLite 3.53.x); `/usr/bin/python3` (SQLite 3.51) yields different VACUUM bytes — a consistent pair, but a manifest diff you must not commit. Since 2026-09-19 `make testflight` is **side-effect-free**: it stages the public DB under `ios/App/build/stage-<ver>-<build>/`, generates a temporary `SGGS-TestFlight.xcodeproj` from a 3-line rewrite of `project.yml`, runs no tree-changing git command, and never reads or writes `ios/Resources/` (proved by `ios/tests/test_ios_archive.py`, including SIGKILL mid-build). `pipeline/build_ios_db.py` is atomic (builds + proves at `dest.tmp`, then `os.replace`). Never "fix" an integrity failure by editing the manifest, and never point a build at `ios/Resources` for a non-personal profile.
