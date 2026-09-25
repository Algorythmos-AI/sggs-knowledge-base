import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import gen_route_table  # noqa: E402


class RouteTable(unittest.TestCase):
    def test_every_served_route_is_on_the_page_and_the_page_is_current(self):
        text = gen_route_table.build()
        import serve  # noqa: WPS433 (path set by gen_route_table)
        for (seg1, seg2), (_fn, ctx) in serve.ROUTES.items():
            path = f"/api/{seg1}" + (f"/{seg2}" if seg2 else "")
            self.assertIn(path, text, path)
            self.assertIn(f"`{ctx}`", text)
        self.assertIn(gen_route_table.HEADER, text)
        self.assertEqual(gen_route_table.OUT.read_text(encoding="utf-8"), text, "run: python3 tools/gen_route_table.py")

    def test_check_mode_exits_zero_when_current(self):
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "gen_route_table.py"), "--check"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


class Generators(unittest.TestCase):
    def test_contributors_page_is_current_and_generated(self):
        import gen_contributors
        self.assertEqual(gen_contributors.OUT.read_text(encoding="utf-8"), gen_contributors.build(), "run: python3 tools/gen_contributors.py")
        self.assertIn(gen_contributors.HEADER, gen_contributors.build())

    def test_repo_map_platform_paths_exist(self):
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "gen_repo_map.py"), "--check"], capture_output=True, text=True, env={**os.environ, "GH_TOKEN": "", "GITHUB_TOKEN": ""})
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
