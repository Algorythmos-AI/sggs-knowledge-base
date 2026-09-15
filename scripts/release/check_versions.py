#!/usr/bin/env python3
"""
check_versions.py — assert the single unified version is identical across every
place it lives. The CI `version-consistency` gate; also runnable locally
(`make check-versions`).

Sources of truth checked (all must equal webapp/serve.py:APP_VERSION):
  webapp/serve.py APP_VERSION · MANIFEST.json version · frontend/package.json
  version · ios/App/project.yml MARKETING_VERSION · README.md badge ·
  MASTER-INDEX.md header · CLAUDE.md build line · CHANGELOG.md top entry.

Exit 0 if consistent, 1 otherwise.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(p): return (ROOT / p).read_text(encoding="utf-8")

def first(pattern, text, label):
    m = re.search(pattern, text)
    return m.group(1) if m else f"<not found: {label}>"

def main():
    canon = first(r"APP_VERSION\s*=\s*'([^']+)'", read("webapp/serve.py"), "serve.py")
    found = {
        "webapp/serve.py APP_VERSION": canon,
        "MANIFEST.json version": json.loads(read("MANIFEST.json")).get("version", "<none>"),
        "frontend/package.json version": json.loads(read("frontend/package.json")).get("version", "<none>"),
        "ios project.yml MARKETING_VERSION": first(r'MARKETING_VERSION:\s*"([^"]+)"', read("ios/App/project.yml"), "project.yml"),
        "README.md badge": first(r"version-([0-9]+\.[0-9]+\.[0-9]+)-", read("README.md"), "README"),
        "MASTER-INDEX.md header": first(r"·\s*v([0-9]+\.[0-9]+\.[0-9]+),\s*built", read("MASTER-INDEX.md"), "MASTER-INDEX"),
        "CLAUDE.md build line": first(r"APP_VERSION\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)", read("CLAUDE.md"), "CLAUDE.md"),
        "CHANGELOG.md top entry": first(r"##\s*\[([0-9]+\.[0-9]+\.[0-9]+)\]", read("CHANGELOG.md"), "CHANGELOG"),
    }
    width = max(len(k) for k in found)
    ok = True
    print(f"canonical version (serve.py): {canon}\n")
    for k, v in found.items():
        match = (v == canon)
        ok = ok and match
        print(f"  {'ok  ' if match else 'FAIL'} {k:<{width}} = {v}")
    print()
    if not ok:
        print("RESULT: FAIL — version strings are not unified. Run `python3 scripts/release/bump.py <X.Y.Z>`.")
        return 1
    print(f"RESULT: PASS — all {len(found)} version strings == {canon}.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
