#!/usr/bin/env python3
"""Check docs/reference/repo-map.json — every path it names exists.

    python3 tools/gen_repo_map.py --check          # platform paths on disk; sibling paths against their pinned trees when a token is set

The map is curated by hand (a one-line purpose per path is the point); this check keeps it honest.
Platform paths are checked on disk. Sibling paths are checked against the repository tree at the
commit docs-site/sources.lock.json pins when GH_TOKEN/GITHUB_TOKEN is available (CI); without a
token they are listed as unchecked. Stdlib only.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "docs" / "reference" / "repo-map.json"
LOCK = ROOT / "docs-site" / "sources.lock.json"


def walk(entries):
    for e in entries:
        yield e["path"]
        yield from walk(e.get("children", []))


def sibling_tree(repository: str, commit: str) -> set[str] | None:
    tok = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not tok:
        return None
    req = urllib.request.Request(f"https://api.github.com/repos/{repository}/git/trees/{commit}?recursive=1",
                                 headers={"Authorization": f"Bearer {tok}", "Accept": "application/vnd.github+json", "User-Agent": "sggs-gen-repo-map"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read())
    paths = {t["path"] for t in data["tree"]}
    return paths | {p + "/" for p in paths if any(t["type"] == "tree" and t["path"] == p for t in data["tree"])}


def main(argv=None) -> int:
    m = json.loads(MAP.read_text(encoding="utf-8"))
    lock = json.loads(LOCK.read_text(encoding="utf-8")).get("sources", {}) if LOCK.exists() else {}
    bad, unchecked = [], 0
    for repo in m["repositories"]:
        paths = list(walk(repo["entries"]))
        if repo["repository"].endswith("/sggs-platform"):
            for p in paths:
                if not (ROOT / p).exists():
                    bad.append(f"{repo['repository']}: {p} does not exist")
            continue
        pinned = next((s for s in lock.values() if s.get("repository") == repo["repository"]), None)
        tree = sibling_tree(repo["repository"], pinned["commit"]) if pinned else None
        if tree is None:
            unchecked += len(paths)
            continue
        for p in paths:
            if p not in tree and p.rstrip("/") not in tree:
                bad.append(f"{repo['repository']}@{pinned['commit'][:7]}: {p} does not exist")
    for b in bad:
        print(f"::error file=docs/reference/repo-map.json::{b}")
    n = sum(len(list(walk(r["entries"]))) for r in m["repositories"])
    print(f"gen_repo_map: {n} paths, {len(bad)} missing, {unchecked} unchecked (no token)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
