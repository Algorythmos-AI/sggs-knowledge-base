#!/usr/bin/env python3
"""Deploy an exact commit to a Render service found by name, through the Render API.

    RENDER_API_KEY=... python3 scripts/ci/render_deploy.py SERVICE_NAME COMMIT_SHA   # prints the service URL

One API key serves every service (no per-service deploy-hook secrets). The service is looked up by
its exact name; its public URL is printed on stdout so the caller can wait for /readyz there.
Stdlib only; the key is sent only to api.render.com and never printed.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

API = "https://api.render.com/v1"


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {os.environ['RENDER_API_KEY']}",
                                          "Accept": "application/json", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read() or b"null")


def main(argv):
    if len(argv) != 3 or not os.environ.get("RENDER_API_KEY"):
        sys.exit("usage: RENDER_API_KEY=… render_deploy.py SERVICE_NAME COMMIT_SHA")
    name, sha = argv[1], argv[2]
    found = [s["service"] for s in call("GET", "/services?" + urllib.parse.urlencode({"name": name, "limit": 20}))
             if s.get("service", {}).get("name") == name]
    if len(found) != 1:
        sys.exit(f"expected exactly one Render service named {name!r}, found {len(found)}")
    svc = found[0]
    dep = call("POST", f"/services/{svc['id']}/deploys", {"commitId": sha, "clearCache": "do_not_clear"})
    print(f"deploy {dep.get('id')} of {sha[:7]} requested for {name}", file=sys.stderr)
    print(svc.get("serviceDetails", {}).get("url") or f"https://{name}.onrender.com")


if __name__ == "__main__":
    main(sys.argv)
