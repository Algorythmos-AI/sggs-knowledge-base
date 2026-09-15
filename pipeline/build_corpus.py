# -*- coding: utf-8 -*-
"""Phase B: full extraction of Angs 1-1430 -> corpus/sggs.jsonl"""
import sys, json, fitz, re
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from sggs_pipeline import (fix_text, translit_line, first_letters, skeleton,
                           page_content, segment_units, detect_header, GDIGITS, DDANDA)

PDF, OUT = sys.argv[1], sys.argv[2]
doc = fitz.open(PDF)

def display_form(text, markers, no_danda=False, lead_danda=False):
    if no_danda and not markers:
        return text                      # e.g. ਸੁਧੁ, or a raag-title line — printed without ॥
    d = text + ' ' + DDANDA
    for m in markers:
        if all(ch in GDIGITS for ch in m): d += m + DDANDA
        else: d += ' ' + m + ' ' + DDANDA
    if lead_danda:
        d = DDANDA + ' ' + d             # title enclosed in dandas: ॥ ਜਪੁ ॥
    return d

IK = 'ੴ'
def split_invocations(units):
    """The print sets the raag title and the ੴ invocation as separate display
    lines, but they share one ॥-unit. Split any unit with a mid-text ੴ."""
    out = []
    for u in units:
        t = u['text']
        i = t.find(IK)
        if i > 0:
            out.append({'text': t[:i].strip(), 'markers': [], 'rahao': False, 'no_danda': True})
            out.append({'text': t[i:].strip(), 'markers': u['markers'], 'rahao': u['rahao']})
        else:
            out.append(u)
    return out

NEW_SECTION_STARTS = ('ਰਾਗੁ ', IK)

RAAG_CANON = {'ਵਡਹੰਸ': 'ਵਡਹੰਸੁ', 'ਬਿਲਾਵਲ': 'ਬਿਲਾਵਲੁ', 'ਗੋਡ': 'ਗੋਂਡ', 'ਸਾਰਗ': 'ਸਾਰੰਗ',
              'ਬਸੰਤ': 'ਬਸੰਤੁ', 'ਕਲਿਆਨ': 'ਕਲਿਆਨੁ', 'ਨਟ ਨਾਰਾਇਨ': 'ਨਟ', 'ਆਸਾਵਰੀ': 'ਆਸਾ'}
# After Jaijavanti (Ang 1353) the Granth leaves the raag framework: saloks,
# swaiyye, Mundavani, Raagmala. Sections are detected by header; raag is cleared.
POST_RAAG_ANG = 1353

records, all_anoms = [], []
ctx = {'raag': None, 'section': None, 'author': None, 'comp_type': None, 'ghar': None,
       'vaar_author': None}
comp_id, line_no, lid = 0, 0, 0
carry, carry_ang, carry_page = '', None, None
expected_ang = 1

