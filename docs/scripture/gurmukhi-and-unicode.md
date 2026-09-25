---
title: "Gurmukhi and Unicode"
description: "The script of the Granth and its signs in Unicode: vowel signs, the sihari that prints before its consonant, the subjoined ya, the nasal signs, the dandas and ੴ — what the pipeline decodes."
sidebar:
  order: 5
verified:
  commit: 6332e947
  date: "2026-09-25"
---
# Gurmukhi and Unicode

> **Explanation, not scripture — scholar review pending (gate G3).** These pages explain the
> scripture to engineers and students. Every quoted line is verbatim from the pinned database and
> cited by Ang; everything else is explanation, written by engineers and awaiting a Granthi's
> review. Where this page and the scripture differ, the scripture is right.

Every stored line is **[[Gurmukhi]]** — the script the Gurus standardised for Punjabi — encoded in
the Unicode block U+0A00–U+0A7F. You do not have to read it to work here, but you do have to know
how its signs behave in Unicode, because that is where the pipeline's only transforms live and
where a careless string operation would alter scripture.

## Consonants, vowel signs, and where they sit

A Gurmukhi syllable is a consonant with an optional **[[Matra|vowel sign]]** attached
(`ਾ ਿ ੀ ੁ ੂ ੇ ੈ ੋ ੌ`) and optional nasal or other marks. Logical Unicode order is *consonant,
then signs*. One sign breaks the visual rule: the **[[Sihari]]** `ਿ` (short i) is *printed before*
the consonant it belongs to. A PDF extracts the printed order, so the pipeline moves each sihari
after its consonant cluster (`ਿਕ੍ਰਪਾ → ਕ੍ਰਿਪਾ`) — a decoding step, registered as rule D5 in the
[editorial ledger](../data/editorial-ledger.md). The `skeleton` search column strips all vowel
signs, which is why a typo-tolerant search still finds a line.

## Subjoined letters and the ya

The **[[Halant]]** `੍` joins a consonant to a subjoined one — `ਰ`, `ਹ`, `ਵ` and `ਯ` most often. The
source font emitted several of these as private-use glyphs and, for the
**[[Addha-yayya|subjoined ya]]** in Sahaskriti words, doubled the sequence (`੍ਯ੍ਯ`): 234 lines in
the corpus carry a subjoined ya. The text keeps what the Bir prints; the *traditional saroop*
display toggle on the website collapses the doubled ya in rendered glyphs only, and a copy-event
handler strips the display markup from anything you copy. The stored text, the API, search and the
app's database are untouched — the [[Saroop]] is a display layer, and the glossary says why its
rendering is a different, legitimate typographic tradition from the printed Bir's deep subscript.

## Nasal signs, nukta and editions

**[[Tippi|Tippi and bindi]]** — `ੰ` and `ਂ` — both mark nasalisation; 17,755 lines carry a tippi
and 1,817 a bindi in this edition. Editions differ in which they print for some words. The
project keeps its edition's choice and, in the Answer Protocol, *notes* an edition difference rather
than correcting it. The [[Nukta]] `਼` marks borrowed sounds and is kept wherever printed.

## Dandas, numerals and ੴ

The **[[Danda|double danda]]** `॥` closes a line or unit and carries the closing numerals (`॥੧॥`,
`॥੨॥`); 60,176 of the 60,658 lines end with one, and the pipeline cuts the page stream into
units on it. The numerals are Gurmukhi digits (`੦`–`੯`); the `markers` column keeps them as a list.
**[[ੴ]]** — Ik Onkar, U+0A74 — opens compositions and the Granth itself: 568 lines carry it, and
`/api/health` refuses a database with fewer than 560. The source font printed it as two glyphs;
restoring the single character is decoding rule D3.

## What the pipeline may do, and what it may not

| Allowed (registered decoding) | Never |
|---|---|
| move a sihari after its consonant cluster | "correct" a spelling, however obvious |
| restore a font glyph to the sign it printed | normalise editions to each other |
| restore ੴ from two glyphs to one | change a tippi to a bindi or back |
| re-attach a vowel sign split off by a stray space | delete or reorder a word |
| strip print-job timestamps and stray Latin from the PDF stream | add or remove a danda or a numeral |
| apply one of the four reviewed editorial rules | apply an unregistered transform of any kind |

Everything in the left column is an entry in the ledger; `ledger_check.py` fails a pull request in
sggs-data whose code and register disagree. Everything in the right column is a fidelity concern
for a scholar, never an edit.

## For your code

- Treat every `gurmukhi` value as opaque: never lower-case it, never strip it, never normalise
  beyond NFC for *comparison* (the verifier does that on its own copy).
- Escape it before it reaches `innerHTML` — the front-end's central escape helper does; use it.
- Render it with the bundled [[Sant Lipi]] font and `lang="pa"`; the site's theme keeps Gurmukhi
  ink-coloured, never the accent colour.
- Search keys — `text`, `translit`, `translit_norm`, `fl_g`, `skeleton` — are *derived* columns.
  Query them; never rebuild them from the text at request time.

## Check yourself

<!-- sggs:quiz -->
```quiz
Q: The sihari prints before its consonant. What does the pipeline store?
- The consonant first, then the sihari — logical Unicode order ✓ — the one reordering the pipeline performs, registered as rule D5
- The printed order, sihari first — that would not be valid logical Unicode and would break search
- Neither: it drops the sihari — no sign is ever dropped
Q: The website's traditional-saroop toggle collapses the doubled subjoined ya. Where?
- In rendered glyphs only ✓ — the stored text, the API, search and the copied text stay verbatim
- In the database — the app never writes the database
- In the API response — the API serves lines verbatim
Q: This edition prints a tippi where another prints a bindi. What does the project do?
- Keep its edition's sign and note the difference where known ✓ — editions are never normalised to each other
- Change it to the more common form — that would alter scripture
- Store both — a line is stored exactly once, as printed
```
Read next: [Transliteration and the fold](transliteration-and-the-fold.md).
