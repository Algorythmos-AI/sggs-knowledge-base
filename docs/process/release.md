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

## Versioning
SemVer, one unified version across web/API/iOS. **MAJOR** = breaking API/data-model
(e.g. a `comp_id` renumber); **MINOR** = features or data corrections (v1.1.0 heading
fix); **PATCH** = fixes. Release candidates on `integration` are `vX.Y.Z-rc.N`. The
DB keeps its own decoupled `meta.version`. See [ADR-0004](../adr/0004-unified-semver.md).
