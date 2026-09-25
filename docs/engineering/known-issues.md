---
title: "Release timeline & known issues"
description: "The releases that explain today's invariants, in order, with what each one changed and the rule it left behind; then the items that are still open and who owns them."
sidebar:
  order: 5
---
# Release timeline & known issues

`CHANGELOG.md` is the authoritative release history. This page keeps the releases that explain an
invariant you will meet in the code, and the items that are still open. The 2026-06 static audit
and live verification passes live under [reports](../reports/README.md).

## Timeline

| Release | Date | What changed | The invariant it left |
|---|---|---|---|
| **Live verification** | 2026-06-19 | Scripture integrity proven end to end: reconcile char-exact, golden all-pass, 1,430 Angs gap-free, 60,658 lines; footer/version bug fixed. | The Ang 1256 "duplicate" is a **legitimate refrain — never de-duplicate it.** |
| **v2.9.3** | 2026-06-19 | `MANIFEST.json` re-certified; version strings synced; `build_db.py` no longer hardcodes a version; `rebuild_all.sh` builds the analytics, vaar and semantic tables (validated by a full green rebuild, vaars=22); `concept_lines(line_id)` index fixes the Constellation hang. | A rebuild populates every layer; large concepts need that index. |
| **v2.9.4** | 2026-06-19 | Lineage redesign, plain-language Insights captions; `line_neighbors` rebuilt as exact sparse cosine (header-excluded, verbatim-twin de-duplicated, 0.30 floor, `source='tfidf-exact-cosine-lite'`, scipy at build) with relatedness bands; `db_sha256` re-certified. | Neighbour scores are shown as bands, never a raw percentage. Scripture byte-identical. |
| **v2.9.5** | 2026-06-19 | Insights accuracy from the audit: theme tags curated, `akal_kaal` split into `akal` + `kaal` (concepts 53 → 54), resonance refreshed, full-edge theme network (min-PPMI 0.7 by default), hardened neighbour matmul; PPMI/Jaccard recompute exact. | 54 concepts. Scripture byte-identical. |
| **v2.10.0** | 2026-06-20 | Bundled **Sant Lipi** Gurmukhi webfont (SIL OFL 1.1, `unicode-range`-scoped) and the **traditional saroop** display toggle (`saroop.ts`), which collapses the doubled subjoined ya in rendered glyphs only. | **Display only:** the corpus, DB, API, search and copy stay verbatim; the saroop markup never enters stored text or `/api`. Sant Lipi's inline addha-yayya is a legitimate but *different* tradition from the printed Bir's deep subscript; pending a scholar's review. |
| **v2.10.1** | 2026-06-20 | Saroop becomes the default rendering without writing `localStorage`; an explicit choice (`sggs_saroop` `'0'`/`'1'`) is stored and respected. | To change the default, flip `let ON` in `saroop.ts`. |
| **v2.11.0** | 2026-06-26 | Apple-grade hardening: `verify.py` FTS tokens sanitised and quoted with a central empty-`MATCH` guard (a crafted quote/asterisk no longer 500s or leaks the exception type); `min_ppmi` clamped; `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` on every response; `lang="pa"` on verse containers; pinch-zoom re-enabled; charts honour reduced motion; theme network gains a data-table alternative; styled 404. | 500s return a generic body. Security headers on every response. |
| **v2.12.1 / iOS 1.1.1** | 2026-09-05 | Pre-TestFlight hardening. | `romannorm.py` is the single Roman fold and must equal the pipeline's (24,719 golden vectors); every integer query parameter goes through `_int()`; the Study-Trail pin reads verbatim text from `data-gm`, never rendered text (`/api/lines?ids=` repairs old pins); iOS `sheetHosted` gate, SwiftData ladder, `SavedLineSchemaV1`; an English-bundled iOS build needs `LICENSED: true`. |
| **v1.0.0** | 2026-09-06 | Version strings reset to one unified baseline ahead of the first public release; no code, corpus or DB change. | One version number across web, API and app ([ADR-0004](../adr/0004-unified-semver.md)). |
| **v1.1.0 – v1.1.5** | 2026-09 | `comp_id` groups a heading run with its composition (post-pass 1b); v1.1.4 demoted 233 verses mis-flagged as headings; CI-gated deploys; Soul Gold brand. | No body line ever changes `comp_id`; deploys only through CI. |
| **v1.3.8** | 2026-09-24 | Three repositories: data, platform, app ([ADR-0007](../adr/0007-three-repositories.md)); the database arrives by pin ([ADR-0008](../adr/0008-dataset-by-pin.md)). | `dataset.lock.json` is the only way a dataset changes here; the editorial ledger is 4 rules, 11 applications. |

## Still open

| Item | State | Owner |
|---|---|---|
| Analytics-chart accessibility: the D3 charts are mouse-driven; the theme network has a data-table alternative, the others do not yet | open | web |
| One line with an empty `translit_norm` (id 35328, Ang 829) | fixes on the next rebuild; tracked row by row in sggs-data's data-quality baseline | data |
| 21 source-faithful lines with a vowel sign that has no base consonant (Angs 214, 342, 695, 698, 699, 897, 1203, 1205) | flagged for scholarly review; never silently changed (the Ang 1354/1358/1387 rows were resolved by the G3-approved editorial corrections) | scholar (G3) |
| Saroop rendering vs the printed Bir's deep-subscript ya | pending a Granthi/scholar's review; an exact match needs a licensed or commissioned font | scholar (G3) |
| Japji `author = null`: author filters for Guru Nanak miss it | known, deferred | data |
| `comp_type` mislabelled in places | suppressed at the display layer; prefer `comp_id`/`section` | data |
| `Validation-Report.md` lags the code | banner-flagged superseded; archived | docs |

What each of these means for the text is on [the editorial ledger](../data/editorial-ledger.md) page.
