# ADR-0004: One unified SemVer across web, API, and iOS

**Status:** accepted (2026-09-15)

**Context.** Versions were hand-edited in 8 places and tags were inconsistent
(`v2.9.3` web vs `v1.0.0-ios`).

**Decision.** A single SemVer version spans web/API/iOS, set everywhere by
`scripts/release/bump.py` and enforced by `check_versions.py`. Tags are `vX.Y.Z`
on `main` only; the DB keeps its own decoupled `meta.version` so a search-only
patch need not re-commit the ~104 MiB LFS DB. The `-ios` tag suffix is retired.

**Consequences.** MAJOR = breaking API/data-model, MINOR = features/data
corrections, PATCH = fixes. RCs on integration are `vX.Y.Z-rc.N`.
