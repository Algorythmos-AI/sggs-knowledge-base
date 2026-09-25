---
title: "Contributing to the wiki"
description: "How to write, diagram, poster and widget for this wiki so the gates pass and the pages stay true: the page rules, the diagram rules, the poster kit, the widget contract, the docs job."
sidebar:
  order: 0
---
# Contributing to the wiki

The wiki is Markdown under `docs/`, reviewed in pull requests like code and rendered by
`docs-site/` ([ADR-0003](../adr/0003-docs-in-repo.md), [ADR-0012](../adr/0012-docs-site.md)).
Every page is also readable on GitHub, so nothing you write may depend on the site to make sense.
The repository-wide rules are in [CONTRIBUTING](../../CONTRIBUTING.md); these pages are the wiki's own.

| Page | When |
|---|---|
| [Writing a page](writing-docs.md) | any page: frontmatter, links, the scripture rule, terms, quizzes, verified stamps |
| [Adding a diagram](adding-a-diagram.md) | a Mermaid diagram in a page |
| [Adding a poster](adding-a-poster.md) | a large step-through picture |
| [Adding a widget](adding-a-widget.md) | anything interactive |
| [The docs gates](docs-gates.md) | what `make docs-check` and the docs job check, and how to read a failure |

Two rules above all: **scripture is never typed into a page**, and **the code is the truth** —
a page that describes code names the files it was read against, and the gates check what they
can.
