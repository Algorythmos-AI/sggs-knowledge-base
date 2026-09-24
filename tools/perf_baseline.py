#!/usr/bin/env python3
"""Latency baseline per route — the yardstick the service split is held to.

    python3 tools/perf_baseline.py --base https://sggs-knowledge-base.onrender.com \\
        [--requests 60] [--concurrency 2] [--out docs/perf/baseline.json]
    python3 tools/perf_baseline.py --base URL --compare docs/perf/baseline.json [--tolerance 0.10]

Measures a fixed, representative request mix per bounded context (reader, search, verify,
insights, knowledge) against one origin — the API itself, not the CDN, so the numbers describe the
service. Reports p50/p95/max per route and per context. Gentle by default (60 requests per route,
2 in flight). --compare fails when any context's p95 is worse than the recorded baseline by more
than the tolerance (the services plan allows +10 %). Stdlib only.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import statistics
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# (context, path) — the same mix every run, so baselines compare like for like.
MIX = [
    ("reader", "/api/ang/712"), ("reader", "/api/shabad/2"), ("reader", "/api/meta"),
    ("search", "/api/search?q=naam"), ("search", "/api/search?q=%E0%A8%B8%E0%A9%8B%E0%A8%9A%E0%A9%88"),
    ("search", "/api/word?w=%E0%A8%A8%E0%A8%BE%E0%A8%AE"),
    ("verify", "/api/verify?q=sochai%20soch%20na%20hovai"),
    ("insights", "/api/themes/network"), ("insights", "/api/analytics/author"),
    ("knowledge", "/api/timing/clock"),
]


def _once(url: str) -> float:
    t0 = time.perf_counter()
    req = urllib.request.Request(url, headers={"User-Agent": "sggs-perf-baseline", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=60) as r:
        r.read()
        if r.status != 200:
            raise RuntimeError(f"{url}: HTTP {r.status}")
    return (time.perf_counter() - t0) * 1000


def _pct(xs, p):
    xs = sorted(xs)
    return round(xs[min(len(xs) - 1, int(round(p / 100 * (len(xs) - 1))))], 1)


def measure(base: str, n: int, conc: int) -> dict:
    base = base.rstrip("/")
    for _, path in MIX:                              # warm every route once (cold start is not latency)
        _once(base + path)
    routes, per_ctx = {}, {}
    for ctx, path in MIX:
        with cf.ThreadPoolExecutor(conc) as ex:
            ms = list(ex.map(lambda _: _once(base + path), range(n)))
        routes[path] = {"context": ctx, "p50": _pct(ms, 50), "p95": _pct(ms, 95), "max": round(max(ms), 1)}
        per_ctx.setdefault(ctx, []).extend(ms)
    contexts = {c: {"p50": _pct(v, 50), "p95": _pct(v, 95), "n": len(v)} for c, v in sorted(per_ctx.items())}
    return {"base": base, "measured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "requests_per_route": n, "concurrency": conc, "contexts": contexts, "routes": routes}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", required=True)
    ap.add_argument("--requests", type=int, default=60)
    ap.add_argument("--concurrency", type=int, default=2)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--compare", type=Path)
    ap.add_argument("--tolerance", type=float, default=0.10)
    ap.add_argument("--from", dest="vantage", default="unspecified",
                    help="where the requests come from (network RTT dominates; compare like with like)")
    a = ap.parse_args(argv)
    r = measure(a.base, a.requests, a.concurrency)
    r["from"] = a.vantage
    for c, v in r["contexts"].items():
        print(f"  {c:<10} p50 {v['p50']:>7.1f} ms   p95 {v['p95']:>7.1f} ms   ({v['n']} requests)")
    if a.out:
        a.out.parent.mkdir(parents=True, exist_ok=True)
        a.out.write_text(json.dumps(r, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        print(f"baseline written: {a.out}")
    if a.compare:
        recorded = json.loads(a.compare.read_text(encoding="utf-8"))
        if recorded.get("from") != a.vantage:
            print(f"WARNING: baseline measured from {recorded.get('from')!r}, this run from {a.vantage!r}")
        base = recorded["contexts"]
        worse = {c: (base[c]["p95"], v["p95"]) for c, v in r["contexts"].items()
                 if c in base and v["p95"] > base[c]["p95"] * (1 + a.tolerance)}
        for c, (was, now) in worse.items():
            print(f"FAIL {c}: p95 {now} ms vs baseline {was} ms (> +{a.tolerance:.0%})")
        print(f"RESULT: {'FAIL' if worse else 'PASS'} against {a.compare}")
        return 1 if worse else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
