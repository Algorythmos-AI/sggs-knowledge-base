# Phase 3 — Innovation Roadmap
### Sri Guru Granth Sahib Knowledge Base · "The Beyond"

*Synthesised from a three-agent SME brainstorming fleet (Theological Data Scientist · Frontend UX Visionary · Sovereign Architecture Auditor), each grounded read-only against the live `db/sggs.sqlite` and `webapp/serve.py`. Authored after Phase 2 (offline semantic vectors + Insights dashboard) shipped at v2.3.0.*

---

## The vision

Phase 1–2 turned a verbatim corpus into a **searchable, analysable** knowledge base. Phase 3 turns it into an **immersive study environment** — one that reveals the deep structure of the Guru Granth Sahib (its themes, its architecture, its many voices) and lets a student *work with* the text, all while never breaking the two founding promises: **scripture is shown verbatim and never ranked or judged**, and the runtime stays **100% offline, stdlib-only, sovereign**.

Everything below is computable from data already in the DB (or one small hand-authored static file), needs no new runtime dependency, and reuses the Astro MPA + Tailwind + D3/Chart.js stack already in place.

---

## Cross-cutting principles (non-negotiable)

1. **Descriptive, never evaluative.** Every metric — tag density, embedding similarity, stylometry — is a *computed pattern in the text*, surfaced beside the verbatim Gurmukhi. No leaderboards, no "more/less spiritual," no rating verses. (`serve.py` already captions neighbours this way; keep it everywhere.)
2. **Reverence over engagement.** No gamification — no streaks, badges, rarity, or slot-machine "draws." Calm, contemplative motion that always respects `prefers-reduced-motion`.
3. **Honour reliability.** Grey out / footnote anything where `is_reliable = 0` or sample sizes are small (Satta & Balwand = 87 lines, several Bhatts).
4. **Sovereign by construction.** The pure core (`serve.py`) is a *closed, read-only, stdlib SELECT engine over precomputed tables*. Every heavy thing — embeddings, ANN, LLM — is **precomputed away at build time** or pushed into an **optional satellite process**. Never a runtime dependency.

---

## Workstream A — Data & Analytics (what we visualise next)

Ranked by impact-per-effort. All offline-computable from existing tables.

| # | Initiative | What it reveals | Powered by | New precompute? | Effort |
|---|------------|-----------------|------------|------------------|--------|
| A1 | **Cross-Contributor Resonance Map** | Which voices echo whom semantically — Bhagat Kabir ↔ Guru Nanak across centuries/traditions; the SGGS's radical inclusivity, measured | `line_neighbors` ⟕ `lines.author` + `source_category` | small `author_resonance` (GROUP BY + lift normalisation) | M |
| A2 | **Semantic Trail Reader** | Hop verse→verse along a chain of meaning across the whole canon — a guided study/meditation path | `/api/neighbors` (exists) + `lines`/`translations` | none | S |
| A3 | **Raag Theme-Progression Ribbon** | The emotional arc of a raag: how themes ebb/flow as you read it linearly (e.g. Maru front-loads struggle, resolves toward `naam`) | `lines`(raag,ang,comp_id) ⟕ `concept_lines`; `raag_analytics.top_themes` | none (bin on read) | M |
| A4 | **Vaar Anatomy Strip** | The salok⇄pauri architecture of a Vaar, with the famous cross-author split (saloks vs pauris by different Gurus) | `lines`(comp_type, markers, stanza_index, author) + `concept_lines` | none | M |
| A5 | **Concept Constellation + bridge detection** | Which themes are *structurally central* — is `naam` the hub joining devotion- and cosmology-clusters? (betweenness, community detection) | `theme_network` (ppmi, jaccard) → `theme_centrality` | small `theme_centrality` (networkx at build) | S–M |
| A6 | **Author Linguistic-Evolution Quadrant** | Stylometric signature: lexical diversity × rarity, by chronology (M1→M9) and Bhagat/Guru | `author_analytics` (mattr_100, hapax_pct, n_tokens) + `author_distinctive_terms` | none | S |
| A7 | **Rahao-Centred Shabad Lens** | The "thesis line" method: how a shabad's body develops its refrain (`is_rahao` concept lift vs body) | `lines`(is_rahao, comp_id) ⟕ `concept_lines` | optional `rahao_concept_lift` | M |
| A8 | **Concept Geography across the Ang timeline** | A macro-map of the whole volume: where each theme concentrates across Angs 1–1430, with section bands | `lines`(ang) ⟕ `concept_lines`; `sections` | optional density table | M |

