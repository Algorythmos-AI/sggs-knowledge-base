---
title: "Path: data engineer"
description: "For work on the corpus, the database, the gates or a dataset release: from the line record to the pipeline, the editorial ledger and the pin that carries a dataset to production."
sidebar:
  order: 2
---
# Path: data engineer

You will work in sggs-data, or take its releases here. Two days, in this order. The pipeline itself
runs only in the data repository; this platform consumes its output by pin.

<!-- sggs:progress path="data-engineer" -->
On the rendered wiki each step has a checkbox remembered in your browser; on GitHub, tick them in
your head.

1. Read the [reverence checklist](../onboarding/reverence-checklist.md), then all of
   [Scripture 101](../scripture/README.md) — the structure page with its poster, and Gurmukhi and
   Unicode with its quiz, most carefully.
2. [Run it locally](../onboarding/run-it-locally.md) — `make dataset` and `make dataset-check`.
3. [Data & pipeline](../data/README.md): the overview, then
   [anatomy of a line record](../data/line-record.md) with the Ang explorer.
4. [Corpus pipeline and gates](../data/pipeline.md) — walk poster 04 step by step; read the
   `fix_text` and `reconcile.py` excerpts.
5. [The editorial ledger](../data/editorial-ledger.md): the two kinds of transform, the eleven
   applications, how a concern travels.
6. The pinned canonical documents: [scripture integrity](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/scripture-integrity.md),
   the [database schema](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/database-schema.md), the
   [rebuild runbook](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/process/runbooks/rebuild-db.md).
7. [The dataset pin](../data/dataset-pin.md) — the lock, the fetcher's guarantees, the lock-bump flow.
8. **[Exercise 03 — bump a pin in a scratch branch](../exercises/03-bump-a-pin.md).**
9. [The Roman fold](../search/the-roman-fold.md) — because the index-time fold is yours.
10. [Harnesses and golden vectors](../search/harnesses-and-golden-vectors.md) — what a dataset
    change must not break, and how `make contract` proves it.
11. [The Answer Protocol for engineers](../scripture/answer-protocol-for-engineers.md).
12. **[Exercise 04 — write an ADR](../exercises/04-write-an-adr.md)** for a change to the data
    model you would propose.
13. [Engineering invariants](../engineering/invariants.md), the data bullets in particular.

When you are done you can say what `reconcile.py` proves and what it does not, why a rebuild
never edits the committed corpus until two gates pass, and what a scholar sees before any repair
reaches a reader.
