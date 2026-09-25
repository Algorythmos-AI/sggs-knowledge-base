---
title: "Writing a page"
description: "The rules a wiki page must meet: frontmatter, headings, relative links, the scripture rule, glossary terms, quizzes and code excerpts, verified stamps, and how a sibling page reaches the site."
sidebar:
  order: 1
---
# Writing a page

## Frontmatter and headings

Every page begins with `title` (8–120 characters) and `description` (40–200) and a body whose
first `# H1` equals the title (GitHub shows it; the site strips it). Order a section's pages with
`sidebar.order`. Pages under `docs/process/`, `docs/engineering/` and `docs/architecture/` must
carry `verified: {commit, date}` — the commit you last read the page against — and the gate warns
when a stamp falls sixty commits behind.

## Links

Write relative Markdown links as you would for GitHub (`../data/line-record.md#explore-real-records`).
The site turns them into page links, sends links to code files to GitHub at the right ref, and
turns a GitHub link to a document the wiki pins into the wiki page. Never a root-absolute `/…`
link, never `localhost`. Anchors are checked with GitHub's slug rules.

## The scripture rule

No verse is ever typed into a page. Scripture appears in exactly two ways: fetched live by a
widget, verbatim with its Ang; or as a cited blockquote whose last line is
`— Sri Guru Granth Sahib Ji · Ang N`, which the gate verifies against the pinned database line by
line. A run of Gurmukhi of four words or thirty characters outside a code span is refused; names
and tokens (`ਰਹਾਉ`, `ਮਃ`, a raag's name) go in code spans or stay short. Posters and diagrams carry
no scripture at all.

## Terms, quizzes and excerpts

- `[[Term]]` or `[[Term|as shown]]` makes a hover-card from the [glossary](../glossary.md); an
  unknown term fails the build. Add the term first.
- `<!-- sggs:quiz -->` followed by a ```quiz fence: `Q:` lines, `-` answers, one marked `✓`,
  optionally `— why`. It reads as text on GitHub.
- `<!-- sggs:code file="…" symbol="…" repo="…" -->` shows a function read from the source at
  build time; never paste code that could drift.

The full widget list is in `docs-site/plugins/widgets.schema.json`; every widget needs a fallback
sentence within three lines.

## Numbers

A number that describes the data or the code should come from it: generate the table, read the
constant, quote the test. Where that is not possible, name the file and the commit. The gates
check what they can (search modes, verify thresholds, generated pages); the rest is your
`verified` stamp.

## Sibling repositories

The data and app repositories' documents are published here by pin
(`docs-site/sources.lock.json`); to change one, edit it in its own repository, and bump the pin
with `python3 tools/fetch_sibling_docs.py --update <name>` in a small pull request here.

## Before the pull request

```bash
make docs-check    # every gate the docs job runs, in seconds
make docs          # the full build, with every Mermaid rendered and every link resolved
```
