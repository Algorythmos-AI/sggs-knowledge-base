#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v2.0 structural enrichment — ADDITIVE, zero-data-loss.

Derives three NEW columns on `lines` from data ALREADY in the DB (no re-parse, no guess):
  • stanza_index    INT  — running pada/stanza number within a shabad (comp_id). Lines
                            accumulate into pada N until a ॥N॥ Ank marker closes it.
                            Rahao refrains take their surrounding stanza and DON'T advance
                            the count. Headers = 0.
  • pada_total      INT  — number of padas (stanzas) in the shabad (per comp_id).
  • source_category TEXT — Gurus / Bhagats / Bhatts / Other, rolled up from `author`.

It does NOT touch: existing columns, the FTS5 index (external-content over text/translit/
translit_norm/fl_g/fl_r/skeleton — unaffected by ADD COLUMN), fts_shabad, variants,
translations, folds, or anything serve.py reads. is_rahao and comp_type already exist and
are reused as-is.

Also runs the DOUBLE-CONFIRMATION CHECKSUM: per shabad, the terminal Ank (॥N॥...) must
equal the count of padas actually indexed; mismatches are classified and logged.

Usage:
  python3 pipeline/enrich_v2.py --db db/sggs.sqlite --report            # read-only dry run
  python3 pipeline/enrich_v2.py --db /tmp/sggs_v2.db --apply            # ALTER+UPDATE
  python3 pipeline/enrich_v2.py --db db/sggs.sqlite --checksum-only
"""
import argparse, json, sqlite3, sys, collections

GURMUKHI_DIGITS = {chr(0x0A66 + i): i for i in range(10)}   # ੦..੯ -> 0..9


def ank_to_int(s):
    """'੨੩' -> 23, return None if not all Gurmukhi digits."""
    if not s or any(ch not in GURMUKHI_DIGITS for ch in s):
        return None
    return int(''.join(str(GURMUKHI_DIGITS[ch]) for ch in s))


def source_category(author):
    if not author:
        return 'Other'
    a = author
    if a.startswith('Guru '):
        return 'Gurus'
    if a.startswith('Bhagat ') or 'Farid' in a:
        return 'Bhagats'
    if 'Bhatt' in a:
        return 'Bhatts'
    return 'Other'        # Satta & Balwand, Sundar, Mardana, etc.


def parse_markers(m):
    """DB stores markers as a JSON string; corpus as a list. Return list."""
    if m is None:
        return []
    if isinstance(m, list):
        return m
    try:
        return json.loads(m)
    except Exception:
        return []


def is_rahao_markers(markers):
    return any('ਰਹਾਉ' in str(x) for x in markers)


def first_ank(markers):
    """The leading numeric Ank of a line's markers (pada number), else None."""
    for x in markers:
        v = ank_to_int(str(x))
        if v is not None:
            return v
    return None


def enrich(rows):
    """Derive structure from the Ank MARKERS, not comp_id (a shabad's padas split across
    comp_ids — see comp_id 35). Walk body lines in id order:
      • a SINGLE-number marker ॥N॥ closes pada N;
      • a MULTI-number marker ॥N॥M॥(॥K॥) closes pada N AND ends the shabad (M = shabad
        sequence within the section);
      • a Rahao refrain belongs to the pada being accumulated but does not advance it.
    stanza_index = the running pada number a line belongs to (resets per marker-derived
    shabad). pada_total = padas in that shabad. Headers = stanza 0.

    Returns per-id {stanza_index, source_category, pada_total} and a checksum list at each
    shabad terminal: does the terminal pada number == padas actually closed in the shabad?"""
    per_id = {}
    checks = []          # (first_id, last_ang, terminal_pada, n_padas, verdict, detail)
    sh_lines = []        # committed line-ids of the current shabad/run
    pending = []         # non-marker lines seen since the last pada marker (tentative)
    run = []             # pada numbers closed in the current run, in order
    first_id = [None]
    last_ang = [None]
    sh_ctypes = []       # comp_types seen in the current group (regime disambiguation)

    def close():
        nonlocal sh_lines, run, sh_ctypes
        if sh_lines:
            n = len(run)
            term = run[-1] if run else 0
            pada = 1
            for lid in sh_lines:
                si, sc, _ = per_id[lid]
                per_id[lid] = (min(pada, n) if n else 1, sc, n)
                if lid in marker_line_ids:
                    pada += 1
            if run:
                # Three-way, regime-aware. SGGS numbers padas several ways:
                #  • plain shabad: run == [1,2,..,N], terminal N  -> CLEAN double-confirm
                #  • Vaar pauri: saloks [1,2] then a cumulative pauri number (big jump) -> STRUCTURAL
                #  • Japji/cumulative salok run [1,2,3,..] (still contiguous) -> CLEAN
                # Only a run that starts at 1 and is contiguous EXCEPT for an internal gap
                # (e.g. [1,2,4] — a pada marker actually missing) is a genuine ANOMALY.
                contig_from = run[0] if run else 0
                is_contig = run == list(range(contig_from, contig_from + n))
                if is_contig and contig_from == 1:
                    v, d = 'PASS', ''                       # clean shabad: padas 1..N, terminal N
                elif is_contig:                             # 2..k: cumulative continuation
                    v, d = 'STRUCTURAL', f'cumulative run {run[0]}..{term} (Japji/Thitee/Ruti/salok block)'
                elif run[:-1] == list(range(1, n)) and term > n:
                    # saloks 1..n-1 + a larger terminal. Legit cumulative pauri ONLY in a
                    # vaar/cumulative comp_type OR when the jump is large (>=3). A small
                    # gap inside a plain shabad (e.g. [1,2,4]) is a REAL missing marker.
                    grp_vaar = any(c in VAAR_TYPES for c in sh_ctypes)
                    if grp_vaar or (term - n) >= 3:
                        v, d = 'STRUCTURAL', f'vaar/cumulative (saloks 1..{n-1} + pauri {term})'
                    else:
                        v, d = 'ANOMALY', f'likely missing pada marker: run {run} (terminal {term}, {n} closed)'
                elif sorted(run) == list(range(1, n + 1)):
                    v, d = 'STRUCTURAL', f'reordered padas {run}'
                else:
                    v, d = 'ANOMALY', f'non-contiguous padas {run} (terminal {term}, {n} closed)'
                checks.append((first_id[0], last_ang[0], term, n, v, d))
        sh_lines, run, sh_ctypes = [], [], []
        first_id[0] = None

    marker_line_ids = set()
    for r in rows:
        sc = source_category(r['author'])
        mk = parse_markers(r['markers'])
        rahao = bool(r['is_rahao']) or is_rahao_markers(mk)
        if r['is_header']:
            per_id[r['id']] = (0, sc, 0)
            continue
        last_ang[0] = r['ang']
        nums = [v for v in (ank_to_int(str(x)) for x in mk) if v is not None]
        per_id[r['id']] = (0, sc, 0)          # filled at close()
        if r.get('comp_type'): sh_ctypes.append(r['comp_type'])
        if nums and not rahao:                # a pada-closing line
            if run and nums[0] <= run[-1]:    # pada number reset -> previous shabad ended;
                close()                       # `pending` are the new shabad's opening lines
            if first_id[0] is None:
                first_id[0] = (pending[0] if pending else r['id'])
            sh_lines += pending + [r['id']]
            pending = []
            marker_line_ids.add(r['id'])
            run.append(nums[0])
            if len(nums) >= 2:                # ॥N॥M॥ explicitly ends the shabad
                close()
        else:                                 # non-marker / rahao line: tentative
            if first_id[0] is None and not run:
                pass
            pending.append(r['id'])
    sh_lines += pending
    close()
    return per_id, checks


