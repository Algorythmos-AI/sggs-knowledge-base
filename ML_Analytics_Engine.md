# ML Analytics Engine — Phase 1 (v2.1.0)

**Status:** shipped · **Date:** 2026-06-13 · **Scope:** additive, offline. The live server gains a few cached `SELECT`s and **zero** runtime ML dependencies; the search path is untouched; every existing table is byte-identical (verified).

This is the first step in turning the SGGS Knowledge Base from a *search* engine into an *insight* engine — applying statistics and offline NLP as an **analytical lens**, never altering, scoring, or reinterpreting the sacred text.

---

## 1. The governing principle

> ML is applied only to data the corpus **already contains** — the structural metadata, the **53 corpus-verified themes**, and the **labeled English translation**. The Gurmukhi is never touched, never scored, never ranked.

This was stress-tested by a domain/ethics SME and it changed the design (§4): **no generic sentiment model is used.** Running VADER/TextBlob on Gurbani mislabels ~47% of devotional lines and *inverts* the most sacred idioms — it scores "those who die while yet alive obtain it" (jiwan mukti, the supreme goal) as the **most negative line in the corpus**, and labels *bhau* (reverential awe) and *viraha* (sacred longing) as negative. Shipping that would violate the project's founding rule. Affect is therefore expressed only through the corpus's own verified themes.

---

## 2. Architecture (guardrails honoured)

| Guardrail | How it is met |
|---|---|
| **Additive only** | A standalone builder copies the DB, **adds** new tables, and asserts every existing table (`lines`, `fts*`, `variants`, `translations`, `concepts`, `concept_lines`) is content-hash identical. Search logic in `serve.py` is not touched. |
| **Offline batch** | All computation is in `pipeline/ml_analytics_builder.py` (stdlib + numpy). It pre-computes everything into new tables. Build time: **~2 s**. |
| **Zero runtime overhead** | The server runs only basic cached `SELECT`s against the pre-computed tables. No numpy/sklearn/torch at runtime; the stdlib-only invariant holds. Endpoints degrade gracefully if the analytics tables are absent. |

DB footprint: the seven new tables add **< 0.5 MB**; `db_sha256` is updated in `MANIFEST.json` (this release changes the DB).

---

## 3. What was built

