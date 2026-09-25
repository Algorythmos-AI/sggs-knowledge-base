---
title: "The Answer Protocol for engineers"
description: "The eight rules for answering a Gurbani question from this knowledge base — quote verbatim, cite the Ang, label explanation, never fabricate, verify by machine — and where the code enforces each."
sidebar:
  order: 7
verified:
  commit: 6332e947
  date: "2026-09-25"
---
# The Answer Protocol for engineers

> **Explanation, not scripture — scholar review pending (gate G3).** These pages explain the
> scripture to engineers and students. Every quoted line is verbatim from the pinned database and
> cited by Ang; everything else is explanation, written by engineers and awaiting a Granthi's
> review. Where this page and the scripture differ, the scripture is right.

The [Answer Protocol](https://github.com/Algorythmos-AI/sggs-data/blob/main/Answer-Protocol.md)
binds every session — human or assistant — that answers from this knowledge base. It is short.
This page restates its eight rules for an engineer and points at the code that enforces each,
so that a feature, a widget or a chat reply can be checked against them.

| # | Rule | Enforced by |
|---|---|---|
| 1 | **Quote only verbatim.** Every quoted line is retrieved from the corpus, never typed from memory, and carries its Ang (and raag or author where known). No re-spelling, no modernising, no paraphrase presented as scripture. | the read-only database; `/api/ang`, `/api/shabad`, `/api/lines`; the wiki's gate that verifies every cited line on these pages |
| 2 | **Bilingual presentation.** Gurmukhi line, then the transliteration in italics, then the Ang; an English explanation follows separately. | the reader and the widgets: Gurmukhi first, translit under it, the English layer labelled |
| 3 | **Interpretation is always labelled** — *Explanation (interpretation, not scripture)* — grounded in the retrieved verses, conservative, never presented as doctrine. | the banner on these pages; the app never "interprets" |
| 4 | **No fabrication.** If the corpus does not contain it, say so; never invent a line, an Ang or an attribution; show candidates when retrieval is ambiguous. | the verification engine's `NOT_FOUND` and `AMBIGUOUS` verdicts |
| 5 | **Search order:** exact Gurmukhi → transliteration → first letters → skeleton → theme. | the [search waterfall](../architecture/search-waterfall.md) |
| 6 | **Provenance.** Answers cite this edition; where editions differ, note it rather than "correct" it. | `/api/meta` names the edition; the editorial ledger registers every transform |
| 7 | **Reverence.** All content is sacred text; nothing flippant; disrespectful requests are declined politely and firmly. | the [reverence checklist](../onboarding/reverence-checklist.md); the code of conduct |
| 8 | **Machine verification before presenting a quotation.** Only `VERIFIED_EXACT` or `VERIFIED` may be presented as scripture; `PROBABLE` shows the canonical line instead of the claim; `NOT_FOUND` is disclosed. The Ang shown is the verifier's, never a remembered one. | `/api/verify` — the [verification engine](../search/verification-engine.md) |

## What this means when you build something

- **A widget shows only what the API returned.** The Ang explorer, the search simulator and the
  verify playground on this wiki render `gurmukhi` and `ang` from the response and nothing else;
  none of them holds a verse in its source.
- **A test fixture is a captured response.** The e2e fixtures are verbatim API captures with
  their Ang, never hand-written Gurmukhi.
- **A page quotes with a citation or not at all.** A verse-sized run of Gurmukhi in prose fails
  the docs gate; a blockquote must end with *— Sri Guru Granth Sahib Ji · Ang N* and is verified
  against the pinned database.
- **An answer to a person follows the eight rules above**, including rule 8: run the claim
  through `/api/verify` before you present it, and present the canonical line.

The canonical text of the protocol is pinned from sggs-data and published on this wiki with the
data pages.
