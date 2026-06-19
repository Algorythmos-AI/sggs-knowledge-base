# -*- coding: utf-8 -*-
"""Phase C: corpus/sggs.jsonl -> db/sggs.db (SQLite + FTS5) + readable Markdown."""
import sys, json, sqlite3, os, collections, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sggs_pipeline import roman_norm, translit_line

def _app_version():
    """Single-source the DB build version from webapp/serve.py:APP_VERSION so the
    DB's db_version tracks the release it was built for (no stale hardcode)."""
    try:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'webapp', 'serve.py')
        m = re.search(r"APP_VERSION\s*=\s*'([^']+)'", open(p, encoding='utf-8').read())
        return m.group(1) if m else '0.0.0'
    except Exception:
        return '0.0.0'

JSONL, DB = sys.argv[1], sys.argv[2]
rows = [json.loads(l) for l in open(JSONL, encoding='utf-8')]
for r in rows:
    r['translit_norm'] = roman_norm(r['translit'])
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)
cur = con.cursor()
cur.executescript('''
CREATE TABLE lines(
  id INTEGER PRIMARY KEY, ang INT, pdf_page INT, raag TEXT, section TEXT,
  author TEXT, comp_type TEXT, ghar TEXT, comp_id INT, line_no INT,
  is_rahao INT, is_header INT, markers TEXT,
  gurmukhi TEXT, text TEXT, translit TEXT, translit_norm TEXT,
  fl_g TEXT, fl_r TEXT, skeleton TEXT);
CREATE INDEX idx_ang ON lines(ang);
CREATE INDEX idx_raag ON lines(raag);
CREATE INDEX idx_author ON lines(author);
CREATE INDEX idx_comp ON lines(comp_id);
CREATE TABLE raags(name TEXT PRIMARY KEY, first_ang INT, last_ang INT,
                   n_lines INT, n_shabads INT, roman TEXT, seq INT);
CREATE TABLE sections(name TEXT PRIMARY KEY, first_ang INT, last_ang INT, n_lines INT);
CREATE TABLE authors(name TEXT PRIMARY KEY, first_ang INT, last_ang INT, n_lines INT);
CREATE TABLE word_freq(word TEXT PRIMARY KEY, n INT);
CREATE TABLE concepts(concept TEXT PRIMARY KEY, gurmukhi_terms TEXT, description TEXT);
CREATE TABLE concept_lines(concept TEXT, line_id INT, term TEXT);
CREATE INDEX idx_cl ON concept_lines(concept);
CREATE INDEX idx_cl_line ON concept_lines(line_id);  -- Constellation co-theme self-join (co.line_id=cl.line_id); without it large concepts (e.g. satguru, 6319 verses) hang
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
''')
GM_MARKS = 'ਾਿੀੁੂੇੈੋੌ੍ੰਂਃ਼ੱੑੵ'
try:
    cur.execute(f'''CREATE VIRTUAL TABLE fts USING fts5(
        text, translit, translit_norm, fl_g, fl_r, skeleton,
        content='lines', content_rowid='id',
        tokenize="unicode61 tokenchars '{GM_MARKS}ੴ'")''')
    HAVE_FTS = True
except sqlite3.OperationalError as e:
    print('FTS5 unavailable:', e); HAVE_FTS = False

