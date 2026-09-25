---
title: "The Bhatts and the Swaiyye"
description: "The bards' praise-verses of the first five Gurus on Angs 1385–1409: who the Bhatts were, how each Swaiyya is attributed from its signature, and where the generic attribution stays."
sidebar:
  order: 4
verified:
  commit: 6332e947
  date: "2026-09-25"
---
# The Bhatts and the Swaiyye

> **Explanation, not scripture — scholar review pending (gate G3).** These pages explain the
> scripture to engineers and students. Every quoted line is verbatim from the pinned database and
> cited by Ang; everything else is explanation, written by engineers and awaiting a Granthi's
> review. Where this page and the scripture differ, the scripture is right.

The **[[Swaiyye]]** (Angs 1385–1409, 780 lines in the
database's `ਸਵਈਏ` section) are verses in praise of the first five Gurus. The first of them are Guru
Arjan Dev Ji's own; from Ang 1389 they are the work of the **[[Bhatt|Bhatts]]**, bards who came to
the Guru's court and sang what they saw. Eleven Bhatts are named in the tradition, and the corpus
attributes their lines like this:

| Bhatt | Angs | Lines |
|---|---|---|
| Bhatt Kalsahar | 1389–1408 | 279 |
| Bhatt Nal | 1398–1401 | 84 |
| Bhatt Mathura | 1404–1409 | 69 |
| The Bhatts | 1389–1410 | 54 |
| Bhatt Kirat | 1395–1406 | 40 |
| Bhatt Gayand | 1402–1404 | 38 |
| Bhatt Bal | 1405–1405 | 26 |
| Bhatt Jalap | 1394–1395 | 25 |
| Bhatt Sal | 1396–1406 | 18 |
| Bhatt Bhikha | 1395–1396 | 13 |
| Bhatt Haribans | 1409–1409 | 7 |
| Bhatt Bhal | 1396–1396 | 4 |

The row *The Bhatts* is the generic attribution: a verse whose signature names no single bard, or
whose attribution the review did not settle, keeps it rather than a guess.

## How a Swaiyya is attributed

A Swaiyya usually ends with the bard's name — the signature. The pipeline's third post-pass reads
`bhatt_attribution.json`, a table produced by a subject-matter audit and verified against those
signatures, and refines only rows that carry the generic Bhatt label (conservative by design:
nothing already attributed is changed). The table lives in sggs-data beside the pipeline; the
[corpus pipeline](../data/pipeline.md) page shows where the post-pass runs.

## Why this matters to an engineer

- **Author filters.** "Lines by Bhatt Kalsahar" is a query on `author`; a verse still under the
  generic label will not appear in it. Say so in any UI that filters by author.
- **Sahaskriti spelling.** The Swaiyye use Sanskritised forms with subjoined letters, which is
  where most of the editorial ledger's [applications](../data/editorial-ledger.md) fall (Angs 1398
  to 1409): the source font emitted impossible sequences in exactly these clusters.
- **Nothing is inferred at query time.** Attribution is a build-time fact of the corpus; the API
  never re-attributes.

Read next: [Gurmukhi and Unicode](gurmukhi-and-unicode.md).