for p in range(53, 1483):
    ang, raw = page_content(doc, p)
    if ang != expected_ang:
        all_anoms.append(('ang_sequence', f'pdf_page {p+1}: got {ang}, expected {expected_ang}'))
        ang = expected_ang
    expected_ang += 1
    fixed, anoms = fix_text(raw)
    for a in anoms: all_anoms.append((f'ang {ang}',) + a)
    units, frag = segment_units(fixed)
    units = split_invocations(units)
    if carry and units:
        if units[0]['text'].startswith(NEW_SECTION_STARTS):
            # the carry (e.g. vaar-closing ਸੁਧੁ) ends ITS OWN section; a new
            # raag/invocation begins this page — never glue across the boundary
            units.insert(0, {'text': carry, 'markers': [], 'rahao': False,
                             'no_danda': True, '_carry': True})
        else:
            units[0]['text'] = (carry + ' ' + units[0]['text']).strip()
            units[0]['_carry'] = True
        carry = ''
    elif carry and not units:
        carry = (carry + ' ' + frag).strip()
        continue
    for k, u in enumerate(units):
        u_ang, u_page = (carry_ang, carry_page) if u.get('_carry') else (ang, p + 1)
        text = u['text']
        h = detect_header(text)
        is_header = 0
        if h.get('is_header') and not u['markers'] and not u['rahao'] and len(text.split()) <= 16:
            is_header = 1
            if 'raag' in h and u_ang < POST_RAAG_ANG and \
               (re.search(r'(^|\s)ਰਾਗੁ?\s', text) or 'author' in h or 'comp_type' in h):
                new_raag = RAAG_CANON.get(h['raag'], h['raag'])
                if new_raag != ctx['raag']:
                    ctx['raag'] = new_raag
                    ctx['vaar_author'] = None               # vaar scope ends with its raag
                    if u_ang >= 14: ctx['section'] = None   # raag begins, liturgy section ends
            if 'section' in h and (u_ang <= 13 or u_ang >= POST_RAAG_ANG):
                # liturgy sections live on Angs 1-13; closing sections after 1352.
                # A bani repeating inside a raag (e.g. ਸੋ ਦਰੁ in Asa) is not a section start.
                ctx['section'] = h['section']
                if u_ang >= POST_RAAG_ANG: ctx['raag'] = None   # post-raag canon
            if 'author' in h: ctx['author'] = h['author']
            if 'comp_type' in h: ctx['comp_type'] = h['comp_type']
            # a Vaar's pauris belong to the Vaar's author, even though the
            # saloks interleaved before them carry other Gurus' ਮਃ headers
            if 'ਵਾਰ' in text and 'author' in h:
                ctx['vaar_author'] = h['author']
            if h.get('comp_type') == 'ਪਉੜੀ' and 'author' not in h and ctx['vaar_author']:
                ctx['author'] = ctx['vaar_author']
            ctx['ghar'] = h.get('ghar', ctx['ghar'] if 'author' not in h else None)
            comp_id += 1; line_no = 0
        line_no += 1; lid += 1
        records.append({
            'id': lid, 'ang': u_ang, 'pdf_page': u_page,
            'raag': ctx['raag'], 'section': ctx['section'], 'author': ctx['author'],
            'comp_type': ctx['comp_type'], 'ghar': ctx['ghar'], 'comp_id': comp_id,
            'line_no': line_no, 'is_rahao': 1 if u['rahao'] else 0, 'is_header': is_header,
            'markers': u['markers'],
            'gurmukhi': display_form(text, u['markers'], u.get('no_danda', False), u.get('lead_danda', False)),
            'text': text,
            'translit': translit_line(text),
            'fl_g': first_letters(text)[0], 'fl_r': first_letters(text)[1],
            'skeleton': skeleton(text),
        })
    if frag:
        if not carry or units:           # fragment starts on this page
            carry_ang, carry_page = ang, p + 1
        carry = frag
    else:
        carry, carry_ang, carry_page = '', None, None

if carry:
    all_anoms.append(('trailing_fragment', carry[:80]))

# ---- post-pass 1: merge page-start orphan numeral units ('੩ ॥੨੬॥') into the
#      preceding line's marker chain (16 page-break artifacts corpus-wide)
merged = []
for r in records:
    if (merged and not r['is_header'] and r['text']
            and all(ch in GDIGITS for ch in r['text'].replace(' ', ''))):
        prev = merged[-1]
        prev['markers'] = prev['markers'] + [r['text']] + r['markers']
        prev['is_rahao'] = prev['is_rahao'] or r['is_rahao']
        prev['gurmukhi'] = display_form(prev['text'], prev['markers'])
        all_anoms.append(('orphan_marker_merged', f"ang {r['ang']}: {r['gurmukhi'][:30]}"))
        continue
    merged.append(r)
records = merged
for i, r in enumerate(records, 1): r['id'] = i

