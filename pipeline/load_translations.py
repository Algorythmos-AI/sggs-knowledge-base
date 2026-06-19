# -*- coding: utf-8 -*-
"""Align fetched translation pairs (gurmukhi -> english) to corpus line_ids and
load them into the translations table. Translations are NEVER scripture: stored
in a separate table with source attribution, displayed labeled and subordinate.

Usage: python3 load_translations.py <db_path> <pairs.jsonl ...>
Pair format per line: {"ang": N, "gurmukhi": "...", "en": "..."}
"""
import sys, json, sqlite3, unicodedata, re, difflib, glob

DB = sys.argv[1]
SOURCE_ID = 'ssk-banidb'
args = sys.argv[2:]
if args and args[0].startswith('--source='):
    SOURCE_ID = args[0].split('=', 1)[1]; args = args[1:]
files = []
for pat in args:
    files += glob.glob(pat)

con = sqlite3.connect(DB)
cur = con.cursor()
cur.executescript('''
CREATE TABLE IF NOT EXISTS translations(
  line_id INT, lang TEXT, source TEXT, text TEXT, match_quality TEXT,
  PRIMARY KEY(line_id, lang));
CREATE TABLE IF NOT EXISTS sources(
  source_id TEXT PRIMARY KEY, kind TEXT, attribution TEXT, license TEXT, ingest_date TEXT);
INSERT OR REPLACE INTO sources VALUES(
  'ssk-banidb', 'translation-en',
  'English translation by Dr. Sant Singh Khalsa, sourced via BaniDB (banidb.com)',
  'Personal, local, non-commercial use with attribution', date('now'));
INSERT OR REPLACE INTO sources VALUES(
  'ssk-shabados', 'translation-en',
  'English translation by Dr. Sant Singh Khalsa, via the ShabadOS open database (github.com/shabados/database, release 4.8.7)',
  'Open data with attribution; translation author attribution required', date('now'));
''')

MATRAS = 'ਾਿੀੁੂੇੈੋੌ੍ੰਂਃ਼ੱੑੵ'
def norm(s):
    s = unicodedata.normalize('NFC', s)
    s = re.sub(r'[॥।|੦-੯\s]+', ' ', s).strip()
    s = re.sub(r'( ਰਹਾਉ( ਦੂਜਾ)?)+$', '', s)   # refrain label = marker, not verse text
    return s
def skel(s):
    return re.sub('[' + MATRAS + ' ]', '', norm(s))

# corpus lines per ang
lines_by_ang = {}
for lid, ang, text in cur.execute('SELECT id, ang, text FROM lines'):
    lines_by_ang.setdefault(ang, []).append((lid, norm(text), skel(text)))

stats = {'exact': 0, 'skeleton': 0, 'fuzzy': 0, 'unmatched': 0, 'empty': 0}
unmatched = []
rows = []
seen_ids = set()
for f in files:
    for raw in open(f, encoding='utf-8'):
        raw = raw.strip()
        if not raw: continue
        try: p = json.loads(raw)
        except json.JSONDecodeError: continue
        g, en, ang = p.get('gurmukhi', ''), (p.get('en') or '').strip(), p.get('ang')
        if not g or not en: stats['empty'] += 1; continue
        gn, gs = norm(g), skel(g)
        cands = []
        for a in (ang, ang - 1, ang + 1):
            cands += lines_by_ang.get(a, [])
        lid = quality = None
        for c_lid, c_n, c_s in cands:
            if c_n == gn: lid, quality = c_lid, 'exact'; break
        if lid is None:
            sk_hits = [c_lid for c_lid, c_n, c_s in cands if c_s == gs and gs]
            if len(sk_hits) == 1: lid, quality = sk_hits[0], 'skeleton'
        if lid is None and cands:
            best = max(cands, key=lambda c: difflib.SequenceMatcher(None, gn, c[1]).ratio())
            r = difflib.SequenceMatcher(None, gn, best[1]).ratio()
            if r >= 0.92: lid, quality = best[0], 'fuzzy'
        if lid is None:
            stats['unmatched'] += 1; unmatched.append((ang, g[:50])); continue
        if lid in seen_ids: continue
        seen_ids.add(lid)
        stats[quality] += 1
        rows.append((lid, 'en', SOURCE_ID, en, quality))

cur.executemany('INSERT OR REPLACE INTO translations VALUES(?,?,?,?,?)', rows)
# Record the TOTAL en rows in the table, not just this batch — rebuild_all.sh calls
# load_translations twice, and writing len(rows) made the 2nd (small) call clobber the
# count via INSERT OR REPLACE. Derive from the table so the count is always the true total.
total_en = cur.execute("SELECT count(*) FROM translations WHERE lang='en'").fetchone()[0]
cur.execute("INSERT OR REPLACE INTO meta VALUES('translations_en', ?)", (str(total_en),))
con.commit(); con.close()
print(f'loaded {len(rows)} translations | match quality: {stats}')
for u in unmatched[:10]: print('  unmatched:', u)
