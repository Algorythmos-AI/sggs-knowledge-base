---
title: "Path: iOS engineer"
description: "For work on Gurbani Soul: from the one rule through the contract and parity, the database pair and launch integrity, Nitnem, and how the app takes a release."
sidebar:
  order: 3
---
# Path: iOS engineer

You will change the app in `Algorythmos-AI/gurbani-soul-ios`. A day and a half, in this order.

<!-- sggs:progress path="ios-engineer" -->
On the rendered wiki each step has a checkbox remembered in your browser; on GitHub, tick them in
your head.

1. Read the [reverence checklist](../onboarding/reverence-checklist.md) and
   [what Sri Guru Granth Sahib Ji is](../scripture/what-sggs-is.md).
2. [How the three repositories fit](../onboarding/how-the-repos-fit.md) and
   [three repositories and pins](../architecture/three-repositories-and-pins.md).
3. [The iOS app](../ios/README.md), then [how the app takes a release](../ios/how-the-app-takes-a-release.md).
4. [Contract and parity](../ios/contract-and-parity.md) — read the Swift fold beside
   [the Roman fold](../search/the-roman-fold.md).
5. [Database pair and launch integrity](../ios/db-pair-and-launch-integrity.md) — walk poster 12.
6. [Anatomy of a line record](../data/line-record.md) — the columns your queries read.
7. [Nitnem for engineers](../ios/nitnem-for-engineers.md), then the pinned
   [Nitnem spec](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/nitnem/spec.md) and [ADR-0006](../adr/0006-bani-registry-over-verbatim-corpus.md).
8. The pinned [TestFlight launch plan](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/ios/testflight-launch-plan.md) and the
   [App Store submission runbook](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/process/runbooks/app-store-submission.md).
9. **[Exercise 01 — trace a search](../exercises/01-trace-a-search.md)** against the API, then
   find the same tier in `SearchEngine.swift`.
10. [The verification engine](../search/verification-engine.md) — the thresholds your port shares.
11. [Brand and domains](../engineering/brand.md): what the app is called and what it is never called.
12. **[Exercise 04 — write an ADR](../exercises/04-write-an-adr.md)** in the app repository's format
    for a change you would propose.
13. The app repository's [contributing guide](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/CONTRIBUTING.md) — then a pull request there.

When you are done you can explain why the app refuses to open a database that does not hash to
its manifest, why `MARKETING_VERSION` is never chosen by hand, and why a Nitnem line from Sri
Dasam Granth can never be bookmarked.
