# SGGS Knowledge Base — Engineering Wiki

An offline, sovereign, zero-dependency study application over the complete
**Sri Guru Granth Sahib Ji** (Angs 1–1430). A reproducible pipeline extracts the
source PDF into a verbatim corpus, builds a SQLite/FTS5 database, and a Python
standard-library server serves a prebuilt Astro site and a native iOS app.

> **Prime directive:** the Gurmukhi text is sacred and **verbatim**. It is never
> edited, normalized, or corrected. Every change is proven against the source PDF.
> See [Scripture integrity](architecture/scripture-integrity.md).

## Start here
| If you want to… | Read |
|---|---|
| Understand the whole system in 5 minutes | [Architecture overview](architecture/overview.md) |
| Know how text fidelity is guaranteed | [Scripture integrity](architecture/scripture-integrity.md) |
| Understand the data model & `comp_id` | [Database schema](architecture/database-schema.md) |
| See how search works | [Search waterfall](architecture/search-waterfall.md) |
| Ship a change | [Branching](process/branching.md) · [Environments](process/environments.md) · [Release](process/release.md) |
| Rebuild the database | [Runbook: rebuild-db](process/runbooks/rebuild-db.md) |
| Know what CI checks and why | [CI gates](process/ci-gates.md) |
| Take the iOS app through TestFlight to the App Store | [`Algorythmos-AI/gurbani-soul-ios`](https://github.com/Algorythmos-AI/gurbani-soul-ios) (`docs/ios/`) |
| Understand a past decision | [ADRs](adr/) |

## Repository at a glance
| Path | What |
|---|---|
| `corpus/sggs.jsonl` | Verbatim machine-readable corpus (source of truth for the DB). |
| `db/sggs.sqlite` | SQLite + FTS5, ~104 MiB, Git LFS, opened read-only by the app. |
| `pipeline/` | PDF → corpus → DB + enrichment + analytics + tests. |
| `webapp/serve.py` | Stdlib HTTP server + JSON API. |
| `frontend/` | Astro multi-page UI (build output synced into `webapp/static/`). |
| `contract/` | Golden vectors pinning the Swift port (vendored by the iOS app) to the Python source of truth. |

See also the [engineering handbook](engineering/README.md) and the migrated
audit history under [`docs/reports/`](reports/).