### 3.1 Theme co-occurrence network — `theme_network`
Themes that appear together within the same shabad (`comp_id`). Raw counts are **base-rate biased** (`naam ↔ satguru` looks #1 but is barely above chance), so the edge weight is **PPMI** (positive pointwise mutual information) with **Jaccard** as a second signal. This surfaces *real* associations:

| Strongest by PPMI | co-occurrence | PPMI | Jaccard |
|---|---|---|---|
| kaam ↔ krodh | 176 | 3.39 | 0.43 |
| krodh ↔ lobh | 78 | 3.05 | 0.23 |
| garab ↔ haumai | 461 | 2.75 | 0.69 |
| anhad ↔ shabad | 847 | 2.13 | **0.82** |

The five vices (panj chor) cluster correctly; `anhad ↔ shabad` (the unstruck sound and the Word) is the tightest large pair — patterns raw counts miss entirely. Min support = 20 shabads.

### 3.2 Theme fingerprints — `theme_fingerprint`
Per author and per raag: emphasis on each theme as **lift** (entity rate ÷ corpus rate), so it shows what a Guru/Bhagat/raag *emphasises*, not just what is frequent. E.g. Guru Amar Das (M3) → haumai/manmukh/shabad; Guru Arjan (M5) → sant_sadh/simran/daya/anand. Rows for entities with < 300 lines are flagged `is_reliable = 0`.

**This is the "emotional/affect fingerprint" the task asked for** — grounded in verified themes (anand→joy, prem_pyar→devotion, maran_jeevan/maya→detachment, bhau→awe, bhana→surrender, nimrata→humility) instead of a sentiment model.

### 3.3 Stylometry — `author_analytics`, `raag_analytics`, `author_distinctive_terms`
Objective, size-stable features on the English translation: **MATTR** vocabulary richness (not raw TTR, which is corpus-size biased), hapax %, words/line, lines/shabad. Distinctive words per author via **Monroe et al. log-odds-ratio with an informative Dirichlet prior** (not TF-IDF — it accounts for variance). Authors under ~3,000 tokens (all Bhatts, small Bhagats) are flagged unreliable. Example — Kabir's distinctive English voice: *says · now · what · why* (direct, present-tense, interrogative).

### 3.4 Related shabads — `shabad_neighbors`
"Find compositions on a similar theme profile." Cosine over each shabad's **IDF-weighted theme vector** (53 dims) so distinctive shared themes dominate. Top-K = 10 per shabad. Grounded entirely in the verified themes — not a translation artifact, not an external model. (A richer MiniLM line-level *semantic* mode is the documented Phase-2 upgrade; see §6.)

### 3.5 Provenance — `analytics_meta`
Key/value build provenance and the framing caveats (scripture untouched, affect method, stylometry surface, metric choices) so the honesty travels with the data.

---

## 4. API (additive, cached `SELECT`s)

| Endpoint | Returns |
|---|---|
| `GET /api/themes/network?concept=naam&min_ppmi=0&limit=N` | a theme's strongest associations (PPMI + Jaccard); no `concept` → the global top edges |
| `GET /api/analytics/author?author=…` | stylometry + theme fingerprint + distinctive terms; no `author` → the author list |
| `GET /api/analytics/raag?raag=…` | raag aggregates + thematic profile; no `raag` → the raag list |
| `GET /api/related?comp_id=N` | related shabads (theme-profile cosine) with Ang + first line |

Every response carries a `note` framing the result as descriptive, never a judgement of scripture.

---

## 5. Validation

- **Additive integrity:** all 11 existing tables content-hash **identical** old vs. new; FTS functional on the new DB.
- **Search untouched:** in-process canonical spot-check unchanged (hamra→366, jamuna→1403, baba farid→1377, waheguru→1402); **chaos 175/200** held; `serve.py` search path diff = none (only new branches + version).
- **Endpoint smoke:** all endpoints 200; outputs sanity-checked (kaam↔krodh, M5→anand/sant_sadh, Kabir→"says/now/why").
- **Build:** `python3 pipeline/ml_analytics_builder.py` → 2,520 network edges, 2,265 fingerprints, 30 authors, 31 raags, 45,430 neighbor rows, in ~2 s.

---

## 6. Roadmap (Phase 2 — not in this release)

Ranked by value × safety × fit, all offline-precompute + zero-runtime:

1. **MiniLM line-level semantic neighbors** — embed the 58,039 EN translations offline (all-MiniLM-L6-v2, Apache-2.0), store top-K per line. Adds ~9 MB, **zero** runtime deps. Requires model access at *build* time only (the sandbox's model host was blocked, so this was deferred — it is a one-command regen on a network-capable machine). Must be labeled "similar in the English translation." Full analysis in **`Vector_Search_Feasibility_Report.md`**.
2. **Community detection + centrality** on the theme network (theme "families"; the hub concept) — Louvain + PageRank over the PPMI graph.
3. **NMF topic model** on the EN as an unsupervised *cross-check* of the 53 curated themes (validation, not replacement).
4. **Gurmukhi collocations**, **raag↔theme affinity deep-dive**, **ang-level theme density**, and a **front-end** (theme-network graph viz, author/raag fingerprint cards) on top of these endpoints.
5. **Live free-text semantic search** — only as an *opt-in, isolated micro-service* (`semantic_server.py`), never imported into the stdlib-only core server.

---

## 7. What we will never ship

No "negative/positive shabads", no per-verse emotion label, no sentiment ranking of Gurus/raags, no off-the-shelf sentiment tool on Gurbani lines, nothing that sorts or judges scripture by tone. The right question is never "what is the sentiment of this shabad?" but "what themes does it illuminate, and where else do they appear?" — which the data answers honestly.
