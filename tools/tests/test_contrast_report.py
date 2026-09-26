import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "brand" / "contrast_report.py"
_spec = importlib.util.spec_from_file_location("contrast_report", SCRIPT)
contrast_report = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(contrast_report)


class ContrastReport(unittest.TestCase):
    def test_page_is_current_and_keeps_its_frontmatter(self):
        text, failed = contrast_report.build()
        self.assertTrue(text.startswith("\n".join(contrast_report.FRONTMATTER) + "\n# Contrast report\n"))
        self.assertEqual(failed, 0)
        self.assertEqual(contrast_report.OUT.read_text(encoding="utf-8"), text, "run: python3 scripts/brand/contrast_report.py")

    def test_check_mode_exits_zero_when_current(self):
        r = subprocess.run([sys.executable, str(SCRIPT), "--check"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_check_mode_fails_on_a_stale_page_and_writes_nothing(self):
        text, _ = contrast_report.build()
        stale = text.split("---\n", 2)[2]          # the page as it was regenerated before: no frontmatter
        real = contrast_report.OUT
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "docs" / "brand" / "contrast-report.md"
            out.parent.mkdir(parents=True)
            out.write_text(stale, encoding="utf-8")
            contrast_report.OUT, root = out, contrast_report.ROOT
            contrast_report.ROOT = Path(d)
            try:
                self.assertEqual(contrast_report.main(["--check"]), 1)
                self.assertEqual(out.read_text(encoding="utf-8"), stale)
            finally:
                contrast_report.OUT, contrast_report.ROOT = real, root
