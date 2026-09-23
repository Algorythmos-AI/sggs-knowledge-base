#!/usr/bin/env python3
"""
check_versions.py — assert the single unified version is identical across every
place it lives, plus two iOS build invariants. The CI `version-consistency`
gate; also runnable locally (`make check-versions`).

Sources of truth checked (all must equal webapp/serve.py:APP_VERSION):
  webapp/serve.py APP_VERSION · MANIFEST.json version · frontend/package.json
  version · ios/App/project.yml MARKETING_VERSION · README.md badge ·
  MASTER-INDEX.md header · CHANGELOG.md top entry.

iOS build invariants (independent of the marketing version):
  - ios/App/project.yml CURRENT_PROJECT_VERSION is the floor "1" (each upload
    passes BUILD=N to the archive script; the committed floor never moves).
  - no <x.y.z>+<n> version literal is hardcoded in ios/App/Tests/UI/*.swift
    (the About-screen UI test must read the built version, not a literal).

One-number policy (web == API == iOS binary):
  - the newest version in the ledger ios/testflight-builds.json is <= APP_VERSION.
    The shipped binary may equal APP_VERSION (this release) or trail it (a past
    release), but it can never be AHEAD of the repo. (This runs on every branch,
    so it deliberately makes no assertion about commit ancestry, which only holds
    on main after a release merge.)

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

    # One-number policy: the shipped iOS binary can never be ahead of the repo.
    def _semver(v):
        try:
            return tuple(int(x) for x in v.split("."))
        except ValueError:
            return None
    try:
        ledger = json.loads(read("ios/testflight-builds.json"))
        rows = ledger.get("builds", []) if isinstance(ledger, dict) else []
        led_versions = [r["version"] for r in rows if isinstance(r, dict) and "version" in r]
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        led_versions = []
    canon_t = _semver(canon)
    newest = max((_semver(v) for v in led_versions if _semver(v)), default=None)
    if not led_versions:
        led_detail, led_ok = "ledger empty (no uploads yet)", True
    elif canon_t is None:
        led_detail, led_ok = f"canonical version {canon!r} unparseable", False
    else:
        newest_s = ".".join(str(x) for x in newest)
        led_ok = newest <= canon_t
        led_detail = (f"newest ledger {newest_s} <= APP_VERSION {canon}" if led_ok
                      else f"newest ledger {newest_s} is AHEAD of APP_VERSION {canon} — bump the repo")
    invariants.append(("iOS ledger not ahead of APP_VERSION", led_ok, led_detail))

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
