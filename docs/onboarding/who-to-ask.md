---
title: "Who to ask, where to look"
description: "Where questions, bugs, feature ideas, scripture-fidelity concerns, security reports and design decisions each go, and who reviews what."
sidebar:
  order: 4
---
# Who to ask, where to look

| I want to… | Go to |
|---|---|
| understand why something is the way it is | the [ADRs](../adr/README.md) — every decision that shaped the project, with its context and consequences |
| find the rule for a change I am making | [Engineering invariants](../engineering/invariants.md) first; then the [glossary](../glossary.md) for a term |
| report a bug in the site, the API or a tool | a [bug report](https://github.com/Algorythmos-AI/sggs-platform/issues/new?template=bug.yml) |
| propose a feature | a [feature request](https://github.com/Algorythmos-AI/sggs-platform/issues/new?template=feature.yml) |
| say that a verse, heading, numeral or Ang looks wrong | a [scripture fidelity concern](https://github.com/Algorythmos-AI/sggs-platform/issues/new?template=scripture-fidelity.yml) — **never a code change**; it is routed to a Granthi or scholar |
| report a security problem | email **support@gurbanisoul.com** ([SECURITY](../../SECURITY.md)); never a public issue |
| ask how to do something in this repository | open a discussion on the pull request or issue you are working on; the owner reads every one |
| change how we work (branching, gates, tooling) | propose an ADR in a pull request (`docs/adr/NNNN-title.md`, status *proposed*) |

## Who reviews what

Every change is reviewed by the code owner (`.github/CODEOWNERS`). Some paths are listed there
explicitly because a mistake in them reaches the scripture or the apps: the dataset pin
(`dataset.lock.json`), the golden contract (`contract/`), the Roman fold (`webapp/romannorm.py`),
the verifier (`webapp/verify.py`) and the CI configuration (`.github/`). Expect a slower, closer
review on those.

Scripture questions are not answered by engineers. The project keeps a scholarly review gate (G3)
for anything that changes how the text is extracted, displayed or explained; the
[answer protocol](https://github.com/Algorythmos-AI/sggs-data/blob/main/Answer-Protocol.md) in
sggs-data says how a quotation may be shown and how explanation must be labelled.

## Company and product names

The company is **Algorythmos Pty Ltd**; the app is **Gurbani Soul**; the website and this wiki are
the **Sri Guru Granth Sahib Ji — Knowledge Base**. The scripture is always cited as
*Sri Guru Granth Sahib Ji · Ang N*; "Gurbani Soul" names the app, never the text.
[Brand & domains](../engineering/brand.md) has the rest.
