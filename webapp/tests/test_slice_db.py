"""tools/slice_db.py — a service's slice holds its declared tables and their closure, proven equal."""
import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("slice_db", ROOT / "tools/slice_db.py")
sd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sd)


def _full(path):
    con = sqlite3.connect(path)
    con.executescript("""
        CREATE TABLE raags (id INTEGER PRIMARY KEY, name TEXT);
        CREATE TABLE lines (id INTEGER PRIMARY KEY, ang INT, gurmukhi TEXT, raag_id INT REFERENCES raags(id));
        CREATE VIRTUAL TABLE fts USING fts5(gurmukhi, content='lines', content_rowid='id');
        CREATE TABLE timing (id INTEGER PRIMARY KEY, note TEXT);
        CREATE VIRTUAL TABLE fts_other USING fts5(note);
        INSERT INTO raags VALUES (1, 'ਸਿਰੀਰਾਗੁ');
        INSERT INTO lines VALUES (1, 1, 'ੴ ਸਤਿ ਨਾਮੁ', 1), (2, 1, 'ਸੋਚੈ ਸੋਚਿ', 1);
        INSERT INTO fts(fts) VALUES ('rebuild');
        INSERT INTO timing VALUES (1, 'x');
        INSERT INTO fts_other VALUES ('y');
    """)
    con.commit()
    con.close()


class Closure(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.full = Path(self.tmp.name) / "full.sqlite"
        _full(self.full)

    def tearDown(self):
        self.tmp.cleanup()

    def test_fts_pulls_its_shadows_and_content_table_and_fk_targets(self):
        con = sqlite3.connect(self.full)
        keep = sd.closure(con, {"fts"})
        self.assertTrue({"fts", "fts_data", "fts_idx", "fts_docsize", "fts_config", "lines", "raags"} <= keep)
        self.assertFalse({"timing", "fts_other"} & keep)

    def test_slice_contains_only_the_closure_and_passes_integrity(self):
        import serve
        saved = dict(serve.CONTEXT_TABLES)
        serve.CONTEXT_TABLES.clear()
        serve.CONTEXT_TABLES.update({"verify": frozenset({"fts", "lines"})})
        try:
            out = Path(self.tmp.name) / "verify.sqlite"
            r = sd.slice_db(self.full, {"verify"}, out)
        finally:
            serve.CONTEXT_TABLES.clear()
            serve.CONTEXT_TABLES.update(saved)
        con = sqlite3.connect(out)
        names = {n for (n,) in con.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
        self.assertIn("raags", names)                        # FK target of lines
        self.assertNotIn("timing", names)
        self.assertNotIn("fts_other", names)
        self.assertEqual(con.execute("SELECT gurmukhi FROM lines ORDER BY id").fetchall(),
                         [("ੴ ਸਤਿ ਨਾਮੁ",), ("ਸੋਚੈ ਸੋਚਿ",)])
        self.assertEqual(con.execute("SELECT rowid FROM fts WHERE fts MATCH 'ਸੋਚੈ'").fetchall(), [(2,)])
        self.assertEqual(r["bytes"], out.stat().st_size)
        self.assertEqual([p.name for p in out.parent.glob("*.part")], [])


if __name__ == "__main__":
    unittest.main()
