---
title: "Architecture Overview"
description: "The system in one page: who uses it, the containers across three repositories, production deployment and the five data layers."
sidebar:
  order: 1
verified:
  commit: df4bff43
  date: "2026-09-26"
---
# Architecture Overview

The whole system on one poster — press *Next* on the site to build it up step by step:

![Poster 01 — the system landscape: people, surfaces, API, pinned database, sources, CI](../diagrams/posters/01-system-landscape.svg)

## System context (C4 level 1)

```mermaid
flowchart TB
    accTitle: System context
    accDescr: Readers and scholars use the web app and the iOS app; both read the stdlib API. The source Bir PDF feeds the reproducible pipeline; the ShabadOS English layer is attached, labelled, to the API.
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
    classDef person fill:#8A1538,color:#FFFFFF,stroke:#8A1538;
    classDef ext fill:#B69A81,color:#201A12,stroke:#B69A81;
```

## Containers (C4 level 2)

```mermaid
flowchart LR
    accTitle: Containers across the three repositories
    accDescr: sggs-data builds the corpus and the SQLite database from the PDF through the reconcile and golden gates; this repository pins that database and serves it through serve.py and the Astro site; gurbani-soul-ios bundles a database built from it and vendors the golden contract.
    subgraph data[sggs-data — build time]
      PDF[(Bir PDF)] --> corpus[build_corpus.py<br/>+ sggs_pipeline.py]
      corpus --> jsonl[corpus/sggs.jsonl<br/>verbatim, SHA-pinned]
      jsonl -->|reconcile.py + golden_test.py<br/>GATES| db[build_db.py → SQLite/FTS5]
      db --> enrich[translations · variants · concepts<br/>analytics · vaars · timing]
      enrich --> sqlite[(db/sggs.sqlite<br/>published by commit + sha256)]
    end
    subgraph platform[this repository]
      lock[dataset.lock.json] -.->|pins| sqlite
      sqlite -->|fetch_dataset.py<br/>sha256-verified| serve[webapp/serve.py<br/>read-only, mmap]
      serve --> contract[tools/gen_golden_vectors.py<br/>→ contract/*.ndjson]
      serve --> static[Astro static MPA]
      static -->|/api/* same-origin| serve
    end
    subgraph ios[gurbani-soul-ios]
      sqlite --> iosdb[build_ios_db.py<br/>→ ios/Resources/*.sqlite]
      iosdb --> app[SwiftUI app<br/>GurbaniSearchKit]
      contract -.->|vendored; byte-parity tests| app
    end
    classDef gate fill:#B33528,color:#FFFFFF,stroke:#B33528;
```

## Deployment (production)

```mermaid
flowchart LR
    accTitle: Production deployment
    accDescr: A push to main deploys one Vercel project holding the static frontend and the API as Python functions; /api is rewritten internally to the all function, which serves the pinned database; the Render single API stays deployed as the rollback target; the iOS archive ships through TestFlight to the App Store.
    dev[git push main] --> vercel[Vercel<br/>static frontend + API functions]
    vercel -->|/api/* internal rewrite| fn[function all<br/>serve.py + pinned DB]
    vercel -.->|rollback: api_platform render| render[Render<br/>the single API, kept deployed]
    ios2[iOS archive] --> tf[TestFlight / App Store]
    classDef n fill:#FDF6E3,color:#201A12,stroke:#A87900;
```

The web frontend and API are **same-origin**: the browser calls `/api/*` and Vercel's internal
rewrites send those paths to the API, which runs as Python functions in the same Vercel project
([ADR-0011](../adr/0011-api-as-functions-in-the-web-project.md)) — in production the whole API as
one function, `all`. There is no CORS and the frontend carries no API-base configuration.
`gateway/routes.json` decides this per environment: setting production's `api_platform` back to
`render` proxies `/api` to the Render single API, which every release still deploys as the rollback
target. Staging routes each bounded context to its own function — see
[Environments](../process/environments.md) and [bounded contexts](bounded-contexts-and-gateway.md).

## The five layers
1. **Scripture core** — `lines` (60,658 verbatim rows), raags, sections, authors, vaars.
2. **Search indexes** — [[FTS5]] (`fts`, `fts_en`, `fts_shabad`, `fts_tri`), `variants`, `word_freq`.
3. **Translations** — the Khalsa English layer, a separate labelled table (never blended into [[Gurmukhi]]).
4. **Analytics / Insight Engine** — theme network, stylometry, resonance, semantic neighbours.
5. **Knowledge layer** — attributed raag-timing claims (divergence preserved, never adjudicated).

## Source of truth vs generated
- **In sggs-data:** the PDF-derived corpus and database, the timing seed, the concept definitions and
  the private translation inputs (fetched from `Algorythmos-AI/sggs-source`, checksum-verified).
- **Here, source of truth:** `webapp/serve.py` + `verify.py` + `romannorm.py` (the behaviour the Swift
  port mirrors), `frontend/src/`, and `dataset.lock.json` (which database is served).
- **Here, generated:** `contract/*.ndjson` + `contract/openapi.json`, `frontend/dist/`, `webapp/static/`;
  `db/sggs.sqlite` is installed from the pin, never committed.

See [microservices roadmap](microservices-roadmap.md) for how the monolith is
factored for a later service split.
