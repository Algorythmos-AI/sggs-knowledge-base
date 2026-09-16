---
name: sggs-ship
description: Ship a code/docs/CI change in the SGGS Knowledge Base repo through the proper flow — branch from integration, run the local gates, commit, open a PR into integration, watch CI to green, and hand the user the exact merge command. Use whenever the user asks to fix, add, change, or "push"/"PR"/"ship"/"merge into integration" anything in this repo, or after finishing an edit that should land. For corpus/DB changes use sggs-rebuild-db first; for integration→main use sggs-release.
---

# Ship a change → integration

Repo: `Algorythmos-AI/sggs-knowledge-base`. Trunk = `integration` (default branch). `main` = production,
only via sggs-release. Both are protected; merges need the owner's `--admin` (solo maintainer
can't self-approve), and **you cannot merge** — auto-mode blocks merge-without-review. Your job
ends at a green PR plus the exact command for the user.

## 1. Branch
```bash
git fetch -q origin && git switch integration -q && git pull --ff-only -q
git switch -c <type>/<short-slug>      # type: fix feat docs ci chore refactor perf test data ios web
```
Touching `corpus/`, `db/`, or scripture-producing `pipeline/` code? Stop and use **sggs-rebuild-db**.
Gurmukhi text is never edited — see CLAUDE.md prime directive.

## 2. Local gates (run what the change touches — CI runs all of them anyway)
| Changed | Run |
|---|---|
| anything | `make ci` (versions, invariants, scripture guard, server tests, contract drift) · `python3 -m ruff check .` |
| `.github/workflows/**` | `actionlint` (with shellcheck; unused loop vars → use `for _ in`) |
| `frontend/**` | `cd frontend && npm run build` · UI: `npx playwright test --grep @smoke --project=desktop` (needs `serve.py` on 7777) |
| `webapp/Dockerfile`, `.dockerignore` | CI `api-image` job proves it; nothing local required |
| user-visible release content | `python3 scripts/release/bump.py X.Y.Z` + fill the CHANGELOG `## [X.Y.Z]` section, then `python3 scripts/release/check_versions.py` |

## 3. Commit + PR
- Conventional commit subject (`fix(ci): …`, `feat(web): …`), body = what + why + how verified.
  End with the Co-Authored-By line from the session's attribution reminder.
- PR title must match pr-hygiene: `^(feat|fix|docs|chore|ci|refactor|perf|test|data|ios|web|build|revert|release)(scope)?!?: …`.
- PR body: what/why, verification evidence, **"Merge with Squash"**, then the Generated-with footer.
```bash
git push -u origin HEAD -q
gh pr create --repo Algorythmos-AI/sggs-knowledge-base --base integration --head "$(git branch --show-current)" --title "…" --body "…"
```

## 4. Watch CI
```bash
bash .claude/skills/sggs-ship/scripts/wait_pr_checks.sh <PR#>     # run in background; exits 1 if any check failed
```
Required: python, frontend, integrity, versions, secrets, static-analysis (+ playwright, api-image run too).
`verify` is the non-required preview smoke — it passes with a notice unless a repo-level bypass secret exists.
On failure read `gh run view <run> --log-failed`, fix on the same branch, push, re-watch. Don't hand
over a red PR, and don't weaken a gate to get green.

## 5. Hand off the merge
Give the command alone in a `bash` block — **no comment lines** (zsh treats `#` + an apostrophe as an
open quote, which stalled a paste before):
```bash
gh pr merge <PR#> --repo Algorythmos-AI/sggs-knowledge-base --squash --admin --delete-branch
```
When the user says merged, confirm with `gh pr view <PR#> --json state` and pull integration.

## Hard-won gotchas
- A **required** check must never be path-filtered — it stays "Expected" and blocks the PR forever.
- CI checkouts never use `lfs: true`; use `./.github/actions/lfs-db` (cached, asserts real SQLite).
- Secrets: never type or echo a value. The user sets them with the hidden prompt:
  `gh secret set NAME --env production --repo Algorythmos-AI/sggs-knowledge-base`. If a value is pasted
  into chat, treat it as leaked and ask the user to rotate it.
