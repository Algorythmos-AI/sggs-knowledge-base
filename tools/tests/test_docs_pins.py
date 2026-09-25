"""tools/docs_pins.py — a pin moves only when a file the wiki publishes changed (no network)."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import docs_pins  # noqa: E402
import fetch_sibling_docs as fsd  # noqa: E402

LOCK = {"sources": {
    "a": {"repository": "o/a", "ref": "main", "commit": "1" * 40, "alias": "data", "include": ["docs/**"],
          "files": {"docs/x.md": {"blob": "b1", "sha256": "s1"}, "docs/y.md": {"blob": "b2", "sha256": "s2"}}},
    "b": {"repository": "o/b", "ref": "main", "commit": "3" * 40, "alias": "ios", "include": ["docs/**"],
          "files": {"docs/z.md": {"blob": "b3", "sha256": "s3"}}},
}}


class DocsPins(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.lock_path = Path(self.tmp.name) / "sources.lock.json"
        self.lock_path.write_text(json.dumps(LOCK), encoding="utf-8")
        self.patches = [mock.patch.object(fsd, "LOCK", self.lock_path),
                        mock.patch.object(fsd, "load_lock", lambda: json.loads(self.lock_path.read_text()))]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.tmp.cleanup()

    def fake_update(self, new_files: dict):
        """An update that moves every pin to a new commit, with the files given per source."""
        def update(lock, name):
            lock["sources"][name]["commit"] = "9" * 40
            lock["sources"][name]["files"] = new_files.get(name, lock["sources"][name]["files"])
            self.lock_path.write_text(json.dumps(lock), encoding="utf-8")
        return update

    def test_a_commit_that_touched_nothing_published_keeps_the_pin(self):
        changed, results = docs_pins.run(update=self.fake_update({}))
        self.assertFalse(changed)
        self.assertEqual(json.loads(self.lock_path.read_text()), LOCK)

    def test_a_changed_page_moves_only_that_pin(self):
        new_a = {"docs/x.md": {"blob": "b1", "sha256": "s1"}, "docs/y.md": {"blob": "b9", "sha256": "s9"},
                 "docs/new.md": {"blob": "b8", "sha256": "s8"}}
        changed, results = docs_pins.run(update=self.fake_update({"a": new_a}))
        self.assertTrue(changed)
        lock = json.loads(self.lock_path.read_text())
        self.assertEqual(lock["sources"]["a"]["commit"], "9" * 40)
        self.assertEqual(lock["sources"]["b"]["commit"], "3" * 40)       # b's commit moved, nothing published changed
        self.assertEqual(results["a"][2], {"added": ["docs/new.md"], "removed": [], "changed": ["docs/y.md"]})
        body = docs_pins.summary(results)
        self.assertIn("`1111111` → `9999999`", body)
        self.assertIn("- changed: `docs/y.md`", body)
        self.assertIn("- added: `docs/new.md`", body)

    def test_diff_files(self):
        d = docs_pins.diff_files({"p": {"sha256": "1"}, "q": {"sha256": "2"}}, {"p": {"sha256": "1"}, "r": {"sha256": "3"}})
        self.assertEqual(d, {"added": ["r"], "removed": ["q"], "changed": []})


if __name__ == "__main__":
    unittest.main()
