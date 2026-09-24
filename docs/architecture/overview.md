# Architecture Overview

## System context (C4 level 1)

```mermaid
flowchart TB
    reader([Sikh sangat / student]):::person
    granthi([Granthi / scholar]):::person
    subgraph SGGS[SGGS Knowledge Base]
        web[Astro web app]
        ios[iOS app]
        api[Stdlib API server]
    end
    pdf[(Source Bir PDF<br/>1,483 pp, offline)]:::ext
    shabados[(ShabadOS / BaniDB<br/>Khalsa English layer)]:::ext

    reader -->|search, read, study| web
    reader -->|search, read, offline| ios
    web -->|/api/*| api
    pdf -.->|reproducible pipeline<br/>char-exact| SGGS
    shabados -.->|labelled translation layer| api
    granthi -.->|reviews flagged text<br/>never edits| SGGS
    classDef person fill:#1a3a6b,color:#fff,stroke:#0d2340;
    classDef ext fill:#444,color:#fff,stroke:#222;
```

## Containers (C4 level 2)

```mermaid
flowchart LR
    subgraph build[Build time]
      PDF[(Bir PDF)] --> corpus[build_corpus.py<br/>+ sggs_pipeline.py]
      corpus --> jsonl[corpus/sggs.jsonl<br/>verbatim, SHA-pinned]
      jsonl -->|reconcile.py + golden_test.py<br/>GATES| db[build_db.py → SQLite/FTS5]
      db --> enrich[translations · variants · concepts<br/>analytics · vaars · timing]
      enrich --> sqlite[(db/sggs.sqlite<br/>Git LFS)]
      sqlite --> contract[gen_golden_vectors.py<br/>→ contract/*.ndjson]
      sqlite --> iosdb[build_ios_db.py<br/>→ ios/Resources/*.sqlite]
    end
    subgraph run[Run time]
      sqlite --> serve[webapp/serve.py<br/>read-only, mmap]
      serve --> static[Astro static MPA]
      static -->|/api/* same-origin| serve
      iosdb --> app[SwiftUI app<br/>GurbaniSearchKit]
      contract -.->|byte-parity tests| app
    end
    classDef gate fill:#7a1f1f,color:#fff;
```

## Deployment (production)

```mermaid
flowchart LR
    dev[git push main] --> vercel[Vercel<br/>static frontend]
    vercel -->|/api/* rewrite| render[Render<br/>Docker: serve.py + pinned DB]
    ios2[iOS archive] --> tf[TestFlight / App Store]
    classDef n fill:#1a3a6b,color:#fff;
```

The web frontend and API are **same-origin**: the browser calls `/api/*` and
Vercel rewrites those paths to the Render service, so there is no CORS and the
frontend carries no API-base configuration. A staging environment mirrors this
with a host-conditioned rewrite — see [Environments](../process/environments.md).

## The five layers
1. **Scripture core** — `lines` (60,658 verbatim rows), raags, sections, authors, vaars.
2. **Search indexes** — FTS5 (`fts`, `fts_en`, `fts_shabad`, `fts_tri`), `variants`, `word_freq`.
3. **Translations** — the Khalsa English layer, a separate labelled table (never blended into Gurmukhi).
4. **Analytics / Insight Engine** — theme network, stylometry, resonance, semantic neighbours.
5. **Knowledge layer** — attributed raag-timing claims (divergence preserved, never adjudicated).

## Source of truth vs generated
- **Source of truth:** the PDF; `validation/concepts_*.json`; `pipeline/timing/timing_seed.json`;
  `pipeline/translations/*.jsonl` (private — fetched from `Algorythmos-AI/sggs-source` by
  `scripts/data/fetch_translations.sh`, verified against `pipeline/translations.SHA256SUMS`); `webapp/serve.py` + `verify.py` + `romannorm.py` (the behaviour the Swift port mirrors); all `frontend/src/` and `ios/App/Sources/`.
- **Generated:** `corpus/sggs.jsonl` (committed, SHA-pinned), `db/sggs.sqlite`, `contract/*.ndjson`, `frontend/dist/`, `webapp/static/` (and, in the app repository, `ios/Resources/*.sqlite`).

See [microservices roadmap](microservices-roadmap.md) for how the monolith is
factored for a later service split.
