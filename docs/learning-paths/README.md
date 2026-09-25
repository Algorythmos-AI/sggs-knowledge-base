---
title: "Learning paths"
description: "Four guided routes through the wiki — platform engineer, data engineer, iOS engineer, reviewer or scholar — each a checklist of pages and exercises in the order that builds understanding."
sidebar:
  order: 0
---
# Learning paths

A path is a checklist: pages to read and exercises to do, in an order that builds on itself. Tick
items as you go — the ticks are remembered in your browser only (nothing is sent anywhere) — and
start again whenever you like. Every path begins with the same two stops: the
[reverence checklist](../onboarding/reverence-checklist.md) and
[Scripture 101](../scripture/README.md), because the one rule of this project comes before any
code.

```mermaid
flowchart LR
    accTitle: The four learning paths share a start and branch by role
    accDescr: Every path starts with the reverence checklist and Scripture 101, then branches: platform engineer, data engineer, iOS engineer, reviewer or scholar.
    start([Reverence checklist · Scripture 101]) --> pe[Platform engineer<br/>the API, search, verification, delivery]
    start --> de[Data engineer<br/>the corpus, the pipeline, the pin, the ledger]
    start --> ie[iOS engineer<br/>the contract, the database pair, Nitnem]
    start --> rs[Reviewer or scholar<br/>what to check, where, and how to say no]
```

| Path | For | Time |
|---|---|---|
| [Platform engineer](platform-engineer.md) | someone who will change the API, the website or the pipeline that ships them | about two days |
| [Data engineer](data-engineer.md) | someone who will work on the corpus, the database, the gates or a dataset release | about two days |
| [iOS engineer](ios-engineer.md) | someone who will change the app | about a day and a half |
| [Reviewer or scholar](reviewer-scholar.md) | a Granthi, a scholar or a maintainer who reviews changes and never writes code | half a day |

Each exercise on a path is runnable with `make` targets alone and says what output to expect;
the [exercises index](../exercises/README.md) lists them all.
