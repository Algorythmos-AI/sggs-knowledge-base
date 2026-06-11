# SGGS Knowledge Base — Production Web App Architecture (v2)

*Status: approved decisions locked (2026-06-10): verbatim + labelled explanation · reader-friendly Roman transliteration · external structure-level spot-checks allowed · local web app.*

---

## 1. Audit of the v1 plan — is it robust enough for a production web app?

**What v1 already gets right (kept as-is):** verified Unicode source, the visual→logical sihari correction as the central correctness problem, golden-Ang-first methodology, full per-line metadata schema, context inheritance, canonical validation gates, parallel agent build, reverence rules.

**Gaps found — v1 was built for a `query.py` CLI, not a web app. Six things were missing:**

| # | Gap | Fix in v2 |
|---|---|---|
| 1 | **No database.** JSONL + a Python script can't serve interactive search. | **SQLite + FTS5** — single file, zero server admin, full-text search built in. |
| 2 | **No first-letter search.** This is *the* standard way Gurbani is searched (e.g. `ਧ ਧ ਰ ਗ` or `dh dh r g` finds ਧਨੁ ਧਨੁ ਰਾਮਦਾਸ ਗੁਰੁ). | Per-line first-letter strings (Gurmukhi + Roman) stored and FTS-indexed. |
| 3 | **No fuzzy tier.** Exact Gurmukhi search fails on matra/spelling variants. | A matra-stripped "skeleton" column (consonants only) as a normalized search fallback. |
| 4 | **No API or frontend.** | Local web server + single-page UI (below). |
| 5 | **No input story.** Sam shouldn't need a Gurmukhi keyboard. | Roman input works everywhere: searches transliteration + Roman first-letters; Gurmukhi input also supported. |
| 6 | **No dependency story.** A "production-grade" personal app must start reliably for a non-developer. | Server uses **Python stdlib only** (`http.server` + `sqlite3`) — no pip installs. One command: `python3 serve.py`. FTS5 missing → automatic LIKE fallback. |

Everything else in v1 (phases A–F, quality gates, risks) stands and is executed below.

---

## 2. Repository layout

```
SGGS-KnowledgeBase/
├── 00_Build-Plan.md              v1 plan (approved)
├── 01_Production-Architecture.md this file
├── pipeline/                     build scripts (reproducible)
│   ├── extract.py                PDF → per-page raw text + Ang map
│   ├── reorder.py                visual→logical sihari correction
│   ├── translit.py               Gurmukhi → reader-friendly Roman
│   ├── parse.py                  structure: raag/author/composition/rahao
│   ├── build_corpus.py           runs everything → corpus/sggs.jsonl
│   ├── build_db.py               corpus → db/sggs.db (FTS5)
│   └── tests/golden/             golden-Ang fixtures + harness
├── corpus/
│   ├── sggs.jsonl                master line-by-line corpus
│   └── by-raag/*.md              human-readable corpus
├── db/sggs.db                    the knowledge base (SQLite + FTS5)
├── concordance/                  word + concept indexes (also in DB)
├── webapp/
│   ├── serve.py                  stdlib-only server (API + static UI)
│   ├── static/index.html         the app (single file)
│   └── README.md                 how to run
├── Answer-Protocol.md            faithfulness rules for answers
├── Validation-Report.md          all checks + error rates
└── MASTER-INDEX.md               navigation + "how to ask"
```

## 3. Database schema (sggs.db)

```sql
lines(id INTEGER PK, ang INT, pdf_page INT, raag TEXT, author TEXT,
      comp_type TEXT, comp_id INT, line_no INT,
      is_rahao INT, is_header INT, verse_marker TEXT,
      gurmukhi TEXT,        -- verbatim, logical order, NFC (the scripture)
      translit TEXT,        -- reader-friendly Roman (reading aid)
      fl_gurmukhi TEXT,     -- first letters: "ਧ ਧ ਰ ਗ"
      fl_roman TEXT,        -- first letters: "dh dh r g"
      skeleton TEXT)        -- matra-stripped consonant skeleton
fts_gurmukhi, fts_translit, fts_fl (FTS5, content=lines)
raags(name, first_ang, last_ang, n_lines)
authors(name, n_lines)
concepts(concept, gurmukhi_terms, description)
concept_lines(concept, line_id)
word_freq(word, count)        -- the concordance head
```

## 4. Search modes (API: `GET /api/search?q=…&mode=…`, plus `/api/ang/N`, `/api/shabad/ID`, `/api/concepts`, `/api/random`)

1. **Auto** (default) — detects script; runs Gurmukhi FTS / translit FTS / first-letter in order, merges ranked.
2. **Gurmukhi** exact + FTS; falls back to skeleton match.
3. **Roman** — against transliteration.
4. **First letters** — Gurmukhi or Roman initials.
5. **Browse** — Ang 1–1430 pager, Raag list, author list; any line opens its full shabad in context with Rahao highlighted.
6. **Theme** — concept index lookup (Naam, Hukam, Haumai, Simran, Seva …).

Every result everywhere shows: **verbatim Gurmukhi · transliteration · Ang · Raag · author**. The UI never paraphrases scripture; the app is retrieval-only — meaning/explanation stays in Claude sessions per the Answer Protocol.

## 5. Quality gates (unchanged from v1 §6, plus)

- App starts on a clean Mac with system Python 3, zero installs.
- Search battery: 25 known queries (all 6 modes) return the expected Ang(s).
- p95 search latency < 100 ms on the full corpus.
