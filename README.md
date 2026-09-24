# ੴ Sri Guru Granth Sahib Ji — Knowledge Base & Study App

A **sovereign, verifiable Gurbani corpus** with a zero-dependency local web app. Built from a 1,483-page Unicode Gurmukhi edition of Sri Guru Granth Sahib Ji — every line verbatim, every line carrying its Ang, with a machine-verification engine so that no AI (or human) can misquote scripture unchecked.

One corpus powers two things people can use today:

- **The Knowledge Base** — the scholarly study website: search, reader, themes, lineage, insights and the raag clock. Live at **[gurbanisoul.com/search](https://gurbanisoul.com/search)** (and fully offline via `serve.py`).
- **Gurbani Soul** — the native iOS/iPadOS app (SwiftUI): the whole Granth verbatim and offline, Nitnem with gentle reminders, Hukam, the raag clock, widgets and a Live Activity. Its landing page is **[gurbanisoul.com](https://gurbanisoul.com)**. Built by **Algorythmos Pty Ltd**.

The website and the app keep separate names and identities on purpose — see [Brand & domains](docs/engineering/brand.md) and [`docs/website/README.md`](docs/website/README.md).

![version](https://img.shields.io/badge/version-1.3.6-1a3a6b)
![python](https://img.shields.io/badge/python-3.8%2B%20·%20stdlib%20only-3776ab)
![dependencies](https://img.shields.io/badge/dependencies-none-2e7d32)
![corpus](https://img.shields.io/badge/corpus-60%2C658%20lines%20·%201%2C430%20Angs-9a3412)
![license](https://img.shields.io/badge/repo-PRIVATE-b00020)

> **A note on reverence.** Scripture is shown verbatim with its Ang. Transliteration and English translations are *reading aids only*, always clearly labeled — never presented as the scripture itself. Please handle this corpus, and this app, with the respect Gurbani deserves.

---


> **Engineering wiki:** see [`docs/`](docs/README.md) — architecture & diagrams, scripture-integrity, branching, environments, CI gates, runbooks, ADRs.

## Table of contents

- [Why this exists](#why-this-exists)
- [Quick start](#quick-start)
- [The app](#the-app)
- [What's inside](#whats-inside)
- [The search engine](#the-search-engine)
- [API reference](#api-reference)
- [The verification engine](#the-verification-engine)
- [Data fidelity & provenance](#data-fidelity--provenance)
- [Architecture](#architecture-the-5-layers)
- [Repository layout](#repository-layout)
- [Validation & quality evidence](#validation--quality-evidence)
- [Rebuild from source](#rebuild-from-source)
- [Versioning](#versioning)
- [Governance — how an AI may use this corpus](#governance--how-an-ai-may-use-this-corpus)
- [Known limitations & roadmap](#known-limitations--roadmap)
- [License & attribution](#license--attribution)
- [Acknowledgements](#acknowledgements)

---

## Why this exists

Most digital Gurbani lives behind an API you can't audit, mixed with translations you can't separate from scripture, with no way to prove a quoted line is real. The risk is quiet corruption: a wrong matra, a hallucinated "quote," a translation silently treated as the original.

This project takes the opposite stance — **sovereign and verifiable**:

- **Sovereign** — it runs entirely on your machine. No cloud, no API keys, no installs. Python 3 standard library only. It works offline, forever.
- **Verifiable** — the corpus is reconciled character-for-character against the source edition, checksummed in `MANIFEST.json`, and every claimed quote can be machine-checked against the canonical text via `/api/verify`.
- **Honest about layers** — scripture, transliteration, and translation are stored and labeled separately. A translation is never returned as scripture.

The result is a corpus you can trust as a study base, a citation source, and a guardrail for any tool (LLM or otherwise) that needs to quote Gurbani without getting it wrong.

---

## Quick start

```bash
cd webapp && python3 serve.py     # or double-click "Start SGGS App.command" (macOS)
```

Opens **`http://localhost:7777`**. Python 3 standard library only — nothing to install.

Health check: open **`http://localhost:7777/api/health`** — it self-tests line count, Ang count, FTS, the Mool Mantar, the ੴ count, and the verify engine, and returns `"ok": true` when all pass.

---

## Where it runs (production)

The same offline app runs unchanged in the cloud. The browser only ever calls `/api/*`; the host rewrites those to the API, so there is no CORS and no client config.

```
                          Cloudflare DNS-only (CNAME → Vercel)
                                       │
                    ┌──────────────────┴───────────────────┐
   gurbanisoul.com (canonical apex, 200)      www + *.vercel.app (308 → apex)
                    │
     ┌──────────────┴───────────────┐
     │  Vercel — Astro static site   │   /            → Gurbani Soul landing
     │  (frontend/ → webapp/static/) │   /search /reader … → Knowledge Base
     └──────────────┬───────────────┘   /privacy /support  → policy (App Store URLs)
                    │  /api/*  (rewrite)
                    ▼
     ┌───────────────────────────────┐
     │  Render — stdlib Python API    │   webapp/serve.py, DB opened read-only
     │  (webapp/Dockerfile)           │   /api/search /ang /shabad /verify /health …
     └───────────────────────────────┘

     Gurbani Soul (iOS) — no network at all: the DB ships inside the app.
```

| | Local | Staging | Production |
|---|---|---|---|
| Web | `serve.py` :7777 | `sggs-staging.vercel.app` (SSO) | **`gurbanisoul.com`** |
| API | same process | `sggs-api-staging.onrender.com` | `sggs-knowledge-base.onrender.com` |
| Branch | working tree | `integration` | `main` |

**Delivery is CI-gated end to end** — no hand deploys. Branch → PR into `integration` → merge auto-deploys **staging** → release PR `integration → main` (merge commit) runs the gated production deploy, verified by the running **commit**, then a `vX.Y.Z` tag. Full topology, DNS and email: [`docs/website/README.md`](docs/website/README.md). Process and runbooks:

- [Environments](docs/process/environments.md) · [Branching](docs/process/branching.md) · [CI gates](docs/process/ci-gates.md) · [Release](docs/process/release.md)
- Runbooks: [deploy](docs/process/runbooks/deploy.md) · [rollback](docs/process/runbooks/rollback.md) · [rebuild-db](docs/process/runbooks/rebuild-db.md) · [app-store-submission](docs/process/runbooks/app-store-submission.md) · [ios-hotfix](docs/process/runbooks/ios-hotfix.md) · [support-inbox](docs/process/runbooks/support-inbox.md)
- Skills that run the loop: `sggs-ship`, `sggs-release`, `sggs-verify-prod`, `sggs-rebuild-db`.

---

## The app

Five views, all keyboard-friendly, with a labeled transliteration toggle, adjustable Gurmukhi font size, and automatic dark mode.

| View | What it does |
|------|--------------|
| **Search** | One box, many ways in — Gurmukhi, spelling-tolerant Roman, first-letters, English meaning, theme, or **Verify quote**. Results show the line, its transliteration, the labeled English, and metadata chips (Ang, Raag, author, ਰਹਾਉ). |
| **Reader** | Read any Ang (1–1430). Lines are grouped into shabads, ੴ invocations are rendered as printed, and a pill links a composition back to where it continues from. `←` / `→` page through Angs. |
| **Index** | The whole structural index, tabbed: **Major Compositions** (one-tap routes to Sukhmani Sahib, Asa Ki Vaar, Anand Sahib, Bavan Akhri, Sidh Gosht, Dakhni Oankaar), **The 31 Raags** (canonical order), and **Banis & Sections** (Nitnem and the closing banis). |
| **Themes** | 53 corpus-verified concepts grouped into six theological categories — tap one to read the verbatim lines where its Gurmukhi terms occur. |
| **Hukam-style random** | Draws a *complete structural unit* — a full shabad, or a Vaar's Pauri with its preceding Saloks — never a fragment. |

### Gurbani Soul (iOS / iPadOS)

The native SwiftUI app (`ios/`, Swift package `GurbaniSearchKit`) ships the **same verified corpus inside the binary** and makes **no network requests at all** — it works in Airplane Mode, with no account and no tracking (App Store privacy label: *Data Not Collected*). Beyond reader and search it adds **Nitnem** (daily banis by time of day, place kept, optional gentle reminders), **Hukam**, the **Raag Clock** (optional solar mode), **widgets + a Live Activity**, App Intents/Siri and Spotlight. The Gurmukhi engine is pinned to this Python source of truth by golden vectors in `contract/`. Distribution, gates and the store listing: [`docs/ios/`](docs/ios/) and the [app-store-submission runbook](docs/process/runbooks/app-store-submission.md).

---

## What's inside

| | |
|---|---|
| **Corpus** | 60,658 lines · all 1,430 Angs · char-for-char reconciled with the source edition (1,643,385 chars, zero loss / dup / reorder — `pipeline/reconcile.py`) |
| **Metadata** | Raag (31, canonical order) · author (Gurus, Bhagats, per-Bhatt Swaiyye attribution, Vaar-correct pauris) · bani / section · composition · ਰਹਾਉ · Ang · stanza index · pada total · source category |
| **Search** | Gurmukhi FTS (BM25-ranked) · spelling-tolerant Roman (*waheguru* → ਵਾਹਿਗੁਰੂ) · first-letter (ਧ ਧ ਰ ਗ / *dh dh r g*) · 79,666-entry phonetic-variant index · 53 corpus-verified themes · word concordance |
| **Verify engine** | `/api/verify` — any claimed quote → VERIFIED_EXACT / VERIFIED / VERIFIED_PARTIAL / PROBABLE / AMBIGUOUS / NOT_FOUND, with Ang cross-check + confidence |
| **English layer** | **58,039 lines — the full Granth** (Dr. Sant Singh Khalsa, via the ShabadOS open database — see `NOTICE.md`), labeled "EN ·", stored separately, never mixed with scripture |
| **Footprint** | One ~87 MB SQLite file + ~1,800 lines of Python. No framework, no build step, no network. |

---

## The search engine

A seeker rarely types a line perfectly. They half-remember it, romanize it the modern way, drop an aspirate, or quote across two lines. The engine is a **precision-first cascade**: it tries the most exact interpretation first and only widens when needed, so an exact match is never out-ranked by a fuzzy one.

1. **Exact FTS** — Gurmukhi or Roman transliteration, BM25-ranked.
2. **Seeker lexicon** — a curated map of how people *type* vs. how the corpus *spells* (modern postpositions का/के/की, spoken verb forms, named figures, common compounds).
3. **Phonetic variant matcher** — a 79,666-entry index plus a query-side phonetic fold (`roman_norm`) that folds aspirates, voicing, and vowel length, with a graceful "match all-but-one token" fallback so one odd word can't sink a query.
4. **English translation** — falls through to the labeled EN layer for meaning-based queries.
5. **Honorific-drop retry** — strips *ji / sahib / maharaj …* and retries.
6. **Cross-line passage matcher** — for couplets quoted across two ॥ boundaries, matched at shabad level with the true line bubbled to the top.
7. **Phonetic-fold / fuzzy skeleton** — last-resort tolerance for keyboard-smash and spaceless input.
8. **Theme** — single concept words route to their thematic line set.

Also: **first-letter** search (Gurmukhi or Roman initials of a half-remembered line) and **mixed-script** queries (Gurmukhi + Roman in one box).

Measured precision: **99.3% pass@1 / 100% pass@3** when a line is typed exactly, **98.4% / 99.7%** when typed casually (full-corpus round-trip harnesses; see [Validation](#validation--quality-evidence)).

---

## API reference

All endpoints are local, read-only, and return JSON (`application/json; charset=utf-8`). Base URL `http://localhost:7777`.

| Endpoint | Purpose | Key parameters |
|----------|---------|----------------|
| `GET /api/search` | Multi-tier search | `q`, `mode` = `auto`·`roman`·`gurmukhi`·`english`·`first`·`theme`, `limit` (≤200), `offset` |
| `GET /api/ang/{n}` | One Ang (1–1430) | path `n`; returns lines + raag/section/authors + `continued_from` |
| `GET /api/shabad/{id}` | A full composition | path `id` (comp_id) |
| `GET /api/random` | Complete Hukam-style unit | — (never a fragment) |
| `GET /api/verify` | Verify a claimed quote | `q`, optional `ang` (cross-check) |
| `GET /api/word` | Word concordance | `w` (a Gurmukhi word) |
| `GET /api/meta` | Raags, sections, authors, themes, counts | — (cached) |
| `GET /api/health` | Self-test | — (returns `ok` + per-check booleans) |

**Examples**

```bash
# Spelling-tolerant Roman search
curl 'http://localhost:7777/api/search?q=waheguru&mode=auto&limit=5'

# Read Ang 917 (Anand Sahib)
curl 'http://localhost:7777/api/ang/917'

# Verify a quote, and cross-check its Ang
curl 'http://localhost:7777/api/verify?q=ਸੋਚੈ%20ਸੋਚਿ%20ਨ%20ਹੋਵਈ&ang=1'
```

A `/api/search` result item carries: `gurmukhi`, `translit`, `en` (when available), `ang`, `raag`, `section`, `author`, `comp_id`, `is_rahao`, `stanza_index`, `pada_total`, `source_category`, plus the interpreted `mode` and any `related_themes`.

---

## The verification engine

`webapp/verify.py` answers one question precisely: **is this line really in Sri Guru Granth Sahib Ji, and where?** It is the guardrail that lets an LLM (or a person) quote without corrupting.

| Verdict | Meaning |
|---------|---------|
| `VERIFIED_EXACT` | byte-identical to a canonical line |
| `VERIFIED` | identical after benign normalization |
| `VERIFIED_PARTIAL` | a real fragment of a canonical line |
| `PROBABLE` / `AMBIGUOUS` | close, but compare carefully — returned with the nearest line |
| `NOT_FOUND` | no such line in this edition — treat the quote as unverified |

Each verdict carries a **confidence**, the matched line's **Ang / Raag / author / comp_id / section**, and — when you pass `&ang=` — an `+ANG_MATCH` / `+ANG_MISMATCH(actual=N)` tag. This is what catches a fabricated "Gurbani quote" (e.g. a Dasam-Granth line or an Ardas phrase that isn't in SGGS) instead of silently surfacing a coincidental match.

---

## Data fidelity & provenance

Trust here is not a claim — it is a chain you can re-run:

- **Char-exact reconciliation** — `pipeline/reconcile.py` compares the DB's line stream against the source edition character-for-character: **1,643,385 chars, zero loss / duplication / reordering**.
- **Checksums** — `MANIFEST.json` records `corpus_sha256` and `db_sha256` (`f0a64f78…`) for the exact build.
- **Structural double-confirmation** — `pipeline/enrich_v2.py` cross-checks each shabad's terminal Ank against the padas actually indexed: **3,159 CLEAN / 527 STRUCTURAL / 2 verified-structural** (comp_type-aware, because SGGS uses four distinct numbering regimes).
- **Independent second source** — the ShabadOS corpus matched ours at **97.26% character-exact** line-for-line, an external check on the extraction.
- **Canonical anchors** — ੴ appears exactly **568** times; the Mool Mantar and Ang count are health-checked at every startup.

The English layer is **58,039 lines (95.7% of the Granth)**, aligned exact/skeleton/fuzzy with 102 documented unmatched edition-variant lines, and stored in a separate table — labeled, never scripture.

---

## Architecture (the 5 layers)

1. **Canonical data** — SQLite + FTS5 (`db/sggs.sqlite`), versioned builds, `MANIFEST.json` checksums.
2. **Search** — BM25 + a unified cross-script query cascade + theme expansion (`webapp/serve.py`).
3. **Verification** — a rule-engine cascade with confidence (`webapp/verify.py`).
4. **Explanation** — LLMs may only *explain*; any quote must pass the verifier (`Answer-Protocol.md`).
5. **Governance** — mandatory citation, a source registry, `CHANGELOG.md`, and audit reports.

Design docs (in `docs/design/`), in reading order: `00_Build-Plan.md` → `01_Production-Architecture.md` → `02_Sovereign-Architecture-Assessment.md` → `03_Phonetic-Variant-Engine.md` → `docs/reports/archive/Schema_v2_Migration_Report.md`. `MASTER-INDEX.md` is the doc index; the [engineering handbook](docs/engineering/README.md) is the operating manual.

---

## Repository layout

```
sggs-knowledge-base/
├── webapp/
│   ├── serve.py            # zero-dependency stdlib HTTP server + the search cascade
│   ├── verify.py           # the quotation-verification engine
│   └── static/index.html   # the entire UI (single file: HTML + CSS + vanilla JS)
├── db/sggs.sqlite          # the canonical corpus (SQLite + FTS5; Git-LFS tracked)
├── pipeline/               # the full rebuild chain (see below)
│   ├── build_corpus.py     #   PDF → JSONL (extraction + Gurmukhi normalization)
│   ├── reconcile.py        #   char-exact equality vs. the source edition
│   ├── golden_test.py      #   49 canonical structural checks
│   ├── build_db.py         #   JSONL → SQLite + FTS5
│   ├── build_variants.py   #   the 79,666-entry phonetic-variant index
│   ├── enrich_v2.py        #   structural columns + the pada checksum
│   ├── load_translations.py#   the labeled English layer
│   ├── reconcile / golden / roundtrip / chaos / casual_quote harnesses
│   └── rebuild_all.sh      #   runs the whole chain end-to-end
├── validation/             # QA artifacts: chaos attacks, harness logs, audit notes
├── MANIFEST.json           # version + checksums + provenance
├── CHANGELOG.md            # every release, with before/after metrics
├── Answer-Protocol.md      # the rules for explaining over this corpus
├── NOTICE.md               # licensing of the English layer (read this)
└── *_Report.md             # Audit / Hardening / Validation / Schema-migration reports
```

---

## Validation & quality evidence

Every release is gated against a battery of harnesses; nothing ships that regresses them.

| Check | Tool | Result |
|-------|------|--------|
| Source reconciliation | `pipeline/reconcile.py` | char-exact, 1,643,385 chars, 0 divergence |
| Canonical structure | `pipeline/golden_test.py` | 49 checks pass |
| Round-trip (exact) | `pipeline/roundtrip_harness.py` | **99.3% pass@1 / 100% pass@3** |
| Round-trip (casual typing) | `pipeline/roundtrip_harness.py --perturb` | **98.4% / 99.7%** |
| Casual fragment-quote | `pipeline/casual_quote_harness.py` | **~98% pass@1 / ~100% pass@3** |
| Adversarial "chaos" suite | `pipeline/chaos_harness.py` | **175 / 200** |
| Structural checksum | `pipeline/enrich_v2.py --report` | 3,159 CLEAN / 527 STRUCTURAL / 2 verified |
| Runtime self-test | `GET /api/health` | 6 / 6 checks |

Narrative evidence lives in [`docs/reports/archive/`](docs/reports/archive/): `Validation-Report.md`, `Audit_Report.md`, `Proactive_Hardening_Report_v2.0.6.md`, and `QA_Resolution_Report.md`.

---

## Rebuild from source

The source PDF is **not** included in this repository. With your own copy of the edition:

```bash
# 1) Extract + normalize, then prove it
python3 pipeline/build_corpus.py <the-source-pdf> corpus/sggs.jsonl
python3 pipeline/reconcile.py   <the-source-pdf> corpus/sggs.jsonl   # must print RECONCILED
python3 pipeline/golden_test.py <the-source-pdf>                     # 49 checks

# 2) Build the DB + indexes (SQLite can't build on some mounts — build in /tmp, then copy)
python3 pipeline/build_db.py       corpus/sggs.jsonl /tmp/sggs.db
python3 pipeline/build_variants.py /tmp/sggs.db                      # phonetic-variant index
python3 pipeline/enrich_v2.py      /tmp/sggs.db --apply              # structural columns + checksum
bash scripts/data/fetch_translations.sh                             # private inputs (see NOTICE.md)
python3 pipeline/load_translations.py /tmp/sggs.db "pipeline/translations/en_*.jsonl"
cp /tmp/sggs.db db/sggs.sqlite

# …or run the whole chain:
bash pipeline/rebuild_all.sh <the-source-pdf>
```

> The phonetic fold (`roman_norm`) is duplicated in `webapp/serve.py` and `pipeline/sggs_pipeline.py` and **must stay in sync** — changing it requires rebuilding the `translit_norm` / `norm_blob` columns and the FTS indexes.

---

## Versioning

Current release: **v1.3.6** (`MANIFEST.json`). The running build is stamped in the footer and at `/api/health`. Every change — search-logic, data, or UI — is recorded in `CHANGELOG.md` with its before/after metrics and whether the DB changed. Search-only patches never re-commit the DB; the `db_sha256` in `MANIFEST.json` always matches the shipped `db/sggs.sqlite`.

---

## Governance — how an AI may use this corpus

`Answer-Protocol.md` is binding for any assistant built on this corpus:

1. **Never quote Gurbani from memory.** Retrieve from `db/sggs.sqlite` or the `serve.py` API.
2. **Machine-verify every quote** (`/api/verify`) before presenting it.
3. **Always cite the Ang.**
4. **Label interpretation as interpretation** — translation and explanation are clearly separated from verbatim scripture.

This is what makes the corpus a *guardrail*, not just a dataset.

---

## Known limitations & roadmap

Honest about the edges:

- **Search tail (~1–2%)** — the remaining misses are mostly near-duplicate lines and ranking ties, not phonetic gaps. The next lever is a confidence-floor / "not in this edition" signal so non-SGGS phrases (Dasam lines, greetings) stop returning coincidental matches rather than a clear *not found*.
- **`comp_type` metadata** — a few sections carry an upstream mislabel (corrected at the display layer; a data-layer fix is queued and has no search impact).
- **Coverage** — this is SGGS only. Other granths (e.g. Dasam Bani) and additional translation/teeka layers (Bhai Gurdas, Sahib Singh) are deliberately out of scope unless explicitly added.

---

## License & attribution

> ### ⚠️ Keep this repository PRIVATE
> The **English translation layer** (Dr. Sant Singh Khalsa, via the ShabadOS open database) is licensed for **personal, non-commercial use with attribution** and **must not be redistributed publicly**. See **`NOTICE.md`** for the full terms and the source registry.

The Gurmukhi scripture is the eternal Word and belongs to the Panth; it is reproduced here verbatim for study. Code in this repository is the author's own. Before making anything public, read `NOTICE.md`.

---

## Acknowledgements

- **Sri Guru Granth Sahib Ji** — ਧੁਰ ਕੀ ਬਾਣੀ.
- **Dr. Sant Singh Khalsa** — the English translation.
- **[ShabadOS](https://github.com/shabados/database)** — the open database used for the English layer and as an independent cross-verification source.

<div align="center">

ੴ · <em>ਧੁਰ ਕੀ ਬਾਣੀ</em> · handled with reverence

</div>
