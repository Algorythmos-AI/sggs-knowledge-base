#!/usr/bin/env python3
"""
Bani-forms derivation: populates shabd_raag_map, shabd_musical_markers,
shabd_structural_form, shabd_poetic_genre from the VERIFIED TEXT ONLY.

Honesty rules (hard):
  * reads are plain SELECTs on `lines`; writes go only to the four new tables;
  * a form/genre is recorded ONLY when the composition's own heading states it.
    The pipeline's `comp_type` column is substring-derived and demonstrably
    unreliable (e.g. ordinary Sireeraag M3 shabads labeled ਅਨੰਦੁ from verse
    text), so it is kept as a hint inside source_label but NEVER trusted alone;
  * `is_header=1` marks the first line of a comp, which for pauris of longer
    banis is verse, not a title — so matching applies only to TITLE-LIKE
    headers (containing ਮਹਲਾ / ਮਹਲੇ / ਮਃ / ਰਾਗੁ / ਬਾਣੀ / ਕੀ ਵਾਰ, or starting
    with a raag name). Anything unmatched stays NULL and is counted in the
    report — never guessed;
  * all matching on NFC-normalized text;
  * scripture baseline verified BEFORE and AFTER.

Usage: python3 derive_bani_forms.py [--db PATH] [--baseline PATH] [--refresh]
"""

import argparse
import sqlite3
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import baseline_lib as bl

ROOT = Path(__file__).resolve().parents[2]

GURMUKHI_DIGITS = str.maketrans("੦੧੨੩੪੫੬੭੮੯", "0123456789")


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def tokens(s):
    return nfc(s).replace("॥", " ").split()


# ---- heading classification -------------------------------------------------

TITLE_MARKS = ("ਮਹਲਾ", "ਮਹਲੇ", "ਮਃ", "ਰਾਗੁ", "ਬਾਣੀ")

# Minimal headings like 'ਪਉੜੀ ॥', 'ਸਲੋਕੁ ॥', 'ਡਖਣੇ ਮਃ ੫ ॥' are genuine titles:
# every token is a known heading word (form/genre/marker) or a numeral.
PURE_HEADING_TOKENS = {
    "ਪਉੜੀ", "ਸਲੋਕ", "ਸਲੋਕੁ", "ਸਲੋਕਾ", "ਛੰਤ", "ਛੰਤੁ", "ਸੋਲਹੇ", "ਡਖਣੇ", "ਡਖਣਾ",
    "ਅਸਟਪਦੀ", "ਅਸਟਪਦੀਆ", "ਵਾਰ", "ਮਃ", "ਮਹਲਾ", "ਘਰੁ", "ਪੜਤਾਲ", "ਦਖਣੀ",
}


def _numeral(tok):
    t = tok.translate(GURMUKHI_DIGITS)
    return t.isdigit()


def is_title(header, raag_names):
    toks = tokens(header)
    if not toks:
        return False
    if any(m in toks for m in TITLE_MARKS):
        return True
    if "ਕੀ ਵਾਰ" in " ".join(toks):
        return True
    if toks[0] in raag_names:  # e.g. 'ਆਸਾ ਸ੍ਰੀ ਕਬੀਰ ਜੀਉ ਕੇ ...'
        return True
    return all(t in PURE_HEADING_TOKENS or _numeral(t) for t in toks)


# ---- structural form: first match wins (vaar headings often also name
#      saloks, so precedence is broad-to-narrow) -------------------------------

STRUCT_RULES = [
    ("vaar",     lambda t, j: "ਕੀ ਵਾਰ" in j or (t and t[0] == "ਵਾਰ") or "ਵਾਰ ਮਹਲਾ" in j or "ਵਾਰ ਸਲੋਕਾ" in j),
    ("solahe",   lambda t, j: "ਸੋਲਹੇ" in t),
    ("ashtpadi", lambda t, j: any(x.startswith("ਅਸਟਪਦੀ") for x in t)),
    ("chhant",   lambda t, j: any(x.startswith("ਛੰਤ") for x in t)),
    ("pauri",    lambda t, j: any(x.startswith("ਪਉੜੀ") for x in t)),
    ("salok",    lambda t, j: any(x.startswith("ਸਲੋਕ") for x in t)),
]

