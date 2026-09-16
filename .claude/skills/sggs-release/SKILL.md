---
name: sggs-release
description: Release the SGGS Knowledge Base from integration to production — preflight (trunk green, versions unified, CHANGELOG section, nothing already open), open the release PR to main, hand the user the merge-commit command, then watch the CI-gated deploy-production pipeline gate by gate, verify production by commit identity, and confirm the vX.Y.Z tag. Use whenever the user says release, ship to prod, deploy to production, cut a version, merge integration into main, or asks why a deploy/release failed.
---

# Release integration → production

Production deploys happen **only** through `.github/workflows/deploy-production.yml`, triggered by a
push to `main`. It runs: gates (required checks on the exact SHA) → preflight (secrets) → approve →
deploy-api (Render hook `ref=SHA`, waits until `/api/health.commit == SHA`) → verify-api → deploy-web
(Vercel build, deployed **unaliased**) → verify-web (@smoke) → promote (+ public smoke, auto-rollback)
→ release (tag + GitHub Release). Runbook: `docs/process/runbooks/deploy.md`.

## 1. Preflight (read-only)
```bash
bash .claude/skills/sggs-release/scripts/release_preflight.sh
```
It fails with a reason if: integration has nothing new for main, integration's tip checks aren't all
green, version strings disagree, the CHANGELOG has no
`## [X.Y.Z]` section, or a release PR is already open. It **warns** if the version is already tagged:
fine for CI/infra-only releases (the deploy is still gated; the tag step skips), but user-visible changes
need a bump. Fix failures through **sggs-ship** first.

## 2. Open the release PR
Title `release: vX.Y.Z — <summary>`. Body: the commits going out (`git log --oneline origin/main..origin/integration`),
what the pipeline will do, and in bold **"Merge with a MERGE COMMIT (not squash)"** — squash/rebase
rewrites SHAs so main and integration diverge and every later release conflicts. Footer as usual.
Then watch it: `bash .claude/skills/sggs-ship/scripts/wait_pr_checks.sh <PR#>`.

## 3. Hand off the merge (you cannot merge)
One line, alone in a `bash` block, no comments:
```bash
gh pr merge <PR#> --repo Algorythmos-AI/sggs-knowledge-base --merge --admin
```

## 4. Watch the deploy
```bash
bash .claude/skills/sggs-release/scripts/watch_deploy.sh            # defaults to origin/main SHA; run in background
```
Prints each job transition; exits with the run's conclusion. Report gate by gate.

## 5. Verify + confirm tag
```bash
python3 .claude/skills/sggs-verify-prod/scripts/verify_prod.py --commit "$(git rev-parse origin/main)" --version X.Y.Z
gh release view vX.Y.Z --repo Algorythmos-AI/sggs-knowledge-base --json tagName,url
```

## When a job fails — read `gh run view <run> --log-failed`, then:
| Job | Meaning | Action |
|---|---|---|
| gates | a required check failed / never ran on the main SHA | fix via sggs-ship on integration, re-release |
| preflight | a `production` env secret is missing | user sets it with the hidden `gh secret set NAME --env production …` prompt |
| deploy-api | Render didn't reach the SHA | check Render GitHub App access to the org, service repo, hook; `commit=unknown` → Dockerfile/`SGGS_COMMIT` |
| verify-api | API is live but wrong | incident issue auto-opened; roll back Render to previous deploy (runbooks/rollback.md) |
| deploy-web / verify-web | web build or smoke failed | **nothing went live**; fix and re-release (`gh workflow run deploy-production --ref main` redeploys) |
| promote | public smoke failed | pipeline auto-rolled back Vercel; investigate the incident issue |
| release | tagging failed; **deploy already verified** | tag manually from the SHA (below), then fix the job |

Manual tag (only after the deploy is verified):
```bash
python3 scripts/release/release_notes.py X.Y.Z > /tmp/notes.md
git tag -a vX.Y.Z -m "vX.Y.Z" <sha> && git push origin vX.Y.Z
gh release create vX.Y.Z --repo Algorythmos-AI/sggs-knowledge-base --title "vX.Y.Z — …" --notes-file /tmp/notes.md --verify-tag
```

Never tag before a verified deploy; never "fix" a deploy by pushing to main directly or deploying
by hand from a dirty tree (a manual hotfix is only for a pipeline outage — see runbooks/deploy.md).
