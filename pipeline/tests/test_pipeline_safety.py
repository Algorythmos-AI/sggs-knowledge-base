"""Unit tests for the rebuild's install safety: atomic_install + db_integrity_gate."""
import os, sqlite3, stat, sys, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import atomic_install as ai  # noqa: E402
import build_clock  # noqa: E402
import db_integrity_gate as gate  # noqa: E402
sys.path.insert(0, str(ROOT / "scripts" / "data"))
import compare_builds  # noqa: E402

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


class BuildClock(unittest.TestCase):
    def test_source_date_epoch_pins_every_stamp_in_utc(self):
        old = os.environ.get("SOURCE_DATE_EPOCH")
        os.environ["SOURCE_DATE_EPOCH"] = "1790167539"   # 2026-09-23T12:45:39Z
        try:
            self.assertEqual(build_clock.stamp("%Y-%m-%d %H:%M"), "2026-09-23 12:45")
            self.assertEqual(build_clock.stamp("%Y-%m-%dT%H:%M:%S%z")[:19], "2026-09-23T12:45:39")
        finally:
            if old is None:
                os.environ.pop("SOURCE_DATE_EPOCH", None)
            else:
                os.environ["SOURCE_DATE_EPOCH"] = old


class CompareBuilds(unittest.TestCase):
    def _db(self, rows):
        p = os.path.join(tempfile.mkdtemp(), "b.db")
        con = sqlite3.connect(p)
        con.execute("CREATE TABLE canon_tokens(token TEXT PRIMARY KEY)")
        con.executemany("INSERT INTO canon_tokens VALUES(?)", [(t,) for t in rows])
        con.commit(); con.close()
        return p

    def test_identical_builds(self):
        self.assertEqual(compare_builds.compare(self._db("abc"), self._db("abc"))[0], [])

    def test_same_set_different_insertion_order_is_a_difference(self):
        diffs, _ = compare_builds.compare(self._db("abc"), self._db("cba"))
        self.assertEqual([d[0] for d in diffs], ["canon_tokens"])


class RebuildWritesOnlyDataPaths(unittest.TestCase):
    """The rebuild runs in this repository alone: every path it writes must be one this
    repository owns (a path under another repository's tree fails the fail-hard build)."""

    OWNED = ("corpus/", "db/", "validation/", "audit/", "pipeline/", "MANIFEST.json", "$", "/tmp")
    FOREIGN = ("docs/nitnem", "ios/", "frontend/", "webapp/", "contract/")

    def test_report_and_output_paths_are_data_owned(self):
        import re
        script = (ROOT / "pipeline" / "rebuild_all.sh").read_text(encoding="utf-8")
        targets = re.findall(r"--(?:report|out|output)[ =](\S+)", script)
        self.assertTrue(targets, "expected at least one explicit output flag in rebuild_all.sh")
        for t in targets:
            with self.subTest(target=t):
                self.assertTrue(t.strip("\"'").startswith(self.OWNED), f"rebuild writes outside the data repo: {t}")

    def test_rebuild_never_touches_another_repositorys_tree(self):
        script = (ROOT / "pipeline" / "rebuild_all.sh").read_text(encoding="utf-8")
        for foreign in self.FOREIGN:
            with self.subTest(path=foreign):
                self.assertNotIn(foreign, script)

    def test_banis_report_parent_is_created(self):
        src = (ROOT / "pipeline" / "banis" / "build_banis.py").read_text(encoding="utf-8")
        self.assertIn("Path(args.report).parent.mkdir(parents=True, exist_ok=True)", src)


if __name__ == "__main__":
    unittest.main()
