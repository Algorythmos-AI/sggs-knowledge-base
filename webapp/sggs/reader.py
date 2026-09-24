# -*- coding: utf-8 -*-
"""Reader context: build identity and integrity self-test, verbatim lines by Ang / composition /
id, the random complete unit (Hukam), and the Nitnem bani registry."""
import json, re, sqlite3
from . import core
from .core import ApiError, LINE_COLS, _FALLTHROUGH, _ID_MAX, _int_str, attach_translations, db, rows_to_list
from verify import verify as verify_claim


_BANI_KEY_RE = re.compile(r'^[a-z0-9_]{1,32}$')     # /api/bani/{key}


_BANI_VARIANTS = ('', 'sgpc', 'taksal', 'kirtan', 'printed')   # allowlist; never interpolated


def hukam_package(seed=None):
    """A COMPLETE Hukamnama unit, never a comp_id fragment. comp_id splits shabads and
    isolates a Vaar's saloks from its pauri (the v2.0 checksum finding), so a random seed
    is expanded to its full structural unit:
      • Vaar  -> the concluding Pauri + every Salok that precedes it (back to the prior Pauri)
      • shabad -> all padas + Rehao (expanded across comps if the shabad was split, bounded
        by the ॥N॥M॥ shabad terminal)
    Standalone saloks (Salok M9 etc.) and self-contained shabads return their own comp. A
    ±15-comp window bounds the scan so a malformed structure can never run away. (15 not 9:
    one real Vaar — Maajh, comps 399-409 at Ang 141 — has a 10-comp Salok run before its
    Pauri, so a seed at the run's head needs >9 candidates to reach the concluding Pauri.)"""
    if seed is None:
        row = db().execute('SELECT comp_id FROM lines WHERE is_header=0 ORDER BY RANDOM() LIMIT 1').fetchone()
        if row is None: raise ValueError('corpus is empty')
        seed = row['comp_id']
    win = rows_to_list(db().execute(
        f'SELECT {LINE_COLS}, markers FROM lines WHERE comp_id BETWEEN ? AND ? ORDER BY id',
        (seed - 15, seed + 15)).fetchall())
    comps = {}
    for l in win: comps.setdefault(l['comp_id'], []).append(l)
    order = list(comps.keys())
    SAL, PAU = {'ਸਲੋਕ', 'ਸਲੋਕੁ'}, 'ਪਉੜੀ'
    def dtype(ls):
        body = [x for x in ls if not x['is_header']] or ls
        cnt = {}
        for x in body: cnt[x['comp_type']] = cnt.get(x['comp_type'], 0) + 1
        return max(cnt, key=cnt.get)
    def multi_end(ls):
        body = [x for x in ls if not x['is_header']]
        if not body: return False
        try: mk = json.loads(body[-1].get('markers') or '[]')
        except Exception: mk = []
        return sum(1 for x in mk if isinstance(x, str) and x and all('੦' <= c <= '੯' for c in x)) >= 2
    typ = {cid: dtype(ls) for cid, ls in comps.items()}
    mend = {cid: multi_end(ls) for cid, ls in comps.items()}
    if seed not in comps:                                  # defensive fallback
        rs = db().execute(f'SELECT {LINE_COLS} FROM lines WHERE comp_id=? ORDER BY id', (seed,)).fetchall()
        return {'comp_id': seed, 'comp_ids': [seed], 'lines': rows_to_list(rs)}
    i = order.index(seed)
    # Expansion is VAAR-ONLY by design: a Salok-in-Vaar attaches to its concluding Pauri,
    # and a Pauri gathers its preceding Saloks. Every other composition is a self-contained
    # comp (a standard shabad already holds all padas + Rehao in one comp; long composite
    # banis — Gatha, Patti, Dakhni Onkar, cumulative saloks — must NOT be merged across
    # comps, which would over-collect). This makes a runaway scan structurally impossible.
    if typ[seed] in SAL:                                   # salok -> attach following Pauri if a Vaar
        j = i
        while j + 1 < len(order) and typ[order[j]] in SAL and not mend[order[j]] and typ[order[j + 1]] in SAL:
            j += 1
        end = j + 1 if (j + 1 < len(order) and typ[order[j + 1]] == PAU) else i
    else:
        end = i                                            # pauri or self-contained shabad/composition
    if typ[order[end]] == PAU:                             # Vaar: prepend the Pauri's preceding Saloks
        s = end
        while s - 1 >= 0 and typ[order[s - 1]] in SAL:
            s -= 1
        start = s
    else:
        start = i                                          # everything else: the seed comp alone
    unit = set(order[start:end + 1])
    lines = [l for l in win if l['comp_id'] in unit]       # already id-ordered
    for l in lines: l.pop('markers', None)
    return {'comp_id': seed, 'comp_ids': sorted(unit), 'lines': lines}


