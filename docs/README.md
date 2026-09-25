---
title: "SGGS Knowledge Base — Engineering Wiki"
description: "Start here: what the SGGS Knowledge Base is, how its three repositories fit together, and where to read next."
sidebar:
  order: 0
---
# SGGS Knowledge Base — Engineering Wiki

An offline, sovereign, zero-dependency study application over the complete
**Sri Guru Granth Sahib Ji** (Angs 1–1430). A reproducible pipeline extracts the
source PDF into a verbatim corpus, builds a SQLite/FTS5 database, and a Python
standard-library server serves a prebuilt Astro site and a native iOS app.

> **Prime directive:** the Gurmukhi text is sacred and **verbatim**. It is never
> edited, normalized, or corrected. Every change is proven against the source PDF.
> See [Scripture integrity](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/scripture-integrity.md) (in sggs-data).

<!-- sggs:status -->
On the rendered wiki this line shows what production is serving right now — version, commit,
build date, dataset build and the health checks — read live from `/api/health`.

![Poster 01 — The system landscape: the people, the three surfaces (web, iOS, API), the one read-only API, the pinned database, and where the verbatim text comes from](diagrams/posters/01-system-landscape.svg)

## Ten minutes to your first search

1. Clone the platform: `git clone https://github.com/Algorythmos-AI/sggs-platform.git && cd sggs-platform`
2. `make doctor` — checks Python 3.12, Node 22 and whether the database is installed.
3. `make dataset` — downloads the pinned database (~104 MiB), verifies its sha256, installs it.
4. `cd webapp && python3 serve.py` — the API and the website on <http://localhost:7777>.
5. Search. Every line comes back verbatim, with its Ang — or try it here, against production:

<!-- sggs:waterfall q="sat nam" limit="3" -->
On the rendered wiki this is the search simulator: it runs the query against the live API and
lights the tier of the waterfall that answered. On GitHub, run
`curl -s 'http://localhost:7777/api/search?q=sat%20nam&limit=3'` after step 4.

The whole walk-through, with what to do when a step fails: [Run it locally](onboarding/run-it-locally.md).

## Choose your path

<!-- sggs:cards -->
- [Platform engineer](learning-paths/platform-engineer.md) — the API, the search and verification engines, the data pin and the delivery pipeline, in order.
- [Data engineer](learning-paths/data-engineer.md) — the line record, the corpus pipeline and its gates, the editorial ledger, and how a dataset reaches production.
- [iOS engineer](learning-paths/ios-engineer.md) — Gurbani Soul: the contract and parity, the database pair and launch integrity, Nitnem, and how the app takes a release.
- [Reviewer or scholar](learning-paths/reviewer-scholar.md) — what the project promises, where the text is proven, what a review checks, and how to say no.

## Start here
| If you want to… | Read |
|---|---|
| Join the project (engineer, intern, student) | [Start here — your first week](onboarding/README.md) |
| Follow a guided path, or do a hands-on exercise | [Learning paths](learning-paths/README.md) · [Exercises](exercises/README.md) · [Contributing to the wiki](contributing/README.md) |
| Learn what the scripture is before you touch the data | [Scripture 101](scripture/README.md) — what it is, its structure, the script and its Unicode, the Answer Protocol |
| Understand the whole system in 5 minutes | [Architecture overview](architecture/overview.md) |
| Know how text fidelity is guaranteed | [Scripture integrity](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/scripture-integrity.md) (sggs-data) · [The editorial ledger](data/editorial-ledger.md) |
| Understand the data model & `comp_id` | [Anatomy of a line record](data/line-record.md) · [Database schema](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md) (sggs-data) |
| See how search and verification work | [Search waterfall](architecture/search-waterfall.md) · [Search & verification](search/README.md) · [The API](api/README.md) |
| Ship a change | [Branching](process/branching.md) · [Environments](process/environments.md) · [Release](process/release.md) |
| Rebuild the database, or take a new dataset | [Corpus pipeline and gates](data/pipeline.md) · [The dataset pin](data/dataset-pin.md) · the [rebuild runbook](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/process/runbooks/rebuild-db.md) (sggs-data) |
| Know what CI checks and why | [CI gates](process/ci-gates.md) |
| Understand the iOS app, or take it through TestFlight to the App Store | [The iOS app](ios/README.md) · [How the app takes a release](ios/how-the-app-takes-a-release.md) · the pinned [launch plan](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/ios/testflight-launch-plan.md) |
| Understand a past decision, a release, or a path in the repository | [Decisions](adr/README.md) · [Releases](reference/releases.md) · [Repository map](reference/repo-map.md) |

## Latest changes

<!-- sggs:releases limit="3" -->
The newest releases, read from the changelog at build. Every release and what it changed:
[Releases](reference/releases.md) · the full [changelog on GitHub](https://github.com/Algorythmos-AI/sggs-platform/blob/integration/CHANGELOG.md).

## Repository at a glance
| Path | What |
|---|---|
| `dataset.lock.json` | The sggs-data commit + database sha256 this platform serves (`make dataset` installs it). |
| `webapp/serve.py` | Stdlib HTTP server + JSON API. |
| `frontend/` | Astro multi-page UI (build output synced into `webapp/static/`). |
| `tools/` | Golden-vector + OpenAPI generators, HTTP contract replay, search harnesses. |
| `contract/` | Golden vectors pinning the Swift port (vendored by the iOS app) to the Python source of truth. |

See also the [engineering handbook](engineering/README.md) and the migrated
audit history under [`docs/reports/`](reports/).
