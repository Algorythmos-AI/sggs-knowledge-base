"""contract/openapi.json: current, complete (every dispatcher route), and structurally valid."""
import json, sys, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import gen_openapi as go  # noqa: E402

SPEC = json.loads((ROOT / "contract" / "openapi.json").read_text(encoding="utf-8"))
REAL_DB = ROOT / "db" / "sggs.sqlite"


def _is_real_sqlite(p):
    try:
        with open(p, "rb") as f:
            return f.read(16) == b"SQLite format 3\x00"
    except OSError:
        return False


def dispatcher_routes():
    """Route keys handled by webapp/serve.py:api() — its ROUTES table."""
    sys.path.insert(0, str(ROOT / "webapp"))
    import serve
    return {a if b is None else f"{a}/{b}" for a, b in serve.ROUTES}


def spec_routes():
    out = set()
    for path in SPEC["paths"]:
        segs = [s for s in path.split("/")[2:] if not s.startswith("{")]
        out.add("/".join(segs))
    return out


class OpenApi(unittest.TestCase):
    def test_every_dispatcher_route_is_documented_and_vice_versa(self):
        self.assertEqual(spec_routes(), dispatcher_routes())

    def test_structure(self):
        self.assertEqual(SPEC["openapi"], "3.1.0")
        self.assertEqual(SPEC["info"]["version"], go.API_CONTRACT_VERSION)
        for path, item in SPEC["paths"].items():
            op = item["get"]
            self.assertTrue(op.get("operationId") and op.get("summary"), path)
            self.assertTrue({"200", "400", "500"} <= set(op["responses"]), path)
            for prm in op["parameters"]:
                self.assertIn(prm["in"], ("query", "path"), path)
                if prm["in"] == "path":
                    self.assertIn("{" + prm["name"] + "}", path)

    def test_operation_ids_unique(self):
        ids = [i["get"]["operationId"] for i in SPEC["paths"].values()]
        self.assertEqual(len(ids), len(set(ids)))

    @unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite (git lfs pull)")
    def test_spec_is_current(self):
        self.assertEqual((ROOT / "contract" / "openapi.json").read_text(encoding="utf-8"), go.render(),
                         "contract/openapi.json is stale — run: python3 tools/gen_openapi.py")


if __name__ == "__main__":
    unittest.main()
