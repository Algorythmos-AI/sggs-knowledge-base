#!/usr/bin/env python3
"""Prove a running API honours the golden-vector contract — over HTTP, not in-process.

    python3 tools/contract_http.py --base http://127.0.0.1:7777 [--suites verify,search,...]

Replays the SAME projections tools/gen_golden_vectors.py records (its API / SEARCH /
VERIFY transport is rebound to HTTP GETs), then compares every record with the committed
contract/golden_<suite>.ndjson by parsed-JSON equality. Nothing is forked: a projection
change is a change to the generator, and both paths pick it up.

Scope and documented normalisations:
  * suites: verify, search, reader, timing, banis, analytics (roman_norm / difflib are
    pure functions with no endpoint)
  * reader: the seeded Hukam records are skipped — /api/random has no seed
  * verify: /api/verify rejects an empty (whitespace-only) claim with HTTP 400 — input
    validation the in-process engine does not do — so those records are checked for the
    400 and excluded from the verdict comparison
  * search: /api/search always returns related_themes (defaults to []), while the vector
    records do_search's own field (null when absent) — null and [] compare equal
  * analytics picks its sample raags/authors from the local db/sggs.sqlite, so run it
    against a server built from the same dataset (the normal CI/deploy case)

Deployment protection: if VERCEL_AUTOMATION_BYPASS_SECRET is set it is sent as
x-vercel-protection-bypass (preview/staging). Exit 0 only if every record matches.
Stdlib only.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
_ARGV = sys.argv[1:]
sys.argv = sys.argv[:1]          # the generator reads its DB path from argv; use its default
import gen_golden_vectors as g  # noqa: E402

HTTP_SUITES = ("verify", "search", "reader", "timing", "banis", "analytics")


class Http:
    def __init__(self, base, timeout=60):
        self.base = base.rstrip("/")
        self.timeout = timeout
        self.headers = {"Accept": "application/json", "User-Agent": "sggs-contract-http"}
        secret = os.environ.get("VERCEL_AUTOMATION_BYPASS_SECRET")
        if secret:
            self.headers["x-vercel-protection-bypass"] = secret
        self.calls = 0

    def get(self, path, qs):
        query = urllib.parse.urlencode(qs or {}, doseq=True)
        url = self.base + path + ("?" + query if query else "")
        req = urllib.request.Request(url, headers=self.headers)
        self.calls += 1
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            try:
                msg = json.loads(e.read().decode("utf-8")).get("error", "")
            except Exception:
                msg = ""
            raise g.serve.ApiError(e.code, msg or f"HTTP {e.code}") from None


REJECTED = []   # empty claims the endpoint correctly refused with 400


def _verify(http, claim, ang):
    try:
        return http.get("/api/verify", dict({"q": [claim]}, **({"ang": [str(ang)]} if ang else {})))
    except g.serve.ApiError as e:
        if e.status == 400 and not claim.strip():
            REJECTED.append(claim)
            return {}
        raise


def bind(http):
    g.API = lambda path, qs: http.get(path, qs)
    g.SEARCH = lambda q, mode: http.get("/api/search", {"q": [q], "mode": [mode], "limit": ["50"], "offset": ["0"]})
    g.VERIFY = lambda claim, ang: _verify(http, claim, ang)
    g.HUKAM = False


def normalise(suite, rec):
    rec = json.loads(json.dumps(rec, ensure_ascii=False))     # tuples -> lists, as on disk
    if suite == "search" and rec.get("related_themes") is None:
        rec["related_themes"] = []
    return rec


def committed(suite):
    fname = g.SUITES[suite][0]
    rows = [json.loads(line) for line in (ROOT / "contract" / fname).read_text(encoding="utf-8").splitlines() if line.strip()]
    if suite == "reader":
        rows = [r for r in rows if r.get("kind") != "hukam"]
    return [normalise(suite, r) for r in rows]


def _comparable(suite, rows):
    if suite == "verify":
        return [r for r in rows if (r.get("claim") or "").strip()]
    return rows


def run_suite(suite):
    all_want = committed(suite)
    got = _comparable(suite, [normalise(suite, r) for r in g.SUITES[suite][1]()])
    want = _comparable(suite, all_want)
    fails = []
    if suite == "verify":
        empties = [r["claim"] for r in all_want if not (r.get("claim") or "").strip()]
        if sorted(REJECTED) != sorted(empties):
            fails.append(f"verify: empty claims {empties!r} should each be rejected with HTTP 400; got {REJECTED!r}")
    if len(got) != len(want):
        fails.append(f"{suite}: {len(got)} records over HTTP vs {len(want)} committed")
    for i, (a, b) in enumerate(zip(want, got)):
        if a != b:
            label = {k: a.get(k) for k in ("kind", "query", "mode", "claim", "n", "comp_id", "key", "raag", "id") if k in a}
            fails.append(f"{suite}[{i}] {json.dumps(label, ensure_ascii=False)} differs")
    return len(want), fails


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", required=True, help="API origin, e.g. http://127.0.0.1:7777")
    ap.add_argument("--suites", default=",".join(HTTP_SUITES))
    a = ap.parse_args(argv)
    suites = [s.strip() for s in a.suites.split(",") if s.strip()]
    bad = [s for s in suites if s not in HTTP_SUITES]
    if bad:
        print(f"not HTTP-checkable: {bad} (choose from {list(HTTP_SUITES)})")
        return 2
    http = Http(a.base)
    bind(http)
    total, fails = 0, []
    for s in suites:
        n, f = run_suite(s)
        total += n
        fails += f
        print(f"  {'ok  ' if not f else 'FAIL'} {s:<10} {n} records")
    for f in fails[:40]:
        print("    " + f)
    print(f"contract over HTTP: {'PASS' if not fails else 'FAIL'} — {total} records, {http.calls} requests to {a.base}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(_ARGV))
