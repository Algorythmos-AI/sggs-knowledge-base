---
title: "The iOS app"
description: "Gurbani Soul for iPhone and iPad lives in its own repository and takes every input by pin: the dataset, the platform's golden contract and the database builder. How it fits, and where to read next."
sidebar:
  order: 0
verified:
  commit: 417c92f6
  date: "2026-09-25"
---
# The iOS app

**Gurbani Soul** is the consumer app: reading, searching and studying Sri Guru Granth Sahib Ji,
fully offline, with the verbatim [[Gurmukhi]] cited by [[Ang]]. It lives in
[`Algorythmos-AI/gurbani-soul-ios`](https://github.com/Algorythmos-AI/gurbani-soul-ios) and
**reads nothing from this repository's working tree**: every input arrives pinned and hash-verified
([ADR-0007](../adr/0007-three-repositories.md)), and its Swift search, verify and reader core is
held to the platform's API by the golden contract.

| Input | Owner | How it arrives in the app repository |
|---|---|---|
| The scripture database | sggs-data | `dataset.lock.json` — the same pin as this platform — installed by `make dataset`, sha256-verified |
| The iOS database builder (`pipeline/build_ios_db.py`) | sggs-data | vendored at the dataset's commit, recorded in `vendor.lock.json` |
| The golden contract (`contract/`) and the contributors roster | this platform | vendored at a release tag, recorded in `vendor.lock.json` with a sha256 per file |

## The pages

| Page | What you learn | Interactive |
|---|---|---|
| [How the app takes a release](how-the-app-takes-a-release.md) | vendor-sync, the one version number, the ledger, and what makes a release *complete* | the flow as a sequence diagram; the tools read from the app repository at its pinned commit |
| [Contract and parity](contract-and-parity.md) | how the Swift port is proven byte-identical to the API, suite by suite | the Swift fold read from the source |
| [Database pair and launch integrity](db-pair-and-launch-integrity.md) | the two database profiles, the manifest, the licence gate, the fail-closed launch check, the bookmarks store | poster 12 walkthrough |
| [Nitnem for engineers](nitnem-for-engineers.md) | the bani registry as pointers over the verbatim corpus, the separate non-SGGS layer, variants, numbering, the review gate | the registry as a diagram |

## Pinned from gurbani-soul-ios

The app's own documents are published here **by pin** (`docs-site/sources.lock.json`), with a banner
naming the canonical file; edit them there:

| Document | Canonical file |
|---|---|
| TestFlight → App Store launch plan | [docs/ios/testflight-launch-plan.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/ios/testflight-launch-plan.md) |
| TestFlight test plan | [docs/ios/testflight-test-plan.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/ios/testflight-test-plan.md) |
| The App Store listing | [docs/ios/app-store-listing.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/ios/app-store-listing.md) |
| Nitnem / Gutka Sahib — spec and frozen contract | [docs/nitnem/spec.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/nitnem/spec.md) |
| Runbook: App Store submission (go / no-go) | [docs/process/runbooks/app-store-submission.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/process/runbooks/app-store-submission.md) |
| Runbook: iOS hotfix | [docs/process/runbooks/ios-hotfix.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/process/runbooks/ios-hotfix.md) |
| ADR-0001: pinned inputs and the platform's version number | [docs/adr/0001-vendored-inputs-one-number.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/docs/adr/0001-vendored-inputs-one-number.md) |
| Contributing | [CONTRIBUTING.md](https://github.com/Algorythmos-AI/gurbani-soul-ios/blob/main/CONTRIBUTING.md) |

## What the app promises

- **Verbatim scripture.** Every line shown is the Gurmukhi of the pinned database; the app refuses
  to present scripture at all if the bundled database does not hash to its certified manifest.
- **The platform's behaviour.** Search, verification, the reader, timing, the banis and the
  insights are Swift ports proven against the golden contract of the release they carry the
  number of.
- **One number.** `MARKETING_VERSION` equals the platform release whose contract is vendored;
  every platform release is re-archived as `X.Y.Z (1)`, so the App Store always equals the site.
- **Nothing collected.** No accounts, no network at runtime, no tracking; the privacy manifest
  declares only what the app stores on the device.

Identifiers are stable through the brand: bundle ids `org.sggs.*`, the App Group
`group.org.sggs`, the URL scheme `sggs://` ([Brand & domains](../engineering/brand.md)).
