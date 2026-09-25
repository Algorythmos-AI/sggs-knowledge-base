---
title: "Reverence checklist — working with sacred text as an engineer"
description: "Concrete habits for everyday engineering on Sri Guru Granth Sahib Ji: where scripture may come from, what may be done to it, how it is shown and cited, and what to do when something looks wrong."
sidebar:
  order: 5
---
# Reverence checklist — working with sacred text as an engineer

Sikhs treat Sri Guru Granth Sahib Ji as their living Guru. This project's users trust that what they
read on screen is exactly what is printed in the source edition. The checklist below is how that
trust survives contact with ordinary engineering: fixtures, refactors, screenshots, docs, tests.
It applies to everyone, whatever their own beliefs.

## Where scripture may come from

- **Only from the pinned database**, through the API or the corpus tools. Never from memory, a
  website, a screenshot, or a colleague's message.
- In the website and the app, text reaches the screen from `/api/ang`, `/api/shabad`, `/api/search`
  or `/api/lines`, verbatim, with its [[Ang]]. Keep it that way: no code path constructs, trims or
  "cleans" a line on the way.
- In tests and fixtures, refer to a line by **id and Ang** and read it from the database at test
  time, or quote it verbatim with its Ang as the fixture's source. Do not type [[Gurmukhi]] from
  memory into a fixture.
- In documentation, a verse appears only as a blockquote ending
  `— Sri Guru Granth Sahib Ji · Ang N`; the wiki's gate verifies that quote against the database.
  Names and titles (a bani, a raag, a `ਮਃ` header) may appear in prose or code spans.

## What may be done to it

- **Nothing** in storage, search indexing, copy, share or export: no normalisation, no
  "correcting" a matra, no reordering, no removal of dandas or numerals, no merging of lines.
- The only sanctioned transforms are those the data pipeline proves and logs (the PDF's visual to
  logical Unicode reordering and the editorial ledger's registered repairs, each reviewed by a
  scholar). They live in sggs-data, not here.
- **Display-only** transforms (the traditional-saroop rendering, the Sant Lipi font) change glyphs on
  screen and nothing else; the copied text stays verbatim. If you add one, prove the copied text is
  unchanged.
- [[Transliteration]] and English are **separate, labelled layers**. Never blend them into the Gurmukhi;
  never present a translation as the original.

## How it is shown and cited

- Cite as **Sri Guru Granth Sahib Ji · Ang N** — everywhere, in every surface. "Gurbani Soul" is
  the app's name, never the text's.
- Gurmukhi is rendered in Sant Lipi, ink-coloured, never in the brand gold or red, never as
  decoration.
- Explanation, summary or interpretation is always labelled as such and kept apart from the
  quotation ([answer protocol](https://github.com/Algorythmos-AI/sggs-data/blob/main/Answer-Protocol.md)).
- Screenshots and marketing images show real, verbatim, cited lines or none.

## When something looks wrong

- You will find things that look wrong: a repeated line (Ang 1256 is a genuine refrain), an odd
  Unicode sequence, a missing header, an unexpected author. **Assume the source is right and your
  expectation is wrong**, then check the source PDF page.
- If it still looks wrong, open a
  [scripture fidelity concern](https://github.com/Algorythmos-AI/sggs-platform/issues/new?template=scripture-fidelity.yml)
  with the Ang, the line id and what you expected. A Granthi or scholar decides; a change, if any,
  is made in sggs-data through the editorial ledger with a review.
- Never "fix" it in a branch, a fixture, a doc or a screenshot while you wait.

## Tone and language

- Write about the scripture and its authors respectfully and plainly. Use the names the project
  uses (the glossary has them). Avoid jokes, mascots or slang around the text.
- Interns and students are welcome to ask any question about the domain; there are no stupid
  questions here, only unverified claims. Verify before you assert.

## Before you open a pull request

- [ ] No Gurmukhi was typed by hand anywhere in the diff.
- [ ] No code path changes a line between the database and the screen, the clipboard or a file.
- [ ] Every quotation shown to a person carries its Ang.
- [ ] Any display-only transform is proven to leave copied text verbatim.
- [ ] Anything that looked wrong in the text became an issue, not a change.