**Agent A's first three:** A1 (uniquely exploits the brand-new 581k-edge `line_neighbors`, tells the most important story), A2 (endpoint already exists — lowest effort, highest daily use), A3 (fulfils the stated vision, most visually striking single artifact).

---

## Workstream B — UX & Immersion (index → study environment)

All consistent with the existing premium dark/saffron, glassmorphism, MPA-offline architecture. Heavy viz stays code-split on `/analytics`; new visuals elsewhere are hand-rolled inline SVG/CSS (no extra bundle, no CDN).

| # | Initiative | The experience | Data | Effort |
|---|------------|----------------|------|--------|
| B1 | **Contributor Timeline & Lineage Ribbon** | Scrollable historical ribbon of the 30 contributors — the ten-Guru spine then Bhagats/Bhatts; grasp *when & by whom*, jump into their Bani | `/api/meta` authors + tiny static `contributors.json` (public-domain chronology — the one real data gap) | M |
| B2 | **Ambient / Sehaj Reading Mode** | A "settle in" mode: chrome fades, one Ang centred on a warm dimmed ground; optional line-spotlight | pure client CSS/state on existing Reader | S |
| B3 | **Semantic Constellation** (Related Verses, radial) | The chosen verse at centre, neighbours orbiting by similarity — *see* a thought echo across the Granth, tap to travel | `/api/neighbors` (exists); inline SVG, not D3 | M |
| B4 | **Cross-Reference Margin & Study Trail** | Pin verses to a persistent rail that survives MPA navigation (localStorage) — gather every line on *hukam*; export with Ang citations | `store` (localStorage) + line payload; optional `/api/neighbors` suggestions | M |
| B5 | **Raag Atmosphere Panel** | The traditional time/season/rasa of a raag as a calm reading frame, + its distinctive themes | `/api/analytics/raag` (exists) + tiny static `raag_moods.json` | S–M |
| B6 | **Theme Atlas** (Insights upgrade) | Reframe the cold PPMI graph as a navigable atlas: click a theme → focus its neighbourhood + a plain-language gloss → jump to Search | `/api/themes/network` + concept descriptions (exist) | M |
| B7 | **Hukam Mode** | The existing random draw elevated into a reverent daily opening (ੴ breath intro, date-seeded so it holds for the day) | `/api/random` (exists) | S |
| B8 | **Composition Companion** | "Related compositions" at the foot of each shabad — whole shabads sharing its theme-DNA | `/api/related` (exists, underused on FE) | S |

**Agent B's first three:** B1 (the headline "immersive" ask; one small static JSON closes the data gap), B2 (biggest experiential lift per line of code; Reader → sanctuary), B4 (turns the MPA's main limitation — no shared SPA state — into a *feature* via localStorage).

**MPA stays a feature, not a fight:** persistent state (Study Trail, focus pref, date-seeded Hukam) lives in local/sessionStorage and survives full page loads with zero SPA framework. New data ships as flat static JSON in `public/`, served by the existing stdlib server — no new Python routes.

---

## Workstream C — Sovereign Architecture (scale without bloat)

The architecture is already correct in its bones (build-time ML in throwaway venvs; runtime reads precomputed tables). These protect that line as vectors/graphs grow.

**Quick-wins — two already applied in this release:**

