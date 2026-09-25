---
title: "The docs gates"
description: "What make docs-check and the docs job check on every pull request — frontmatter, links, widgets, the scripture rule, posters, stamps, drift, generated pages, pins, build, e2e, axe, Lighthouse."
sidebar:
  order: 5
---
# The docs gates

The wiki is gated like the product. Locally, `make docs-check` runs the fast gates in seconds and
`make docs` the full build; in CI the `docs` job of `deploy-docs.yml` runs both on every pull
request and is a **required check on `integration`**.

## `tools/docs_check.py`

| Check | Fails when |
|---|---|
| frontmatter | `title` or `description` missing or the wrong length; the H1 differs from the title |
| links | a relative link or anchor does not resolve on disk; a root-absolute or localhost link |
| widgets | an unknown widget or attribute; no fallback sentence within three lines; a code excerpt's file or symbol missing |
| Mermaid | a colour outside the palette; an `%%{init}` directive; (warning) no `accTitle` |
| scripture | a verse-sized run of Gurmukhi outside a code span; a blockquote without the citation; a cited line that is not verbatim in the pinned database |
| terms | `[[Term]]` names no glossary row |
| verified stamps | a process, engineering or architecture page without one; (warning) a stamp sixty commits behind |
| posters | the visual spec; a footer naming a missing file; a sidecar that disagrees with the step groups; a poster no page references |
| drift | a search `mode` the code reports that the waterfall page or poster 05 does not name; a verify threshold poster 07 does not state; a generated page without its header |
| site config | the `/api` rewrite, git deployments off, the CSP, the sources lock's shape |

Pinned sibling pages are checked too, but what only their repository can fix (a palette colour,
a link to an unpinned file) is a notice, never an error.

## Generators and pins

`gen_route_table.py --check`, `gen_contributors.py --check` and `gen_repo_map.py --check` fail
when a generated page or the repository map is stale; `fetch_sibling_docs.py --check` fails when
a pinned file no longer matches its commit. Regenerate or re-pin; never edit a generated file.

## The build and after

`npm run build` renders every Mermaid fence and every poster; then `check-render` (every page
rendered completely — Astro logs a failed render and exits 0), `check-mermaid`, `check-links`
(every internal link and fragment in the built HTML) and `check-budget` (JS per page, largest page).
Then Playwright with a mocked API on desktop and phone, axe on every new page, and Lighthouse on
five pages.

## Reading a failure

Each message names the file and line and says what to do (`run: python3 tools/gen_route_table.py`,
`add it to include and run --update`). A red `docs` check on your pull request is one of these
messages, in the job's log, under the step that failed.
