---
title: "CI Gates — what each check proves"
description: "What each GitHub Actions workflow and job proves before a change can merge or deploy."
sidebar:
  order: 3
---
# CI Gates — what each check proves

| Workflow · job | Proves | Needs |
|---|---|---|
| `web-ci · python` | ruff clean; server + repo-gate unit tests; the **golden contract replayed over HTTP** (`tools/contract_http.py`); `contract/openapi.json` is current and covers every dispatcher route; `/api/health` all-true; the **shabad-heading regression** (`api_superset_check`); search harnesses; **contract does not drift** | pinned DB |
| `web-ci · frontend` | Astro builds; `pahar` vectors pass | Node 22 |
| `scripture-integrity` | dataset pin: `dataset.lock.json` ↔ `contract/_meta.json`, and sggs-data publishes that object at the pinned commit; the installed DB passes `quick_check` with 60,658 lines over Angs 1–1430 (the scripture gates themselves run in sggs-data) | pinned DB |
| `version-consistency` | all 5 platform version strings unified (the dataset versions in sggs-data; the iOS app keeps its own match); `main` PRs come from `integration`/`hotfix` | — |
| `security` | gitleaks; bandit; semgrep OSS; actionlint; **blocking** `npm audit --audit-level=high` on `frontend/` and `docs-site/` (job `deps`) | — |
| `pr-hygiene` | conventional-commit PR title | — |
| `e2e · playwright` | Ang 712 heading smoke, search → panel heading, axe WCAG on the home page (desktop project) | serve.py + pinned DB |
| `web-ci · api-image` | Docker image builds; the running container reports the build commit **and honours the golden contract over HTTP** | Docker |
| `deploy-verify` (on Vercel `deployment_status`, previews only) | preview `/api/health` all-true (passes with a notice without the repo-level bypass secret) | — |
| `release` (manual fallback) | idempotent tag + GitHub Release on `main`; normal releases are cut by `deploy-production` after a verified deploy | — |
| `data-canary` (every 6 h, not a PR check) | production serves the pinned scripture byte for byte: 500 random lines (`/api/lines`) and 12 random Angs plus Angs 1, 712, 1430 (`/api/ang/N`), from the API origin **and** through the public site's CDN; the golden contract replays against production; a failure opens or updates one issue | pinned DB |
| `deploy-staging · deploy-web` | the API functions are generated at the commit from the pinned database (slices proven); after `vercel build` every function bundles only its entry, the API code and its own database, and no database or API source is in the static output | pinned DB |
| `deploy-staging · verify` | every API function's `/readyz` reports this commit and exactly its contexts; no API file is downloadable; the web smoke; every routed context answers **through the gateway** with its own `X-Service`; an unknown prefix falls through to `all`; the **whole golden contract passes through the gateway** | bypass secret, pinned DB |
| `deploy-docs · docs` | the wiki (`docs-site/` over `docs/`, ADR-0012): pinned sibling docs consistent and installed; `tools/docs_check.py` (frontmatter, links and anchors, widget fallbacks, Mermaid palette, the scripture-quotation rule, posters, site config); tool and plugin unit tests; the site builds with **every Mermaid fence rendered to SVG**; every internal link and fragment in the built HTML resolves; page budgets (JS ≤ 60 KB gz); Playwright e2e + axe (mocked API); Lighthouse (performance ≥ 0.9, accessibility 1, best-practices ≥ 0.95) | Node 22, Chromium |
| `deploy-docs · deploy-staging` / `deploy-production` | the wiki is deployed only by CI: `integration` → `sggs-docs-staging.vercel.app`; `main` → build, deploy unaliased, smoke by commit, promote to `docs.gurbanisoul.com`, smoke again, roll back on failure (`scripts/ci/docs_smoke.py`) | docs Vercel project secrets |
| `uptime` (every 15 min, not a PR check) | production `/api/health` all-true; `/privacy` and `/support` (the App Store URLs) resolve with their content; a failure opens or updates one issue | — |

The PDF, the corpus rebuild and the scripture gates (reconcile attestation, regroup invariants,
scripture guard, editorial ledger, fingerprints) belong to `Algorythmos-AI/sggs-data` and run in its
CI. The iOS app's gates run in `Algorythmos-AI/gurbani-soul-ios`.

Run the no-PDF subset locally with `make ci`.

`npm audit` has been **blocking** since the Astro 7 upgrade cleared the advisory backlog
(2026-09-20): a new high/critical advisory in `frontend/package-lock.json` fails `security · deps`.
Fix it with `npm audit fix` (never `--force` blind — read the migration notes), rebuild, and
re-sync `webapp/static/`; do not re-add `|| true`.

## Deploy pipeline
`deploy-production` (push to `main`) waits for the required checks above **plus `playwright`**
on the exact commit, then deploys API → verifies → builds web unaliased → smoke → promotes →
smoke public → tags. Details: [runbook: deploy](runbooks/deploy.md).

## Not yet wired (roadmap)
`perf` (latency budget + Lighthouse on staging) and a load/soak test — nothing yet exercises the
request-cost limits this repo now enforces (the /api/verify claim cap, the socket timeout, the
bounded worker pool). `npm audit` is already blocking (see the `security` row above).
