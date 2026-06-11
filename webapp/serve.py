#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sri Guru Granth Sahib — local search app.
Zero dependencies: Python 3 standard library only.

Run:   python3 serve.py        then open  http://localhost:7777
"""
import json, os, re, sqlite3, random, sys, threading, webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, '..', 'db', 'sggs.sqlite')
PORT = int(os.environ.get('SGGS_PORT', '7777'))

import sys as _sys
_sys.path.insert(0, HERE)
from verify import verify as verify_claim     # Layer-3: quotation verification engine

GURMUKHI = re.compile('[਀-੿]')
_local = threading.local()

def roman_norm(s):
    """Spelling-tolerant Roman normal form: 'waheguru' & 'vaahiguroo' -> 'vhgr'."""
    out = []
    for w in s.lower().split():
        w = w.replace('w', 'v').replace('f', 'ph')
        head = w[0] if w[0] in 'aeiou' else ''
        body = re.sub('[aeiou]', '', w)
        out.append((head + body) if (head + body) else w)
    return ' '.join(out)

def db():
    if not hasattr(_local, 'con'):
        _local.con = sqlite3.connect(f'file:{DB}?mode=ro&immutable=1', uri=True)
        _local.con.row_factory = sqlite3.Row
    return _local.con

def have_fts():
    try:
        db().execute("SELECT count(*) FROM fts WHERE fts MATCH 'ਨਾਮੁ'").fetchone()
        return True
    except sqlite3.OperationalError:
        return False

HAVE_FTS = None
LINE_COLS = ('id, ang, raag, section, author, comp_type, comp_id, line_no, '
             'is_rahao, is_header, gurmukhi, translit')

def rows_to_list(rs):
    return [dict(r) for r in rs]

def fts_query(tokens, phrase=False):
    toks = [t.replace('"', '') for t in tokens if t.replace('"', '')]
    if not toks: return None
    if phrase: return '"' + ' '.join(toks) + '"'
    return ' AND '.join(f'"{t}"' for t in toks)

def search_fts(col, q, phrase, limit, offset):
    m = fts_query(q.split(), phrase)
    if not m: return []
    # BM25 relevance ranking; column weights: text, translit, translit_norm, fl_g, fl_r, skeleton
    sql = (f"SELECT {LINE_COLS} FROM lines JOIN "
           f"(SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk "
           f" FROM fts WHERE {col} MATCH ?) m ON lines.id = m.rowid "
           f"ORDER BY m.rk, lines.id LIMIT ? OFFSET ?")
    try:
        return rows_to_list(db().execute(sql, (m, limit, offset)).fetchall())
    except sqlite3.OperationalError:      # very old SQLite without bm25(): fall back
        sql = (f"SELECT {LINE_COLS} FROM lines WHERE id IN "
               f"(SELECT rowid FROM fts WHERE {col} MATCH ?) ORDER BY id LIMIT ? OFFSET ?")
        return rows_to_list(db().execute(sql, (m, limit, offset)).fetchall())

_TERM2CONCEPT = None
def term_concepts(tokens):
    """Map any query token to its theme(s) — the corpus-verified concept index."""
    global _TERM2CONCEPT
    if _TERM2CONCEPT is None:
        _TERM2CONCEPT = {}
        for name, terms in db().execute('SELECT concept, gurmukhi_terms FROM concepts'):
            for t in json.loads(terms):
                _TERM2CONCEPT.setdefault(t, []).append(name)
    hits = []
    for t in tokens:
        for c in _TERM2CONCEPT.get(t, ()):
            if c not in hits: hits.append(c)
    return hits

def search_like(col, q, limit, offset):
    pat = '%' + '%'.join(q.split()) + '%'
    sql = f"SELECT {LINE_COLS} FROM lines WHERE {col} LIKE ? ORDER BY id LIMIT ? OFFSET ?"
    return rows_to_list(db().execute(sql, (pat, limit, offset)).fetchall())

def do_search(q, mode, limit, offset):
    q = q.strip()
    if not q: return {'mode': mode, 'results': []}
    global HAVE_FTS
    if HAVE_FTS is None: HAVE_FTS = have_fts()
    toks = q.split()
    is_gurmukhi = bool(GURMUKHI.search(q))

    def run(col, phrase=False):
        if HAVE_FTS: return search_fts(col, q, phrase, limit, offset)
        return search_like('text' if col == 'text' else col, q, limit, offset)

    # explicit modes
    if mode == 'gurmukhi':
        res = run('text'); used = 'gurmukhi'
        if not res and HAVE_FTS:
            res = search_like('skeleton', re.sub('[ਾਿੀੁੂੇੈੋੌੰਂ੍]', '', q), limit, offset); used = 'gurmukhi-skeleton'
    elif mode == 'roman':
        res = run('translit'); used = 'roman'
        if not res and HAVE_FTS:
            res = search_fts('translit_norm', roman_norm(q), False, limit, offset)
            used = 'roman-spelling-tolerant'
    elif mode == 'first':
        col = 'fl_g' if is_gurmukhi else 'fl_r'
        res = run(col, phrase=True); used = 'first-letters'
    elif mode == 'theme':
        return theme_search(q, limit, offset)
    else:  # auto
        if is_gurmukhi:
            single_letters = all(len(t) == 1 for t in toks) and len(toks) >= 2
            if single_letters:
                res = run('fl_g', phrase=True); used = 'first-letters'
            else:
                res = run('text'); used = 'gurmukhi'
                if not res:
                    res = search_like('skeleton', re.sub('[ਾਿੀੁੂੇੈੋੌੰਂ੍]', '', q), limit, offset); used = 'gurmukhi-skeleton'
        else:
            ql = q.lower()
            cpt = db().execute('SELECT concept FROM concepts WHERE concept = ?', (ql,)).fetchone()
            if cpt:
                return theme_search(ql, limit, offset)
            if all(len(t) <= 3 for t in toks) and len(toks) >= 2:
                res = run('fl_r', phrase=True); used = 'first-letters'
                if not res:
                    res = run('translit'); used = 'roman'
            else:
                res = run('translit'); used = 'roman'
            if not res and HAVE_FTS:
                res = search_fts('translit_norm', roman_norm(q), False, limit, offset)
                used = 'roman-spelling-tolerant'
            if not res and len(toks) == 1:
                t = theme_search(q, limit, offset)
                if t['results']: return t
    out = {'mode': used, 'results': res}
    if is_gurmukhi:
        rel = term_concepts(toks)
        if rel: out['related_themes'] = rel[:3]
    return out

def theme_search(q, limit, offset):
    ql = q.strip().lower()
    row = db().execute('SELECT concept, gurmukhi_terms, description FROM concepts WHERE concept = ?', (ql,)).fetchone()
    if not row:
        like = f'%{ql}%'
        row = db().execute('SELECT concept, gurmukhi_terms, description FROM concepts WHERE concept LIKE ? OR description LIKE ?',
                           (like, like)).fetchone()
    if not row: return {'mode': 'theme', 'results': [], 'concept': None}
    rs = db().execute(
        f"SELECT {LINE_COLS}, cl.term AS matched_term FROM concept_lines cl "
        f"JOIN lines ON lines.id = cl.line_id WHERE cl.concept = ? "
        f"ORDER BY lines.id LIMIT ? OFFSET ?", (row['concept'], limit, offset)).fetchall()
    n = db().execute('SELECT count(*) FROM concept_lines WHERE concept = ?', (row['concept'],)).fetchone()[0]
    return {'mode': 'theme', 'concept': {'name': row['concept'], 'terms': json.loads(row['gurmukhi_terms']),
            'description': row['description'], 'total': n}, 'results': rows_to_list(rs)}

def attach_translations(lines):
    """Merge labeled English translations (separate table; never scripture)."""
    if not lines: return lines
    try:
        ids = [l['id'] for l in lines]
        qmarks = ','.join('?' * len(ids))
        tr = dict(db().execute(
            f"SELECT line_id, text FROM translations WHERE lang='en' AND line_id IN ({qmarks})",
            ids).fetchall())
        for l in lines:
            if l['id'] in tr: l['en'] = tr[l['id']]
    except sqlite3.OperationalError:
        pass                                   # older DB without translations table
    return lines

def api(path, qs):
    p = [x for x in path.split('/') if x][1:]   # drop 'api'
    if p[0] == 'meta':
        m = {r['key']: r['value'] for r in db().execute('SELECT * FROM meta')}
        try:
            m['raags'] = rows_to_list(db().execute('SELECT * FROM raags ORDER BY seq'))
        except sqlite3.OperationalError:
            m['raags'] = rows_to_list(db().execute('SELECT * FROM raags ORDER BY first_ang'))
        m['sections'] = rows_to_list(db().execute('SELECT * FROM sections ORDER BY first_ang'))
        m['authors'] = rows_to_list(db().execute('SELECT * FROM authors ORDER BY n_lines DESC'))
        m['concepts'] = rows_to_list(db().execute('SELECT concept, description FROM concepts ORDER BY concept'))
        return m
    if p[0] == 'search':
        q = qs.get('q', [''])[0]
        return do_search(q, qs.get('mode', ['auto'])[0],
                         min(int(qs.get('limit', ['50'])[0]), 200), int(qs.get('offset', ['0'])[0]))
    if p[0] == 'ang':
        ang = max(1, min(1430, int(p[1])))
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
    if p[0] == 'shabad':
        cid = int(p[1])
        rs = db().execute(f'SELECT {LINE_COLS} FROM lines WHERE comp_id = ? ORDER BY id', (cid,)).fetchall()
        return {'comp_id': cid, 'lines': attach_translations(rows_to_list(rs))}
    if p[0] == 'health':
        h = {'version': None, 'checks': {}, 'ok': True}
        def check(name, cond):
            h['checks'][name] = bool(cond)
            if not cond: h['ok'] = False
        m = {k: v for k, v in db().execute('SELECT * FROM meta')}
        h['version'] = m.get('version')
        check('lines_60658', db().execute('SELECT count(*) FROM lines').fetchone()[0] == 60658)
        check('angs_1430', db().execute('SELECT count(DISTINCT ang) FROM lines').fetchone()[0] == 1430)
        check('fts5', m.get('fts5') == '1' and bool(
            db().execute("SELECT rowid FROM fts WHERE fts MATCH 'ਨਾਮੁ' LIMIT 1").fetchone()))
        mm = db().execute('SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1').fetchone()[0]
        check('mool_mantar', mm.startswith('ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ'))
        check('ik_onkar_568', db().execute(
            "SELECT count(*) FROM (SELECT rowid FROM fts WHERE text MATCH 'ੴ')").fetchone()[0] >= 560)
        v = verify_claim('ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ', ang=1, db_path=DB)
        check('verify_engine', v['verdict'].startswith('VERIFIED_EXACT'))
        try:
            h['translations_en'] = db().execute("SELECT count(*) FROM translations WHERE lang='en'").fetchone()[0]
        except sqlite3.OperationalError:
            h['translations_en'] = 0
        return h
    if p[0] == 'random':
        row = db().execute('SELECT comp_id FROM lines WHERE is_header = 0 ORDER BY RANDOM() LIMIT 1').fetchone()
        rs = db().execute(f'SELECT {LINE_COLS} FROM lines WHERE comp_id = ? ORDER BY id', (row['comp_id'],)).fetchall()
        return {'comp_id': row['comp_id'], 'lines': rows_to_list(rs)}
    if p[0] == 'verify':
        q = qs.get('q', [''])[0].strip()
        if not q: raise ValueError('empty claim')
        ang_q = qs.get('ang', [None])[0]
        ang_n = int(ang_q) if ang_q else None
        return verify_claim(q, ang=ang_n, db_path=DB)
    if p[0] == 'word':
        w = qs.get('w', [''])[0].strip()
        n = db().execute('SELECT n FROM word_freq WHERE word = ?', (w,)).fetchone()
        rs = db().execute(f"SELECT {LINE_COLS} FROM lines WHERE id IN "
                          f"(SELECT rowid FROM fts WHERE text MATCH ?) ORDER BY id LIMIT 100",
                          (f'"{w}"',)).fetchall() if HAVE_FTS else []
        return {'word': w, 'count': n['n'] if n else 0, 'lines': rows_to_list(rs)}
    raise ValueError('unknown endpoint')

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _respond(self, status, body, ct):
        self.send_response(status)
        self.send_header('Content-Type', ct)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def _handle(self):
        u = urlparse(self.path)
        if u.path == '/favicon.ico':
            return self._respond(404, b'', 'image/x-icon')
        try:
            if u.path.startswith('/api/'):
                body = json.dumps(api(u.path, parse_qs(u.query)), ensure_ascii=False).encode()
                return self._respond(200, body, 'application/json; charset=utf-8')
            with open(os.path.join(HERE, 'static', 'index.html'), 'rb') as f:
                return self._respond(200, f.read(), 'text/html; charset=utf-8')
        except (ValueError, IndexError) as e:           # bad ang/shabad/params
            msg = json.dumps({'error': 'invalid request: ' + str(e)}).encode()
            return self._respond(400, msg, 'application/json')
        except Exception as e:
            import sys, traceback
            traceback.print_exc(file=sys.stderr)        # visible in server log
            try:                                        # drop a possibly-broken DB handle
                if hasattr(_local, 'con'): _local.con.close(); del _local.con
            except Exception: pass
            msg = json.dumps({'error': type(e).__name__ + ': ' + str(e)}).encode()
            return self._respond(500, msg, 'application/json')

    def do_GET(self): self._handle()
    def do_HEAD(self): self._handle()

if __name__ == '__main__':
    global_fts = None
    if not os.path.exists(DB):
        sys.exit(f'Database not found: {DB}\nRun the pipeline first (see ../01_Production-Architecture.md).')
    HAVE_FTS = None
    srv = ThreadingHTTPServer(('127.0.0.1', PORT), H)
    url = f'http://localhost:{PORT}'
    print(f'ੴ  SGGS Knowledge Base serving at {url}   (Ctrl-C to stop)')
    try: threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    except Exception: pass
    try: srv.serve_forever()
    except KeyboardInterrupt: print('\nstopped.')
