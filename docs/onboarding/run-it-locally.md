---
title: "Run it locally"
description: "From a fresh clone to the API, the website and this wiki running on your machine, with the gates CI runs — and what to do when a step fails."
sidebar:
  order: 2
---
# Run it locally

Everything here runs on a laptop with no accounts and no network after the first download. The
server is Python standard library only; the website and the wiki need Node.

## 1. Toolchain

| Tool | Version | Why |
|---|---|---|
| Python | 3.12 (`.python-version`) | the API, the tools, the gates. On macOS, Homebrew's `python3` is fine; avoid the system `/usr/bin/python3` |
| Node | 22 (`.nvmrc`) | the website (`frontend/`) and the wiki (`docs-site/`) |
| git | any recent | the repository (no Git LFS is needed here — the database is installed by pin) |
| make | any | the entry points below |

```bash
git clone https://github.com/Algorythmos-AI/sggs-platform.git
cd sggs-platform
make doctor          # checks python, node and whether the database is installed
```

## 2. The database (pinned, verified)

The scripture database is not in this repository. `dataset.lock.json` names the sggs-data commit
and the sha256 of the exact object to serve; `make dataset` downloads it (~104 MiB), verifies the
checksum and size, and installs it atomically as `db/sggs.sqlite` (git-ignored).

```bash
make dataset         # install db/sggs.sqlite from the pin
make dataset-check   # prove sggs-data publishes that object at the pinned commit
```

## 3. The API and the site

```bash
cd webapp && python3 serve.py
# → http://localhost:7777  (override with SGGS_PORT)
```

Open <http://localhost:7777> for the prebuilt website served from `webapp/static/`, and check the
API is whole:

```bash
curl -s http://localhost:7777/api/health | python3 -m json.tool
```

Every value under `checks` must be `true`: 60,658 lines, 1,430 Angs, FTS5 working, the Mool
Mantar verbatim, at least 560 `ੴ`, the verifier alive. Then try a search and a page:

```bash
curl -s 'http://localhost:7777/api/search?q=sat%20nam&limit=3' | python3 -m json.tool
curl -s 'http://localhost:7777/api/ang/1' | python3 -m json.tool | head -40
```

Every line comes back verbatim with its Ang. That is the only way scripture ever reaches a screen.

## 4. The website source (optional)

```bash
cd frontend && npm ci && npm run dev     # http://localhost:4321, calls the API on :7777
npm run build:deploy                      # builds and syncs dist/ into webapp/static/
```

## 5. This wiki

```bash
make docs-dev        # http://localhost:4322 — live reload; /api proxied to serve.py on :7777
make docs-check      # the docs gates: frontmatter, links, widgets, palette, the scripture rule
make docs            # full build with every Mermaid fence rendered and every link validated
```

## 6. The gates CI runs

```bash
make ci              # versions unified · dataset pin · platform tests · contract drift · docs gates
```

`make ci` is the no-PDF subset of what a pull request runs; the scripture gates themselves run in
sggs-data. The full list, with what each check proves, is in [CI gates](../process/ci-gates.md).

## When something fails

| Symptom | Cause | Fix |
|---|---|---|
| `db/sggs.sqlite missing — run: make dataset` | fresh clone | `make dataset` |
| `/api/health` has a `false` check | a partial or wrong database | `make dataset-check`, then `make dataset` again |
| `serve.py` says a table is missing at startup | `SGGS_MODULES` set to a subset without its slice | unset it, or point `SGGS_DB` at a slice from `make slices` |
| `python3` is 3.9 or the system interpreter | macOS default on `PATH` | use Homebrew's 3.12; `make doctor` tells you which one it found |
| `npm ci` fails on a platform binary | `node_modules` copied from another machine | delete `node_modules` and run `npm ci` again |
| the wiki build says a Mermaid diagram failed | a syntax error in a fence | the message names the file and diagram; GitHub's preview of the same fence helps |
| the wiki build cannot find Chromium | Playwright browsers not installed | `cd docs-site && npx playwright install chromium` |

More detail on the layout of the repository and the API is in
[Local setup, repository map & API](../engineering/local-setup.md).
