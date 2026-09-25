---
title: "Search & verification"
description: "How a seeker's query finds a line and how a quoted line is proven: the waterfall's modes and tiers, the Roman fold, the verification engine, and the harnesses and golden vectors that keep them honest."
sidebar:
  order: 0
verified:
  commit: 7a343c62
  date: "2026-09-25"
---
# Search & verification

Two engines, one rule: **the text is never guessed**. Search returns verbatim lines with their Ang
or nothing; verification returns a verdict with the canonical line or `NOT_FOUND`. Both fold Roman
input with the same function the database was built with, and both are pinned by golden vectors
that every deploy and the iOS app replay.

| Page | What you learn | Interactive |
|---|---|---|
| [Search waterfall](../architecture/search-waterfall.md) | The cascade as `do_search` codes it | Poster 05 · a simulator over the real API |
| [Modes and tiers](modes-and-tiers.md) | Each `mode` you can ask for, each tier's entry condition, what it queries, what it reports | The same simulator, focused on modes |
| [The Roman fold](the-roman-fold.md) | The five steps of `roman_norm` and why it lives in three repositories | Poster 06 · the function read from the source |
| [Verification engine](verification-engine.md) | The verdict ladder, the thresholds, the Ang modifier | Poster 07 · a playground over `/api/verify` |
| [Harnesses and golden vectors](harnesses-and-golden-vectors.md) | What roundtrip, casual-quote and chaos measure; what `make contract` pins | The contract files and their counts |

Search is the `search` bounded context (`/api/search`, `/api/word`); verification is the `verify`
context (`/api/verify`). Both are read-only over the immutable database — see the
[API routes](../api/routes.md).
