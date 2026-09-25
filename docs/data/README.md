---
title: "Data & pipeline"
description: "Where the scripture data comes from, how it is proven, how it reaches this platform by pin, and which pages explain each part — with the canonical sggs-data documents published beside them."
sidebar:
  order: 0
verified:
  commit: fe1ff7df
  date: "2026-09-25"
---
# Data & pipeline

Everything the API serves comes from one artifact: a SQLite database of **60,658 line records over
Angs 1–1430**, built by a reproducible pipeline from the source Bir PDF and proven, character for
character, to contain exactly the printed text. That artifact is built, gated and published in the
data repository, [`Algorythmos-AI/sggs-data`](https://github.com/Algorythmos-AI/sggs-data); this
platform never edits it and never commits a copy — it **pins** a commit and a checksum
(`dataset.lock.json`) and installs exactly that object.

> **Prime directive.** The Gurmukhi is sacred and verbatim. Nothing in this platform, and nothing
> described on these pages, rewrites it. The two sanctioned kinds of transform — decoding the PDF
> font's glyph order into logical Unicode, and a handful of scholar-reviewed repairs of impossible
> sequences the font emitted — are registered in the [editorial ledger](editorial-ledger.md) and
> enforced by a gate in sggs-data.

## The four pages

| Page | What you learn | Interactive |
|---|---|---|
| [Anatomy of a line record](line-record.md) | The 23 columns of the `lines` table, how a page becomes rows, what search reads | Poster 03 walkthrough · a live Ang explorer against the real API |
| [Corpus pipeline and gates](pipeline.md) | `rebuild_all.sh` stage by stage, and the gates that stop it | Poster 04 walkthrough · code read from sggs-data at the pinned commit |
| [The dataset pin](dataset-pin.md) | How this platform obtains the database, what it verifies, how a new dataset arrives | The lock, the fetcher's guarantees, a pin bump end to end |
| [The editorial ledger](editorial-ledger.md) | What may change in the text, what never does, and how a fidelity concern travels | The rules and their applications, the review flow |

## Pinned from sggs-data

The canonical data documents live in the data repository. The wiki publishes them here **by pin**
(`docs-site/sources.lock.json` records the commit and the sha256 of every file), with a banner that
says where the canonical file is; edit them there.

| Document | Canonical file |
|---|---|
| Database schema and the `comp_id` model | [docs/architecture/database-schema.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md) |
| Scripture integrity: the guarantee chain, the proof tools, the hash chain | [docs/architecture/scripture-integrity.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/scripture-integrity.md) |
| Runbook: rebuild the database from the PDF | [docs/process/runbooks/rebuild-db.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/process/runbooks/rebuild-db.md) |
| Runbook: restore the data from backups | [docs/process/runbooks/data-restore.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/process/runbooks/data-restore.md) |
| ADR-0002 · keep-last `comp_id` regroup | [docs/adr/0002-comp-id-keep-last-regroup.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/adr/0002-comp-id-keep-last-regroup.md) |
| ADR-0003 · integrity proofs | [docs/adr/0003-integrity-proofs.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/adr/0003-integrity-proofs.md) |
| ADR-0004 · backups and restore | [docs/adr/0004-backups-and-restore.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/adr/0004-backups-and-restore.md) |
| The Answer Protocol: how Gurbani questions are answered | [Answer-Protocol.md](https://github.com/Algorythmos-AI/sggs-data/blob/main/Answer-Protocol.md) |

## The numbers that never drift

| Fact | Value | Proven by |
|---|---|---|
| Line records | 60,658 | `data_quality.py` (sggs-data), `/api/health` |
| Angs | 1–1430, gap-free | `golden_test.py`, `/api/health` |
| Compositions (`comp_id`) | 4,706 distinct; `max(comp_id)` 5,380; gaps permanent | `verify_regroup.py --invariants` |
| Vaars | 22, detected by title header | `build_vaars.py` |
| Editorial rules / applications | 4 / 11, all reviewed | `ledger_check.py` |
| Dataset served | `dataset.lock.json` → commit, sha256, size | `make dataset-check`, the `scripture-integrity` workflow |

Read next: [Anatomy of a line record](line-record.md).
