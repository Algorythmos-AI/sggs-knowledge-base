#!/usr/bin/env python3
"""Generate the gateway (frontend/vercel.json "rewrites", "functions", "regions") from the code.

    python3 tools/gen_gateway.py            # rewrite frontend/vercel.json
    python3 tools/gen_gateway.py --check    # exit 1 if vercel.json differs from what would be generated
    python3 tools/gen_gateway.py --probes staging   # "context url-path" for each routed context

The API runs inside the web's Vercel project as Python functions: one per bounded context plus
`all` (the whole API on the full database), generated at build time by tools/build_api_functions.py.
Every deployment carries all of them; gateway/routes.json decides, per environment, where /api goes:

  * api_platform "vercel": each context in "services" is rewritten to its function (every prefix
    that serve.ROUTES tags with that context, and its /api/v1 twin); every other /api path, /readyz
    and /healthz go to `all`. /readyz?svc=<context> reaches that context's readiness check.
  * api_platform "render": every /api path is proxied to the Render origin in "api" (the single API).

Staging rules are host-conditioned and come first (Vercel applies the first matching rewrite), so
production's rules catch every other host, including an unaliased deployment URL. Rewrite sources
use unnamed groups on purpose: a named segment the destination does not use is appended to the
query string, which would change what the handler sees. Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "webapp"))
VERCEL = ROOT / "frontend" / "vercel.json"
ROUTES_FILE = ROOT / "gateway" / "routes.json"
# One cheap, parameter-complete request per context: how CI proves the gateway routes it.
PROBES = {"reader": "/api/ang/1", "search": "/api/search?q=naam", "verify": "/api/verify?q=sochai%20soch",
          "insights": "/api/themes/network", "knowledge": "/api/timing/clock"}
PLATFORMS = ("vercel", "render")
FN_DIR = "api/svc"         # function entries, relative to the web project's root (frontend/)
DATA_DIR = "_sggs"         # the API's code and databases, next to them (never in the static output)
REGION = "pdx1"            # next to the Render API (Oregon) the functions replace
MAX_DURATION_S = 60
# The web project's own files: kept out of every function bundle (node_modules is excluded by
# Vercel already). tools/build_api_functions.py --verify-output fails the build on anything else.
WEB_ONLY = ("src/**", "public/**", "e2e/**", "scripts/**", "dist/**", ".astro/**", "test-results/**",
            "playwright-report/**", "*.json", "*.mjs", "*.ts")


def prefixes_by_context() -> dict[str, list[str]]:
    import serve
    owner: dict[str, set[str]] = {}
    for (p0, _p1), route in serve.ROUTES.items():
        owner.setdefault(p0, set()).add(route[1])
    shared = {p: sorted(c) for p, c in owner.items() if len(c) > 1}
    if shared:
        raise SystemExit(f"prefixes served by more than one context cannot be routed: {shared}")
    out: dict[str, list[str]] = {}
    for p, (ctx,) in sorted(owner.items()):
        out.setdefault(ctx, []).append(p)
    return out


def function_names() -> list[str]:
    """Every deployment carries a function per context plus `all`."""
    return sorted(prefixes_by_context()) + ["all"]


def environments(cfg: dict) -> dict[str, dict]:
    """The environments in routes.json, validated: a known platform, services only on Vercel."""
    by_ctx = prefixes_by_context()
    envs = {k: v for k, v in cfg.items() if not k.startswith("_")}
    for name, e in envs.items():
        if e.get("api_platform") not in PLATFORMS:
            raise SystemExit(f"{name}: api_platform must be one of {PLATFORMS}")
        if e["api_platform"] == "render" and not str(e.get("api", "")).startswith("https://"):
            raise SystemExit(f"{name}: a Render API needs its https origin in \"api\"")
        unknown = [c for c in e["services"] if c not in by_ctx]
        if unknown:
            raise SystemExit(f"{name}: unknown context(s) {unknown}")
        if e["services"] and e["api_platform"] != "vercel":
            raise SystemExit(f"{name}: per-context services exist only on the Vercel functions")
    return envs


def rewrites(cfg: dict) -> list[dict]:
    envs = environments(cfg)
    by_ctx = prefixes_by_context()
    out = []

    def add(source, destination, host=None, query=None):
        rule = {"source": source}
        has = ([{"type": "host", "value": host}] if host else []) + \
              ([{"type": "query", "key": "svc", "value": query}] if query else [])
        if has:
            rule["has"] = has
        rule["destination"] = destination
        out.append(rule)

    for name in ("staging", "production"):
        e, host = envs[name], envs[name].get("host")
        if e["api_platform"] == "render":
            add("/api/:path*", f"{e['api']}/api/:path*", host)
            continue
        for ctx in sorted(e["services"]):
            for p in by_ctx[ctx]:
                for base in ("/api", "/api/v1"):
                    add(f"{base}/{p}(/.*)?", f"/{FN_DIR}/{ctx}", host)
            add("/readyz", f"/{FN_DIR}/{ctx}", host, query=ctx)
        add("/api/(.*)", f"/{FN_DIR}/all", host)
        add("/readyz", f"/{FN_DIR}/all", host)
        add("/healthz", f"/{FN_DIR}/all", host)
    return out


def functions() -> dict:
    names = function_names()
    out = {}
    for name in names:
        own = [f"{DATA_DIR}/db/{n}.sqlite" for n in names if n != name]
        out[f"{FN_DIR}/{name}.py"] = {"maxDuration": MAX_DURATION_S,
                                      "excludeFiles": "{" + ",".join(list(WEB_ONLY) + own) + "}"}
    return out


def render(cfg: dict) -> str:
    doc = json.loads(VERCEL.read_text(encoding="utf-8"))
    doc["regions"] = [REGION]
    doc["functions"] = functions()
    doc["rewrites"] = rewrites(cfg)
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--probes", metavar="ENV")
    a = ap.parse_args(argv)
    cfg = json.loads(ROUTES_FILE.read_text(encoding="utf-8"))
    if a.probes:
        for ctx in sorted(environments(cfg)[a.probes]["services"]):
            print(ctx, PROBES[ctx])
        return 0
    want = render(cfg)
    if a.check:
        if VERCEL.read_text(encoding="utf-8") != want:
            print("frontend/vercel.json is stale — run: python3 tools/gen_gateway.py")
            return 1
        print("gateway routing is current")
        return 0
    VERCEL.write_text(want, encoding="utf-8")
    doc = json.loads(want)
    print(f"wrote {VERCEL.relative_to(ROOT)} ({len(doc['rewrites'])} rewrites, {len(doc['functions'])} functions)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
