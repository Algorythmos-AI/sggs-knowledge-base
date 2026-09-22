#!/usr/bin/env python3
"""Extract the verbatim opening line (Ang 1) from db/sggs.sqlite into the landing's generated
data. Run from the repo root. The LandingVerseIsVerbatim gate re-checks the built page vs the DB,
so scripture on the landing can never drift from the corpus."""
import sqlite3, json, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
db = root / "db" / "sggs.sqlite"
row = sqlite3.connect(f"file:{db}?mode=ro", uri=True).execute(
    "SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1").fetchone()
if not row: sys.exit("no ang-1 line in db")
out = root / "frontend" / "src" / "generated" / "landing-verse.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({"ang": 1, "gurmukhi": row[0]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("wrote", out)
