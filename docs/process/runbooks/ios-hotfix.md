# Runbook: iOS hotfix

iOS has no rollback. The levers, mildest first:

1. **Pause the phased release** — stops new automatic updates; users who already updated keep the
   build. A pause has a time limit (check the current one in App Store Connect).
2. **Ship a fixed build** (below), optionally asking for an **expedited review** through
   App Store Connect → Contact Us → App Review. Use it rarely and say plainly what is broken;
   a scripture-fidelity defect is a legitimate reason.
3. **Remove from sale** — last resort; existing installs keep working (the app is fully offline).

## Procedure
1. Reproduce and write the failing test first. Scripture text is never edited to "fix" anything —
   see the prime directive in `docs/engineering/invariants.md`.
2. Branch `hotfix/<slug>` **from the release tag's commit on `main`** (not from `integration`, which
   may already hold unreleased work):
   `git worktree add <scratch>/wt-hotfix -b hotfix/<slug> vX.Y.Z`
3. Fix, bump to the next patch version (`python3 scripts/release/bump.py X.Y.(Z+1)`), fill the
   CHANGELOG section. Build numbers restart at the ledger's `next` for the new version.
4. PR `hotfix/<slug>` → `main` (squash). CI must be green, including the iOS jobs.
5. From a worktree at that `main` commit:
   `make testflight TEAM_ID=… BUILD=N CHANNEL=appstore UPLOAD=1`
   The script refuses a dirty tree, an off-trunk commit and red CI, exactly as for a normal release.
6. Commit the ledger row via PR. `make appstore-preflight` must pass. Re-sign Charter S on the new
   build number; re-run only the hardware checks the fix could affect, and say which.
7. Submit. After approval, release and resume (or restart) the phased rollout.
8. **Back-merge `main` → `integration`** the same day so the trunk contains the fix.
9. Write the incident note: what users saw, how it got past the gates, which gate now catches it.
   A hotfix without a new test or gate is not finished.
