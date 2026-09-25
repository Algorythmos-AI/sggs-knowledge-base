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
| verified stamps | a process, engineering or architecture page without one; (warning) code the page cites — a code excerpt, a linked source file, a poster's *Source of truth* — changed after its stamp, or, for a page that cites no code, a stamp 300 commits old |
| posters | the visual spec (legend included); a footer naming a missing file; a sidecar that disagrees with the step groups; a poster no page references |
| drift | a search `mode` the code reports that the waterfall page or poster 05 does not name; a verify threshold poster 07 does not state; a generated page without its header |
| site config | the `/api` rewrite, git deployments off, the CSP (inline scripts by hash only, never `'unsafe-inline'`), no `trailingSlash`, keys Vercel accepts, the sources lock's shape |
| theme | a brand colour in `docs-site/src/styles/theme.css` (paper, card, accent, accent text, accent fill, maroon, kraft, status colours; light and dark) that differs from `docs/brand/tokens.json` |

Pinned sibling pages are checked too, but what only their repository can fix (a palette colour,
a link to an unpinned file) is a notice, never an error.

## Generators and pins

`gen_route_table.py --check`, `gen_contributors.py --check` and `gen_repo_map.py --check` fail
when a generated page or the repository map is stale; `fetch_sibling_docs.py --check` fails when
a pinned file no longer matches its commit. Regenerate or re-pin; never edit a generated file.

## The build and after

`npm run typecheck` first; `npm run build` renders every Mermaid fence and every poster; then
`npm run check:all` — `check-render` (every page rendered completely — Astro logs a failed render
and exits 0), `check-mermaid`, `check-links` (every internal link and fragment in the built HTML),
`check-budget` (JS per page, largest page) and `check-csp`. Then Playwright with a mocked API on
desktop and phone, axe on **every page the build produced** (from the sitemap), and Lighthouse on
twenty pages. The e2e server (`scripts/serve-dist.mjs`) sends the headers `docs-site/vercel.json`
gives production, so every page runs under the real Content-Security-Policy.

### The CSP and its hashes

The site allows inline scripts by their sha256, never with `'unsafe-inline'`. Starlight and the
OpenAPI plugin inline a few small scripts (the theme picker, the sidebar, the search dialog); their
hashes are listed in `docs-site/vercel.json`. They change only when those packages do — so a
Starlight upgrade (often a Dependabot PR) turns `check-csp` red with the exact hashes. Then:

```bash
cd docs-site && npm run build && npm run csp:write
```

and review the diff: every new hash must belong to a script the upgrade brought. A script of your
own belongs in a module file under `src/`, not inline; an inline `on…=` handler or a
`javascript:` URL is refused outright.

## Reading a failure

Each message names the file and line and says what to do (`run: python3 tools/gen_route_table.py`,
`add it to include and run --update`). A red `docs` check on your pull request is one of these
messages, in the job's log, under the step that failed.
