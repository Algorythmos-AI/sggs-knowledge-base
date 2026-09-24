"""SGGS_MODULES: one image serves any subset of the bounded contexts (the platform's services)."""
import json, os, socket, sqlite3, subprocess, sys, tempfile, time, unittest, urllib.error, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WEBAPP = ROOT / "webapp"
REAL_DB = ROOT / "db" / "sggs.sqlite"
sys.path.insert(0, str(WEBAPP))
import serve  # noqa: E402


def _is_real_sqlite(p):
    try:
        with open(p, "rb") as f:
            return f.read(16) == b"SQLite format 3\x00"
    except OSError:
        return False


def _free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _tiny_db(tables):
    path = os.path.join(tempfile.mkdtemp(), "slice.sqlite")
    con = sqlite3.connect(path)
    for t in tables:
        con.execute(f'CREATE TABLE "{t}" (x)')
    con.commit(); con.close()
    return path


class ParseModules(unittest.TestCase):
    def test_default_and_all_are_the_monolith(self):
        full = frozenset(serve.CONTEXT_TABLES)
        for raw in (None, "", "all", " ALL "):
            self.assertEqual(serve.parse_modules(raw), full)

    def test_subsets(self):
        self.assertEqual(serve.parse_modules("search"), {"search"})
        self.assertEqual(serve.parse_modules(" Insights , knowledge "), {"insights", "knowledge"})

    def test_unknown_or_empty_is_an_error(self):
        for raw in ("bogus", "search,bogus", ",", " , "):
            with self.assertRaises(ValueError):
                serve.parse_modules(raw)

    def test_default_process_serves_everything(self):
        self.assertFalse(serve.split_mode())


class Routing(unittest.TestCase):
    def setUp(self):
        self.saved = serve.ENABLED

    def tearDown(self):
        serve.ENABLED = self.saved

    def test_route_of_a_disabled_context_is_404(self):
        serve.ENABLED = frozenset({"knowledge"})
        with self.assertRaises(serve.ApiError) as cm:
            serve.api("/api/ang/1", {})
        self.assertEqual(cm.exception.status, 404)

    def test_unknown_endpoint_is_still_400_semantics(self):
        serve.ENABLED = frozenset({"knowledge"})
        with self.assertRaises(ValueError):
            serve.api("/api/no_such_route", {})


class Readiness(unittest.TestCase):
    def setUp(self):
        self.saved = serve.ENABLED

    def tearDown(self):
        serve.ENABLED = self.saved

    def test_incomplete_slice_is_not_ready_and_names_the_gap(self):
        serve.ENABLED = frozenset({"knowledge"})
        tables = sorted(serve.CONTEXT_TABLES["knowledge"])
        r = serve.readiness(_tiny_db(tables[1:]))
        self.assertFalse(r["ready"])
        self.assertEqual(r["missing_tables"], [tables[0]])

    def test_complete_slice_is_ready(self):
        serve.ENABLED = frozenset({"knowledge"})
        self.assertTrue(serve.readiness(_tiny_db(serve.CONTEXT_TABLES["knowledge"]))["ready"])

    @unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite")
    def test_full_database_is_ready_for_every_context(self):
        r = serve.readiness(str(REAL_DB))
        self.assertTrue(r["ready"], r)
        self.assertEqual(r["contexts"], sorted(serve.CONTEXT_TABLES))


class Process(unittest.TestCase):
    def run_serve(self, env, timeout=20):
        e = dict(os.environ, SGGS_ACCESS_LOG="0", SGGS_OPEN_BROWSER="0", **env)
        return subprocess.run([sys.executable, "serve.py"], cwd=WEBAPP, env=e, capture_output=True, text=True, timeout=timeout)

    def test_unknown_module_refuses_to_start(self):
        r = self.run_serve({"SGGS_MODULES": "bogus", "SGGS_PORT": str(_free_port())})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("SGGS_MODULES", r.stderr)

    def test_split_mode_refuses_an_incomplete_database(self):
        tables = sorted(serve.CONTEXT_TABLES["knowledge"])
        r = self.run_serve({"SGGS_MODULES": "knowledge", "SGGS_DB": _tiny_db(tables[1:]), "SGGS_PORT": str(_free_port())})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("refusing to start", r.stderr)
        self.assertIn(tables[0], r.stderr)

    @unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite")
    def test_split_service_over_http(self):
        port = _free_port()
        env = dict(os.environ, SGGS_ACCESS_LOG="0", SGGS_OPEN_BROWSER="0", SGGS_MODULES="search", SGGS_PORT=str(port))
        proc = subprocess.Popen([sys.executable, "serve.py"], cwd=WEBAPP, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        base = f"http://127.0.0.1:{port}"

        def get(path):
            try:
                with urllib.request.urlopen(base + path, timeout=10) as r:
                    return r.status, json.loads(r.read())
            except urllib.error.HTTPError as e:
                with e:
                    return e.code, json.loads(e.read() or b"{}")
        try:
            for _ in range(60):
                try:
                    if get("/healthz")[0] == 200:
                        break
                except OSError:
                    time.sleep(0.25)
            st, body = get("/readyz")
            self.assertEqual((st, body["ready"], body["contexts"]), (200, True, ["search"]))
            self.assertEqual(get("/api/search?q=naam")[0], 200)
            self.assertEqual(get("/api/ang/1")[0], 404)          # reader route: another service
            self.assertEqual(get("/api/timing/clock")[0], 404)   # knowledge route: another service
        finally:
            proc.terminate(); proc.wait(timeout=10)


if __name__ == "__main__":
    unittest.main()
