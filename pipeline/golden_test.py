# -*- coding: utf-8 -*-
"""Golden-Ang proof of the extraction pipeline. Nothing scales until this passes."""
import sys, fitz
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from sggs_pipeline import fix_text, translit_line, first_letters, page_content, segment_units, detect_header

PDF = sys.argv[1]
doc = fitz.open(PDF)
FAIL = []

def check(name, got, want):
    ok = got == want
    print(('PASS' if ok else 'FAIL'), name)
    if not ok:
        print('   got :', repr(got)); print('   want:', repr(want)); FAIL.append(name)

# ---- 1. unit corrections on raw extracted words (proven evidence set)
for raw, want in [('ਸਿਤ', 'ਸਤਿ'), ('ਿਨਰਭਉ', 'ਨਿਰਭਉ'), ('ਪਰ੍ਸਾਿਦ', 'ਪ੍ਰਸਾਦਿ'),
                  ('ਅੰਿਮਰ੍ਤੁ', 'ਅੰਮ੍ਰਿਤੁ'), ('ਿਕਰ੍ਪਾ', 'ਕ੍ਰਿਪਾ'), ('ਿਤਨ¸ਾ', 'ਤਿਨ੍ਹਾ'),
                  ('ਪਿੜ¸', 'ਪੜ੍ਹਿ'), ('ਸÂਿਤ', 'ਸਾਂਤਿ'), ('੧ਓ', 'ੴ'),
                  ('ਿਲਿਖਆ', 'ਲਿਖਿਆ'), ('ਪਾਰਬਰ੍ਹਮੁ', 'ਪਾਰਬ੍ਰਹਮੁ'), ('ਿਮਤਰ੍ਾ', 'ਮਿਤ੍ਰਾ')]:
    got, _ = fix_text(raw)
    check(f'fix {raw!r}', got, want)

# ---- 2. Ang map invariants
for pno, want_ang in [(53, 1), (54, 2), (759, 707), (1482, 1430)]:
    ang, _ = page_content(doc, pno)
    check(f'pdf_page {pno+1} -> Ang {want_ang}', ang, want_ang)

# ---- 3. Mool Mantar exact (Ang 1) — character-for-character
ang, raw = page_content(doc, 53)
fixed, anom = fix_text(raw)
units, frag = segment_units(fixed)
mm = units[0]['text']
check('Mool Mantar verbatim', mm,
      'ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ ਅਜੂਨੀ ਸੈਭੰ ਗੁਰ ਪ੍ਰਸਾਦਿ')
check('Japji title unit', units[1]['text'], 'ਜਪੁ')
check('Aad sach unit', units[2]['text'], 'ਆਦਿ ਸਚੁ ਜੁਗਾਦਿ ਸਚੁ')
check('Hosee bhee sach + ॥੧॥', (units[3]['text'], units[3]['markers']),
      ('ਹੈ ਭੀ ਸਚੁ ਨਾਨਕ ਹੋਸੀ ਭੀ ਸਚੁ', ['੧']))
