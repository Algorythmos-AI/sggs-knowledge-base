---
title: "Contract and parity"
description: "The Swift search, verify, reader, timing, bani and insight code is a port of the platform's Python, proven byte for byte against the vendored golden contract on the derived database, suite by suite."
sidebar:
  order: 2
verified:
  commit: 417c92f6
  date: "2026-09-25"
---
# Contract and parity

The app does not call the API: it ships its own Swift implementation of search, verification,
the reader, timing, the banis and the insights, against a database it bundles. What keeps that
implementation honest is the **golden contract** — recorded outputs of the platform's real
functions — vendored at the release tag and replayed by parity tests on every pull request.

## What is vendored

<!-- sggs:code file="vendor.lock.json" lines="1-32" repo="gurbani-soul-ios" -->
Source: [`vendor.lock.json`](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/vendor.lock.json) in gurbani-soul-ios.

Two sources, each with a commit and a sha256 per file: the platform (the contract files and the
contributors roster, at a release tag whose `APP_VERSION` the lock records) and sggs-data (the iOS
database builder, at the dataset's commit). `scripts/vendor_sync.py check --remote` proves in CI
that every file equals both its lock entry and the file at its source commit.

## The parity suites

Package `GurbaniSearchKit` holds the ports and their tests
(`ios/Packages/GurbaniSearchKit/Tests/`):

| Suite | Replays | Against |
|---|---|---|
| `GoldenVectorTests` | `golden_roman_norm.ndjson` (24,719 fold vectors) and `golden_difflib.ndjson` (the scorer, repr-exact) | pure functions, no database |
| `SearchParityTests` | `golden_search.ndjson` — queries through the Swift waterfall | the derived database |
| `VerifyParityTests` | `golden_verify.ndjson` — claims and full verdicts | the derived database |
| `ReaderParityTests` | `golden_reader.ndjson` — Ang, shabad and Hukam projections | the derived database |
| `TimingParityTests`, `BaniParityTests`, `AnalyticsParityTests` | the knowledge, Nitnem and insight suites | the derived database |
| `DegradationParityTests` | how each feature degrades on an older database without a layer (capability bits, never a fork) | a database with tables dropped |

`make parity` runs them locally; the `iOS fidelity gate · parity` job runs them on every pull
request after building both database profiles with the vendored builder.

## The same fold, in Swift

The phonetic fold is the sharpest example: one function, three homes, one contract
([The Roman fold](../search/the-roman-fold.md)). The Swift port is read here from the app
repository at the pinned commit:

<!-- sggs:code file="ios/Packages/GurbaniSearchKit/Sources/GurbaniSearchKit/RomanNorm.swift" symbol="fold" repo="gurbani-soul-ios" -->
Source: [`RomanNorm.swift`](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/ios/Packages/GurbaniSearchKit/Sources/GurbaniSearchKit/RomanNorm.swift) in gurbani-soul-ios.

Compare it with the Python on [The Roman fold](../search/the-roman-fold.md): the rules are the
same in the same order, and `GoldenVectorTests` proves the outputs equal for every one of the
24,719 recorded inputs. The verifier's scorer is held the same way: `SequenceMatcher.swift`
reproduces `difflib` ratio for ratio (`golden_difflib.ndjson`), which is why the verdict ladder
can use the platform's thresholds unchanged.

## What a parity failure means

- **The contract changed upstream** (a deliberate engine change released on the platform): the
  app re-vendors at the new tag and ports the change; the failing suite names exactly which
  records differ.
- **The port drifted** (a Swift change without a platform change): fix the port; the contract is
  the truth.
- **The database differs** (a dataset bump): the suites run on the database the vendored builder
  derives from the pinned dataset, so a bump is a lock change plus a rebuilt database pair, never
  a test edit.

Nothing in the app repository is allowed to move the contract: vendored files are read-only by
policy and by CI.
