"""Tests for ios/tools/testflight_ledger.py — the TestFlight build-number gate/ledger."""
import importlib.util
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "testflight_ledger", ROOT / "ios" / "tools" / "testflight_ledger.py"
)
ledger = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ledger)


class LedgerTests(unittest.TestCase):
    def setUp(self):
        self._tmp = TemporaryDirectory()
        self.path = Path(self._tmp.name) / "testflight-builds.json"
        self.path.write_text(json.dumps({
            "schema": 1,
            "builds": [
                {"version": "1.1.3", "build": 1, "profile": "public"},
                {"version": "1.1.3", "build": 2, "profile": "public"},
            ],
        }), encoding="utf-8")
        self._orig = ledger.LEDGER
        ledger.LEDGER = self.path

    def tearDown(self):
        ledger.LEDGER = self._orig
        self._tmp.cleanup()

    def run_cli(self, *argv):
        return ledger.main(list(argv))

    # check --strict
    def test_reused_build_fails_strict(self):
        self.assertEqual(self.run_cli("check", "1.1.3", "2", "--strict"), 1)

    def test_lower_build_fails_strict(self):
        self.assertEqual(self.run_cli("check", "1.1.3", "1", "--strict"), 1)

    def test_next_build_passes_strict(self):
        self.assertEqual(self.run_cli("check", "1.1.3", "3", "--strict"), 0)

    def test_new_version_build_one_passes(self):
        self.assertEqual(self.run_cli("check", "1.1.4", "1", "--strict"), 0)

    def test_new_version_any_build_passes(self):
        self.assertEqual(self.run_cli("check", "2.0.0", "9", "--strict"), 0)

    def test_version_downgrade_fails_strict(self):
        self.assertEqual(self.run_cli("check", "1.1.2", "5", "--strict"), 1)

    # non-strict never blocks
    def test_reused_build_warns_non_strict(self):
        self.assertEqual(self.run_cli("check", "1.1.3", "2"), 0)

    def test_downgrade_warns_non_strict(self):
        self.assertEqual(self.run_cli("check", "1.1.2", "5"), 0)

    # next
    def test_next_existing_version(self):
        self.assertEqual(ledger.max_build_for(ledger.builds(ledger.load()), "1.1.3") + 1, 3)

    def test_next_new_version(self):
        self.assertEqual(ledger.max_build_for(ledger.builds(ledger.load()), "9.9.9") + 1, 1)

    # record
    def _candidate(self, **over):
        cand = {"version": "1.1.3", "build": 3, "profile": "public",
                "db_sha256": "abc", "source_commit": "deadbeef", "uploaded": True}
        cand.update(over)
        p = Path(self._tmp.name) / "candidate.json"
        p.write_text(json.dumps(cand), encoding="utf-8")
        return str(p)

    def test_record_appends(self):
        self.assertEqual(self.run_cli("record", self._candidate()), 0)
        rows = ledger.builds(ledger.load())
        self.assertTrue(any(r["version"] == "1.1.3" and r["build"] == 3 for r in rows))
        row = [r for r in rows if r["build"] == 3][0]
        self.assertEqual(row["source_commit"], "deadbeef")
        self.assertTrue(row["uploaded_at"].endswith("Z"))

    def test_record_duplicate_refused(self):
        self.assertEqual(self.run_cli("record", self._candidate(build=2)), 1)

    def test_record_not_uploaded_refused_without_force(self):
        self.assertEqual(self.run_cli("record", self._candidate(uploaded=False)), 1)

    def test_record_not_uploaded_allowed_with_force(self):
        self.assertEqual(self.run_cli("record", self._candidate(uploaded=False), "--force"), 0)


if __name__ == "__main__":
    unittest.main()
