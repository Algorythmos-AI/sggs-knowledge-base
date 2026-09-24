# Semantic Vector Search — Feasibility Report (Agent 3)

**For:** SGGS Knowledge Base · **Date:** 2026-06-13 · **Status:** decision-ready, no code written yet.

## Question

Can we add local semantic ("meaning-based") search — e.g. `sentence-transformers/all-MiniLM-L6-v2` (384-dim, Apache-2.0) — **without** breaking the project's founding invariant: a **zero-dependency, Python-stdlib-only runtime server**?

## The one fact that decides everything

Live semantic search has two halves: (1) embed the corpus, and (2) **embed the user's query at request time**. Half (1) is offline and harmless. **Half (2) requires running the transformer model inside `serve.py`** — which means importing `torch` (~2 GB) or `onnxruntime` + a ~23 MB model into the server. That directly violates the stdlib-only runtime, adds 45–500 MB resident RAM, 2–15 s startup, and a brand-new hard-failure surface (missing/incompatible model). The constraint is architectural, not just "a library isn't installed."

## Storage math (58,039 English translation lines)

| Artifact | Size | Note |
|---|---|---|
| float32 embedding matrix (58,039 × 384 × 4B) | **85 MB** | nearly **doubles** the 86 MB DB |
| int8 quantized matrix | 21 MB | still +27 MB as SQLite BLOBs |
| **Pre-computed neighbors table (top-K=10)** | **~9 MB** | **recommended** — pure SQL rows, no BLOBs |
| Offline build time (CPU, one-time) | ~3–4 min | runtime unaffected |

## Options vs. the sovereign architecture

| Option | Runtime deps | Runtime RAM | Latency | Fit |
|---|---|---|---|---|
| 1. numpy in-memory cosine | numpy + model | 45–175 MB | 15–70 ms | ✗ imports non-stdlib into serve.py |
| 2. `sqlite-vec` extension | C ext + model | lean | 5–20 ms | ✗ still needs the model for query embedding |
| **3. Pre-computed `line_neighbors` table** | **none** | **none** | **< 1 ms (PK SELECT)** | ✅ **perfect fit** |
| 4. Optional isolated micro-service | model (separate process) | separate | 15–70 ms | ✅ for Phase 2, opt-in only |

## Language-surface caveat

MiniLM is English-centric. Gurmukhi/transliteration would embed as near-noise. The only sensible surface is the **English translation** — so any similarity reflects the *translation* (Dr. Sant Singh Khalsa), not the Gurmukhi prosody/roots, and must be labeled **"semantically similar in translation,"** never "theologically related."

## Recommendation

- **Phase 1 (optional, ship-ready):** build a `line_neighbors` table **offline** (embed once, store top-K similar `line_id`s). Runtime stays stdlib-only; a `GET /api/neighbors?line_id=N` endpoint is a 3-line `SELECT`. Cost: **+9 MB**, **zero runtime deps/RAM**. This is the only option that adds genuine semantic similarity while preserving every architectural invariant.
- **Phase 2 (later, opt-in):** an isolated `semantic_server.py` micro-service for live free-text semantic queries, gated by an env-var; the core server never imports it.
- **Reject** numpy-in-memory and sqlite-vec **for the core server** (they break the stdlib-only runtime).
- **Do not** ship raw embeddings inside the main DB (size/LFS); if ever needed, a separate `sggs_embeddings.sqlite` keeps the core DB's checksum stable.

**Bottom line:** semantic *similarity* is fully compatible with the sovereign design **if precomputed offline**; live query-time semantic *search* is not, and belongs in an opt-in side-car. Recommended Phase-1 footprint if approved: +9 MB, no new runtime dependencies.
