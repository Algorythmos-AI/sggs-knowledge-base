---
title: "What Sri Guru Granth Sahib Ji is"
description: "The scripture and eternal Guru of the Sikhs: what it is, the edition this project serves, the line it opens with, and the single rule that governs every byte of it here."
sidebar:
  order: 1
verified:
  commit: 6332e947
  date: "2026-09-25"
---
# What Sri Guru Granth Sahib Ji is

> **Explanation, not scripture — scholar review pending (gate G3).** These pages explain the
> scripture to engineers and students. Every quoted line is verbatim from the pinned database and
> cited by Ang; everything else is explanation, written by engineers and awaiting a Granthi's
> review. Where this page and the scripture differ, the scripture is right.

**Sri Guru Granth Sahib Ji** is the scripture of the Sikhs and, since 1708, their living Guru: the
Sikh tradition treats the text itself as the Guru, which is why it is always named in full, kept
with reverence, and never edited. It holds the hymns of six of the ten Sikh Gurus together with
those of saint-poets from several traditions — the [[Bhagat|Bhagats]] — and the praise-verses of
the [[Bhatt|Bhatts]], compiled by Guru Arjan Dev Ji in 1604 and completed by Guru Gobind Singh Ji.
The hymns are in Gurmukhi script in a range of languages, and they are meant to be sung: most of
the book is ordered by [[Raag|raag]], the musical mode.

Every copy has the same **1,430 [[Ang|Angs]]** — the word means "limb", used instead of "page" —
so a citation by Ang points to the same place in every printed volume. The project's citation
form is always the full name and the Ang: *Sri Guru Granth Sahib Ji · Ang N*.

## The opening line

The Granth opens with the [[Mool Mantar]], the statement of the One:

> ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ ਅਜੂਨੀ ਸੈਭੰ ਗੁਰ ਪ੍ਰਸਾਦਿ ॥
> *ik oankaar sat naam karataa purakh nirabhau niravair akaal moorat ajoonee saibhn gur prasaad*
> — Sri Guru Granth Sahib Ji · Ang 1

and [[Japji]] Sahib begins immediately after it, on the same Ang:

> ਆਦਿ ਸਚੁ ਜੁਗਾਦਿ ਸਚੁ ॥
> *aad sach jugaad sach*
> — Sri Guru Granth Sahib Ji · Ang 1

The first line is exactly what `/api/ang/1` returns as its first record — verbatim, with the Ang.
The transliteration under each line is a reading aid built by the pipeline, not scripture
([Transliteration and the fold](transliteration-and-the-fold.md)).

## This edition

The corpus reproduces one printed [[Bir]] — *Siri Guru Granth Sahib in Gurmukhi with Index (user PDF, 1483 pp)* — character for character:
sggs-data's `reconcile.py` proves the extracted text equals the PDF's text stream, and every
rebuild aborts on a single difference ([Corpus pipeline and gates](../data/pipeline.md)).
[[Edition|Editions]] differ in small typographic conventions (the spacing of some words, the
choice between the two nasal signs, the ligature used for the subjoined ya). The project does not
"correct" its edition to another; it records which edition it is and notes differences where they
are known.

## The one rule

> **The text is never altered.** Not corrected, normalised, paraphrased, reordered or guessed at —
> not in the corpus, the database, the API, the website, the app, search, copy or share. If a line
> looks wrong, it is flagged for a scholar and left as printed. The only transforms the pipeline
> applies decode the PDF font's glyph order into logical Unicode, and every one of them is
> registered and reviewed in the [editorial ledger](../data/editorial-ledger.md).

Everything else in the system follows from that rule: the character-exact proof, the pinned
dataset, the read-only database, the verification engine that never asserts a line it is unsure
of, the app that refuses to show scripture if its bundled database does not hash to the manifest,
and the wiki's own gate that verifies every quoted line on these pages against the database.

## Two questions

<!-- sggs:quiz -->
```quiz
Q: How many Angs does Sri Guru Granth Sahib Ji have?
- 1,430 ✓ — the same in every printed volume, which is why a citation by Ang is universal
- 1,483 — that is the page count of the source PDF, which includes an index
- 60,658 — that is the number of line records in the corpus
Q: A line in the corpus looks misspelled. What do you do?
- Flag it for a scholar and leave it as printed ✓ — the text is never altered; a confirmed repair is a reviewed ledger entry and a new dataset
- Fix the character in the database — never: the app never writes, and the corpus is proven against the PDF
- Fix it in the API response — the API serves the database verbatim
```
Read next: [The structure](structure.md).
