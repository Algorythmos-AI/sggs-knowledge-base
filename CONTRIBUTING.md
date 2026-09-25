# Contributing

## Prime directive
This repository is a verbatim knowledge base of **Sri Guru Granth Sahib Ji**.
**Never edit, normalize, or "correct" the Gurmukhi text.** If something looks
wrong, open a *Scripture fidelity concern* issue for a Granthi/scholar — do not
change it. See [`docs/engineering/invariants.md`](docs/engineering/invariants.md) and
the data repository's [scripture-integrity guide](https://github.com/Algorythmos-AI/sggs-data/blob/main/docs/architecture/scripture-integrity.md). The full engineering handbook is
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
- CODEOWNERS review is required for every change; `dataset.lock.json`, `contract/`, the fold and the verifier are listed explicitly.
- Watch your PR to green with `make pr-checks PR=<n>`; delivery tooling is listed in
  [`docs/engineering/delivery.md`](docs/engineering/delivery.md#delivery-tooling).
- Commits and PRs carry the author's name only (no tool attribution trailers).

## Docs (the wiki)
The engineering wiki is the Markdown under `docs/`, rendered at docs.gurbanisoul.com by `docs-site/`
(ADR-0012). Write pages as before, with a `title`/`description` frontmatter block and relative links;
`make docs-check` runs the gates (frontmatter, links, widgets, Mermaid palette, the scripture rule),
`make docs` builds the site, `make docs-dev` serves it locally. Scripture is never typed into a
page: it appears only as an API-fetched verbatim line with its Ang, or a cited blockquote the gate
verifies against the pinned database.

## Toolchain (important)
The server and tools are Python stdlib only; the web UI needs Node. CI pins Python to
`.python-version` (3.12) and Node to `.nvmrc` (22). `make doctor` checks the toolchain and
the installed database (`make dataset`). The data pipeline and its toolchain live in sggs-data.
