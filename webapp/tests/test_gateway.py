"""frontend/vercel.json's routing is generated from the code (tools/gen_gateway.py) and must stay so."""
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("gen_gateway", ROOT / "tools/gen_gateway.py")
gg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gg)


class Gateway(unittest.TestCase):
    def test_vercel_json_is_generated(self):
        self.assertEqual(gg.main(["--check"]), 0, "run: python3 tools/gen_gateway.py")

    def test_every_prefix_has_exactly_one_context(self):
        seen = [p for ps in gg.prefixes_by_context().values() for p in ps]
        self.assertEqual(len(seen), len(set(seen)))

    def test_specific_rules_precede_catch_alls_and_production_is_last(self):
        rw = json.loads((ROOT / "frontend/vercel.json").read_text(encoding="utf-8"))["rewrites"]
        catch = [i for i, r in enumerate(rw) if r["source"] == "/api/:path*"]
        self.assertEqual(len(catch), 2)
        self.assertEqual(catch[-1], len(rw) - 1)                       # production catch-all last
        self.assertNotIn("has", rw[-1])
        staging_catch = catch[0]
        for r in rw[:staging_catch]:                                    # every service rule is host-conditioned
            self.assertEqual(r["has"], [{"type": "host", "value": "sggs-staging.vercel.app"}])

    def test_routed_contexts_have_probes(self):
        cfg = json.loads((ROOT / "gateway/routes.json").read_text(encoding="utf-8"))
        for env in ("staging", "production"):
            for ctx in cfg[env]["services"]:
                self.assertIn(ctx, gg.PROBES)


if __name__ == "__main__":
    unittest.main()
