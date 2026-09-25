---
title: "Adding a poster"
description: "A poster is generated from a declarative spec by the poster kit: nodes, edges, groups and steps with captions and links; the visual spec the gate enforces; the drift check."
sidebar:
  order: 3
---
# Adding a poster

Posters are the wiki's large step-through pictures. Each is generated from a spec in
`docs-site/posters/NN-slug.mjs` by `docs-site/posters/kit.mjs` into an SVG and a steps sidecar
under `docs/diagrams/posters/`; the generated files are committed and checked for drift. The full
visual spec and the node kinds are on [Diagrams and posters](../diagrams/README.md).

## Steps

1. Copy the nearest existing spec; take the next number and a slug.
2. Lay out `nodes` on the 1600-wide canvas: `x, y, w, h`, a `kind` (box, store, actor, gate, pin,
   ext, good, note), `lines` of text (18 px titles, 16 px detail, `mono: true` for code). A node
   can carry no text and a `title` instead (a scaled bar segment). Give each node and edge the
   `step` that introduces it.
3. Write `steps`: an id `step-NN`, a title, a caption a student can read on its own, and the page
   that explains it.
4. Name the files the poster was read against in `sources` (a pinned sibling file as
   `sggs-data/<path>`), and the commit in `verified`.
5. Generate and check:

   ```bash
   make posters
   cd docs-site && node scripts/build-posters.mjs --check
   ```

   The kit refuses text under 16 px, text wider than its box, a link inside the SVG, more than
   two footer lines; the gate refuses colours outside the palette, a missing title or description,
   a footer that names a missing file, a sidecar that disagrees with the step groups.
6. Embed it: `![Alt text](../diagrams/posters/NN-slug.svg)` in a paragraph of its own. On GitHub it
   is a picture; on the site, a walkthrough.
7. Look at it: light and dark, phone width, keyboard only (Tab to the poster, arrow keys step,
   *Full size* opens the lightbox, Escape closes). Run `make docs-e2e` for the posters suite.

## Facts

A poster states facts about code: read the files in `sources` before you write a caption, and
when a number can be checked by a test, add the check to `tools/docs_check.py` (the search modes
and verify thresholds are checked this way).
