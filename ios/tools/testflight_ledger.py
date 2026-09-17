#!/usr/bin/env python3
"""
testflight_ledger.py — the source of record for every build uploaded to App Store
Connect, and the gate that keeps a build number monotonic *before* a 20-minute
archive+upload discovers Apple's rejection.

The ledger is ios/testflight-builds.json (tracked). Apple enforces two rules that
this tool mirrors:
  - a CFBundleVersion (build number) may not be reused within a marketing version, and
  - a marketing version already on TestFlight may not be undercut by a lower one.

Commands
  check <version> <build> [--strict]
      Print `next: N` for the version. With --strict, exit 1 when <build> is not
      greater than every build already recorded for <version>, or when <version>
      is lower than the highest version in the ledger. Without --strict a violation
      is a warning and the exit code stays 0 (so a local re-archive with UPLOAD=0
      is never blocked).
  next <version>
      Print only the next build number for <version> (1 if the version is new).
  record <candidate.json> [--force]
      Append a row from the archive script's candidate-<v>-<b>.json. Refuses a
      duplicate (version, build). Refuses a candidate whose "uploaded" is false
      unless --force (the Transporter path, where the upload happens later).

Exit codes: 0 ok · 1 gate/refusal · 2 usage/IO error.
"""
import argparse, json, sys
from datetime import datetime, timezone
from pathlib import Path

LEDGER = Path(__file__).resolve().parents[1] / "testflight-builds.json"


def _semver(v):
    try:
        return tuple(int(x) for x in v.split("."))
    except ValueError:
        raise SystemExit(f"error: {v!r} is not a X.Y.Z version")


def load():
    try:
        doc = json.loads(LEDGER.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"error: ledger not found: {LEDGER}")
    except json.JSONDecodeError as e:
        raise SystemExit(f"error: ledger is not valid JSON: {e}")
    if not isinstance(doc.get("builds"), list):
        raise SystemExit("error: ledger has no 'builds' list")
    return doc


def builds(doc):
    return doc["builds"]


def max_build_for(rows, version):
    ns = [r["build"] for r in rows if r["version"] == version]
    return max(ns) if ns else 0


def max_version(rows):
    vs = [_semver(r["version"]) for r in rows]
    return max(vs) if vs else (0, 0, 0)


def cmd_check(args):
    rows = builds(load())
    version, build = args.version, args.build
    _semver(version)
    nxt = max_build_for(rows, version) + 1
    problems = []
    if build <= max_build_for(rows, version):
        problems.append(
            f"build {build} was already uploaded for {version} "
            f"(highest is {max_build_for(rows, version)}); next: {nxt}"
        )
    if _semver(version) < max_version(rows):
        hi = ".".join(str(x) for x in max_version(rows))
        problems.append(
            f"version {version} is lower than {hi}, which is already on TestFlight"
        )
    print(f"next: {nxt}")
    if problems:
        tag = "error" if args.strict else "warning"
        for p in problems:
            print(f"{tag}: {p}", file=sys.stderr)
        if args.strict:
            return 1
    return 0


def cmd_next(args):
    rows = builds(load())
    _semver(args.version)
    print(max_build_for(rows, args.version) + 1)
    return 0


def cmd_record(args):
    doc = load()
    rows = builds(doc)
    try:
        cand = json.loads(Path(args.candidate).read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"error: candidate not found: {args.candidate}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"error: candidate is not valid JSON: {e}", file=sys.stderr)
        return 2
    try:
        version = str(cand["version"])
        build = int(cand["build"])
    except (KeyError, ValueError, TypeError):
        print("error: candidate needs 'version' and integer 'build'", file=sys.stderr)
        return 2
    _semver(version)
    if not cand.get("uploaded", False) and not args.force:
        print(
            "error: candidate 'uploaded' is false — pass --force to record a "
            "Transporter upload done outside the script",
            file=sys.stderr,
        )
        return 1
    if any(r["version"] == version and r["build"] == build for r in rows):
        print(f"error: {version} build {build} is already in the ledger", file=sys.stderr)
        return 1
    rows.append({
        "version": version,
        "build": build,
        "source_commit": cand.get("source_commit"),
        "profile": cand.get("profile"),
        "db_sha256": cand.get("db_sha256"),
        "uploaded_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "note": None,
    })
    LEDGER.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print(f"recorded {version} build {build} in {LEDGER.name}")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("check")
    c.add_argument("version")
    c.add_argument("build", type=int)
    c.add_argument("--strict", action="store_true")
    c.set_defaults(fn=cmd_check)

    n = sub.add_parser("next")
    n.add_argument("version")
    n.set_defaults(fn=cmd_next)

    r = sub.add_parser("record")
    r.add_argument("candidate")
    r.add_argument("--force", action="store_true")
    r.set_defaults(fn=cmd_record)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
