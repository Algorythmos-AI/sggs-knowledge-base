"""frontend/vercel.json's routing and API functions are generated from the code (tools/gen_gateway.py)."""
import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("gen_gateway", ROOT / "tools/gen_gateway.py")
gg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gg)
CFG = json.loads((ROOT / "gateway/routes.json").read_text(encoding="utf-8"))
VERCEL = json.loads((ROOT / "frontend/vercel.json").read_text(encoding="utf-8"))


class Gateway(unittest.TestCase):
    def test_vercel_json_is_generated(self):
        self.assertEqual(gg.main(["--check"]), 0, "run: python3 tools/gen_gateway.py")

    def test_every_prefix_has_exactly_one_context(self):
        seen = [p for ps in gg.prefixes_by_context().values() for p in ps]
        self.assertEqual(len(seen), len(set(seen)))

    def test_staging_rules_come_first_and_production_catches_every_other_host(self):
        rw = VERCEL["rewrites"]
        staging_host = [{"type": "host", "value": CFG["staging"]["host"]}]
        first_prod = next(i for i, r in enumerate(rw) if not any(h.get("type") == "host" for h in r.get("has", [])))
        for r in rw[:first_prod]:
            self.assertEqual([h for h in r["has"] if h["type"] == "host"], staging_host)
        for r in rw[first_prod:]:
            self.assertFalse(any(h.get("type") == "host" for h in r.get("has", [])))
        self.assertIn(rw[-1]["source"], ("/api/:path*", "/healthz"))

    def test_each_routed_context_prefix_reaches_its_own_function(self):
        by_ctx = gg.prefixes_by_context()
        for ctx in CFG["staging"]["services"]:
            for p in by_ctx[ctx]:
                for base in ("/api", "/api/v1"):
                    rule = next(r for r in VERCEL["rewrites"] if r["source"] == f"{base}/{p}(/.*)?")
                    self.assertEqual(rule["destination"], f"/api/svc/{ctx}")

    def test_function_rewrites_never_use_named_segments(self):
        # a named segment the destination does not use is appended to the query the handler sees
        for r in VERCEL["rewrites"]:
            if r["destination"].startswith("/api/svc/"):
                self.assertNotIn(":", r["source"], r)

    def test_every_function_excludes_the_web_and_the_other_databases(self):
        names = gg.function_names()
        self.assertEqual(sorted(VERCEL["functions"]), sorted(f"api/svc/{n}.py" for n in names))
        for name in names:
            excl = VERCEL["functions"][f"api/svc/{name}.py"]["excludeFiles"]
            for n in names:
                self.assertEqual(f"_sggs/db/{n}.sqlite" in excl, n != name, (name, n))
            for w in gg.WEB_ONLY:
                self.assertIn(w, excl)

    def test_services_exist_only_on_the_vercel_functions(self):
        bad = copy.deepcopy(CFG)
        bad["production"]["services"] = ["search"]
        with self.assertRaises(SystemExit):
            gg.environments(bad)
        bad = copy.deepcopy(CFG)
        bad["staging"]["api_platform"] = "fly"
        with self.assertRaises(SystemExit):
            gg.environments(bad)

    def test_routed_contexts_have_probes(self):
        for env in ("staging", "production"):
            for ctx in CFG[env]["services"]:
                self.assertIn(ctx, gg.PROBES)


if __name__ == "__main__":
    unittest.main()