check('Sochai soch', units[4]['text'], 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ')
print('Ang 1 anomalies:', anom)

# ---- 4. transliteration spot checks
for g, want in [('ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ', 'sat naam karataa purakh'),
                ('ਜਪੁ', 'jap'), ('ਗੁਰ ਪ੍ਰਸਾਦਿ', 'gur prasaad'),
                ('ਅੰਮ੍ਰਿਤੁ', 'ammrit')]:
    check(f'translit {g}', translit_line(g), want)

# ---- 5. first letters
fl_g, fl_r = first_letters('ਧਨੁ ਧਨੁ ਰਾਮਦਾਸ ਗੁਰੁ')
check('first letters gurmukhi', fl_g, 'ਧ ਧ ਰ ਗ')
check('first letters roman', fl_r, 'dh dh r g')

# ---- 6. rahao detection (find one on Ang 9-12 So Dar section)
found_rahao = False
carry = ''
for p in range(53, 66):
    a, raw = page_content(doc, p)
    fixed, _ = fix_text(raw)
    units, carry2 = segment_units(carry + ' ' + fixed)
    carry = carry2
    for u in units:
        if u['rahao']: found_rahao = True; print('PASS rahao found:', u['text'][:60], u['markers']); break
    if found_rahao: break
if not found_rahao: print('FAIL rahao'); FAIL.append('rahao')

# ---- 7. header detection
h = detect_header('ਸਿਰੀਰਾਗੁ ਮਹਲਾ ੧ ਘਰੁ ੧')
check('header raag', h.get('raag'), 'ਸਿਰੀਰਾਗੁ')
check('header author', h.get('author'), 'Guru Nanak Dev Ji (M1)')
check('header ghar', h.get('ghar'), '੧')
# a comp-type word / leading raag name inside a verse is NOT a header (v1.1.4)
for v in ['ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ', 'ਮਿਟਿਆ ਸੋਗੁ ਮਹਾ ਅਨੰਦੁ ਥੀਆ', 'ਗੁਰਬਾਣੀ ਸਖੀ ਅਨੰਦੁ ਗਾਵੈ',
          'ਆਸਾ ਮਨਸਾ ਬਾਂਧੋ ਬਾਰੁ', 'ਬਸੰਤੁ ਹਮਾਰੈ ਰਾਮ ਰੰਗੁ', 'ਬਸੰਤ ਰੁਤਿ ਆਈ', 'ਮਾਰੂ ਮਸਤਅੰਗ ਮੇਵਾਰਾ',
          'ਪ੍ਰਥਮ ਰਾਗ ਭੈਰਉ ਵੈ ਕਰਹੀ', 'ਕਹਿ ਕਬੀਰ ਉਰਵਾਰ ਨ ਪਾਰ', 'ਕਬੀਰ ਗਰਬੁ ਨ ਕੀਜੀਐ ਚਾਮ ਲਪੇਟੇ ਹਾਡ',
          'ਨਾਮਦੇਵ ਹਰਿ ਜੀਉ ਬਸਹਿ ਸੰਗਿ', 'ਸੁੰਦਰੁ ਸੁਘੜੁ ਚਤੁਰੁ ਜੀਅ ਦਾਤਾ']:
    check('verse is not a header: ' + v[:24], detect_header(v).get('is_header'), None)
for v in ['ਪਉੜੀ', 'ਸਲੋਕੁ', 'ਗਉੜੀ ਕਬੀਰ ਜੀ ਦੁਪਦੇ', 'ਗਉੜੀ ਭੀ ਸੋਰਠਿ ਭੀ', 'ਗਉੜੀ ਬੈਰਾਗਣਿ ਰਵਿਦਾਸ ਜੀਉ',
          'ਸਲੋਕ ਵਾਰਾਂ ਤੇ ਵਧੀਕ', 'ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀਉ ਕੇ', 'ਏਹੁ ਸਲੋਕੁ ਆਦਿ ਅੰਤਿ ਪੜਣਾ', 'ਜੁਮਲਾ', 'ਦੁਤੁਕੇ',
          'ਗਉੜੀ ਮਾਲਾ ੫', 'ਮਾਰੂ ਸੋਲਹੇ ੩', 'ਬਿਲਾਵਲੁ ਬਾਣੀ ਭਗਤਾ ਕੀ', 'ਗਉੜੀ ਬੈਰਾਗਣਿ ਤਿਪਦੇ',
          'ਗਉੜੀ ਕਬੀਰ ਜੀ', 'ਆਸਾ ਸ੍ਰੀ ਕਬੀਰ ਜੀਉ', 'ਕਬੀਰ ਜੀਉ ਨਾਮਦੇਉ ਜੀਉ ਰਵਿਦਾਸ ਜੀਉ', 'ਸ੍ਰੀਰਾਗ ਬਾਣੀ ਭਗਤ ਬੇਣੀ ਜੀਉ ਕੀ',
          'ਸਾਰੰਗ ਬਾਣੀ ਨਾਮਦੇਉ ਜੀ ਕੀ', 'ਸਲੋਕੁ ਮਰਦਾਨਾ ੧', 'ਰਾਗ ਮਾਲਾ']:
    check('label stays a header: ' + v[:24], detect_header(v).get('is_header'), 1)
check('danda-less title stays a header', detect_header('ਬਸੰਤ ਕੀ ਵਾਰ ਮਹਲੁ ੫', no_danda=True).get('is_header'), 1)

# ---- 8. Ang 1430 (Raagmala) + Mundavani Ang 1429
ang, raw = page_content(doc, 1482)
fixed, _ = fix_text(raw)
units, _ = segment_units(fixed)
print('Ang 1430 first unit:', units[0]['text'][:70])
print('Ang 1430 last unit :', units[-1]['text'][:70], units[-1]['markers'])
ang, raw = page_content(doc, 1481)
fixed, _ = fix_text(raw)
mund = 'ਮੁੰਦਾਵਣੀ' in fixed and 'ਥਾਲ ਵਿਚਿ ਤਿੰਨਿ ਵਸਤੂ' in fixed
check('Ang 1429 contains Mundavani + Thaal', mund, True)

# ---- 9. raag-start pages: header + invocation must be separate, correctly-placed units
import json, subprocess, os
CORPUS = os.path.join(os.path.dirname(__file__), '..', 'corpus', 'sggs.jsonl')
if os.path.exists(CORPUS):
    rows = [json.loads(l) for l in open(CORPUS, encoding='utf-8')]
    by_ang = {}
    for r in rows: by_ang.setdefault(r['ang'], []).append(r)
    a151 = by_ang[151]
    check('Ang 151 unit 1 = raag title (header, no ॥)',
          (a151[0]['text'], a151[0]['is_header'], a151[0]['gurmukhi'].endswith('॥')),
          ('ਰਾਗੁ ਗਉੜੀ ਗੁਆਰੇਰੀ ਮਹਲਾ ੧ ਚਉਪਦੇ ਦੁਪਦੇ', 1, False))
    check('Ang 151 unit 2 = ੴ invocation (header)',
          (a151[1]['text'].startswith('ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ'), a151[1]['is_header']), (True, 1))
    check('Ang 151 unit 3 = ਭਉ ਮੁਚੁ…', a151[2]['text'].startswith('ਭਉ ਮੁਚੁ ਭਾਰਾ'), True)
    check('ਸੁਧੁ stays on Ang 150, standalone', by_ang[150][-1]['gurmukhi'], 'ਸੁਧੁ')
    n_onkar = sum(r['text'].count('ੴ') for r in rows)
    check('ੴ count preserved (568)', n_onkar, 568)
    mid = sum(1 for r in rows if 'ੴ' in r['text'][1:])
    check('no unit hides a mid-text ੴ', mid, 0)
    for a in (14, 347, 489, 595, 728, 1107, 1254, 1327):
        u = by_ang[a]
        inv = next((x for x in u[:4] if x['text'].startswith('ੴ')), None)
        check(f'Ang {a} opens with its invocation in first units',
              bool(inv and inv['is_header']), True)

print('\n====', 'ALL GOLDEN TESTS PASS' if not FAIL else f'{len(FAIL)} FAILURES: {FAIL}', '====')
sys.exit(1 if FAIL else 0)
