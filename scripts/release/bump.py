#!/usr/bin/env python3
"""
bump.py X.Y.Z — set the single unified version everywhere at once, and open a
dated CHANGELOG stub. Run check_versions.py afterwards (it is the CI gate).

Updates: webapp/serve.py (APP_VERSION + APP_BUILT), MANIFEST.json (version+built),
frontend/package.json, ios/App/project.yml (MARKETING_VERSION), README badge +
"Current release" line, MASTER-INDEX header. It does NOT
touch db_sha256/corpus_sha256 (those are stamped by the rebuild) and does NOT
touch the iOS build number: CURRENT_PROJECT_VERSION stays at its floor "1" and
each TestFlight upload passes BUILD=N explicitly to ios/tools/testflight_archive.sh,
which records it (per marketing version, monotonic) in ios/testflight-builds.json.

Usage: python3 scripts/release/bump.py 1.2.0 [--date 2026-09-20]
"""
import argparse, json, re, sys, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

def edit(rel, fn):
    p = ROOT / rel
    s = p.read_text(encoding="utf-8")
    s2 = fn(s)
    if s2 != s:
        p.write_text(s2, encoding="utf-8")
        print(f"  updated {rel}")
    else:
        print(f"  (no change) {rel}")

def sub1(pattern, repl):
    return lambda s: re.sub(pattern, repl, s, count=1)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    args = ap.parse_args()
    v, d = args.version, args.date
    if not SEMVER.match(v):
        print(f"error: {v!r} is not X.Y.Z", file=sys.stderr); return 2

    print(f"Bumping to {v} (built {d})…")
    edit("webapp/serve.py", sub1(r"APP_VERSION = '[^']+'", f"APP_VERSION = '{v}'"))
    edit("webapp/serve.py", sub1(r"APP_BUILT = '[^']+'", f"APP_BUILT = '{d}'"))

    def man(s):
        m = json.loads(s); m["version"] = v; m["built"] = d
        return json.dumps(m, indent=2) + "\n"
    edit("MANIFEST.json", man)

    def pkg(s):
        return re.sub(r'("version":\s*")[^"]+(")', rf'\g<1>{v}\g<2>', s, count=1)
    edit("frontend/package.json", pkg)

    edit("ios/App/project.yml", sub1(r'MARKETING_VERSION: "[^"]+"', f'MARKETING_VERSION: "{v}"'))
    edit("README.md", sub1(r"version-\d+\.\d+\.\d+-", f"version-{v}-"))
    edit("README.md", sub1(r"Current release: \*\*v\d+\.\d+\.\d+\*\*", f"Current release: **v{v}**"))
    edit("MASTER-INDEX.md", sub1(r"v\d+\.\d+\.\d+, built \d{4}-\d{2}-\d{2}", f"v{v}, built {d}"))

    # CHANGELOG stub (only if this version has no entry yet)
    cl = ROOT / "CHANGELOG.md"
    s = cl.read_text(encoding="utf-8")
    if f"## [{v}]" not in s:
        stub = (f"## [{v}] — {d}\n\n### Added\n\n### Changed\n\n### Fixed\n\n### Data\n\n")
        anchor = "entries prior to v1.1.0 are the project's original prose style and are preserved verbatim.\n\n"
        if anchor in s:
            s = s.replace(anchor, anchor + stub, 1)
        else:  # fall back: after the H1
            s = re.sub(r"(# Changelog[^\n]*\n)", r"\1\n" + stub, s, count=1)
        cl.write_text(s, encoding="utf-8")
        print(f"  added CHANGELOG stub for {v}")
    print("\nNext: fill in the CHANGELOG, then run  python3 scripts/release/check_versions.py")
    return 0

if __name__ == "__main__":
    sys.exit(main())