def _route_meta(p, qs):
    if core._META_CACHE is not None: return core._META_CACHE   # built once; ~50ms join avoided per load
    m = {r['key']: r['value'] for r in db().execute('SELECT * FROM meta')}
    m['db_version'] = m.get('version')          # honest record of the DB build
    m['version'] = core.APP_VERSION or m.get('version')   # footer shows the running code build
    m['built'] = core.APP_BUILT or m.get('built')
    m['commit'] = core.APP_COMMIT
    try:
        m['raags'] = rows_to_list(db().execute('SELECT * FROM raags ORDER BY seq'))
    except sqlite3.OperationalError:
        m['raags'] = rows_to_list(db().execute('SELECT * FROM raags ORDER BY first_ang'))
    m['sections'] = rows_to_list(db().execute('SELECT * FROM sections ORDER BY first_ang'))
    m['authors'] = rows_to_list(db().execute('SELECT * FROM authors ORDER BY n_lines DESC'))
    m['concepts'] = rows_to_list(db().execute(
        'SELECT c.concept, c.description, COUNT(cl.line_id) AS n_lines '
        'FROM concepts c LEFT JOIN concept_lines cl ON cl.concept = c.concept '
        'GROUP BY c.concept, c.description ORDER BY c.concept'))
    try:                                        # raag-timing knowledge layer (additive; absent on older DBs)
        db().execute('SELECT 1 FROM timing_sources LIMIT 1').fetchone()
        m['timing_available'] = True
    except sqlite3.OperationalError:
        m['timing_available'] = False
    try:                                        # Nitnem bani registry (additive; migration 002)
        db().execute('SELECT 1 FROM banis LIMIT 1').fetchone()
        m['banis_available'] = True
    except sqlite3.OperationalError:
        m['banis_available'] = False
    core._META_CACHE = m
    return m
    return _FALLTHROUGH


def _route_ang(p, qs):
    ang = _int_str(p[1], 1, 1430)
    rs = rows_to_list(db().execute(f'SELECT {LINE_COLS} FROM lines WHERE ang = ? ORDER BY id', (ang,)).fetchall())
    continued_from = None
    if rs and not rs[0]['is_header']:
        first = db().execute('SELECT min(ang) FROM lines WHERE comp_id = ?',
                             (rs[0]['comp_id'],)).fetchone()[0]
        if first and first < ang: continued_from = first
    def majority(key):
        c = {}
        for l in rs:
            if l[key]: c[l[key]] = c.get(l[key], 0) + 1
        return max(c, key=c.get) if c else None
    return {'ang': ang, 'lines': attach_translations(rs), 'continued_from': continued_from,
            'raag': majority('raag'), 'section': majority('section'),
            'authors': sorted({l['author'] for l in rs if l['author']})}
    return _FALLTHROUGH


def _route_shabad(p, qs):
    cid = _int_str(p[1], 0, _ID_MAX)
    rs = db().execute(f'SELECT {LINE_COLS} FROM lines WHERE comp_id = ? ORDER BY id', (cid,)).fetchall()
    if not rs:
        raise ApiError(404, f'no composition with comp_id {cid}')
    return {'comp_id': cid, 'lines': attach_translations(rows_to_list(rs))}
    return _FALLTHROUGH


def _route_health(p, qs):
    h = {'version': None, 'checks': {}, 'ok': True}
    def check(name, cond):
        h['checks'][name] = bool(cond)
        if not cond: h['ok'] = False
    m = {k: v for k, v in db().execute('SELECT * FROM meta')}
    h['version'] = core.APP_VERSION or m.get('version')
    h['db_version'] = m.get('version')
    h['built'] = core.APP_BUILT or m.get('built')
    h['commit'] = core.APP_COMMIT
    check('lines_60658', db().execute('SELECT count(*) FROM lines').fetchone()[0] == 60658)
    check('angs_1430', db().execute('SELECT count(DISTINCT ang) FROM lines').fetchone()[0] == 1430)
    check('fts5', m.get('fts5') == '1' and bool(
        db().execute("SELECT rowid FROM fts WHERE fts MATCH 'ਨਾਮੁ' LIMIT 1").fetchone()))
    mm = db().execute('SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1').fetchone()[0]
    check('mool_mantar', mm.startswith('ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ'))
    check('ik_onkar_568', db().execute(
        "SELECT count(*) FROM (SELECT rowid FROM fts WHERE text MATCH 'ੴ')").fetchone()[0] >= 560)
    v = verify_claim('ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ', ang=1, db_path=core.DB)
    check('verify_engine', v['verdict'].startswith('VERIFIED_EXACT'))
    try:                                        # Nitnem registry: Japji is exactly our lines 1..385, in order
        jp = [r[0] for r in db().execute(
            'SELECT bl.line_id FROM bani_lines bl JOIN banis b USING(bani_id) '
            "WHERE b.key='japji' ORDER BY bl.seq")]
        n_extra_en = db().execute(
            "SELECT count(*) FROM pragma_table_info('extra_lines') WHERE name IN ('en','english','translation')"
        ).fetchone()[0]
        check('banis_ok', jp == list(range(1, 386)) and n_extra_en == 0)
    except sqlite3.OperationalError:
        pass                                    # registry absent on older DBs: not a failure
    try:
        h['translations_en'] = db().execute("SELECT count(*) FROM translations WHERE lang='en'").fetchone()[0]
    except sqlite3.OperationalError:
        h['translations_en'] = 0
    return h
    return _FALLTHROUGH


