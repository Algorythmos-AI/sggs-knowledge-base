# Delivery, versioning & release

How work reaches users. Read before shipping.

## Versioning convention (important)

- **`APP_VERSION` in `webapp/serve.py` is the source of truth** for the running build. Bump it on every search-logic/UI release.
- **One number, everywhere.** The web footer, `/api/meta`, `/api/health`, the iOS About screen (`MARKETING_VERSION`) and the App Store all report the same X.Y.Z; they are **never allowed to differ** (`check_versions.py` gates the 6 in-repo strings **and** that the iOS ledger is not ahead of `APP_VERSION`). **Every release is re-archived at the same version** and uploaded as iOS `X.Y.Z (1)` from the release tag `vX.Y.Z`, even a web-only change — so the App Store number always equals the live site. The **build number restarts at 1 per version** (only a re-upload of the *same* version increments it). A release is *complete* only when `scripts/release/check_release_complete.py X.Y.Z` passes (prod web+API at the tag commit **and** an `appstore` ledger entry of X.Y.Z from that commit). Never ship a one-sided hotfix — patch-bump both surfaces.
- The DB's own build version is returned separately as `db_version` and is **not** shown in the UI. This decoupling is intentional: a search-only patch shouldn't force a re-commit of the ~104 MiB LFS DB.
- Keep `README.md`, `CHANGELOG.md`, and `MASTER-INDEX.md` in step when you bump (`scripts/release/bump.py` does it).
- **The dataset versions separately.** `DATASET_VERSION` (repo root) is the version of the data: the DB's `meta.version` (served as `db_version`), `MANIFEST.json` `version`, and the `data-vX.Y.Z` releases. It changes only when the dataset is rebuilt and released — never with an app release — so the data can move to its own repository (sggs-data) and release on its own cadence.

## Delivery SOP — how work reaches users (read before shipping)
**Environments:** `integration` = trunk → auto-deploys **staging** (`sggs-staging.vercel.app`, API `sggs-api-staging.onrender.com`, SSO-protected). `main` = **production** (web on the canonical domain **`gurbanisoul.com`**; `www` and the legacy `*.vercel.app` alias 308→apex; API `…onrender.com`). Both deploy **only** through CI (`deploy-staging.yml` / `deploy-production.yml`); the platforms' own git auto-deploys are OFF and Render auto-deploy is OFF. Never deploy by hand except a documented pipeline-outage hotfix.

**The loop (use the tooling below; do not improvise it):**
1. **Ship**: branch from `integration` (`fix/…`, `feat/…`), run local gates, open a PR into `integration`, watch CI green. Corpus/DB change? Follow `docs/process/runbooks/rebuild-db.md` first (scripture proofs). You cannot merge — hand the user the exact `--admin` command (one line, no comments).
2. The user merges → the push auto-deploys **staging**. Review on `sggs-staging.vercel.app` (open logged in to Vercel).
3. **Release**: preflight → PR `integration→main` as a **merge commit** (never squash — `main` must stay a descendant of `integration`) → the merge runs the gated production deploy → verify with `make verify-prod` and confirm the `vX.Y.Z` tag.

**Invariants:** a deploy is verified by the running **commit** (`/api/health.commit`), not just the version. The release tag is cut only after a verified deploy. Secrets live in GitHub Environments (`production`/`staging`) — never type or echo a value; if one is pasted into chat, treat it as leaked and have the user rotate it. Full detail: `docs/process/runbooks/deploy.md`, `docs/process/branching.md`, ADR-0005.

## Delivery tooling

Tested scripts that encode the gotchas learned shipping v1.1.x. Prefer them to ad-hoc commands:

| Step | Command | Script |
|---|---|---|
| Watch a PR's checks to completion | `make pr-checks PR=<n>` | `scripts/ci/wait_pr_checks.sh` |
| Release preflight (trunk green, versions unified, CHANGELOG section) | `make release-preflight` | `scripts/release/release_preflight.sh` |
| Watch the production deploy gate by gate | `make watch-deploy [SHA=<sha>]` | `scripts/release/watch_deploy.sh` |
| Prove what production serves (commit, health, Ang 712 heading, web deployment) | `make verify-prod [ARGS="--commit <sha> --version X.Y.Z"]` | `scripts/ops/verify_prod.py` |
| Byte-level scripture diff between two DBs | `make scripture-diff PRE=<old.sqlite>` | `scripts/data/diff_scripture.py` |
| Re-record the scripture baseline after a sanctioned rebuild | `bash scripts/data/rebaseline_pretiming.sh <scratch-dir>` | — |

## iOS TestFlight / App Store (2026-09-16: TestFlight approved)
Plan and gates live in `docs/ios/` (`testflight-launch-plan.md`, `testflight-test-plan.md`, `app-store-listing.md`). Build candidates **only** with `make testflight TEAM_ID=… BUILD=N` (`ios/tools/testflight_archive.sh`) or the manual `ios-testflight.yml` workflow: both derive the DB profile, run `check_release_license.sh` on the exact artifact, and prove the DB hash inside the archived `.app`. Default profile is **`public`** (Gurmukhi-only) because the English layer is `LICENSED: false`; never hand-edit `project.yml`'s team/build for an upload. Every build gets the scripture-fidelity charter (Charter S) signed before testers see it. **Build numbers** are per marketing version and monotonic: `CURRENT_PROJECT_VERSION` stays at the floor `1`, each upload passes `BUILD=N` (`make testflight-next` prints the next), and the archive script gates + records it in the tracked ledger `ios/testflight-builds.json` (`ios/tools/testflight_ledger.py`) — commit the ledger with the release. The About-screen UI test reads the built version from the test bundle's Info.plist, never a hardcoded literal, and `check_versions.py` enforces both invariants.
