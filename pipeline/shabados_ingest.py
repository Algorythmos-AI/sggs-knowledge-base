# -*- coding: utf-8 -*-
"""Extract the full SGGS English layer (Dr. Sant Singh Khalsa) from a ShabadOS
database.sqlite. Their Gurmukhi is stored in AnmolLipi-style ASCII with embedded
vishraam marks; we convert to Unicode, reuse the proven fix_text() pipeline for
logical ordering, and validate every converted line against OUR corpus.

Usage: python3 shabados_ingest.py <shabados.db> <our_corpus.jsonl> <out.jsonl>
"""
import sys, json, sqlite3, re, unicodedata, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from sggs_pipeline import CONS, HALANT

def move_sihari(s):
    """ASCII sources put sihari before its consonant (visual order); their
    subjoined consonants are already logical — so ONLY the sihari moves."""
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == 'ਿ':
            j = i + 1
            if j < n and s[j] in CONS:
                j += 1
                while j + 1 < n and s[j] == HALANT and s[j+1] in CONS:
                    j += 2
                out.append(s[i+1:j]); out.append('ਿ')
                i = j; continue
        out.append(c); i += 1
    return ''.join(out)

SHA, CORPUS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

# AnmolLipi / GurbaniAkhar ASCII -> Unicode Gurmukhi
# Ordered: independent vowels are composed from parts in the ASCII encoding
# (Aw=ਆ, au=ਉ, ie=ਇ …) and must be replaced before single-char mapping.
DIGRAPHS = dict([('<>', 'ੴ'), ('AW', 'ਆਂ'), ('Aw', 'ਆ'), ('AY', 'ਐ'), ('AO', 'ਔ'),
                 ('aU', 'ਊ'), ('au', 'ਉ'), ('eI', 'ਈ'), ('ey', 'ਏ'), ('ie', 'ਇ')])
MAP = {
 'a':'ੳ','A':'ਅ','e':'ੲ','s':'ਸ','h':'ਹ',
 'k':'ਕ','K':'ਖ','g':'ਗ','G':'ਘ','|':'ਙ',
 'c':'ਚ','C':'ਛ','j':'ਜ','J':'ਝ','\\':'ਞ',
 't':'ਟ','T':'ਠ','f':'ਡ','F':'ਢ','x':'ਣ',
 'q':'ਤ','Q':'ਥ','d':'ਦ','D':'ਧ','n':'ਨ',
 'p':'ਪ','P':'ਫ','b':'ਬ','B':'ਭ','m':'ਮ',
 'X':'ਯ','r':'ਰ','l':'ਲ','v':'ਵ','V':'ੜ',
 'E':'ਓ','S':'ਸ਼','z':'ਜ਼','Z':'ਗ਼','^':'ਖ਼','&':'ਫ਼','L':'ਲ਼',
 'w':'ਾ','i':'ਿ','I':'ੀ','u':'ੁ','U':'ੂ','y':'ੇ','Y':'ੈ','o':'ੋ','O':'ੌ',
 'W':'ਾਂ','M':'ੰ','µ':'ੰ','N':'ਂ','ˆ':'ਂ','Ú':'ਃ','@':'ੑ','~':'ੱ','`':'ੱ',
 'R':'੍ਰ','®':'੍ਰ','H':'੍ਹ','Í':'੍ਵ','´':'੍ਯ','Î':'੍ਯ','ç':'੍ਚ','†':'੍ਟ','œ':'੍ਤ','˜':'੍ਨ',
 'ü':'ੁ','¨':'ੂ','Ø':'',          # Ø = glyph-positioning helper before subjoined ਯ
 ']':'॥','[':'।',
 '0':'੦','1':'੧','2':'੨','3':'੩','4':'੪','5':'੫','6':'੬','7':'੭','8':'੮','9':'੯',
 ' ':' ',
 ';':'',',':'','.':'',             # vishraam pause marks — not scripture text
 '₁':'','₂':'','₃':'','₄':'','₅':'','₆':'','₈':'',   # footnote subscripts
}

unknown = collections.Counter()
PASSTHROUGH = set('ੴਆਉਊਇਈਏਐਔ') | {'ਾ', 'ਂ'}   # produced by DIGRAPHS
# our edition writes without nukta/addak/udaat — fold for alignment keys
FOLD = {'ਸ਼':'ਸ','ਖ਼':'ਖ','ਗ਼':'ਗ','ਜ਼':'ਜ','ਫ਼':'ਫ','ਲ਼':'ਲ','ੱ':'','ੑ':''}
def to_unicode(ascii_g):
    s = ascii_g
    for a, b in DIGRAPHS.items(): s = s.replace(a, b)
    out = []
    for ch in s:
        if ch in PASSTHROUGH: out.append(ch)
        elif ch in MAP: out.append(MAP[ch])
        else: unknown[ch] += 1
    u = ''.join(out)
    for a, b in FOLD.items(): u = u.replace(a, b)
    u = move_sihari(u)
    u = unicodedata.normalize('NFC', u)
    return re.sub(r'\s+', ' ', u).strip()

NORM_STRIP = re.compile(r'[॥।\s੦-੯]+')
RAHAO_STRIP = re.compile(r'ਰਹਾਉ(ਦੂਜਾ)?$')
def norm(s):
    s = NORM_STRIP.sub('', unicodedata.normalize('NFC', s))
    return RAHAO_STRIP.sub('', s)     # refrain label is a marker, not verse text

# our corpus, normalized per ang
ours = collections.defaultdict(set)
for raw in open(CORPUS, encoding='utf-8'):
    r = json.loads(raw)
    ours[r['ang']].add(norm(r['text']))

con = sqlite3.connect(f'file:{SHA}?mode=ro', uri=True)
cur = con.cursor()
rows = cur.execute("""
    SELECT l.source_page, l.gurmukhi, t.translation
    FROM lines l
    JOIN shabads s ON l.shabad_id = s.id
    JOIN translations t ON t.line_id = l.id
    WHERE s.source_id = 1 AND t.translation_source_id = 1
    ORDER BY l.order_id""").fetchall()
con.close()

stats = collections.Counter()
out_f = open(OUT, 'w', encoding='utf-8')
mismatch_sample = []
for ang, ag, en in rows:
    en = (en or '').strip()
    if not en: stats['no_en'] += 1; continue
    u = to_unicode(ag)
    if norm(u) in ours.get(ang, ()) or norm(u) in ours.get(ang - 1, ()) or norm(u) in ours.get(ang + 1, ()):
        stats['exact_vs_ours'] += 1
    else:
        stats['differs_from_ours'] += 1
        if len(mismatch_sample) < 12: mismatch_sample.append((ang, ag[:40], u[:40]))
    out_f.write(json.dumps({'ang': ang, 'gurmukhi': u, 'en': en}, ensure_ascii=False) + '\n')
out_f.close()

total = stats['exact_vs_ours'] + stats['differs_from_ours']
print(f"converted {total} lines | exact match vs our corpus: {stats['exact_vs_ours']} "
      f"({100*stats['exact_vs_ours']/max(total,1):.2f}%) | differs: {stats['differs_from_ours']}")
print('unknown ascii chars:', dict(unknown.most_common(15)) or 'NONE')
for m in mismatch_sample: print('  differs:', m)
