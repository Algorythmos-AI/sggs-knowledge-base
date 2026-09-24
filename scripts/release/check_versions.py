#!/usr/bin/env python3
"""
check_versions.py — assert the platform's single version is identical in every place it lives.
The CI `version-consistency` gate; also runnable locally (`make check-versions`).

Sources of truth checked (all must equal webapp/serve.py:APP_VERSION):
  webapp/serve.py APP_VERSION · frontend/package.json version · README.md badge ·
  MASTER-INDEX.md header · CHANGELOG.md top entry.

The iOS app (Algorythmos-AI/gurbani-soul-ios) keeps the one-number policy on its side: its
MARKETING_VERSION must equal the platform release whose contract it vendors, and its TestFlight
ledger may never lead it. scripts/release/check_release_complete.py proves a release end to end.

Exit 0 if consistent, 1 otherwise.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(p):
    return (ROOT / p).read_text(encoding="utf-8")


def first(pattern, text, label):
    m = re.search(pattern, text)
    return m.group(1) if m else f"<not found: {label}>"


def main():
    canon = first(r"APP_VERSION\s*=\s*'([^']+)'", read("webapp/serve.py"), "serve.py")
    found = {
        "webapp/serve.py APP_VERSION": canon,
        "frontend/package.json version": json.loads(read("frontend/package.json")).get("version", "<none>"),
        "README.md badge": first(r"version-([0-9]+\.[0-9]+\.[0-9]+)-", read("README.md"), "README"),
        "MASTER-INDEX.md header": first(r"·\s*v([0-9]+\.[0-9]+\.[0-9]+),\s*built", read("MASTER-INDEX.md"), "MASTER-INDEX"),
        "CHANGELOG.md top entry": first(r"##\s*\[([0-9]+\.[0-9]+\.[0-9]+)\]", read("CHANGELOG.md"), "CHANGELOG"),
    }
    width = max(len(k) for k in found)
    print(f"canonical version (serve.py): {canon}\n")
    ok = True
    for k, v in found.items():
        match = v == canon
        ok = ok and match
        print(f"  {'ok  ' if match else 'FAIL'} {k:<{width}} = {v}")
    print()
    if not ok:
        print("RESULT: FAIL — run `python3 scripts/release/bump.py <X.Y.Z>` to unify the version.")
        return 1
    print(f"RESULT: PASS — {len(found)} version strings == {canon}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
