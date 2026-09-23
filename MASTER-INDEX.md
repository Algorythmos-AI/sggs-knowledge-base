# SGGS Knowledge Base — Master Index

**Source:** `Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf` (1,483 pages → 1,430 Angs) · v1.3.5, built 2026-09-23 · 60,658 lines (char-for-char reconciled with the source) · 29,244 distinct words · 54 themes · per-Bhatt Swaiyye attribution · Vaar pauris correctly attributed · raag-timing knowledge layer (attributed claims, divergence preserved).

## Use it

- **Web app:** double-click **`Start SGGS App.command`** (or `cd webapp && python3 serve.py`) → http://localhost:7777 (see `webapp/README.md`)
- **Ask a question:** any Gurbani question — answered per `Answer-Protocol.md` (verbatim + Ang + labelled explanation)
- **Direct SQL:** `db/sggs.sqlite` (SQLite FTS5; open read-only)
- **Read:** `corpus/by-raag/*.md` (human-readable, by Raag/Bani) · `corpus/sggs.jsonl` (machine-readable)

## What's where

| Path | Contents |
|---|---|
| `00_Build-Plan.md` | The approved plan (v1) |
| `01_Production-Architecture.md` | Production audit + web-app architecture (v2) |
| `pipeline/` | Reproducible build (`bash pipeline/rebuild_all.sh`): `sggs_pipeline.py`, `build_corpus.py`, `reconcile.py` (char-exact gate), `golden_test.py`, `build_db.py`, then translations/variants + Insight-Engine builders (`ml_analytics_builder.py`, `build_vaars.py`, `build_resonance.py`, `build_semantic_vectors_lite.py`) |
| `corpus/` | `sggs.jsonl` (60,658 records) + `by-raag/` readable Markdown |
| `db/sggs.sqlite` | The knowledge base: `lines` + FTS5 (`fts`/`fts_en`/`fts_shabad`/`fts_tri`), `translations`, `variants`, `canon_tokens`, `raags`, `sections`, `authors`, `concepts`/`concept_lines`, `word_freq`, analytics (`theme_network`, `*_analytics`, `theme_fingerprint`, `author_resonance`, `vaars`/`vaar_units`, `*_neighbors`), `meta` |
| `webapp/` | `serve.py` (stdlib server) + `static/` (prebuilt Astro multi-page UI) + README |
| `Answer-Protocol.md` | Faithfulness rules for answering |
| `Validation-Report.md` | All quality gates, checks, corrections & known limits |
| `Raag_Timing_Knowledge_Layer.md` | Raag timing as attributed claims (pahar clock, divergence policy) + bani-forms metadata; schema, derivation rules, runbook |
| `pipeline/timing/` + `audit/scripture-baseline.json` | Timing-layer migrations/seed/derivation + the committed per-table scripture integrity baseline (`guard_scripture.py` gate) |

## Line record (every one of the 60,658 lines)

`ang` · `raag` · `section` (bani) · `author` · `comp_type` · `comp_id` (shabad grouping) · `is_rahao` · `is_header` · `markers` (॥੧॥…) · `gurmukhi` (verbatim) · `translit` · `fl_g`/`fl_r` (first letters) · `skeleton` (matra-stripped)

## How to ask (worked examples)

1. *Find a line:* "ਸੋਚੈ ਸੋਚਿ" → exact line, Ang 1. Half-remembered? first letters: "ਧ ਧ ਰ ਗ" / "dh dh r g" → Ang 968.
2. *Meaning:* "What does Japji say about Hukam?" → verbatim pauri 2 lines + Ang + labelled explanation.
3. *Theme:* "What does Gurbani say about haumai?" → theme `haumai` (634 occurrences) → verses + Angs.
4. *Structure:* "Which raag is Anand Sahib in, and where?" → ਰਾਮਕਲੀ, Angs 917–922, M3, 40 pauris.
5. *Author:* "Show Sheikh Farid's saloks" → section ਸਲੋਕ ਸੇਖ ਫਰੀਦ, Angs 1377–1385.
