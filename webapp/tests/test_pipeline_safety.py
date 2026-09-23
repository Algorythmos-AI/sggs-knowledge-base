"""Unit tests for the rebuild's install safety: atomic_install + db_integrity_gate."""
import os, sqlite3, stat, sys, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import atomic_install as ai  # noqa: E402
import db_integrity_gate as gate  # noqa: E402

REAL_DB = ROOT / "db" / "sggs.sqlite"


def _is_real_sqlite(p):
    try:
        with open(p, "rb") as f:
            return f.read(16) == b"SQLite format 3\x00"
    except OSError:
        return False


class AtomicInstall(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.src = os.path.join(self.d, "new.bin")
        self.dest = os.path.join(self.d, "live.bin")
        Path(self.src).write_bytes(b"new-content" * 1000)
        Path(self.dest).write_bytes(b"old-content")
        os.chmod(self.dest, 0o444)

    def test_replaces_and_returns_sha(self):
        sha = ai.install(self.src, self.dest)
        self.assertEqual(Path(self.dest).read_bytes(), Path(self.src).read_bytes())
        self.assertEqual(sha, ai.sha256_file(self.src))

    def test_preserves_destination_mode(self):
        ai.install(self.src, self.dest)
        self.assertEqual(stat.S_IMODE(os.stat(self.dest).st_mode), 0o444)

    def test_wrong_expected_sha_leaves_destination_untouched(self):
        with self.assertRaises(ValueError):
            ai.install(self.src, self.dest, expect_sha256="0" * 64)
        self.assertEqual(Path(self.dest).read_bytes(), b"old-content")

    def test_no_temp_files_left_behind(self):
        ai.install(self.src, self.dest)
        self.assertEqual(sorted(os.listdir(self.d)), ["live.bin", "new.bin"])


def _mini_db(path, *, lines=gate.LINES, angs=gate.ANGS):
    con = sqlite3.connect(path)
    con.executescript("""
        CREATE TABLE lines(id INTEGER PRIMARY KEY, ang INT, text TEXT);
        CREATE VIRTUAL TABLE fts USING fts5(text, content='lines', content_rowid='id');
    """)
    con.executemany("INSERT INTO lines VALUES(?,?,?)",
                    [(i + 1, (i % angs) + 1, f"w{i % 97}") for i in range(lines)])
    con.execute("INSERT INTO fts(fts) VALUES('rebuild')")
    con.commit()
    con.close()


class IntegrityGate(unittest.TestCase):
    def setUp(self):
        self.db = os.path.join(tempfile.mkdtemp(), "t.db")

    def test_sound_db_passes(self):
        _mini_db(self.db)
        self.assertEqual(gate.check(self.db, required=("lines", "fts")), [])

    def test_missing_required_table_fails(self):
        _mini_db(self.db)
        fails = gate.check(self.db, required=("lines", "fts", "translations"))
        self.assertIn("missing table: translations", fails)

    def test_wrong_line_count_fails(self):
        _mini_db(self.db, lines=gate.LINES - 1)
        self.assertTrue(any(f.startswith("lines:") for f in gate.check(self.db, required=())))

    def test_stale_external_content_index_fails(self):
        _mini_db(self.db)
        con = sqlite3.connect(self.db)   # change content WITHOUT rebuilding the index
        con.execute("UPDATE lines SET text='changed' WHERE id=1")
        con.commit(); con.close()
        self.assertTrue(any("fts5 integrity-check fts" in f for f in gate.check(self.db, required=())))

    def test_gate_leaves_db_bytes_unchanged(self):
        _mini_db(self.db)
        before = ai.sha256_file(self.db)
        gate.check(self.db, required=("lines", "fts"))
        self.assertEqual(ai.sha256_file(self.db), before)

    @unittest.skipUnless(_is_real_sqlite(REAL_DB), "needs the real db/sggs.sqlite (git lfs pull)")
    def test_committed_db_passes_on_a_copy(self):
        tmp = os.path.join(tempfile.mkdtemp(), "copy.db")
        ai.install(str(REAL_DB), tmp)
        self.assertEqual(gate.check(tmp), [])


if __name__ == "__main__":
    unittest.main()
