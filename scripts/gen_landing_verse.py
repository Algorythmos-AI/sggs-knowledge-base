#!/usr/bin/env python3
"""Extract verbatim Gurmukhi from db/sggs.sqlite into the landing + Learn generated data.
Run from the repo root. The LandingPage / LearnSection gates re-check the built pages against the
DB, so scripture on the site can never drift from the corpus.

Emits (all under frontend/src/generated/, byte-stable across runs):
  - landing-verse.json   the verbatim opening line of Ang 1 (landing hero verse)
  - landing-raags.json   primary raag-timing claims per pahar (metadata, not scripture)
  - quotes.json          verbatim rows for every line id quoted by a Learn article
"""
import sqlite3, json, sys, re, pathlib
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

# 3) quotes.json — every verbatim line quoted by a Learn article. The union of each article's
#    frontmatter `quotes: [ids]` and the `<Verse id={N}` occurrences in its body. A body id that is
#    not also declared in that file's frontmatter is a fidelity hazard (an undeclared quote), so we
#    FAIL rather than silently emit it. Every emitted id must exist in db/sggs.sqlite (else FAIL).
learn_dir = root / "frontend" / "src" / "content" / "learn"
FM = re.compile(r"^---\s*\n(.*?)\n---", re.S)
FM_QUOTES = re.compile(r"(?m)^quotes:\s*\[([^\]]*)\]")
BODY_VERSE = re.compile(r"<Verse\s+id=\{(\d+)\}")

def int_list(s):
    return [int(x) for x in re.findall(r"\d+", s)]

wanted = set()
if learn_dir.is_dir():
    for mdx in sorted(learn_dir.glob("*.mdx")):
        text = mdx.read_text(encoding="utf-8")
        fm = FM.search(text)
        fm_body_split = text[fm.end():] if fm else text
        declared = set()
        if fm:
            mq = FM_QUOTES.search(fm.group(1))
            if mq:
                declared = set(int_list(mq.group(1)))
        body_ids = set(int(x) for x in BODY_VERSE.findall(fm_body_split))
        undeclared = sorted(body_ids - declared)
        if undeclared:
            sys.exit(f"{mdx.name}: <Verse id> {undeclared} used in body but not declared in "
                     f"frontmatter `quotes:` — declare every quoted id.")
        wanted |= declared | body_ids

quotes = {}
for lid in sorted(wanted):
    row = conn.execute(
        "SELECT ang, line_no, raag, author, is_header, gurmukhi FROM lines WHERE id=?",
        (lid,)).fetchone()
    if not row:
        sys.exit(f"quotes.json: line id {lid} not found in db/sggs.sqlite")
    ang, line_no, raag, author, is_header, gurmukhi = row
    quotes[str(lid)] = {
        "ang": ang, "line_no": line_no, "raag": raag, "author": author,
        "is_header": bool(is_header), "gurmukhi": gurmukhi,
    }

manifest = json.loads((root / "MANIFEST.json").read_text(encoding="utf-8"))
out = gen / "quotes.json"
out.write_text(json.dumps(
    {"_db_sha256": manifest.get("db_sha256", ""), "quotes": quotes},
    ensure_ascii=False, indent=2, sort_keys=False) + "\n", encoding="utf-8")
print("wrote", out, f"({len(quotes)} line(s))")
