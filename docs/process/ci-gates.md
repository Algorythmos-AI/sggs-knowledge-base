# CI Gates — what each check proves

| Workflow · job | Proves | Needs |
|---|---|---|
| `web-ci · python` | ruff clean; 9 server unit tests; `/api/health` all-true; the **shabad-heading regression** (`api_superset_check`); search harnesses; **contract does not drift** | LFS DB |
| `web-ci · frontend` | Astro builds; `pahar` vectors pass | Node 22 |
| `scripture-integrity` | MANIFEST↔contract↔attestation hash chain; `verify_regroup --invariants`; `guard_scripture`; timing tests | LFS DB |
| `version-consistency` | all 8 version strings unified; `main` PRs come from `integration`/`hotfix` | — |
| `security` | gitleaks; bandit; semgrep OSS; actionlint; **blocking** `npm audit --audit-level=high` on `frontend/` (job `deps`) | — |
| `pr-hygiene` | conventional-commit PR title | — |
| `ios · parity` | iOS DB matches manifest; Swift golden-vector parity; license gate | macOS, LFS |
| `ios · app` | app builds; unit + XCUITests pass | macOS |

The PDF **never enters CI**. `reconcile.py`/`golden_test.py` run locally via
`make reconcile`, which records `validation/reconcile-attestation.json`; CI then
asserts that attestation's `corpus_sha256` matches the committed corpus.

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
`e2e` (Playwright + axe), `perf` (latency budget + Lighthouse on staging),
`deploy-verify`, `uptime`, and `release` — see the delivery plan.
