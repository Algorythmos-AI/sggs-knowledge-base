---
title: "Exercise 04: write an ADR"
description: "Record a decision the way this project does — context, decision, consequences, a status with a date — for a change you would propose, and learn what a good record leaves behind."
sidebar:
  order: 4
---
# Exercise 04: write an ADR

**Goal.** Write an architecture decision record that would pass review. **Needs.** a text editor.
30 minutes.

## 1. Read three

Read [ADR-0008](../adr/0008-dataset-by-pin.md) (short, one decision, consequences that name a
cost), [ADR-0006](../adr/0006-bani-registry-over-verbatim-corpus.md) (a numbered decision with
proof and gates) and [ADR-0012](../adr/0012-docs-site.md) (a decision that extends an earlier one
and says so). Note the shape: **Context** (what was true and what hurt), **Decision** (what is now
true, in the present tense), **Consequences** (what got better, what it costs, what it forbids).

## 2. Pick a decision

Something you actually believe the project should decide. Two starters if you need them:

- *The wiki's posters carry a `verified` commit; should every Mermaid diagram too?*
- *`/api/random` is `no-store`; should a seeded Hukam be cacheable for a day?*

## 3. Write it

Create `docs/adr/0013-<slug>.md` with the frontmatter the other records use (`title`,
`description`, `sidebar.order`), the H1 `ADR-0013: …`, a `**Status:** proposed (YYYY-MM-DD)` line,
and the three headings. Keep it under a page. Then run:

```bash
make docs-check
```

Expected: `0 error(s)` — the gate checks the frontmatter and every link you added. Open the
[Decisions](../adr/README.md) page on a local build (`make docs-dev`) and find your record on
the timeline with its status.

## 4. Decide what to do with it

If you meant it, open a pull request; the record's status becomes `accepted` with the merge
date. If it was practice, delete the file — but keep the habit.

## Self-check

<!-- sggs:quiz -->
```quiz
Q: A decision was made in a chat and everyone agreed. Does it need an ADR?
- Yes if a future engineer would need to know why the code is the way it is ✓ — the record is for the reader in a year, not for today
- No, the code is the record — code shows what, not why
- Only if it changes the API — the data model, the pipeline and the process all have records here
Q: An accepted ADR turns out to be wrong. What do you do?
- Write a new ADR that supersedes it and says so; leave the old one in place ✓ — records are never edited after acceptance
- Edit the old ADR to the new decision — that erases the history the record exists to keep
- Delete it — the numbering and the links would break, and the reasoning would be lost
```