cur.executemany('''INSERT INTO lines VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
    [(r['id'], r['ang'], r['pdf_page'], r['raag'], r['section'], r['author'],
      r['comp_type'], r['ghar'], r['comp_id'], r['line_no'], r['is_rahao'],
      r['is_header'], json.dumps(r['markers'], ensure_ascii=False),
      r['gurmukhi'], r['text'], r['translit'], r['translit_norm'],
      r['fl_g'], r['fl_r'], r['skeleton'])
     for r in rows])
if HAVE_FTS:
    cur.execute("INSERT INTO fts(fts) VALUES('rebuild')")

# --- aggregates
def spans(field):
    agg = collections.defaultdict(lambda: [10**9, 0, 0])
    for r in rows:
        v = r[field]
        if v:
            a = agg[v]; a[0] = min(a[0], r['ang']); a[1] = max(a[1], r['ang']); a[2] += 1
    return agg
for tbl, field in [('sections', 'section'), ('authors', 'author')]:
    for name, (a, b, n) in spans(field).items():
        cur.execute(f'INSERT INTO {tbl} VALUES(?,?,?,?)', (name, a, b, n))

# --- raags: the TRUE span is the longest contiguous run of Angs where the raag
#     is that Ang's majority raag. Liturgy occurrences (a ਗੂਜਰੀ shabad inside
#     So Purakh on Ang 10) must not drag Gujri's start from 489 to 10.
ang_votes = collections.defaultdict(collections.Counter)
for r in rows:
    if r['raag']:
        ang_votes[r['ang']][r['raag']] += 1
majority = {ang: c.most_common(1)[0][0] for ang, c in ang_votes.items()}
raag_angs = collections.defaultdict(list)
for ang in sorted(majority):
    raag_angs[majority[ang]].append(ang)
def longest_run(angs):
    best = cur_run = (angs[0], angs[0])
    for a in angs[1:]:
        cur_run = (cur_run[0], a) if a <= cur_run[1] + 1 else (a, a)
        if cur_run[1] - cur_run[0] >= best[1] - best[0]: best = cur_run
    return best
raag_seq = []
for name, angs in raag_angs.items():
    fa, la = longest_run(angs)
    raag_seq.append((fa, la, name))
for seq, (fa, la, name) in enumerate(sorted(raag_seq), 1):
    n_lines = sum(1 for r in rows if r['raag'] == name and fa <= r['ang'] <= la)
    n_shabads = len({r['comp_id'] for r in rows
                     if r['raag'] == name and fa <= r['ang'] <= la and r['is_header']})
    cur.execute('INSERT INTO raags VALUES(?,?,?,?,?,?,?)',
                (name, fa, la, n_lines, n_shabads, translit_line(name), seq))

# --- word concordance (mechanical; concept index added in Phase D)
wf = collections.Counter()
for r in rows:
    if r['is_header']: continue
    for w in r['text'].split():
        if w and not all(ch in '੦੧੨੩੪੫੬੭੮੯' for ch in w):
            wf[w] += 1
cur.executemany('INSERT INTO word_freq VALUES(?,?)', wf.items())
cur.execute('INSERT INTO meta VALUES(?,?)', ('total_lines', str(len(rows))))
cur.execute('INSERT INTO meta VALUES(?,?)', ('total_angs', '1430'))
cur.execute('INSERT INTO meta VALUES(?,?)', ('distinct_words', str(len(wf))))
cur.execute('INSERT INTO meta VALUES(?,?)', ('edition', 'Siri Guru Granth Sahib in Gurmukhi with Index (user PDF, 1483 pp)'))
cur.execute('INSERT INTO meta VALUES(?,?)', ('fts5', '1' if HAVE_FTS else '0'))
import datetime
cur.execute('INSERT INTO meta VALUES(?,?)', ('version', _app_version()))   # was hardcoded '1.4.0'; now tracks webapp/serve.py:APP_VERSION
cur.execute('INSERT INTO meta VALUES(?,?)', ('built', datetime.date.today().isoformat()))
con.commit()

# --- human-readable corpus, one file per raag/section
outdir = os.path.join(os.path.dirname(JSONL), 'by-raag')
os.makedirs(outdir, exist_ok=True)
groups = collections.defaultdict(list)
for r in rows:
    key = r['raag'] or r['section'] or 'ਹੋਰ'
    groups[key].append(r)
for i, (key, rs) in enumerate(sorted(groups.items(), key=lambda kv: kv[1][0]['ang'])):
    safe = re.sub(r'[^਀-੿A-Za-z0-9]+', '-', key).strip('-') or 'misc'
    with open(os.path.join(outdir, f'{i:02d}-{safe}.md'), 'w', encoding='utf-8') as f:
        f.write(f'# {key}  (Angs {rs[0]["ang"]}–{rs[-1]["ang"]}, {len(rs)} lines)\n\n')
        cur_ang = None
        for r in rs:
            if r['ang'] != cur_ang:
                cur_ang = r['ang']; f.write(f'\n## Ang {cur_ang}\n\n')
            tag = ' **[ਰਹਾਉ]**' if r['is_rahao'] else (' *(header)*' if r['is_header'] else '')
            f.write(f'{r["gurmukhi"]}{tag}\n*{r["translit"]}*\n\n')
print(f'db: {len(rows)} lines, fts5={HAVE_FTS}, words={len(wf)}, groups={len(groups)}')

# smoke queries
q = lambda sql, *p: cur.execute(sql, p).fetchall()
print('Ang 1 first line:', q("SELECT gurmukhi FROM lines WHERE ang=1 ORDER BY id LIMIT 1")[0][0][:60])
if HAVE_FTS:
    print('fts ਨਾਮੁ hits:', q("SELECT count(*) FROM fts WHERE fts MATCH 'ਨਾਮੁ'")[0][0])
    print('fts translit "saadh sang*" hits:', q("SELECT count(*) FROM fts WHERE translit MATCH 'saadh AND sang'")[0][0])
    print('fts first-letter \"ਧ ਧ ਰ ਗ\":', q('SELECT count(*) FROM fts WHERE fl_g MATCH ?', '"ਧ ਧ ਰ ਗ"')[0][0])
con.close()