# Header-stated pada words -> count (form 'pada').
PADA_WORDS = {
    "ਇਕਪਦੇ": 1, "ਦੁਪਦੇ": 2, "ਦੁਪਦਾ": 2, "ਦੁਪਦ": 2, "ਤਿਪਦੇ": 3, "ਤਿਪਦਾ": 3,
    "ਚਉਪਦੇ": 4, "ਚਉਪਦਾ": 4, "ਚਉਪਦੇਸੰਗੀਤ": 4, "ਪੰਚਪਦੇ": 5, "ਪੰਚਪਦਾ": 5,
    "ਛਿਪਦੇ": 6, "ਇਕਤੁਕੇ": None, "ਦੁਤੁਕੇ": None,  # tuk counts are not pada counts
}

# ---- poetic genre: token/substring evidence in TITLE headings only ----------
# NOTE ਦਖਣੀ (a jati/style marker) is deliberately NOT the genre 'dakhne' —
# the dakhne saloks are ਡਖਣੇ/ਡਖਣਾ.

GENRE_RULES = [
    ("barah_maha", lambda t, j: "ਬਾਰਹ ਮਾਹਾ" in j),
    ("bavan_akhri", lambda t, j: "ਬਾਵਨ ਅਖਰੀ" in j),
    ("din_raini",  lambda t, j: "ਦਿਨ ਰੈਣਿ" in j),
    ("thitti",     lambda t, j: any(x.startswith("ਥਿਤੀ") for x in t)),
    ("ruti",       lambda t, j: "ਰੁਤੀ" in t),
    ("patti",      lambda t, j: "ਪਟੀ" in t),
    ("pahare",     lambda t, j: "ਪਹਰੇ" in t),
    ("alahunian",  lambda t, j: any(x.startswith("ਅਲਾਹਣੀ") for x in t)),
    ("ghorian",    lambda t, j: any(x.startswith("ਘੋੜੀਆ") for x in t)),
    ("karhale",    lambda t, j: "ਕਰਹਲੇ" in t),
    ("vanjara",    lambda t, j: "ਵਣਜਾਰਾ" in t),
    ("kuchaji",    lambda t, j: "ਕੁਚਜੀ" in t),
    ("suchaji",    lambda t, j: "ਸੁਚਜੀ" in t),
    ("gunvanti",   lambda t, j: "ਗੁਣਵੰਤੀ" in t),
    ("sadd",       lambda t, j: "ਸਦੁ" in t),
    ("anjulian",   lambda t, j: any(x.startswith("ਅੰਜੁਲੀ") for x in t)),
    ("birhare",    lambda t, j: "ਬਿਰਹੜੇ" in t),
    ("gatha",      lambda t, j: "ਗਾਥਾ" in t),
    ("funhe",      lambda t, j: any(x.startswith("ਫੁਨਹੇ") for x in t)),
    ("chaubole",   lambda t, j: any(x.startswith("ਚਉਬੋਲੇ") for x in t)),
    ("savaiye",    lambda t, j: any(x.startswith(("ਸਵਈਏ", "ਸਵਯੇ")) for x in t)),
    ("dakhne",     lambda t, j: any(x.startswith(("ਡਖਣੇ", "ਡਖਣਾ")) for x in t)),
    ("mundavani",  lambda t, j: "ਮੁੰਦਾਵਣੀ" in t),
]

JATI_MARKS = ("ਦਖਣੀ", "ਸੁਧੰਗ", "ਜਤਿ")  # stored verbatim when a title states them


