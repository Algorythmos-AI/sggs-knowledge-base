"""tools/data_canary.py — the scheduled proof that production serves the pinned scripture.

Offline: a tiny database stands in for the pin and a fake fetcher for the origins.
"""
import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("data_canary", ROOT / "tools/data_canary.py")
dc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dc)

ROWS = [  # id, ang, comp_id, gurmukhi, translit, is_header, line_no
    (1, 1, 2, "ੴ ਸਤਿ ਨਾਮੁ", "ik oankaar", 1, 1),
    (2, 1, 2, "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ", "sochai soch", 0, 2),
    (3, 712, 9, "ਟੋਡੀ ਮਹਲਾ ੫", "toddee", 1, 1),
    (4, 1430, 12, "ਰਾਗਮਾਲਾ", "raagamaalaa", 0, 1),
]


def _db(path):
    con = sqlite3.connect(path)
    con.execute("CREATE TABLE lines (id INTEGER PRIMARY KEY, ang INT, comp_id INT, gurmukhi TEXT,"
                " translit TEXT, is_header INT, line_no INT)")
    con.executemany("INSERT INTO lines VALUES (?,?,?,?,?,?,?)", ROWS)
    con.commit()
    con.close()


def _server(rows, drop=(), alter=None):
    """A fake origin serving `rows`, optionally dropping ids or altering one field."""
    served = {r[0]: dict(zip(("id", "ang", "comp_id", "gurmukhi", "translit", "is_header", "line_no"), r))
              for r in rows if r[0] not in drop}
    if alter:
        lid, field, value = alter
        served[lid][field] = value

    def fetch(url):
        if "/api/lines?ids=" in url:
            ids = [int(x) for x in url.split("ids=")[1].split(",")]
            return {"lines": [served[i] for i in sorted(ids) if i in served]}
        if "/api/ang/" in url:
            ang = int(url.rsplit("/", 1)[1])
            return {"lines": [r for r in sorted(served.values(), key=lambda r: r["id"]) if r["ang"] == ang]}
        raise AssertionError(url)
    return fetch


class DataCanary(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "pin.sqlite"
        _db(self.db)

    def tearDown(self):
        self.tmp.cleanup()

    def run_canary(self, fetch):
        return dc.run(self.db, ["https://origin.test"], sample=10, n_angs=0, seed=7, fetch=fetch)

    def test_identical_origin_passes(self):
        self.assertEqual(self.run_canary(_server(ROWS)), [])

    def test_one_changed_character_fails(self):
        problems = self.run_canary(_server(ROWS, alter=(2, "gurmukhi", "ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ")))
        self.assertTrue(any("line 2: gurmukhi differs" in p for p in problems), problems)

    def test_structure_change_fails(self):
        problems = self.run_canary(_server(ROWS, alter=(3, "comp_id", 10)))
        self.assertTrue(any("comp_id differs" in p for p in problems), problems)

    def test_missing_line_fails_in_both_routes(self):
        problems = self.run_canary(_server(ROWS, drop=(4,)))
        self.assertTrue(any("line 4: not served" in p for p in problems), problems)
        self.assertTrue(any("Ang 1430: served 0 lines, pinned 1" in p for p in problems), problems)

    def test_unreachable_origin_fails(self):
        def down(url):
            raise RuntimeError("connection refused")
        problems = self.run_canary(down)
        self.assertEqual(problems, ["https://origin.test: connection refused"])

    def test_anchor_angs_are_always_checked(self):
        seen = []

        def spy(url):
            seen.append(url)
            return _server(ROWS)(url)
        self.run_canary(spy)
        for ang in (1, 712, 1430):
            self.assertIn(f"https://origin.test/api/ang/{ang}", seen)


if __name__ == "__main__":
    unittest.main()
