---
title: "Exercise 05: fix a poster"
description: "Change one caption in a poster spec, regenerate the poster, see the drift check pass and the walkthrough update — and learn why a poster is generated from a spec and pinned to the code it describes."
sidebar:
  order: 5
---
# Exercise 05: fix a poster

**Goal.** Make a small, correct improvement to a poster and see every check that keeps posters
honest. **Needs.** the local setup with `docs-site` dependencies (`make docs` once). 30 minutes.

## 1. Find something to improve

Open any poster page — [the request lifecycle](../architecture/request-lifecycle.md) is a good
one — and walk it with *Next*. Find a caption that could be clearer, or a fact you can check
against the file its footer names. (If you find a fact that is *wrong*, that is a bug: open an
issue and fix it for real.)

## 2. Edit the spec, not the picture

Posters are generated: never edit `docs/diagrams/posters/*.svg` by hand. Edit the spec —
`docs-site/posters/08-request-lifecycle.mjs` for that poster — change the caption in `steps`, and
regenerate:

```bash
make posters
git status --short docs/diagrams/posters
```

Expected: the poster's `.svg` and `.steps.json` show as modified. Now the drift check:

```bash
cd docs-site && node scripts/build-posters.mjs --check
```

Expected: `build-posters: every poster is current`. Try the reverse: edit the `.steps.json` by hand
and run the check again — it reports the file as stale, because the spec is the source of truth.
Regenerate to fix it.

## 3. See it

```bash
make docs-dev
```

Open the page, press *Next* to your step, and read your caption. Then run the gate the pull
request would run:

```bash
make docs-check
```

Expected: `0 error(s)`. If you made the text too wide for its box, `make posters` told you already
— the kit refuses text that overflows or is smaller than 16 px.

## Self-check

<!-- sggs:quiz -->
```quiz
Q: You want to change a poster. What do you edit?
- The spec in docs-site/posters/ and regenerate ✓ — the SVG and the steps sidecar are generated and checked for drift
- The SVG in docs/diagrams/posters/ — the drift check would report it stale
- The steps JSON only — same; the spec is the source of truth
Q: A poster's footer names a file that has been deleted. Who notices?
- tools/docs_check.py, on every pull request ✓ — a footer must name files that exist (or files pinned from a sibling)
- Nobody; footers are decoration — the footer is the poster's claim of what it was read against
- The lightbox — the lightbox only zooms
```