def parse_ghar(raw):
    s = nfc(raw).strip().translate(GURMUKHI_DIGITS)
    if not s:
        return None
    try:
        g = int(s)
    except ValueError:
        return None
    return g if 1 <= g <= 17 else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "db" / "sggs.sqlite"))
    ap.add_argument("--baseline", default=str(ROOT / "audit" / "scripture-baseline.json"))
    ap.add_argument("--refresh", action="store_true",
                    help="delete rows from the four derived tables first (only those)")
    ap.add_argument("--skip-baseline", action="store_true",
                    help="ONLY for rebuild_all.sh temp DBs")
    args = ap.parse_args()

    if args.skip_baseline:
        print("WARNING: baseline check skipped (--skip-baseline; rebuild pipeline only).")
    else:
        print("Verifying scripture baseline BEFORE derivation…")
        bl.require_baseline_ok(args.db, args.baseline, when="(pre-derive)")
        print("  baseline PASS.")

    ro = bl.connect_ro(args.db)
    try:
        raag_names = {nfc(n) for (n,) in ro.execute("SELECT name FROM raags")}
        comps = {}
        cur = ro.execute(
            "SELECT comp_id, raag, ang, id, is_header, gurmukhi, ghar, is_rahao, "
            "       pada_total, comp_type "
            "FROM lines WHERE comp_id IS NOT NULL ORDER BY id")
        for comp_id, raag, ang, lid, is_h, gm, ghar, is_r, ptot, ctype in cur:
            c = comps.setdefault(comp_id, {
                "raags": set(), "first_ang": ang, "first_line_id": lid,
                "header": None, "ghar": set(), "rahao": 0, "rahao2": 0,
                "pada_total": None, "comp_type": ctype, "early": [],
            })
            if raag:
                c["raags"].add(nfc(raag))
            if is_h and c["header"] is None:
                c["header"] = nfc(gm)
            if len(c["early"]) < 3:
                c["early"].append(nfc(gm))
            g = parse_ghar(ghar)
            if g is not None:
                c["ghar"].add(g)
            if is_r:
                c["rahao"] = 1
            if "ਰਹਾਉ ਦੂਜਾ" in nfc(gm):
                c["rahao2"] = 1
            if ptot:
                c["pada_total"] = max(c["pada_total"] or 0, ptot)
    finally:
        ro.close()
    print(f"Read {len(comps)} compositions (read-only).")

    # ---- derive -----------------------------------------------------------
    rows_map, rows_mus, rows_struct, rows_genre = [], [], [], []
    stats = {"titles": 0, "multi_raag": 0, "multi_ghar": 0, "multi_genre": 0,
             "comp_type_unconfirmed": 0}
    genre_names = {g for g, _ in GENRE_RULES}
    struct_names = {s for s, _ in STRUCT_RULES}

    for comp_id, c in sorted(comps.items()):
        raag = next(iter(c["raags"])) if len(c["raags"]) == 1 else None
        if len(c["raags"]) > 1:
            stats["multi_raag"] += 1
        rows_map.append((comp_id, raag if raag in raag_names else None,
                         c["first_ang"], c["first_line_id"]))

        header = c["header"] or ""
        toks = tokens(header)
        joined = " ".join(toks)
        title = is_title(header, raag_names)
        if title:
            stats["titles"] += 1

        ghar = None
        if len(c["ghar"]) == 1:
            ghar = next(iter(c["ghar"]))
        elif len(c["ghar"]) > 1:
            stats["multi_ghar"] += 1  # ambiguous -> NULL, never guessed
        partaal = 1 if (title and "ਪੜਤਾਲ" in toks) else 0
        jati = next((m for m in JATI_MARKS if title and m in toks), None)

        form = None
        if title:
            form = next((name for name, rule in STRUCT_RULES if rule(toks, joined)), None)

        # Dhunni: stated in the vaar's own heading, or as a short dedicated
        # dhunni line among the comp's first lines (e.g. Ramkali ki Vaar M3:
        # 'ਜੋਧੈ ਵੀਰੈ ਪੂਰਬਾਣੀ ਕੀ ਧੁਨੀ ॥' is line 2). Verse lines merely
        # containing ਧੁਨਿ don't qualify: vaar comps only, <=8 tokens.
        dhunni = None
        if title and ("ਧੁਨੀ" in joined or "ਧੁਨਿ" in joined) and "ਵਾਰ" in joined:
            dhunni = header
        elif form == "vaar":
            for line in c["early"]:
                ltoks = tokens(line)
                if len(ltoks) <= 8 and ("ਧੁਨੀ" in ltoks or "ਧੁਨਿ" in ltoks):
                    dhunni = line
                    break
        rows_mus.append((comp_id, ghar, partaal, c["rahao"], c["rahao2"],
                         dhunni, jati, header or None))
        pada_count = None
        if title:
            pada_count = next((n for w, n in PADA_WORDS.items()
                               if w in toks and n), None)
            if pada_count and form is None:
                form = "pada"
        if form == "pada" and pada_count is None:
            pada_count = c["pada_total"]
        rows_struct.append((comp_id, form, pada_count, header or None))

        genres = [name for name, rule in GENRE_RULES if title and rule(toks, joined)]
        if len(genres) > 1:
            stats["multi_genre"] += 1
        if genres:
            rows_genre.append((comp_id, genres[0], header or None))

        # comp_type hint that the heading does NOT confirm -> counted, not used
        ct = nfc(c["comp_type"] or "")
        if ct and ct not in ("ਸੁਖਮਨੀ", "ਅਨੰਦੁ", "ਕਾਫੀ", "ਰਾਗ ਮਾਲਾ", "ਸਿਧ ਗੋਸਟਿ",
                             "ਓਅੰਕਾਰੁ") and title:
            confirmed = (form in struct_names or (genres and genres[0] in genre_names)
                         or partaal or ct in joined)
            if not confirmed:
                stats["comp_type_unconfirmed"] += 1

    # ---- write ------------------------------------------------------------
    con = sqlite3.connect(str(Path(args.db).resolve()), isolation_level=None)
    try:
        con.execute("PRAGMA foreign_keys=ON")
        con.execute("BEGIN IMMEDIATE")
        try:
            if args.refresh:
                for t in ("shabd_poetic_genre", "shabd_structural_form",
                          "shabd_musical_markers", "shabd_raag_map"):
                    con.execute(f"DELETE FROM {t}")  # timing-layer tables only
            n = {}
            n["map"] = sum(con.execute(
                "INSERT OR IGNORE INTO shabd_raag_map VALUES (?,?,?,?)", r).rowcount
                for r in rows_map)
            n["musical"] = sum(con.execute(
                "INSERT OR IGNORE INTO shabd_musical_markers VALUES (?,?,?,?,?,?,?,?)",
                r).rowcount for r in rows_mus)
            n["structural"] = sum(con.execute(
                "INSERT OR IGNORE INTO shabd_structural_form VALUES (?,?,?,?)",
                r).rowcount for r in rows_struct)
            n["genre"] = sum(con.execute(
                "INSERT OR IGNORE INTO shabd_poetic_genre VALUES (?,?,?)",
                r).rowcount for r in rows_genre)
            con.execute("COMMIT")
        except Exception as e:
            con.execute("ROLLBACK")
            print(f"ABORT: derivation write failed, rolled back cleanly: {e}",
                  file=sys.stderr)
            return 1
        fk = con.execute("PRAGMA foreign_key_check").fetchall()
        if fk:
            print(f"ABORT: foreign_key_check violations: {fk}", file=sys.stderr)
            return 1

        print("\n=== Derivation report ===")
        print(f"  inserted: map=+{n['map']} musical=+{n['musical']} "
              f"structural=+{n['structural']} genre=+{n['genre']}")
        print(f"  title-like headings: {stats['titles']} / {len(comps)} comps")
        for k in ("multi_raag", "multi_ghar", "multi_genre", "comp_type_unconfirmed"):
            print(f"  {k}: {stats[k]}")
        print("  form breakdown:")
        for form, cnt in con.execute(
                "SELECT COALESCE(form,'(NULL — heading states no form)'), COUNT(*) "
                "FROM shabd_structural_form GROUP BY form ORDER BY 2 DESC"):
            print(f"    {form:38s} {cnt}")
        print("  genre breakdown:")
        for g, cnt in con.execute(
                "SELECT genre, COUNT(*) FROM shabd_poetic_genre GROUP BY genre ORDER BY 2 DESC"):
            print(f"    {g:38s} {cnt}")
        print("  markers: ", dict(con.execute(
            "SELECT 'ghar_set', COUNT(*) FROM shabd_musical_markers WHERE ghar IS NOT NULL "
            "UNION ALL SELECT 'partaal', SUM(partaal) FROM shabd_musical_markers "
            "UNION ALL SELECT 'rahao', SUM(has_rahao) FROM shabd_musical_markers "
            "UNION ALL SELECT 'rahao_dooja', SUM(has_rahao_dooja) FROM shabd_musical_markers "
            "UNION ALL SELECT 'dhunni', COUNT(dhunni) FROM shabd_musical_markers "
            "UNION ALL SELECT 'jati', COUNT(jati) FROM shabd_musical_markers").fetchall()))
    finally:
        con.close()

    if not args.skip_baseline:
        print("\nRe-verifying scripture baseline AFTER derivation…")
        bl.require_baseline_ok(args.db, args.baseline, when="(post-derive)")
        print("  baseline PASS — pre-existing tables byte-identical.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
