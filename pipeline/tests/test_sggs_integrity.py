"""Dataset fingerprints: content (not bytes) identity for tables, FTS indexes and scripture."""
import json, os, sqlite3, sys, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import sggs_integrity as si  # noqa: E402

REAL_DB = ROOT / "db" / "sggs.sqlite"


def _is_real_sqlite(p):
    try:
        with open(p, "rb") as f:
            return f.read(16) == b"SQLite format 3\x00"
    except OSError:
        return False


def mini(path, *, text="ਸਤਿ ਨਾਮੁ", built="2026-01-01", rebuild_index=True):
    con = sqlite3.connect(path)
    con.executescript("""
        CREATE TABLE lines(id INTEGER PRIMARY KEY, ang INT, gurmukhi TEXT, text TEXT, markers TEXT);
        CREATE VIRTUAL TABLE fts USING fts5(text, content='lines', content_rowid='id');
        CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE sources(source_id TEXT PRIMARY KEY, attribution TEXT, ingest_date TEXT);
    """)
    con.executemany("INSERT INTO lines VALUES(?,?,?,?,?)",
                    [(1, 1, "ੴ ਸਤਿ ਨਾਮੁ ॥", "ੴ " + text, "[]"), (2, 1, "ਆਦਿ ਸਚੁ ॥", "ਆਦਿ ਸਚੁ", "[]")])
    con.executemany("INSERT INTO meta VALUES(?,?)", [("built", built), ("version", "1.3.6")])
    con.execute("INSERT INTO sources VALUES('ssk', 'Dr. Sant Singh Khalsa', ?)", (built,))
    if rebuild_index:
        con.execute("INSERT INTO fts(fts) VALUES('rebuild')")
    con.commit(); con.close()
    return path


class Fingerprints(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def fp(self, name, **kw):
        return si.fingerprint(mini(os.path.join(self.d, name), **kw))

    def test_same_data_same_fingerprint(self):
        self.assertEqual(si.compare(self.fp("a.db"), self.fp("b.db")), [])

    def test_build_stamps_do_not_count(self):
        self.assertEqual(si.compare(self.fp("a.db", built="2026-01-01"), self.fp("b.db", built="2026-09-24")), [])

    def test_data_change_is_detected_with_its_table(self):
        diffs = si.compare(self.fp("a.db"), self.fp("b.db", text="changed"))
        self.assertIn("tables.lines", diffs)
        self.assertIn("t0_sha256", diffs)
        self.assertIn("fts_index.fts", diffs)       # rebuilt index reflects the change

    def test_stale_index_differs_from_a_rebuilt_one(self):
        # content changed but the index was NOT rebuilt: the index fingerprint still describes
        # the old text, so it cannot match a correctly rebuilt DB of the new text
        stale = self.fp("a.db", text="changed", rebuild_index=False)
        good = self.fp("b.db", text="changed")
        diffs = si.compare(stale, good)
        self.assertIn("fts_index.fts", diffs)            # the index itself is caught
        self.assertNotIn("tables.lines", diffs)          # while the scripture content is identical
        self.assertNotIn("t0_sha256", diffs)

    def test_index_segment_shadow_tables_are_not_hashed_as_tables(self):
        fp = self.fp("a.db")
        self.assertNotIn("fts_data", fp["tables"])
        self.assertNotIn("fts_idx", fp["tables"])
        self.assertIn("fts", fp["fts_index"])

    def test_fingerprinting_writes_nothing(self):
        p = mini(os.path.join(self.d, "a.db"))
        before = si.bl.file_sha256(p)
        si.fingerprint(p)
        self.assertEqual(si.bl.file_sha256(p), before)


@unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite (git lfs pull)")
class CommittedDataset(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fp = si.fingerprint(REAL_DB)

    def test_committed_db_matches_committed_fingerprint(self):
        want = json.loads((ROOT / "audit" / "dataset-fingerprint.json").read_text(encoding="utf-8"))
        self.assertEqual(si.compare(want, self.fp), [])

    def test_scripture_hash_is_the_ios_definition(self):
        ios = json.loads((ROOT / "ios" / "Resources" / "sggs-ios.manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(self.fp["scripture_sha256"], ios["scripture_sha256"])

    def test_canonical_shape(self):
        self.assertEqual(self.fp["tables"]["lines"]["rows"], 60658)


if __name__ == "__main__":
    unittest.main()
