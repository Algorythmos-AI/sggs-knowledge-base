#!/usr/bin/env python3
"""Print the CHANGELOG section for a version (Keep-a-Changelog '## [X.Y.Z]'). Exit 1 if absent."""
import re, sys
from pathlib import Path
v = sys.argv[1]
s = (Path(__file__).resolve().parents[2] / "CHANGELOG.md").read_text(encoding="utf-8")
m = re.search(rf"^## \[{re.escape(v)}\].*?(?=^## |\Z)", s, re.S | re.M)
if not m:
    sys.stderr.write(f"no CHANGELOG section for {v}\n"); sys.exit(1)
print(m.group(0).strip())
