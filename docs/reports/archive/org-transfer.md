---
title: "Runbook: Transfer the repo to the Algorythmos-AI org"
description: "Moving the repository into the Algorythmos-AI organisation and re-linking the deploy platforms (completed)."
sidebar:
  order: 6
---
# Runbook: Transfer the repo to the Algorythmos-AI org

Human-gated; outward-facing. Do this when ready to re-link Vercel/Render.

1. **Transfer:** GitHub → repo Settings → Danger Zone → Transfer → owner
   `Algorythmos-AI`. (Or `gh api repos/skalaliya/sggs-knowledge-base/transfer -f new_owner=Algorythmos-AI`.)
   Commits, tags, LFS objects, PRs, issues carry over; the old URL redirects.
2. **Local remote:** `git remote set-url origin git@github.com:Algorythmos-AI/sggs-knowledge-base.git`
   then `make dataset-check` — confirm the pinned database is still published.
3. **Vercel:** install/authorize the Vercel GitHub App on the org; re-connect the
   project's Git repo (Settings → Git). Production branch stays `main`.
4. **Render:** authorize the Render GitHub App on the org; re-link the service (or
   link the new `render.yaml` Blueprint).
5. **Org hardening:** require 2FA; restrict repo creation; Actions → allowed actions
   + read-only default token; enable Dependabot alerts org-wide.
6. **Upgrade the org to GitHub Team** (prerequisite for private-repo rulesets), then
   `REPO=Algorythmos-AI/sggs-platform bash scripts/gh/apply_rulesets.sh`.
7. **CODEOWNERS:** create team `@Algorythmos-AI/scripture-reviewers` and switch
   `.github/CODEOWNERS` from `@skalaliya` to the team.
8. Update repo URLs in README/docs/engineering if any are absolute.
