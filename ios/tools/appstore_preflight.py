#!/usr/bin/env python3
"""appstore_preflight.py VERSION — may this marketing version be SUBMITTED to App Review?

A TestFlight binary and an App Store binary are the same upload, so "which build do I submit?" is
answered by the tracked ledger, not by memory. Exit 0 only when ALL of these hold:

  1. the newest recorded build for VERSION has channel == "appstore" (it was archived with
     CHANNEL=appstore, i.e. it passed the scholar-review gate on the Nitnem non-SGGS text);
  2. ios/Resources/NITNEM-REVIEW.md reads `REVIEWED: true`;
  3. the in-app label is off (NitnemReview.extraTextReviewed = true);
  4. that build was made with an SDK at or above the App Store floor;
  5. scripts/release/check_versions.py passes and the top CHANGELOG entry is VERSION;
  6. the store-listing lint (webapp/tests/test_repo_gates.py) passes.

Prints every failed condition, never just the first. Stdlib only.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIN_SDK_MAJOR = 26   # keep in step with MIN_XCODE_MAJOR in testflight_archive.sh


def newest_build(version, builds):
    rows = [b for b in builds if b.get("version") == version]
    return max(rows, key=lambda b: b["build"]) if rows else None


def evaluate(version, builds, review_text, schedule_text):
    """The pure part: every reason VERSION may not be submitted, given the ledger rows, the
    attestation file and the Swift source that carries the in-app label."""
    problems = []
    build = newest_build(version, builds)
    if build is None:
        problems.append(f"no uploaded build is recorded for {version} in ios/testflight-builds.json")
    else:
        label = f"{version} ({build['build']})"
        if build.get("channel") != "appstore":
            problems.append(f"newest build {label} has channel={build.get('channel', 'testflight')!r} — "
                            "rebuild with `make testflight … CHANNEL=appstore`; a TestFlight-channel build "
                            "has not passed the scholar-review gate and must not be submitted")
        sdk = str(build.get("sdk") or "")
        m = re.match(r"[a-z]+(\d+)", sdk)
        if not m or int(m.group(1)) < MIN_SDK_MAJOR:
            problems.append(f"build {label} records sdk={sdk or 'unknown'} — App Store Connect requires the "
                            f"iOS {MIN_SDK_MAJOR} SDK or later")
    if not re.search(r"(?m)^REVIEWED:\s*true\s*$", review_text):
        problems.append("ios/Resources/NITNEM-REVIEW.md is not signed (REVIEWED: true) — owner gate H1")
    if not re.search(r"(?m)^\s*static let extraTextReviewed = true\s*$", schedule_text):
        problems.append('the app still labels the Nitnem extra text "Under scholarly review" '
                        "(NitnemReview.extraTextReviewed is not true)")
    return build, problems


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    version = argv[0]
    doc = json.loads((ROOT / "ios" / "testflight-builds.json").read_text(encoding="utf-8"))
    build, problems = evaluate(
        version, doc.get("builds", []),
        (ROOT / "ios" / "Resources" / "NITNEM-REVIEW.md").read_text(encoding="utf-8"),
        (ROOT / "ios/App/Sources/Data/NitnemSchedule.swift").read_text(encoding="utf-8"))

    checks = [("version strings / CHANGELOG", [sys.executable, "scripts/release/check_versions.py"])]
    if (ROOT / "webapp/tests/test_repo_gates.py").exists():
        checks.append(("store-listing lint", [sys.executable, "-m", "unittest", "-q", "webapp.tests.test_repo_gates"]))
    for title, cmd in checks:
        run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        if run.returncode != 0:
            tail = (run.stdout + run.stderr).strip().splitlines()[-3:]
            problems.append(f"{title} failed: " + " | ".join(tail))

    if problems:
        print(f"NOT ready to submit {version}:")
        for p in problems:
            print(f"  ✗ {p}")
        print("\nOwner gates that no script can check: G3 scholar/Granthi sign-off, G4 legal clearance, "
              "Charter S on this build, the device + accessibility passes, the App Store Connect forms.")
        return 1
    print(f"OK  {version} ({build['build']}) may be submitted: channel=appstore, review signed, "
          f"sdk {build.get('sdk')}, versions and listing clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
