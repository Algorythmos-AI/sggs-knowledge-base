# SGGS Knowledge Base — Master Index

**Source:** `Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf` (1,483 pages → 1,430 Angs) · v1.3.10, built 2026-09-25 · 60,658 lines (char-for-char reconciled with the source) · 29,244 distinct words · 54 themes · per-Bhatt Swaiyye attribution · Vaar pauris correctly attributed · raag-timing knowledge layer (attributed claims, divergence preserved).

## Use it

- **Web app:** double-click **`Start SGGS App.command`** (it installs the pinned database on first run; or `make dataset && cd webapp && python3 serve.py`) → http://localhost:7777 (see `webapp/README.md`)
- **Ask a question:** any Gurbani question — answered per the [Answer Protocol](https://github.com/Algorythmos-AI/sggs-data/blob/main/Answer-Protocol.md) (verbatim + Ang + labelled explanation)
- **Direct SQL:** `db/sggs.sqlite` after `make dataset` (SQLite FTS5; open read-only)
- **Read:** the corpus in [`sggs-data`](https://github.com/Algorythmos-AI/sggs-data): `corpus/by-raag/*.md` (human-readable) · `corpus/sggs.jsonl` (machine-readable)

## What's where

| Path | Contents |
|---|---|
| `docs/engineering/` | Engineering handbook — invariants, local setup, delivery, brand |
| `docs/design/` | Design docs: `00_Build-Plan.md` (v1 plan), `01_Production-Architecture.md` (v2), `02_…`, `03_Phonetic-Variant-Engine.md`, Astro migration, ML analytics, Phase 3 roadmap, raag timing layer |
| `docs/reports/archive/` | Point-in-time audits and reports (validation, QA, hardening, Apple-grade audit, iOS readiness) |
| [`sggs-data`](https://github.com/Algorythmos-AI/sggs-data) | The corpus, the reproducible build from the source edition (reconcile char-exact, golden checks, deterministic double build), the editorial ledger, fingerprints and the timing/Nitnem layers |
| `dataset.lock.json` | The sggs-data commit + database sha256/size this platform serves (`make dataset`) |
| `tools/` | Golden-vector + OpenAPI generators, HTTP contract replay, search harnesses (`qa/chaos/` inputs) |
| `db/sggs.sqlite` | The knowledge base (installed from the pin, never committed): `lines` + FTS5 (`fts`/`fts_en`/`fts_shabad`/`fts_tri`), `translations`, `variants`, `canon_tokens`, `raags`, `sections`, `authors`, `concepts`/`concept_lines`, `word_freq`, analytics (`theme_network`, `*_analytics`, `theme_fingerprint`, `author_resonance`, `vaars`/`vaar_units`, `*_neighbors`), `meta` |
| `webapp/` | `serve.py` (stdlib server) + `static/` (prebuilt Astro multi-page UI) + README |
| `docs/reports/archive/Validation-Report.md` | All quality gates, checks, corrections & known limits (superseded; see banner) |
| `docs/design/Raag_Timing_Knowledge_Layer.md` | Raag timing as attributed claims (pahar clock, divergence policy) + bani-forms metadata; schema, derivation rules, runbook |

## Line record (every one of the 60,658 lines)

`ang` · `raag` · `section` (bani) · `author` · `comp_type` · `comp_id` (shabad grouping) · `is_rahao` · `is_header` · `markers` (॥੧॥…) · `gurmukhi` (verbatim) · `translit` · `fl_g`/`fl_r` (first letters) · `skeleton` (matra-stripped)

## How to ask (worked examples)

1. *Find a line:* "ਸੋਚੈ ਸੋਚਿ" → exact line, Ang 1. Half-remembered? first letters: "ਧ ਧ ਰ ਗ" / "dh dh r g" → Ang 968.
2. *Meaning:* "What does Japji say about Hukam?" → verbatim pauri 2 lines + Ang + labelled explanation.
3. *Theme:* "What does Gurbani say about haumai?" → theme `haumai` (634 occurrences) → verses + Angs.
4. *Structure:* "Which raag is Anand Sahib in, and where?" → ਰਾਮਕਲੀ, Angs 917–922, M3, 40 pauris.
5. *Author:* "Show Sheikh Farid's saloks" → section ਸਲੋਕ ਸੇਖ ਫਰੀਦ, Angs 1377–1385.