def _route_random(p, qs):
    return hukam_package()                  # complete structural unit, not a comp fragment
    return _FALLTHROUGH


def _route_lines(p, qs):   # /api/lines?ids=1,2,3  (verbatim text by id)
    raw = qs.get('ids', [''])[0]
    ids = [int(x) for x in raw.split(',') if x.strip().isdigit() and len(x.strip()) <= 12][:300]
    rows = []
    if ids:
        ph = ','.join('?' * len(ids))
        rows = rows_to_list(db().execute(
            f"SELECT id, ang, comp_id, gurmukhi, translit FROM lines WHERE id IN ({ph}) ORDER BY id", ids))
    return {'lines': rows, 'note': 'verbatim Gurmukhi by line id, cited by Ang'}
    return _FALLTHROUGH


def _route_banis(p, qs):   # /api/banis — the Nitnem / Gutka registry
    try:
        rows = rows_to_list(db().execute(
            'SELECT key, variant, is_default, title_gm, title_en, category, order_no, '
            'n_lines, n_groups, has_extra, estimated_minutes, description_en, source_label '
            'FROM banis ORDER BY order_no, variant'))
    except sqlite3.OperationalError:
        return {'available': False, 'banis': []}
    return {'available': True, 'banis': rows,
            'note': 'Sri Guru Granth Sahib Ji lines are served from the verbatim corpus and cited by Ang; '
                    'has_extra=1 banis also contain a separate, labelled non-SGGS layer.'}
    return _FALLTHROUGH


def _route_bani(p, qs):   # /api/bani/{key}?variant=
    if len(p) < 2:
        raise ValueError('/api/bani requires a key')
    key = p[1]
    if not _BANI_KEY_RE.match(key):
        raise ValueError('bad bani key')
    variant = qs.get('variant', [''])[0]
    if variant not in _BANI_VARIANTS:
        raise ValueError('bad variant')
    try:
        if variant:
            b = db().execute('SELECT * FROM banis WHERE key=? AND variant=?', (key, variant)).fetchone()
        else:
            b = db().execute('SELECT * FROM banis WHERE key=? AND is_default=1', (key,)).fetchone()
    except sqlite3.OperationalError:
        return {'available': False}
    if not b:
        raise ApiError(404, f'no bani with key {key}')
    b = dict(b)
    variants = [r[0] for r in db().execute(
        'SELECT variant FROM banis WHERE key=? ORDER BY is_default DESC, variant', (key,))]
    rows = db().execute(
        f'SELECT bl.seq, bl.line_group, bl.line_id, bl.extra_id, '
        f'{", ".join("l." + c for c in LINE_COLS.replace(" ", "").split(","))}, l.markers, '
        f'e.source AS extra_source, e.panna, e.gurmukhi AS extra_gurmukhi, e.translit AS extra_translit, '
        f'e.is_header AS extra_is_header '
        f'FROM bani_lines bl LEFT JOIN lines l ON l.id = bl.line_id '
        f'LEFT JOIN extra_lines e ON e.extra_id = bl.extra_id '
        f'WHERE bl.bani_id = ? ORDER BY bl.seq', (b['bani_id'],)).fetchall()
    lines, sggs_rows = [], []
    for r in rows:
        r = dict(r)
        if r['line_id'] is not None:
            d = {k: r[k] for k in LINE_COLS.replace(' ', '').split(',')}
            d['markers'] = r['markers']
            d.update({'seq': r['seq'], 'line_group': r['line_group'], 'source': 'sggs'})
            sggs_rows.append(d)
            lines.append(d)
        else:
            lines.append({'seq': r['seq'], 'line_group': r['line_group'],
                          'source': r['extra_source'], 'extra_id': r['extra_id'],
                          'panna': r['panna'], 'gurmukhi': r['extra_gurmukhi'],
                          'translit': r['extra_translit'], 'is_header': r['extra_is_header'],
                          'is_rahao': 0, 'markers': ''})
    attach_translations(sggs_rows)               # English only ever on SGGS lines
    b.pop('bani_id', None)
    angs = sorted({d['ang'] for d in sggs_rows})
    return {'available': True, 'bani': b, 'variants': variants,
            'ang_first': angs[0] if angs else None, 'ang_last': angs[-1] if angs else None,
            'lines': lines,
            'note': 'source=sggs lines are verbatim Sri Guru Granth Sahib Ji, cited by Ang. '
                    'source=dasam/ardaas lines are a separate layer (Sri Dasam Granth / Ardaas via ShabadOS), '
                    'not part of Sri Guru Granth Sahib Ji.'}
    return _FALLTHROUGH