# ---- post-pass 1b: a run of consecutive header lines opens ONE composition
#      together with the body that follows. Each header used to do comp_id += 1,
#      leaving 677 single-line "orphan" header comps (e.g. a raag/title line, then
#      the separate ੴ invocation) so the composition sheet (/api/shabad, and the
#      iOS fetchShabad) lost the title line. Fold each header run into the comp_id
#      of its LAST header -- the one already holding the body -- so no BODY line
#      ever changes comp_id and vacated comp_ids become permanent gaps (never
#      reused). Closing rubrics that belong to the PRECEDING unit break the run and
#      keep their own one-line comp (flagged for scholarly review, never merged).
TRAILING_RUBRICS = {'ਜੁਮਲਾ', 'ਦੁਤੁਕੇ',
                    'ਏਹੁ ਸਲੋਕੁ ਆਦਿ ਅੰਤਿ ਪੜਣਾ'}
def _is_run_header(r):
    return r['is_header'] and r['text'] not in TRAILING_RUBRICS
_regrouped, i, _n = 0, 0, len(records)
while i < _n:
    if not _is_run_header(records[i]):
        i += 1; continue
    j = i
    while j + 1 < _n and _is_run_header(records[j + 1]):
        j += 1
    if j > i:
        keep = records[j]['comp_id']
        for r in records[i:j]:
            all_anoms.append(('header_regrouped',
                              f"ang {r['ang']}: comp {r['comp_id']}->{keep}: {r['text'][:30]}"))
            r['comp_id'] = keep
            _regrouped += 1
    i = j + 1
# renumber line_no 1..N within each comp (id order); also densifies the 16
# post-pass-1 gaps so line_no is always contiguous within a comp
_ln = {}
for r in records:
    _ln[r['comp_id']] = _ln.get(r['comp_id'], 0) + 1
    r['line_no'] = _ln[r['comp_id']]
print(f'header regroup: {_regrouped} header lines folded into the composition they open')

# ---- post-pass 2: an ੴ invocation belongs to the section it OPENS — adopt the
#      raag/section/author of the unit that follows it (fixes stale inheritance
#      when the invocation precedes the raag-title unit in the page stream)
for i, r in enumerate(records[:-1]):
    if r['text'].startswith('ੴ'):
        nxt = records[i + 1]
        r['raag'], r['section'], r['author'] = nxt['raag'], nxt['section'], nxt['author']

# ---- post-pass 3: per-Bhatt attribution in the Swaiyye (1389-1409), from the
#      signature-verified table produced by the SME audit (conservative: only
#      rows currently tagged with the generic Bhatts label are refined)
import os
_bhatt_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'bhatt_attribution.json')
if os.path.exists(_bhatt_file):
    _n = 0
    _ranges = json.load(open(_bhatt_file, encoding='utf-8'))
    by_id = {r['id']: r for r in records}
    for rg in _ranges:
        for lid in range(rg['start_id'], rg['end_id'] + 1):
            r = by_id.get(lid)
            if r and 1389 <= r['ang'] <= 1409 and r['author'] == 'The Bhatts (ਭਟ)':
                r['author'] = rg['bhatt'] + ' (ਭਟ)'; _n += 1
    print(f'bhatt attribution: {_n} lines refined across {len(_ranges)} ranges')

with open(OUT, 'w', encoding='utf-8') as f:
    for r in records:
        f.write(json.dumps(r, ensure_ascii=False) + '\n')

angs = {r['ang'] for r in records}
print(f'lines: {len(records)}  angs covered: {len(angs)} ({min(angs)}-{max(angs)})')
print(f'rahao lines: {sum(r["is_rahao"] for r in records)}  headers: {sum(r["is_header"] for r in records)}')
_other_anoms = [a for a in all_anoms if a[0] != 'header_regrouped']
print(f'anomalies: {len(all_anoms)} ({len(_other_anoms)} excl. header_regrouped)')
for a in _other_anoms[:40]: print('  ', a)
missing = sorted(set(range(1, 1431)) - angs)
print('missing angs:', missing if missing else 'NONE')
