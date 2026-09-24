"""Every bounded context reads only the tables it declares (sggs/<context>.py: TABLES).

The platform split cuts each service's database slice from those declarations, so an
undeclared read would be a missing table — a 500 — in production. This runs every golden-
vector suite and every OpenAPI sample with each route's context enforced by an SQLite
authorizer: a read outside the context's declared tables (plus their FTS5 shadow tables)
is denied and recorded. verify.py opens its own connection, so sqlite3.connect is wrapped too.
"""
import contextlib, io, sqlite3, sys, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
REAL_DB = ROOT / "db" / "sggs.sqlite"
FTS_SHADOW = ("_config", "_content", "_data", "_docsize", "_idx")
ALWAYS = {"sqlite_master", "sqlite_schema", "pragma_table_info"}


def _is_real_sqlite(p):
    try:
        with open(p, "rb") as f:
            return f.read(16) == b"SQLite format 3\x00"
    except OSError:
        return False


@unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite (git lfs pull)")
class DeclaredTables(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(ROOT / "webapp"))
        sys.path.insert(0, str(ROOT / "tools"))
        argv, sys.argv = sys.argv, sys.argv[:1]
        import serve
        import gen_golden_vectors as g
        import gen_openapi as go
        sys.argv = argv
        cls.serve, cls.g, cls.go = serve, g, go

    def allowed(self, ctx):
        base = set(self.serve.CONTEXT_TABLES[ctx])
        return base | {t + s for t in base for s in FTS_SHADOW} | ALWAYS

    def test_declarations_name_real_tables(self):
        with contextlib.closing(sqlite3.connect(f"file:{REAL_DB}?mode=ro&immutable=1", uri=True)) as con:
            real = {n for (n,) in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        for ctx, tables in self.serve.CONTEXT_TABLES.items():
            self.assertEqual(set(tables) - real, set(), f"{ctx} declares tables that do not exist")

    def test_every_route_reads_only_declared_tables(self):
        serve, g, go = self.serve, self.g, self.go
        current, violations = [None], set()

        def auth(action, table, _col, _db, _trigger):
            if action == sqlite3.SQLITE_READ and current[0] and table not in self.allowed(current[0]):
                violations.add((current[0], table))
                return sqlite3.SQLITE_DENY
            return sqlite3.SQLITE_OK

        real_connect = sqlite3.connect

        def connect(*a, **k):
            c = real_connect(*a, **k)
            c.set_authorizer(auth)
            return c

        def scoped(fn, ctx):
            def run(*a, **k):
                prev, current[0] = current[0], ctx
                try:
                    return fn(*a, **k)
                finally:
                    current[0] = prev
            return run

        saved_routes, saved = dict(serve.ROUTES), (g.SEARCH, g.VERIFY)
        sqlite3.connect = connect
        serve.db().set_authorizer(auth)
        try:
            for key, (fn, ctx) in saved_routes.items():
                serve.ROUTES[key] = (scoped(fn, ctx), ctx)
            g.SEARCH, g.VERIFY = scoped(g.SEARCH, "search"), scoped(g.VERIFY, "verify")
            with contextlib.redirect_stdout(io.StringIO()):
                for suite in ("verify", "search", "reader", "timing", "banis", "analytics"):
                    g.SUITES[suite][1]()
            scoped(serve.hukam_package, "reader")(seed=1)
            for _route, (_tag, _summary, _params, samples, _errors) in go.ROUTES.items():
                for path, qs in samples:
                    if path != "/api/random":
                        with contextlib.suppress(Exception):
                            serve.api(path, qs)
        finally:
            sqlite3.connect = real_connect
            serve.db().set_authorizer(None)
            serve.ROUTES.clear()
            serve.ROUTES.update(saved_routes)
            g.SEARCH, g.VERIFY = saved
        self.assertEqual(sorted(violations), [], "undeclared table reads (context, table)")


if __name__ == "__main__":
    unittest.main()
