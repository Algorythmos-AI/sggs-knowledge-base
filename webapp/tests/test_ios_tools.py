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


SPEC2 = importlib.util.spec_from_file_location("appstore_preflight", ROOT / "ios" / "tools" / "appstore_preflight.py")
preflight = importlib.util.module_from_spec(SPEC2)
SPEC2.loader.exec_module(preflight)

SIGNED, UNSIGNED = "notes\nREVIEWED: true\n", "notes\nREVIEWED: false\n"
LABEL_OFF = "enum NitnemReview {\n    static let extraTextReviewed = true\n}\n"
LABEL_ON = "enum NitnemReview {\n    static let extraTextReviewed = false\n}\n"


class AppStorePreflight(unittest.TestCase):
    def rows(self, **newest):
        return [{"version": "1.3.1", "build": 1, "channel": "appstore", "sdk": "iphoneos26.5"},
                dict({"version": "1.3.1", "build": 2, "channel": "appstore", "sdk": "iphoneos26.5"}, **newest)]

    def test_ready(self):
        build, problems = preflight.evaluate("1.3.1", self.rows(), SIGNED, LABEL_OFF)
        self.assertEqual((build["build"], problems), (2, []))

    def test_only_the_newest_build_counts(self):
        _, problems = preflight.evaluate("1.3.1", self.rows(channel="testflight"), SIGNED, LABEL_OFF)
        self.assertEqual(len(problems), 1)
        self.assertIn("channel='testflight'", problems[0])

    def test_rows_without_a_channel_are_testflight_builds(self):
        _, problems = preflight.evaluate("1.3.0", [{"version": "1.3.0", "build": 7, "profile": "public"}], SIGNED, LABEL_OFF)
        self.assertTrue(any("channel='testflight'" in p for p in problems))
        self.assertTrue(any("sdk=unknown" in p for p in problems))

    def test_old_sdk_is_refused(self):
        _, problems = preflight.evaluate("1.3.1", self.rows(sdk="iphoneos18.5"), SIGNED, LABEL_OFF)
        self.assertTrue(any("iOS 26 SDK" in p for p in problems))

    def test_unsigned_review_and_visible_label_are_each_reported(self):
        _, problems = preflight.evaluate("1.3.1", self.rows(), UNSIGNED, LABEL_ON)
        self.assertEqual(len(problems), 2)

    def test_no_build_for_the_version(self):
        build, problems = preflight.evaluate("9.9.9", self.rows(), SIGNED, LABEL_OFF)
        self.assertIsNone(build)
        self.assertEqual(len(problems), 1)


class LedgerRecordsTheChannel(LedgerTests):
    def test_channel_and_toolchain_are_recorded(self):
        cand = Path(self._tmp.name) / "cand.json"
        cand.write_text(json.dumps({"version": "1.1.3", "build": 3, "uploaded": True, "profile": "public",
                                    "channel": "appstore", "xcode": "26.5", "sdk": "iphoneos26.5"}))
        self.assertEqual(self.run_cli("record", str(cand)), 0)
        row = json.loads(self.path.read_text())["builds"][-1]
        self.assertEqual((row["channel"], row["xcode"], row["sdk"]), ("appstore", "26.5", "iphoneos26.5"))

    def test_channel_defaults_to_testflight(self):
        cand = Path(self._tmp.name) / "cand.json"
        cand.write_text(json.dumps({"version": "1.1.3", "build": 3, "uploaded": True}))
        self.assertEqual(self.run_cli("record", str(cand)), 0)
        self.assertEqual(json.loads(self.path.read_text())["builds"][-1]["channel"], "testflight")


if __name__ == "__main__":
    unittest.main()
