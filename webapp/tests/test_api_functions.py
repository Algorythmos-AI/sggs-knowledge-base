"""tools/build_api_functions.py — the API's Vercel functions are generated correctly, serve exactly
their context, and a build that would bundle anything else (or publish a database) is refused."""
import importlib.util
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REAL_DB = ROOT / "db" / "sggs.sqlite"
sys.path.insert(0, str(ROOT / "tools"))
spec = importlib.util.spec_from_file_location("build_api_functions", ROOT / "tools/build_api_functions.py")
baf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baf)
import gen_gateway as gg  # noqa: E402
sys.path.insert(0, str(ROOT / "scripts" / "ci"))
import verify_functions as vf  # noqa: E402

SHA = "0123456789abcdef0123456789abcdef01234567"


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


class Entries(unittest.TestCase):
    def test_every_context_and_all_get_a_function(self):
        self.assertEqual(gg.function_names(), ["insights", "knowledge", "reader", "search", "verify", "all"])

    def test_entry_fixes_its_context_database_and_commit(self):
        src = baf.entry("search", SHA)
        compile(src, "search.py", "exec")
        self.assertIn('os.environ["SGGS_MODULES"] = "search"', src)
        self.assertIn('"_sggs", "db", "search.sqlite"', src)
        self.assertIn(f'os.environ["SGGS_COMMIT"] = "{SHA}"', src)
        self.assertIn("\nclass handler(serve.H):", src)      # Vercel detects a function by this definition
        self.assertIn("serve.readiness()", src)               # fail closed on an incomplete slice

    def test_all_serves_every_context(self):
        src = baf.entry("all", SHA)
        self.assertIn('os.environ.pop("SGGS_MODULES", None)', src)
        self.assertIn('"all.sqlite"', src)

    def test_commit_must_be_a_full_sha(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaises(SystemExit):
                baf.generate("abc123", Path(t), REAL_DB)


def _vercelignored(path, pattern):
    """Does a .vercelignore (gitignore-syntax) pattern exclude `path` (relative to the repo root)?
    Covers the forms that file uses: anchored or not, directory or file, shell globs."""
    import fnmatch
    is_dir = pattern.endswith("/")
    pat = pattern.rstrip("/")
    anchored = pat.startswith("/") or "/" in pat
    pat = pat.lstrip("/")
    parts = path.split("/")
    if anchored:
        n = len(pat.split("/"))
        return fnmatch.fnmatchcase("/".join(parts[:n]), pat) and (not is_dir or n < len(parts))
    last = len(parts) - 1
    return any(fnmatch.fnmatchcase(c, pat) and (not is_dir or i < last) for i, c in enumerate(parts))


class UploadIgnore(unittest.TestCase):
    """The deploy uploads what `vercel build` bundled, minus .vercelignore. A pattern that matches
    the generated API files drops them from the upload (the build then fails on Vercel, or worse)."""
    GENERATED = ("frontend/_sggs/db/all.sqlite", "frontend/_sggs/db/search.sqlite",
                 "frontend/_sggs/webapp/serve.py", "frontend/_sggs/webapp/sggs/core.py",
                 "frontend/api/svc/all.py", "frontend/pyproject.toml", "frontend/.python-version")

    def patterns(self):
        lines = (ROOT / ".vercelignore").read_text(encoding="utf-8").splitlines()
        return [l.strip() for l in lines if l.strip() and not l.lstrip().startswith("#")]

    def test_the_matcher_catches_an_unanchored_directory_rule(self):
        self.assertTrue(_vercelignored("frontend/_sggs/db/all.sqlite", "db/"))
        self.assertFalse(_vercelignored("frontend/_sggs/db/all.sqlite", "/db/"))
        self.assertTrue(_vercelignored("db/sggs.sqlite", "/db/"))

    def test_no_pattern_drops_the_generated_api_files(self):
        for path in self.GENERATED:
            for pat in self.patterns():
                self.assertFalse(_vercelignored(path, pat), f".vercelignore `{pat}` excludes {path}")

    def test_the_repositorys_own_backend_and_database_stay_out_of_uploads(self):
        for path in ("db/sggs.sqlite", "webapp/serve.py", "contract/golden_search.ndjson"):
            self.assertTrue(any(_vercelignored(path, pat) for pat in self.patterns()), path)


class OutputGuard(unittest.TestCase):
    """--verify-output reads what `vercel build` actually bundled."""

    def _output(self, root, extra=None, drop=None, static=()):
        for name in gg.function_names():
            files = {".python-version": "", "pyproject.toml": "", "uv.lock": "", "_vendor/pip/__init__.py": "",
                     f"api/svc/{name}.py": "", "_sggs/webapp/serve.py": "", f"_sggs/db/{name}.sqlite": ""}
            files.update((extra or {}).get(name, {}))
            for f in (drop or {}).get(name, ()):
                files.pop(f)
            d = root / "functions" / "api" / "svc" / f"{name}.func"
            d.mkdir(parents=True)
            (d / ".vc-config.json").write_text(json.dumps({"filePathMap": files}))
        for rel in static:
            p = root / "static" / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("x")
        return root

    def test_a_clean_build_passes(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(baf.verify_output(self._output(Path(t), static=["index.html", "_astro/a.js"])), [])

    def test_a_stray_web_file_or_another_database_fails(self):
        with tempfile.TemporaryDirectory() as t:
            out = self._output(Path(t), extra={"reader": {"src/pages/index.astro": "", "_sggs/db/all.sqlite": ""}})
            problems = baf.verify_output(out)
            self.assertTrue(any("src/pages/index.astro" in p for p in problems))
            self.assertTrue(any("_sggs/db/all.sqlite" in p for p in problems))

    def test_a_function_without_its_database_fails(self):
        with tempfile.TemporaryDirectory() as t:
            out = self._output(Path(t), drop={"knowledge": ["_sggs/db/knowledge.sqlite"]})
            self.assertTrue(any("knowledge: its database" in p for p in baf.verify_output(out)))

    def test_a_published_database_or_api_source_fails(self):
        with tempfile.TemporaryDirectory() as t:
            out = self._output(Path(t), static=["_sggs/db/all.sqlite", "api/svc/all.py", "x.sqlite"])
            self.assertEqual(len(baf.verify_output(out)), 3)

    def test_a_missing_function_fails(self):
        with tempfile.TemporaryDirectory() as t:
            out = self._output(Path(t))
            (out / "functions" / "api" / "svc" / "verify.func" / ".vc-config.json").unlink()
            self.assertTrue(any(p.startswith("verify: no function") for p in baf.verify_output(out)))


@unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite")
class GeneratedFunctionsServe(unittest.TestCase):
    """Each generated function, loaded the way Vercel loads it, answers only its own context."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.web = Path(cls.tmp.name)
        baf.generate(SHA, cls.web, REAL_DB)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _serve(self, name):
        port = _free_port()
        code = ("import runpy, sys; from http.server import ThreadingHTTPServer; "
                f"m = runpy.run_path({str(self.web / 'api' / 'svc' / (name + '.py'))!r}); "
                f"ThreadingHTTPServer(('127.0.0.1', {port}), m['handler']).serve_forever()")
        env = {k: v for k, v in os.environ.items() if not k.startswith("SGGS_")}
        proc = subprocess.Popen([sys.executable, "-c", code], env=env, cwd=self.tmp.name,
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        self.addCleanup(proc.stderr.close)       # cleanups run last-in first-out: stop, reap, close
        self.addCleanup(proc.wait, 10)
        self.addCleanup(proc.terminate)
        for _ in range(80):
            try:
                socket.create_connection(("127.0.0.1", port), 0.2).close()
                return f"http://127.0.0.1:{port}"
            except OSError:
                if proc.poll() is not None:
                    self.fail(f"{name} did not start: {proc.stderr.read()}")
                time.sleep(0.1)
        self.fail(f"{name} did not start")

    def _get(self, url):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return r.status, r.headers.get("X-Service"), json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, e.headers.get("X-Service"), json.loads(e.read())

    def test_each_context_function_serves_its_routes_and_only_them(self):
        other = {"reader": "/api/timing/clock", "search": "/api/ang/1", "verify": "/api/ang/1",
                 "insights": "/api/ang/1", "knowledge": "/api/ang/1"}
        for ctx, probe in gg.PROBES.items():
            with self.subTest(ctx):
                base = self._serve(ctx)
                status, svc, body = self._get(base + "/readyz")
                self.assertEqual((status, svc), (200, ctx))
                self.assertEqual((body["ready"], body["contexts"], body["commit"]), (True, [ctx], SHA))
                status, svc, _ = self._get(base + probe)
                self.assertEqual((status, svc), (200, ctx))
                status, _, _ = self._get(base + other[ctx])
                self.assertEqual(status, 404)                  # another context's route is not served here

    def test_the_build_config_names_exactly_the_generated_functions(self):
        doc = json.loads((self.web / "vercel.json").read_text(encoding="utf-8"))
        self.assertEqual(doc["regions"], [gg.REGION])
        self.assertEqual(doc["functions"], gg.functions())
        for f in doc["functions"]:
            self.assertTrue((self.web / f).is_file(), f)

    def test_all_serves_every_context_with_a_healthy_database(self):
        base = self._serve("all")
        status, svc, body = self._get(base + "/api/health")
        self.assertEqual((status, svc, body["commit"]), (200, "all", SHA))
        self.assertTrue(body["ok"] and all(body["checks"].values()), body["checks"])
        for probe in gg.PROBES.values():
            self.assertEqual(self._get(base + probe)[:2], (200, "all"))

    def test_the_deploy_check_accepts_a_right_function_and_names_a_wrong_one(self):
        base = self._serve("knowledge")
        self.assertIsNone(vf.check_ready(base, "knowledge", ["knowledge"], SHA))
        self.assertIn("commit", vf.check_ready(base, "knowledge", ["knowledge"], "f" * 40))
        self.assertIn("contexts", vf.check_ready(base, "knowledge", ["reader"], SHA))

    def test_a_slice_missing_a_declared_table_refuses_to_load(self):
        import shutil
        import sqlite3
        with tempfile.TemporaryDirectory() as t:     # a copy of the knowledge function with a broken slice
            web = Path(t)
            shutil.copytree(self.web / "_sggs" / "webapp", web / "_sggs" / "webapp")
            (web / "_sggs" / "db").mkdir()
            (web / "api" / "svc").mkdir(parents=True)
            shutil.copy(self.web / "api" / "svc" / "knowledge.py", web / "api" / "svc" / "knowledge.py")
            broken = web / "_sggs" / "db" / "knowledge.sqlite"
            shutil.copyfile(self.web / "_sggs" / "db" / "knowledge.sqlite", broken)
            con = sqlite3.connect(broken)
            con.execute("DROP TABLE raag_timing_claims")
            con.commit()
            con.close()
            r = subprocess.run([sys.executable, "-c", f"import runpy; runpy.run_path({str(web / 'api/svc/knowledge.py')!r})"],
                               capture_output=True, text=True,
                               env={k: v for k, v in os.environ.items() if not k.startswith("SGGS_")})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("lacks declared tables", r.stderr)

if __name__ == "__main__":
    unittest.main()
