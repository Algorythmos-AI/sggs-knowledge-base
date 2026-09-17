#!/usr/bin/env python3
"""
check_versions.py — assert the single unified version is identical across every
place it lives, plus two iOS build invariants. The CI `version-consistency`
gate; also runnable locally (`make check-versions`).

Sources of truth checked (all must equal webapp/serve.py:APP_VERSION):
  webapp/serve.py APP_VERSION · MANIFEST.json version · frontend/package.json
  version · ios/App/project.yml MARKETING_VERSION · README.md badge ·
  MASTER-INDEX.md header · CLAUDE.md build line · CHANGELOG.md top entry.

iOS build invariants (independent of the marketing version):
  - ios/App/project.yml CURRENT_PROJECT_VERSION is the floor "1" (each upload
    passes BUILD=N to the archive script; the committed floor never moves).
  - no <x.y.z>+<n> version literal is hardcoded in ios/App/Tests/UI/*.swift
    (the About-screen UI test must read the built version, not a literal).

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
    # iOS build invariants — booleans, not version-equality (see module docstring).
    proj = read("ios/App/project.yml")
    cpv = first(r'CURRENT_PROJECT_VERSION:\s*"([^"]+)"', proj, "project.yml CPV")
    ui_literals = []
    for sw in sorted((ROOT / "ios/App/Tests/UI").glob("*.swift")):
        for i, line in enumerate(sw.read_text(encoding="utf-8").splitlines(), 1):
            if re.search(r"\b\d+\.\d+\.\d+\+\d+\b", line):
                ui_literals.append(f"{sw.relative_to(ROOT)}:{i}")
    invariants = [
        ("iOS CURRENT_PROJECT_VERSION is the floor \"1\"", cpv == "1", f"got {cpv!r}"),
        ("no x.y.z+n literal in UI tests", not ui_literals,
         "found: " + ", ".join(ui_literals) if ui_literals else "none"),
    ]

    width = max([len(k) for k in found] + [len(k) for k, _, _ in invariants])
    ok = True
    print(f"canonical version (serve.py): {canon}\n")
    for k, v in found.items():
        match = (v == canon)
        ok = ok and match
        print(f"  {'ok  ' if match else 'FAIL'} {k:<{width}} = {v}")
    print()
    for k, passed, detail in invariants:
        ok = ok and passed
        print(f"  {'ok  ' if passed else 'FAIL'} {k:<{width}} : {detail}")
    print()
    if not ok:
        print("RESULT: FAIL — run `python3 scripts/release/bump.py <X.Y.Z>` for version drift, "
              "or fix the iOS invariant shown above.")
        return 1
    n = len(found) + len(invariants)
    print(f"RESULT: PASS — {len(found)} version strings == {canon}; {len(invariants)} iOS invariants hold ({n} checks).")
    return 0

if __name__ == "__main__":
    sys.exit(main())
