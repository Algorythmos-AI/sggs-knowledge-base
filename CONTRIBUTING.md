# Contributing

## Prime directive
This repository is a verbatim knowledge base of **Sri Guru Granth Sahib Ji**.
**Never edit, normalize, or "correct" the Gurmukhi text.** If something looks
wrong, open a *Scripture fidelity concern* issue for a Granthi/scholar — do not
change it. See [`docs/engineering/invariants.md`](docs/engineering/invariants.md) and
`docs/architecture/scripture-integrity.md`. The full engineering handbook is
[`docs/engineering/`](docs/engineering/README.md).

## Branch model
- Trunk is **`integration`** (auto-deploys staging). Branch `feature/*` or `fix/*`
  from it and open a PR back into `integration`.
- **`main` is production.** It only receives release PRs from `integration` (or
  `hotfix/*`). Tags `vX.Y.Z` and GitHub Releases are cut on `main`.
- See `docs/process/branching.md`.

## Before you open a PR
```bash
make doctor        # check your toolchain (the python3 3.12-vs-3.9 trap, node, lfs)
make ci            # run the same gates CI runs
```
- Conventional-commit PR titles: `fix(data): …`, `feat(web): …`, `docs: …`.
- Keep PRs small (< ~400 changed source lines, generated artefacts excluded).
- Unify versions with `python3 scripts/release/bump.py X.Y.Z`; the
  `version-consistency` gate enforces it.
- CODEOWNERS review is required for anything under `corpus/ db/ contract/ pipeline/ .github/`.
- Watch your PR to green with `make pr-checks PR=<n>`; delivery tooling is listed in
  [`docs/engineering/delivery.md`](docs/engineering/delivery.md#delivery-tooling).
- Commits and PRs carry the author's name only (no tool attribution trailers).

## Toolchain (important)
The pipeline needs **PyMuPDF + numpy + scipy**; on this project's macOS box that
is `/usr/bin/python3` (3.9), while Homebrew `python3` (3.14) lacks them — run the
pipeline as `PATH=/usr/bin:$PATH bash pipeline/rebuild_all.sh`. CI pins Python to
`.python-version` (3.12) and Node to `.nvmrc` (22). `make doctor` checks this.
