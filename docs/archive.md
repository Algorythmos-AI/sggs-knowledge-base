---
title: "The archive"
description: "Design notes and audit reports from the project's history, kept for the record and linked from here with the date they stopped being current — not published as pages, never a source of truth."
sidebar:
  order: 9
---
# The archive

Everything here is **history**. These documents describe the system as it was when they were
written; the current truth is the code and the pages this wiki generates or verifies against it.
They are kept in the repository, linked from here, and **not published as wiki pages**. If a
document below contradicts a current page, the current page wins — and if it matters, open an issue.

> **Stale by design.** Numbers, file names, hosts and versions in these files are those of their
> day (a Git LFS database, a single Render service for staging, three logged corrections, the old
> repository name). Do not quote them as current.

## Design notes (`docs/design/`)

| Document | Era | What it was |
|---|---|---|
| [Build Plan](design/00_Build-Plan.md) | before v1 | the first plan for the knowledge base |
| [Production Architecture (v2)](design/01_Production-Architecture.md) | v2 | the production web app design |
| [Sovereign Architecture Assessment](design/02_Sovereign-Architecture-Assessment.md) | v1.4.0 · 2026-06-10 | truth assessment and roadmap for the corpus |
| [Phonetic Variant Engine](design/03_Phonetic-Variant-Engine.md) | v1.7.0 | the design of the romanisation-variant tier |
| [Astro Migration Plan](design/Astro_Migration_Plan.md) | v2 | moving the UI to Astro ("Path A: offline monolith") |
| [ML Analytics Engine](design/ML_Analytics_Engine.md) | v2.1.0 | the Insight Engine's first phase |
| [Phase 3 Innovation Roadmap](design/Phase_3_Innovation_Roadmap.md) | v2 | ideas beyond the core |
| [Raag Timing Knowledge Layer](design/Raag_Timing_Knowledge_Layer.md) | v2.12.0 | the timing layer and bani-form metadata |

## Audit and validation reports (`docs/reports/archive/`)

| Report | Date | Superseded by |
|---|---|---|
| [Validation Report (v1.5.0)](reports/archive/Validation-Report.md) | 2026-06-10 | sggs-data's proofs: reconcile attestation, golden suite, data-quality baseline, the [editorial ledger](data/editorial-ledger.md) (the "2 logged repairs" of this report are now 4 rules, 11 applications) |
| [Overnight Hardening Audit](reports/archive/Audit_Report.md) | v2.0 | [known issues and the release timeline](engineering/known-issues.md) |
| [Proactive Hardening Report](reports/archive/Proactive_Hardening_Report_v2.0.6.md) | v2.0.6 | same |
| [QA Resolution Report — chaos testing](reports/archive/QA_Resolution_Report.md) | v1.9.1 | [harnesses and golden vectors](search/harnesses-and-golden-vectors.md) |
| [Schema v2.0 Migration Report](reports/archive/Schema_v2_Migration_Report.md) | v2.0 | [anatomy of a line record](data/line-record.md) |
| [Semantic Vector Search — feasibility](reports/archive/Vector_Search_Feasibility_Report.md) | v2 | the exact sparse-cosine neighbours shipped in v2.9.4 |
| [v2.8.0 System Audit & Fix Plan](reports/archive/v2_8_System_Audit_and_Fix_Plan.md) | v2.8.0 | the release timeline |
| ["Apple-grade" Audit & Hardening Pass](reports/archive/SGGS-Apple-Grade-Audit-2026-06-26.md) | 2026-06-26 | v2.11.0 in the release timeline |
| [iOS v1 Build Report](reports/archive/SGGS-iOS-Build-Report-2026-06-27.md) | 2026-06-27 | the app repository, `Algorythmos-AI/gurbani-soul-ios` |
| [iOS TestFlight Readiness](reports/archive/SGGS-iOS-TestFlight-Readiness-2026-09-05.md) | 2026-09-05 | the app repository's runbooks |
| [Runbook: transfer the repository to the org](reports/archive/org-transfer.md) | completed 2026-09 | nothing to do; the platforms were re-linked and the old name redirects |

## Still current, but reviewed rarely

- [Risk register](risk-register.md) — the top risks, owners and mitigations; reviewed at release time.
- [Reports & audit history](reports/README.md) — the index of the reports that are still consulted.
