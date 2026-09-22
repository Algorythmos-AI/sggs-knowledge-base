#!/usr/bin/env python3
"""Extract the verbatim opening line (Ang 1) from db/sggs.sqlite into the landing's generated
data. Run from the repo root. The LandingVerseIsVerbatim gate re-checks the built page vs the DB,
so scripture on the landing can never drift from the corpus."""
import sqlite3, json, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[1]
db = root / "db" / "sggs.sqlite"
conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
gen = root / "frontend" / "src" / "generated"
gen.mkdir(parents=True, exist_ok=True)

# 1) The landing verse — the verbatim opening line of Ang 1.
row = conn.execute("SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1").fetchone()
if not row: sys.exit("no ang-1 line in db")
verse = gen / "landing-verse.json"
verse.write_text(json.dumps({"ang": 1, "gurmukhi": row[0]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("wrote", verse)

# 2) Raags per pahar for the live raag-clock arc. Metadata about raags only (names + roman) —
#    NOT scripture. Mirrors serve.py /api/timing/clock (primary claims). Pahar 7 (00:00-03:00)
#    deliberately has no raags; that absence is rendered as content, not a gap.
try:
    rows = conn.execute(
        "SELECT c.pahar, c.raag_name, r.roman FROM raag_timing_claims c "
        "JOIN raags r ON r.name = c.raag_name "
        "WHERE c.claim_type='primary' ORDER BY c.pahar, r.seq").fetchall()
    per = {str(p): [] for p in range(1, 9)}
    for p, name, roman in rows:
        per[str(p)].append({"name": name, "roman": roman})
    raags = gen / "landing-raags.json"
    raags.write_text(json.dumps({
        "_note": "primary raag-timing claims per pahar (metadata, not scripture); "
                 "pahar 7 (00:00-03:00) intentionally empty. Generated from db/sggs.sqlite.",
        "convention": "pahar 1 = 06:00-09:00 ... pahar 8 = 03:00-06:00 (fixed-clock, 6 AM anchor)",
        "pahars": per,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("wrote", raags)
except sqlite3.OperationalError as e:
    sys.exit(f"raag_timing_claims not available in this DB: {e}")
