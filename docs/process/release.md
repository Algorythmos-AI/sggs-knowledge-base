# Release Process

1. On `integration`, ensure everything is green on staging.
2. Bump the unified version: `make release VERSION=1.2.0` (runs `bump.py` +
   `check_versions.py`). Fill in the CHANGELOG section it stubs.
3. If the corpus/DB changed: `make rebuild` → `verify_regroup` → `make reconcile`
   (updates the attestation) → `make ios-db` → `make contract`.
4. Open a **release PR `integration → main`**, labelled `release`. All gates must pass.
5. Merge. `release` CI tags `vX.Y.Z`, cuts a GitHub Release from the CHANGELOG
   section with artefacts (`frontend-dist.zip`, `MANIFEST.json`, iOS manifest,
   `contract.tar.gz`, SBOM), attaches `db_sha256`/`corpus_sha256`, closes the
   milestone, and back-merges `main → integration`.
6. Production deploys automatically; `deploy-verify` confirms `/api/meta.version`.
7. **iOS is part of every release.** After `main` is tagged `vX.Y.Z`, archive + upload
   the App Store binary from that tag: `make testflight TEAM_ID=… BUILD=1 CHANNEL=appstore
   UPLOAD=1` (the archive script refuses an `appstore` upload whose HEAD is not on `main`
   and tagged `vX.Y.Z`). Commit the ledger. The release is **complete** only when
   `scripts/release/check_release_complete.py X.Y.Z` passes.

## Versioning
SemVer, **one unified version number across web, API and iOS** — the footer, `/api/meta`,
`/api/health`, the iOS About screen and the App Store all read the same X.Y.Z, and they are
never allowed to differ. **Every release is re-archived at the same version** and uploaded as
iOS `X.Y.Z (1)` from the release tag, even when the change is web-only — so the number in the
App Store always equals the live site. The iOS **build number restarts at 1 per version** and
only increments for a re-upload of the *same* version (e.g. an App Review fix). Never ship a
one-sided hotfix: web or iOS fixes bump the **patch** everywhere. **MAJOR** = breaking
API/data-model (e.g. a `comp_id` renumber); **MINOR** = features or data corrections; **PATCH**
= fixes. RCs on `integration` are `vX.Y.Z-rc.N`. The DB keeps its own decoupled `meta.version`.
See [ADR-0004](../adr/0004-unified-semver.md).
