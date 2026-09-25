---
title: "ADR-0002: Fold heading runs into the composition, keeping the last heading's comp_id"
description: "Why a run of heading lines folds into the composition it opens, keeping the last heading's comp_id and leaving permanent gaps."
sidebar:
  order: 2
---
# ADR-0002: Fold heading runs into the composition, keeping the last heading's `comp_id`

**Status:** accepted (2026-09-15)

**Context.** Every heading line had its own `comp_id`, so a title line followed by
a separate `ੴ` invocation became an orphan one-line composition; the shabad sheet
never showed the printed title (e.g. Ang 712). 677 such orphans corpus-wide.

**Decision.** A run of consecutive heading lines opens ONE composition with the
body it introduces (`build_corpus.py` post-pass 1b). The run adopts the `comp_id`
of its **last** heading — the one already holding the body — so **no body line's
`comp_id` changes**; vacated ids become permanent gaps. Rejected the alternative
(contiguous renumber), which would break every stored bookmark/deep link.
Three closing rubrics are excluded and stay one-line comps.

**Consequences.** Distinct comps 5,380 → 4,706 with gaps; `max` stays 5,380.
Saved verses, Spotlight ids, deep links, and analytics keyed on `comp_id` remain
valid. Proven by `pipeline/verify_regroup.py` (scripture byte-identical).
