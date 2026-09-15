# Branching & Delivery Flow

```mermaid
gitGraph
    commit id: "main"
    branch integration
    commit id: "trunk"
    branch feature
    commit id: "work"
    commit id: "more"
    checkout integration
    merge feature
    commit id: "STAGING deploy"
    checkout main
    merge integration tag: "v1.2.0"
    commit id: "PROD deploy"
```

## Rules
- **`integration` is the trunk.** Branch `feature/*` or `fix/*` from it; open a PR
  back into `integration`. Merging to `integration` deploys **staging** (web +
  Render + TestFlight internal).
- **`main` is production.** It only ever receives a **release PR from `integration`**
  (or `hotfix/*`). The `version-consistency` gate enforces the source branch.
  Merging to `main` tags `vX.Y.Z`, cuts a GitHub Release, and deploys production.
- **`hotfix/*`** branches from `main` for urgent production fixes, then is
  back-merged into `integration`.

## Required checks (once the owner is on GitHub Team)
Applied from `.github/rulesets/` via `scripts/gh/apply_rulesets.sh`:
- `main`: PR + 1 approval + CODEOWNERS + linear history + `web-ci`, `scripture-integrity`,
  `version-consistency`, `security` green; tags `v*` protected.
- `integration`: PR + CODEOWNERS + `web-ci`, `scripture-integrity`, `security` green.

## PR hygiene
Conventional-commit titles (`fix(data): …`), small diffs, `Closes #NN`, the
scripture-safety checklist in the PR template completed for any corpus/db change.
