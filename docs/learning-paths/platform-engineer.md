---
title: "Path: platform engineer"
description: "From the one rule to a merged pull request: the pages and exercises that take an engineer through the API, the search and verification engines, the data pin and the delivery pipeline, in order."
sidebar:
  order: 1
---
# Path: platform engineer

You will change `webapp/`, `frontend/`, `tools/` or the wiki. Two days, in this order.

<!-- sggs:progress path="platform-engineer" -->
On the rendered wiki each step has a checkbox remembered in your browser; on GitHub, tick them in
your head.

1. Read the [reverence checklist](../onboarding/reverence-checklist.md) and
   [what Sri Guru Granth Sahib Ji is](../scripture/what-sggs-is.md) — the one rule, in your words.
2. [Run it locally](../onboarding/run-it-locally.md): `make doctor`, `make dataset`,
   `python3 webapp/serve.py`, and open `/api/health`.
3. [How the three repositories fit](../onboarding/how-the-repos-fit.md) and
   [the dataset pin](../data/dataset-pin.md): where the database comes from and why you never edit it.
4. [Architecture overview](../architecture/overview.md), then the
   [request lifecycle](../architecture/request-lifecycle.md) and
   [bounded contexts and the gateway](../architecture/bounded-contexts-and-gateway.md).
5. [Anatomy of a line record](../data/line-record.md) — use the Ang explorer on Angs 1, 712 and 1256.
6. [The search waterfall](../architecture/search-waterfall.md), then
   [modes and tiers](../search/modes-and-tiers.md) and [the Roman fold](../search/the-roman-fold.md).
7. **[Exercise 01 — trace a search](../exercises/01-trace-a-search.md).**
8. [The verification engine](../search/verification-engine.md) and
   [harnesses and golden vectors](../search/harnesses-and-golden-vectors.md).
9. [The JSON API](../api/README.md), [API routes](../api/routes.md),
   [contract and OpenAPI](../api/contract-and-openapi.md), [versioning and caching](../api/versioning-and-caching.md).
10. **[Exercise 02 — add a route and watch the gates](../exercises/02-add-a-route.md).**
11. [Engineering invariants](../engineering/invariants.md) — read every bullet; they are what a reviewer checks.
12. [CI gates](../process/ci-gates.md), [branching and delivery](../process/branching.md),
    [the deploy runbook](../process/runbooks/deploy.md).
13. **[Exercise 03 — bump a pin in a scratch branch](../exercises/03-bump-a-pin.md).**
14. [Your first pull request](../onboarding/your-first-pr.md) — then open a real one.

When you are done you can explain, without notes, why `/api/search` reports a `mode`, why the
fold lives in three places, why a deploy is verified by commit, and why none of it may touch a
single character of the text.
