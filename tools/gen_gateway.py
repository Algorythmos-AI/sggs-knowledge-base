#!/usr/bin/env python3
"""Generate the gateway's routing (frontend/vercel.json "rewrites") from the code.

    python3 tools/gen_gateway.py            # rewrite frontend/vercel.json
    python3 tools/gen_gateway.py --check    # exit 1 if vercel.json differs from what would be generated
    python3 tools/gen_gateway.py --probes staging   # "context url-path" for each routed context

Which API prefix belongs to which bounded context comes from serve.ROUTES (every route is tagged
with its context), so the gateway can never send a path to a service that does not serve it.
gateway/routes.json says, per environment, which contexts have their own service. For those, each
of the context's prefixes (and its /api/v1 twin) is rewritten to the service; everything else goes
to the environment's single API. Staging rules are host-conditioned and come first (Vercel applies
the first matching rewrite). Stdlib only.
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


def rewrites(cfg: dict) -> list[dict]:
    by_ctx = prefixes_by_context()
    out = []
    for env in ("staging", "production"):
        e = cfg[env]
        has = [{"type": "host", "value": e["host"]}] if e.get("host") else None
        for ctx in sorted(e["services"]):
            if ctx not in by_ctx:
                raise SystemExit(f"{env}: unknown context {ctx!r}")
            origin = e["service_origin"].format(context=ctx)
            for p in by_ctx[ctx]:
                for base in ("/api", "/api/v1"):
                    rule = {"source": f"{base}/{p}/:path*", "destination": f"{origin}{base}/{p}/:path*"}
                    if has:
                        rule = {"source": rule["source"], "has": has, "destination": rule["destination"]}
                    out.append(rule)
        rule = {"source": "/api/:path*", "destination": f"{e['single_api']}/api/:path*"}
        if has:
            rule = {"source": rule["source"], "has": has, "destination": rule["destination"]}
        out.append(rule)
    return out


def render(cfg: dict) -> str:
    doc = json.loads(VERCEL.read_text(encoding="utf-8"))
    doc["rewrites"] = rewrites(cfg)
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--probes", metavar="ENV")
    a = ap.parse_args(argv)
    cfg = json.loads(ROUTES_FILE.read_text(encoding="utf-8"))
    if a.probes:
        for ctx in sorted(cfg[a.probes]["services"]):
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
    print(f"wrote {VERCEL.relative_to(ROOT)} ({len(json.loads(want)['rewrites'])} rewrites)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
