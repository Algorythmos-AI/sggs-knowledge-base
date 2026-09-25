#!/usr/bin/env python3
"""docs_pins.py — re-pin the sibling repositories' docs, but only when what the wiki publishes changed.

`fetch_sibling_docs.py --update NAME` moves a pin to the tip of its `ref` whenever that repository
has a new commit — usually one that touched nothing the wiki publishes. This keeps the new pin only
when a pinned file was added, removed or changed (a page, or a source file a code excerpt reads), so
the weekly workflow (.github/workflows/docs-pins.yml) opens a pull request only for a real change.

    python3 tools/docs_pins.py                     # every source in docs-site/sources.lock.json
    python3 tools/docs_pins.py sggs-data           # one source
    python3 tools/docs_pins.py --summary pins.md   # also write the pull request body

Prints `changed=true|false` to $GITHUB_OUTPUT when set. Stdlib only; needs the network (GH_TOKEN).
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_sibling_docs as fsd  # noqa: E402


def diff_files(old: dict, new: dict) -> dict[str, list[str]]:
    """Paths added, removed or changed (by sha256) between two `files` maps of the lock."""
    return {
        "added": sorted(set(new) - set(old)),
        "removed": sorted(set(old) - set(new)),
        "changed": sorted(p for p in set(old) & set(new) if old[p].get("sha256") != new[p].get("sha256")),
    }


def summary(results: dict[str, tuple[dict, dict, dict]]) -> str:
    """The pull request body: per source, the commit move and every published file that changed."""
    out = ["The sibling repositories changed documentation the wiki publishes. This pull request moves",
           "their pins in `docs-site/sources.lock.json` (ADR-0012); the `docs` check re-runs every gate",
           "against the new files. Review what changed, then merge.", ""]
    for name, (before, after, d) in results.items():
        repo = after["repository"]
        out.append(f"### {name} — `{before['commit'][:7]}` → `{after['commit'][:7]}`")
        out.append(f"[compare](https://github.com/{repo}/compare/{before['commit']}...{after['commit']})")
        out.append("")
        for kind in ("added", "changed", "removed"):
            for p in d[kind]:
                out.append(f"- {kind}: `{p}`")
        out.append("")
    out.append("Opened by `.github/workflows/docs-pins.yml` (`tools/docs_pins.py`).")
    return "\n".join(out) + "\n"


def run(names: list[str] | None = None, update=None) -> tuple[bool, dict]:
    """Re-pin each source; keep the lock only for sources whose published files changed."""
    update = update or fsd.update
    lock = fsd.load_lock()
    names = names or sorted(lock["sources"])
    results: dict[str, tuple[dict, dict, dict]] = {}
    for name in names:
        before = copy.deepcopy(lock["sources"][name])
        trial = copy.deepcopy(lock)
        update(trial, name)                      # writes the lock with the new pin
        after = json.loads(fsd.LOCK.read_text(encoding="utf-8"))["sources"][name]
        d = diff_files(before["files"], after["files"])
        if any(d.values()):
            lock["sources"][name] = after
            results[name] = (before, after, d)
            print(f"{name}: {before['commit'][:7]} -> {after['commit'][:7]}: "
                  f"{len(d['added'])} added, {len(d['changed'])} changed, {len(d['removed'])} removed")
        else:
            print(f"{name}: nothing the wiki publishes changed (pin stays {before['commit'][:7]})")
        fsd.LOCK.write_text(json.dumps(lock, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return bool(results), results


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("names", nargs="*")
    ap.add_argument("--summary", type=Path)
    a = ap.parse_args(argv)
    changed, results = run(a.names or None)
    if a.summary and changed:
        a.summary.write_text(summary(results), encoding="utf-8")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"changed={'true' if changed else 'false'}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
