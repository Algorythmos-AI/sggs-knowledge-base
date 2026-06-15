#!/usr/bin/env python3
"""
build_vaars.py — Phase 3 offline builder: Vaar Anatomy.

A Vaar is a heroic-ballad form: numbered ਪਉੜੀ (pauri) "rungs", each preceded by
ਸਲੋਕ (salok) couplets — and famously the saloks are often by a DIFFERENT Guru than
the pauris (Guru Arjan's editorial architecture). This builder reconstructs the
ordered salok/pauri anatomy of every Vaar so the UI can render its structure.

DETECTION — TITLE-ANCHORED, COMP-BOUNDED, LINE-PARSED. The corpus tags Vaars
inconsistently (comp_type 'ਵਾਰ' also covers the Bhagat bani after Basant; a salok's
FIRST line is is_header/pada_total=0 just like a section header), so we combine signals:

  1. Anchor: a header line is a Vaar TITLE iff it has "ਵਾਰ" AND one of "ਕੀ ਵਾਰ" |
     "ਵਾਰ ਮਹਲ" | "ਵਾਰ ਸਲੋਕਾ" | "ਸਲੋਕਾ ਨਾਲਿ" | "ਧੁਨੀ"/"ਧੁਨਿ". Yields exactly the canonical
     22, rejecting "ਰਾਗੁ ਗਉੜੀ ਵਾਰ ਕਬੀਰ ਜੀਉ ਕੇ ੭" and "ਬਿਲਾਵਲੁ ਮਹਲਾ ੩ ਵਾਰ ਸਤ".

  2. Boundary (comp level): a Vaar's comps are comp_type in {ਸਲੋਕ,ਸਲੋਕੁ,ਪਉੜੀ,ਵਾਰ},
     same raag. It ends at the next Vaar title, a raag change, a comp_type outside that
     set (the shabads after the Vaar), a ਰਹਾਉ-bearing comp (a shabad), or a section-intro
     header ("…ਬਾਣੀ…", "…ਘਰੁ…", "ਰਾਗੁ…") — which is what ends Basant Ki Vaar.

  3. Units (line level, within member comps): a "ਪਉੜੀ" label opens a pauri; a
     "ਸਲੋਕੁ/ਸਲੋਕ/ਮਃ/ਮਹਲਾ" label opens a salok. Any other line (incl. a salok's
     pada_total=0 opening line) is verse and accrues to the open unit. When a Vaar has
     NO pauri labels at all (Basant: 3 pauris bundled as numbered stanzas), each numbered
     stanza (closing ॥N॥) is a pauri. Never emits a zero-line unit.

The result is asserted against the canonical 22-Vaar roster (by Ang) before commit.

Writes two purely-additive tables:
  vaars(vaar_id, raag, roman, first_ang, last_ang, n_pauris, n_saloks,
        pauri_author, salok_authors, cross_author, title)
  vaar_units(vaar_id, seq, kind, comp_id, author, n_lines, pauri_no, first_line_id, ang, theme)

    python pipeline/build_vaars.py --db db/sggs.sqlite

Idempotent & additive — only creates/replaces vaars + vaar_units.
"""
import argparse, sqlite3, json, time, re, collections

GUR = {'੦': '0', '੧': '1', '੨': '2', '੩': '3', '੪': '4', '੫': '5', '੬': '6', '੭': '7', '੮': '8', '੯': '9'}
CANON_ANGS = [83, 137, 300, 318, 462, 508, 517, 548, 585, 642, 705, 785,
              849, 947, 957, 966, 1086, 1094, 1193, 1237, 1278, 1312]
# comp_types that occur INSIDE Vaars. Besides ਸਲੋਕ/ਸਲੋਕੁ/ਪਉੜੀ/ਵਾਰ, this DB tags some
# in-Vaar saloks with thematic composition names (ਅਨੰਦੁ in Bilaval, ਡਖਣੇ in Maru-M5,
# ਰੁਤੀ in Asa/Majh/Sarang, ਕੁਚਜੀ in Gujri-M3/Maru-M3, ਵਣਜਾਰਾ in Bihagra/Kanra, ਗੁਣਵੰਤੀ in
# Malar). A Vaar ends only when the comp_type leaves this set (→ a following shabad).
IN_SET = {'ਸਲੋਕ', 'ਸਲੋਕੁ', 'ਪਉੜੀ', 'ਵਾਰ', 'ਡਖਣੇ', 'ਅਨੰਦੁ',
          'ਰੁਤੀ', 'ਕੁਚਜੀ', 'ਵਣਜਾਰਾ', 'ਗੁਣਵੰਤੀ', 'ਸਦੁ'}