def load_rows(con):
    cur = con.execute("SELECT id, comp_id, is_header, is_rahao, markers, author, ang, comp_type "
                      "FROM lines ORDER BY id")
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


# composition types that legitimately use cumulative pauri/salok numbering (a big terminal
# jump is structural there); a comparable jump inside a plain shabad is a real anomaly.
VAAR_TYPES = {'ਵਾਰ', 'ਪਉੜੀ', 'ਸਲੋਕ', 'ਸਲੋਕੁ', 'ਰੁਤੀ', 'ਥਿਤੀ', 'ਥਿਤੀਆ', 'ਬਾਵਨ ਅਖਰੀ',
              'ਗਾਥਾ', 'ਫੁਨਹੇ', 'ਚਉਬੋਲੇ', 'ਸਵਈਏ', 'ਪਟੀ', 'ਅੰਜੁਲੀਆ', 'ਦਿਨ ਰੈਣਿ'}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', required=True)
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--report', action='store_true')
    ap.add_argument('--checksum-only', action='store_true')
    ap.add_argument('--limit-comps', type=int, default=0, help='sample: first N comp_ids only')
    args = ap.parse_args()

    con = sqlite3.connect(args.db)
    rows = load_rows(con)
    if args.limit_comps:
        keep = list(dict.fromkeys(r['comp_id'] for r in rows))[:args.limit_comps]
        keepset = set(keep)
        rows = [r for r in rows if r['comp_id'] in keepset]
    per_id, checks = enrich(rows)

    # ---- stats  (checks tuple: first_id, last_ang, terminal_pada, n_padas, verdict, detail)
    vc = collections.Counter(c[4] for c in checks)
    clean = vc['PASS']
    structural = vc['STRUCTURAL']
    anom = vc['ANOMALY']
    cat = collections.Counter(v[1] for v in per_id.values())
    print(f"lines: {len(per_id)}   stanza-groups detected: {len(checks)}")
    print(f"DOUBLE-CONFIRM  CLEAN(pada==count) {clean}  STRUCTURAL(vaar/cumulative) {structural}"
          f"  ANOMALY {anom}   -> integrity {100*(clean+structural)/max(len(checks),1):.2f}% explained")
    print("source_category:", dict(cat))
    print("pada_total (top):", dict(collections.Counter(
        v[2] for v in per_id.values() if v[2]).most_common(8)))
    if args.report or args.checksum_only:
        print("\nANOMALIES (genuine review candidates):")
        an = [c for c in checks if c[4] == 'ANOMALY']
        for fid, ang, tp, pc, v, det in an[:40]:
            print(f"   line_id={fid} ~Ang{ang}: {det}")
        if not an: print("   (none)")

    if args.apply:
        cur = con.cursor()
        existing = {r[1] for r in cur.execute("PRAGMA table_info(lines)")}
        for col, typ in [('stanza_index', 'INT'), ('pada_total', 'INT'),
                         ('source_category', 'TEXT')]:
            if col not in existing:
                cur.execute(f"ALTER TABLE lines ADD COLUMN {col} {typ}")
        cur.executemany("UPDATE lines SET stanza_index=?, source_category=?, pada_total=? WHERE id=?",
                        [(v[0], v[1], v[2], i) for i, v in per_id.items()])
        con.commit()
        print(f"\nAPPLIED: stanza_index, pada_total, source_category on {len(per_id)} lines.")
    con.close()


if __name__ == '__main__':
    main()
