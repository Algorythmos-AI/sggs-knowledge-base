# CI Gates — what each check proves

| Workflow · job | Proves | Needs |
|---|---|---|
| `web-ci · python` | ruff clean; server + repo-gate + pipeline-safety unit tests; the **golden contract replayed over HTTP** (`pipeline/contract_http.py`); `/api/health` all-true; the **shabad-heading regression** (`api_superset_check`); search harnesses; **contract does not drift** | LFS DB |
| `web-ci · frontend` | Astro builds; `pahar` vectors pass | Node 22 |
| `scripture-integrity` | MANIFEST↔contract↔attestation hash chain; `verify_regroup --invariants`; `guard_scripture`; timing tests | LFS DB |
| `version-consistency` | all 7 version strings unified; `main` PRs come from `integration`/`hotfix` | — |
| `security` | gitleaks; bandit; semgrep OSS; actionlint; **blocking** `npm audit --audit-level=high` on `frontend/` (job `deps`) | — |
| `pr-hygiene` | conventional-commit PR title | — |
| `e2e · playwright` | Ang 712 heading smoke, search → panel heading, axe WCAG on the home page (desktop project) | serve.py + LFS DB |
| `web-ci · api-image` | Docker image builds; the running container reports the build commit **and honours the golden contract over HTTP** | Docker |
| `deploy-verify` (on Vercel `deployment_status`, previews only) | preview `/api/health` all-true (passes with a notice without the repo-level bypass secret) | — |
| `release` (manual fallback) | idempotent tag + GitHub Release on `main`; normal releases are cut by `deploy-production` after a verified deploy | — |
| `uptime` (every 15 min, not a PR check) | production `/api/health` all-true; `/privacy` and `/support` (the App Store URLs) resolve with their content; a failure opens or updates one issue | — |
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
`perf` (latency budget + Lighthouse on staging) and a load/soak test — nothing yet exercises the
request-cost limits this repo now enforces (the /api/verify claim cap, the socket timeout, the
bounded worker pool). `npm audit` is already blocking (see the `security` row above).
