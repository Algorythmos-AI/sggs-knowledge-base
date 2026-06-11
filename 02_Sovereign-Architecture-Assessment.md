# Sovereign Gurbani Corpus — Truth Assessment & Roadmap (v1.4.0, 2026-06-10)

Four SME agents investigated your 5-layer "Sovereign Corpus" architecture against what exists. Full reports in `validation/sovereign_*.md`. This is the honest synthesis.

## 1. The verdict per layer

| Layer (target) | Truth today | Decision |
|---|---|---|
| **L1 Canonical data** — Postgres + versioning + multi-corpus | SGGS corpus is *stronger* than target (char-for-char reconciled, versioned builds). **Postgres adds nothing at 60k rows** — SQLite FTS5 is the right engine until this becomes a multi-user server. The real gap is breadth: Bhai Gurdas, Kosh, Steek are absent. | **Keep SQLite. Expand corpus per §3 when you say go.** |
| **L2 Search** — BM25 + embeddings + reranker | FTS5 *has* BM25 — we now rank with it (shipped, v1.4.0). Embeddings measured honestly: every zero-install option is weak (bag-of-words, 20-40% OOV on archaic vocabulary); runtime models break your no-install constraint. **Concept expansion beat embeddings in measurement: +73% recall (naam) to +1,003% (prem_pyar)** — and the 53-theme index already does it. Related-theme hints now surface in search (shipped). | **BM25 + themes now; embeddings only as a future optional module.** |
| **L3 Verification** — rule engine + confidence | Build-time verification was already world-class (reconciliation, canonical invariants). The missing piece was **runtime** verification — now shipped: `/api/verify` + a "Verify quote" mode. Cascade: exact → normalized → skeleton → roman-norm → fuzzy; verdicts VERIFIED_EXACT/VERIFIED/PROBABLE/AMBIGUOUS/NOT_FOUND + Ang cross-check; 7/7 adversarial tests incl. fabricated-line and Ardas negative controls; <14ms. | **Shipped. This is your "Answer → Compare with SGGS → Check Ang → Confidence" loop, as an API.** |
| **L4 Explanation** — LLM explains only | `Answer-Protocol.md` already mandates verbatim-quote-first. The gap was enforcement: now any Claude session (or other LLM) can be *required* to pass its quotes through `/api/verify` before showing them. Protocol updated. | **Shipped (protocol + machine check).** |
| **L5 Governance** — citations, source tracking, review | Citations mandatory (protocol); single-source provenance in meta. Added: `MANIFEST.json` (sha-256 of corpus + DB, counts, version) and `CHANGELOG.md`. Human review = the flagged-anomaly logs + `validation/` reports. | **Shipped (manifest + changelog).** |

## 2. What we deliberately did NOT do, and why

- **Postgres** — at 60,658 rows with <50ms p95, it buys zero capability and costs you a database server to babysit. Revisit only if this becomes a hosted multi-user service.
- **Runtime embeddings** — every honest path breaks the "double-click and it runs" guarantee (430MB+ of model+torch, or compiled extensions). The measured semantic gain over BM25+themes+spelling-tolerance was marginal for line-level Gurbani retrieval.
- **Machine-translating the corpus to English/Hindi/French** — generated translations stored next to scripture would blur the very scripture/interpretation boundary your Layer 4 exists to protect. Translations should be *ingested from attributed human sources*, not fabricated.

## 3. Corpus expansion — the rights-checked menu (your call on each)

| Source | Rights (personal local use) | Effort | Recommendation |
|---|---|---|---|
| **BaniDB dataset** (Gurmukhi + Roman + **Sant Singh Khalsa English** + Punjabi glosses, line-aligned) | OK with attribution (personal, non-commercial) | S | **Best next step** — gives the English layer + a second source to cross-verify our extraction line-by-line |
| **Bhai Gurdas Vaaran + Kabit Savaiye** | Public domain | S | Recommended — the classical "key" to SGGS |
| **Sahib Singh's Darpan** (Punjabi steek) | Personal-use OK (no formal license) | M | Recommended, never republish |
| **Mahan Kosh** (1930, PD) | Public domain | L (OCR/parsing) | Worthwhile, but a project of its own |
| **Hindi translation** | Personal-use OK | M | If Hindi search matters to you |
| **French** | One Archive.org upload, rights unclear, noisy OCR | M | Skip for now |
| **Dasam Granth** | Text available (PD) | M | **Community-sensitive scope decision — entirely yours; not proceeding without your explicit instruction** |

Architecture for expansion (designed, not yet built): each source becomes its own table + source registry row (`source_id, edition, license, ingest_date, checksum`); search федерates across sources with a source filter; SGGS remains the only "canonical scripture" class — everything else is tagged commentary/translation/reference and renders visually subordinate. Per your fidelity rules.

## 4. Multilingual reality check

Users searching `satgur daya kare` / `ਸਤਿਗੁਰੁ ਦਇਆ ਕਰੇ` already resolve to the same lines through the unified layer (Gurmukhi FTS + translit + translit_norm consonant skeleton). "satguru mercy line" (English *meaning* search) requires the English translation layer (BaniDB ingest, §3) — then English FTS slots into the same unified query layer with zero architecture change.

## 5. Shipped in v1.4.0 (this round)

BM25 relevance ranking (weighted across all six index columns, graceful fallback) · related-theme hints on Gurmukhi searches · `/api/verify` + **Verify quote** UI mode with color-coded verdict card and `@ang` checking · `MANIFEST.json` + `CHANGELOG.md` · Answer-Protocol updated to require machine verification of quotes.
