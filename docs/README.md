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

## Start here
| If you want to… | Read |
|---|---|
| Join the project (engineer, intern, student) | [Start here — your first week](onboarding/README.md) |
| Understand the whole system in 5 minutes | [Architecture overview](architecture/overview.md) |
| Know how text fidelity is guaranteed | [Scripture integrity](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/scripture-integrity.md) (sggs-data) |
| Understand the data model & `comp_id` | [Database schema](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md) (sggs-data) |
| See how search works | [Search waterfall](architecture/search-waterfall.md) |
| Ship a change | [Branching](process/branching.md) · [Environments](process/environments.md) · [Release](process/release.md) |
| Rebuild the database | In [sggs-data](https://github.com/Algorythmos-AI/sggs-data) ([runbook](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/process/runbooks/rebuild-db.md)); here, bump `dataset.lock.json` |
| Know what CI checks and why | [CI gates](process/ci-gates.md) |
| Take the iOS app through TestFlight to the App Store | [`Algorythmos-AI/gurbani-soul-ios`](https://github.com/Algorythmos-AI/gurbani-soul-ios) (`docs/ios/`) |
| Understand a past decision | [ADRs](adr/) |

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