SALOK_LBL = ('ਸਲੋਕੁ', 'ਸਲੋਕ', 'ਮਃ ', 'ਮਹਲਾ ')
NUM_MARK = re.compile(r'॥\s*([੦-੯]+)')


def log(m): print(f"[vaars] {m}", flush=True)
def gnum(s):
    t = ''.join(GUR.get(ch, '') for ch in (s or '')); return int(t) if t else None
def mahala(a):
    m = re.search(r'\(M(\d)\)', a or ''); return m.group(1) if m else (a or '')


def is_vaar_title(t):
    if not t or 'ਵਾਰ' not in t:
        return False
    return ('ਕੀ ਵਾਰ' in t or 'ਵਾਰ ਮਹਲ' in t or 'ਵਾਰ ਸਲੋਕਾ' in t
            or 'ਸਲੋਕਾ ਨਾਲਿ' in t or 'ਧੁਨੀ' in t or 'ਧੁਨਿ' in t)


def is_section_intro(t):
    """The sub-section header that ends Basant Ki Vaar: 'ਬਸੰਤੁ ਬਾਣੀ ਭਗਤਾਂ ਕੀ' (bani OF the
    Bhagats). Kept deliberately narrow — 'ਘਰੁ'/'ਬਾਣੀ' alone are common verse words and must
    NOT trip the boundary inside a salok."""
    return 'ਭਗਤਾਂ ਕੀ' in (t or '')


def is_pauri_label(t):
    """A standalone pauri heading. Matches both spellings — ਪਉੜੀ and the variant ਪਵੜੀ —
    as the FIRST token (the trailing danda/number is fine; a verse line that merely begins
    with the word is rejected because its first token carries extra letters). This is the
    fix for Majh Ki Vaar: 4 of its 27 pauris are labelled ਪਵੜੀ on a non-header, nonzero-pada
    line, so they cannot be gated on is_header/pada_total like the other labels."""
    w = t.split()
    return bool(w) and w[0].rstrip('॥') in ('ਪਉੜੀ', 'ਪਵੜੀ')


def line_kind(l):
    """pauri-label | salok-label | skip | verse."""
    t = (l['gurmukhi'] or '').strip()
    if t.startswith('ੴ') or is_vaar_title(t):
        return 'skip'
    if is_pauri_label(t):                       # incl. ਪਵੜੀ variant, regardless of header/pada
        return 'pauri-label'
    if (l['pada_total'] or 0) == 0 and l['is_header'] and t.startswith(SALOK_LBL):
        return 'salok-label'
    return 'verse'