- ✅ **Dropped the redundant `idx_line_neighbors_line`** — the PK `(line_id, neighbor_id)` autoindex already covers `WHERE line_id=?` (verified: query now uses `COVERING INDEX sqlite_autoindex_line_neighbors_1`). Reclaimed **6.7 MB** (DB 115.8 → 109.1 MB). Removed from the builder so future rebuilds stay lean.
- ✅ **Read-only mmap pragmas in `db()`** (`mmap_size=256MB`, `cache_size=32MB`, `query_only`) — pure stdlib, keeps the growing neighbour/analytics tables zero-copy in the page cache.

**Recommended next (ordered, protect the stdlib runtime above all):**

1. **[S] CI sovereignty guard** — fail any build where `serve.py`/`verify.py` import `numpy|torch|sentence_transformers|sklearn` or call `enable_load_extension`. *The single highest-leverage guardrail — makes a sovereignty regression impossible to merge by accident.*
2. **[S] Decide & document: NO ANN extension, NO WAL, NO raw vectors in the shipped DB.** Precomputed top-k stays the runtime path. `sqlite-vec`/`sqlite-vss` are loadable C extensions → per-platform native binaries + `enable_load_extension` (compiled out of many Python builds) → breaks sovereignty. Live ANN, if ever needed, belongs in the optional sidecar (below).
3. **[S] One-time FTS `optimize`** at build + audit `detail=`/trigram necessity to trim the ~31 MB FTS footprint (the largest single category).
4. **[M] Optional offline RAG sidecar** — natural-language Q&A *grounded only in retrieved verses*:
   - **Separate optional process** (`llama-server`/`ask.py` on its own port), **never imported into `serve.py`**. If the user never installs it, everything works exactly as today.
   - **Retrieval is authoritative, generation is only commentary.** Hybrid retrieval (MiniLM cosine + FTS) → prompt: *"answer ONLY from these numbered verses; quote Gurmukhi only by copying verse text exactly; if they don't answer, say so."* Every Gurmukhi quote the model emits is **re-verified through `verify.py`** before display → hallucinated scripture is structurally impossible to surface.
   - **Model:** Qwen2.5-3B-Instruct `Q4_K_M` GGUF (~2 GB) default; don't go below Q4 (lower quant degrades the "use only these verses" constraint — a *safety* regression here). GGUF + vectors distributed **out-of-band** (never in git/LFS/DB).
5. **[M, later] Split core vs analytics SQLite via `ATTACH`** once the core nears ~150 MB — a mandatory small `sggs-core.sqlite` + an optional `sggs-analytics.sqlite`, leaning on serve.py's existing `try/except OperationalError` graceful-degradation pattern.

**Embedding storage math (for the eventual MiniLM run):** 58,039 × 384 dims → f32 = 89 MB (non-starter, bigger than the DB), **int8 = 22 MB** (recall >0.98, the sweet spot), binary = 2.8 MB (prefilter only). **Continue storing precomputed top-k (13 MB), not vectors, in the shipped DB**; if the RAG sidecar needs vectors, keep them in an out-of-band int8 memmap, never inside `sggs.sqlite`.

---

## Phase 3 — recommended first cut

Three shippable, independent slices — one from each workstream — that together move the app from "index" to "immersive study environment" without touching the sovereign core:

1. **Semantic Trail Reader (A2 + B3)** — the `/api/neighbors` endpoint already ships; this is the lowest-effort, highest-daily-use payoff and makes the new embeddings a living study tool inside the Reader.
2. **Contributor Timeline & Lineage Ribbon (B1)** — the headline "immersive" feature; closes the one data gap with a small hand-authored `contributors.json`; pure CSS/SVG, MPA-native.
3. **Cross-Contributor Resonance Map (A1)** — the marquee Insights artifact that uniquely exploits the 581k-edge `line_neighbors` table and tells the SGGS's most important story with hard data; one small `author_resonance` precompute.

Plus the **[S] CI sovereignty guard** as connective tissue — so every Phase 3 change is safe by construction.

---

*Prepared for Sam · Phase 2 delivered at v2.3.0 (offline semantic vectors + Insights dashboard). All Phase 3 initiatives preserve the verbatim-scripture and 100%-offline guarantees.*
