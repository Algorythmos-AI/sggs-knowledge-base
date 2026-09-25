---
title: "Modes and tiers"
description: "The six search modes a caller can ask for and the twelve tiers auto mode runs through, each with its entry condition, the index it queries and the mode string it reports."
sidebar:
  order: 1
verified:
  commit: 7a343c62
  date: "2026-09-25"
---
# Modes and tiers

`/api/search?q=&mode=&limit=&offset=` takes a query of at most 300 characters and a **mode**. The
response always has `mode` (which tier answered), `results` (verbatim lines with their [[Ang]], the
transliteration and the English layer attached) and `related_themes`; a theme answer adds
`concept`. `limit` is clamped to 0–200 and `offset` to 0–1,000,000, so a client can never dump the
corpus by accident.

## The modes

| `mode` | What it does | Falls back to |
|---|---|---|
| `auto` (default) | detects the script and runs the [waterfall](../architecture/search-waterfall.md) | every tier in order |
| `gurmukhi` | the verbatim `text` column (FTS) | the `skeleton` column with vowel signs stripped (`gurmukhi-skeleton`) |
| `roman` | the `translit` column (FTS) | the phonetic fold over `translit_norm` (`roman-spelling-tolerant`) |
| `first` | first letters of each word, as a phrase: `fl_g` for Gurmukhi, `fl_r` for Roman | — |
| `theme` | the concept index: the concept's lines, with its description and total | a `LIKE` over concept names and descriptions |
| `english` | the English translation layer, `fts_en` | — |

## The tiers of auto mode

<!-- sggs:waterfall q="waheguru ji" -->
On the rendered wiki this is the simulator: run a query and the tier that answered is named and lit
on the waterfall poster. On GitHub, the table below lists the same tiers.

| Tier | Entry condition | What it queries | `mode` |
|---|---|---|---|
| Mixed script | Gurmukhi **and** Latin in the query | `mixed_search` — one AND expression: Gurmukhi tokens on `text`, Latin tokens through variants, the lexicon and the fold; up to 10 tokens | `mixed-script` |
| Latin part alone | mixed script found nothing | the Latin tokens re-run through the waterfall | `mixed-script (latin part: …)` |
| Gurmukhi first letters | every token is one letter, ≥ 2 tokens | `fl_g` phrase | `first-letters` |
| Gurmukhi text | Gurmukhi query | `text` (FTS, bm25) | `gurmukhi` |
| Gurmukhi skeleton | text found nothing | vowel signs stripped, `skeleton LIKE` | `gurmukhi-skeleton` |
| Concept name | the query is exactly a concept key (`naam`, `haumai`, …) | the concept index | `theme` |
| Roman first letters | ≥ 2 tokens, all ≤ 3 letters | `fl_r` phrase, then `translit` | `first-letters`, `roman` |
| Transliteration | Roman query | `translit` (FTS, bm25) | `roman` |
| Seeker lexicon | nothing yet | a curated table: a word → a transliteration term or a theme | `seeker-lexicon (term)` |
| Variant index | nothing yet | per-token romanisation variants (≤ 3 by frequency × score), trailing-vowel retry, all-but-one AND | `variant-match` |
| English layer | nothing yet | `fts_en` — before the fold, so an English word reaches translations rather than colliding with a fold | `english-translation` |
| Honorifics dropped | nothing yet; `ji`, `jee`, `jeo`, `jio`, `sahib`, `maharaj`, `shri`, `sri`, `baba`, `guru`, `dev`, `waale` present; ≥ 2 tokens remain | the shorter query, through the waterfall | `… (honorifics dropped)` |
| Passage | nothing yet, ≥ 3 tokens | folded tokens AND in `fts_shabad`; the composition's lines returned in order | `passage-match (quote spans lines)` |
| Phonetic fold | nothing yet | `roman_norm(query)` tokens of ≥ 2 characters against `translit_norm`; headings excluded | `roman-spelling-tolerant` |
| Skeleton blob | nothing yet, ≤ 14 tokens, blob ≥ 8 characters | the query collapsed to one fold-skeleton blob; lines prefiltered by its head, fuzzy-ranked | `skeleton-blob` |
| Single-token theme | nothing yet, one token | the concept index | `theme` |
| Top-up | any tier, < 3 results, honorifics present | the honorific-dropped results appended | `… + honorific-dropped` |

## Ranking

Every FTS tier ranks with SQLite's `bm25` and column weights **10 · 5 · 4 · 3 · 3 · 1** for `text`,
`translit`, `translit_norm`, `fl_g`, `fl_r`, `skeleton`: the verbatim text outranks a
transliteration hit, which outranks the fold, which outranks first letters and the skeleton. The
passage tier ranks by the tightest span of matched lines, then bm25; the blob tier by fuzzy ratio.

## What a client should rely on

- `results[].gurmukhi` is verbatim and `results[].ang` is its Ang: cite them as
  *Sri Guru Granth Sahib Ji · Ang N*. `translit` is a reading aid; `en` is a labelled translation.
- `mode` is informational — it names the tier and may carry a suffix; do not parse it for logic.
- The search route is `no-store` (each query is answered afresh); reader routes are cacheable.
  See [Versioning and caching](../api/versioning-and-caching.md).
- Search is a **contract**: `contract/golden_search.ndjson` records real queries and their results,
  replayed by every deploy — see [Harnesses and golden vectors](harnesses-and-golden-vectors.md).