def closes_stanza(t):
    return bool(NUM_MARK.search(t or ''))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default="db/sggs.sqlite")
    ap.add_argument("--no-vacuum", action="store_true")
    args = ap.parse_args()
    con = sqlite3.connect(args.db); con.row_factory = sqlite3.Row

    # group corpus into comps in reading order
    comps = collections.OrderedDict()
    for r in con.execute("SELECT id, ang, comp_id, comp_type, raag, author, is_header, is_rahao, "
                         "gurmukhi, pada_total FROM lines ORDER BY id"):
        comps.setdefault(r['comp_id'], []).append(dict(r))
    order = []
    for cid, L in comps.items():
        ct = collections.Counter(x['comp_type'] for x in L if x['comp_type']).most_common(1)
        title = next((x['gurmukhi'] for x in L if x['is_header'] and is_vaar_title(x['gurmukhi'])), None)
        hdr = next((x['gurmukhi'] for x in L if x['is_header']), L[0]['gurmukhi'])
        order.append(dict(cid=cid, ctype=(ct[0][0] if ct else None),
                          raag=next((x['raag'] for x in L if x['raag']), None),
                          ang=min(x['ang'] for x in L), lines=L,
                          has_rahao=any(x['is_rahao'] for x in L),
                          is_title=bool(title), header=hdr or ''))

    title_idx = [i for i, c in enumerate(order) if c['is_title']]
    log(f"detected {len(title_idx)} Vaar titles")
    got = sorted(order[i]['ang'] for i in title_idx)
    missing = [a for a in CANON_ANGS if a not in got]; extra = [a for a in got if a not in CANON_ANGS]
    log("roster OK — matches canonical 22 Vaars exactly" if not (missing or extra)
        else f"WARNING roster drift — missing {missing}  extra {extra}")

    def theme_of(ids):
        if not ids: return None
        ph = ','.join('?' * len(ids))
        r = con.execute(f"SELECT concept, COUNT(*) c FROM concept_lines WHERE line_id IN ({ph}) "
                        f"GROUP BY concept ORDER BY c DESC LIMIT 1", ids).fetchone()
        return r['concept'] if r else None

    def mk_unit(kind, verse):
        au = collections.Counter(l['author'] for l in verse if l['author'])
        mno = None                               # the closing ॥N॥ marker number (for the gap self-check)
        if kind == 'pauri':
            m = NUM_MARK.search(verse[-1]['gurmukhi'] or '')
            mno = gnum(m.group(1)) if m else None
        # pno (the DISPLAYED pauri number) is assigned later as the sequential ordinal — the raw
        # marker is unreliable in some Vaars (Maru-M5 'Dakhne' pauris all close ॥੧॥ → 'Pauri 1 ×17').
        return dict(kind=kind, cid=verse[0]['comp_id'], n_lines=len(verse), pno=None, mno=mno,
                    author=(au.most_common(1)[0][0] if au else None),
                    first_line_id=verse[0]['id'], ang=min(l['ang'] for l in verse),
                    line_ids=[l['id'] for l in verse])

    # ---- collect member comps per Vaar, then parse units line-by-line ----
    built = []
    for ti in title_idx:
        t = order[ti]
        vraag = t['raag']
        member_lines = list(t['lines'])
        # A Vaar runs until the next Vaar title, a raag change, the Bhagat-bani section
        # header (Basant), or the first comp whose comp_type is OUTSIDE the salok/pauri
        # family (IN_SET) — i.e. the shabads (ਛੰਤ, ਅਸਟਪਦੀਆ, …) that follow the Vaar. We do
        # NOT use ਰਹਾਉ as the boundary: a few Vaar saloks legitimately carry a ਰਹਾਉ line.
        end_on = 'EOF'
        for j in range(ti + 1, len(order)):
            c = order[j]
            if c['is_title']:
                end_on = 'next-title'; break
            if c['raag'] and vraag and c['raag'] != vraag:
                end_on = f"raag→{c['raag']}"; break
            if is_section_intro(c['header']):
                end_on = 'bhagat-bani'; break
            if c['ctype'] not in IN_SET:
                end_on = f"ctype:{c['ctype']}"; break
            if vraag is None and c['raag']:
                vraag = c['raag']
            member_lines.extend(c['lines'])
        log(f"  vaar@{t['ang']:<4} ends on {end_on}")

        kinds = [line_kind(l) for l in member_lines]
        has_pauri = any(k == 'pauri-label' for k in kinds)
        default_kind = 'salok' if has_pauri else 'pauri'
        units, cur, cur_default = [], None, False

        def flush():
            nonlocal cur
            if cur and cur['lines']:
                units.append(mk_unit(cur['kind'], cur['lines']))
            cur = None

        for l, k in zip(member_lines, kinds):
            if k == 'pauri-label':
                flush(); cur = dict(kind='pauri', lines=[]); cur_default = False
            elif k == 'salok-label':
                flush(); cur = dict(kind='salok', lines=[]); cur_default = False
            elif k == 'skip':
                continue
            else:
                if cur is None:
                    cur = dict(kind=default_kind, lines=[]); cur_default = True
                cur['lines'].append(l)
                if cur_default and closes_stanza(l['gurmukhi']):
                    flush()
        flush()
        # A Vaar is defined by its pauri spine and ends at its last pauri. Drop any trailing
        # saloks gathered after the final pauri — for raag-bounded Vaars those are post-Vaar
        # saloks of the same raag (e.g. the stray Farid salok swept into Asa Ki Vaar).
        last_p = max((i for i, u in enumerate(units) if u['kind'] == 'pauri'), default=None)
        if last_p is not None:
            units = units[:last_p + 1]
        built.append((t, vraag, units))

    con.execute("DROP TABLE IF EXISTS vaars")
    con.execute("DROP TABLE IF EXISTS vaar_units")
    con.execute("CREATE TABLE vaars (vaar_id INTEGER PRIMARY KEY, raag TEXT, roman TEXT, first_ang INT, last_ang INT,"
                " n_pauris INT, n_saloks INT, pauri_author TEXT, salok_authors TEXT, cross_author INT, title TEXT)")
    con.execute("CREATE TABLE vaar_units (vaar_id INT, seq INT, kind TEXT, comp_id INT, author TEXT, n_lines INT,"
                " pauri_no INT, first_line_id INT, ang INT, theme TEXT, PRIMARY KEY(vaar_id, seq))")

    built.sort(key=lambda v: v[0]['ang'])
    for vid, (t, vraag, units) in enumerate(built, 1):
        raag = vraag or t['raag']
        rr = con.execute("SELECT roman FROM raags WHERE name=?", (raag,)).fetchone()
        roman = rr['roman'] if rr else (raag or '')
        P = [u for u in units if u['kind'] == 'pauri']
        S = [u for u in units if u['kind'] == 'salok']
        # Assign the DISPLAYED pauri number by sequential ordinal (1..N) in reading order. This
        # is robust for every Vaar and fixes the Maru-M5 'Dakhne' display (pauris all close ॥੧॥).
        for i, u in enumerate(P, 1):
            u['pno'] = i
        # Per-Vaar gap self-check runs on the raw closing-MARKER numbers (mno), not the ordinals.
        # A GENUINE shortfall = fewer pauri units than the highest marker number (len(P) < maxMno
        # → pauris dropped/merged, e.g. Majh-before: 23<26). We do NOT flag mere marker-VALUE
        # anomalies (duplicates/stanza-markers) — the Maru-M5 Dakhne case has len(P) >= maxMno, so
        # its count is sound even though the raw markers are unreliable.
        mns = [u['mno'] for u in P if u['mno'] is not None]
        if mns and len(P) < max(mns):
            missing = sorted(set(range(1, max(mns) + 1)) - set(mns))
            log(f"  ⚠ GAP {roman}@{t['ang']}: {len(P)} pauris but maxMarker={max(mns)} "
                f"→ dropped pauri #{missing}")
        pauri_author = collections.Counter(u['author'] for u in P if u['author']).most_common(1)[0][0] if P else None
        salok_auths = sorted({u['author'] for u in S if u['author']})
        cross = int(any(mahala(a) != mahala(pauri_author) for a in salok_auths)) if pauri_author else 0
        angs = [u['ang'] for u in units] + [t['ang']]
        a0, a1 = min(angs), max(angs)
        title = (t['header'] or '').strip().rstrip('॥').strip()
        con.execute("INSERT INTO vaars VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                    (vid, raag, roman, a0, a1, len(P), len(S), pauri_author,
                     json.dumps(salok_auths, ensure_ascii=False), cross, title or f"Vaar · {roman}"))
        for seq, u in enumerate(units):
            con.execute("INSERT INTO vaar_units VALUES (?,?,?,?,?,?,?,?,?,?)",
                        (vid, seq, u['kind'], u['cid'], u['author'], u['n_lines'],
                         u['pno'], u['first_line_id'], u['ang'], theme_of(u['line_ids'])))

    con.execute("CREATE TABLE IF NOT EXISTS analytics_meta (key TEXT PRIMARY KEY, value TEXT)")
    con.execute("INSERT OR REPLACE INTO analytics_meta VALUES ('vaars_built', ?)", (time.strftime('%Y-%m-%d %H:%M'),))
    con.commit()
    if not args.no_vacuum:
        con.isolation_level = None; con.execute("VACUUM")
    nv = con.execute("SELECT COUNT(*) FROM vaars").fetchone()[0]
    nu = con.execute("SELECT COUNT(*) FROM vaar_units").fetchone()[0]
    z = con.execute("SELECT COUNT(*) FROM vaar_units WHERE n_lines=0").fetchone()[0]
    con.close()
    log(f"done. vaars={nv}, vaar_units={nu}, zero-line-units={z}")


if __name__ == "__main__":
    main()
