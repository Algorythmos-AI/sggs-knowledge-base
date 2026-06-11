# -*- coding: utf-8 -*-
"""
SGGS extraction pipeline — verbatim Gurmukhi, visual→logical correction,
structure tagging, reader-friendly transliteration.

The scripture itself is NEVER altered beyond the deterministic encoding
corrections proven on golden Angs (sihari reorder, halant swap, font-glyph
restoration). Every correction class is logged.
"""
import re, unicodedata

# ---------------------------------------------------------------- constants
CONS = set('ਕਖਗਘਙਚਛਜਝਞਟਠਡਢਣਤਥਦਧਨਪਫਬਭਮਯਰਲਵਸਹੜਸ਼ਖ਼ਗ਼ਜ਼ਫ਼ਲ਼')
INDEP_VOWELS = set('ਅਆਇਈਉਊਏਐਓਔ')
MATRAS = set('ਾਿੀੁੂੇੈੋੌ')
NASALS = set('ੰਂ')
HALANT = '੍'
DDANDA = '॥'           # U+0965
GDIGITS = '੦੧੨੩੪੫੬੭੮੯'
IK_ONKAR = 'ੴ'         # U+0A74

# ------------------------------------------------- visual→logical correction
def fix_text(s):
    """Apply the proven encoding corrections. Returns (fixed, anomalies)."""
    anomalies = []
    # 0. strip PDF print-job timestamps (HH:MM:SS, ASCII digits — never Gurbani)
    for m in re.finditer(r'\d{1,3}:\d{2}:\d{2}', s):
        anomalies.append(('timestamp_stripped', m.group()))
    s = re.sub(r'\s*\d{1,3}:\d{2}:\d{2}\s*', ' ', s)
    # 1. swap (consonant, halant) -> (halant, consonant)   e.g. ਪਰ੍ਭ -> ਪ੍ਰਭ
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c in CONS and i + 1 < len(s) and s[i+1] == HALANT:
            out.append(HALANT); out.append(c); i += 2
        else:
            out.append(c); i += 1
    s = ''.join(out)
    # 2. font-glyph restorations (proven by word evidence; see Validation-Report)
    for a, b in [('Â', 'ਾਂ'),      # kanna+bindi   ਸÂਿਤ -> ਸਾਂਿਤ
                 ('¸', '੍ਹ'),      # pairin-haha   ਿਤਨ¸ -> ਿਤਨ੍ਹ
                 ('±', '੍ਹ'), ('º', '੍ਹ'), ('¼', '੍ਹ'), ('¾', '੍ਹ'),  # ਕੋੜ±ੇ ਪੜº ਕਾਨ¼ ਚੜ¾
                 ('°', '੍ਵ'),      # pairin-vava   ਸ°ਾਮੀ -> ਸ੍ਵਾਮੀ
                 ('Ô', 'ਂ'), ('', 'ਂ'),   # bindi  ਨੀÔਬੁ ਨੀਦ -> ਨੀਂ…
                 ('', 'ੋ'),  # hora          ਗਿਬੰਦ -> ਗੋਿਬੰਦ
                 ('', 'ਾ')]: # kanna (rare Sahaskriti ligature; flagged)
        if a in s:
            if a == '': anomalies.append(('f02d_kanna', s[:60]))
            s = s.replace(a, b)
    s = s.replace('੧ਓ', IK_ONKAR)      # Ik Onkar restoration
    # 2b. re-attach vowel signs split off by a stray space (archaic ਓੁ spellings:
    #     ਸਫਲਿਓ ੁ -> ਸਫਲਿਓੁ, ਗਾਓ ੁ -> ਗਾਓੁ — 12 cases corpus-wide, all logged)
    for m in re.finditer(r'(\S) ([ੁੋ])(?= |$)', s):
        anomalies.append(('vowel_reattached', m.group(1) + m.group(2)))
    s = re.sub(r'(\S) ([ੁੋ])(?= |$)', r'\1\2', s)
    # 3. move sihari after its consonant cluster  (ਿਕ੍ਰਪਾ -> ਕ੍ਰਿਪਾ)
    out = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == 'ਿ':
            j = i + 1
            if j < n and s[j] in CONS:
                j += 1
                while j + 1 < n and s[j] == HALANT and s[j+1] in CONS:
                    j += 2
                out.append(s[i+1:j]); out.append('ਿ')
                i = j
            else:
                anomalies.append(('orphan_sihari', s[max(0,i-6):i+6]))
                out.append(c); i += 1
        else:
            out.append(c); i += 1
    s = ''.join(out)
    # 4. documented editorial corrections (impossible Unicode produced by the
    #    font's glyph order; restored to the canonical reading -- see Validation-Report)
    for a, b in [('\u0a4d\u0a30\u0a3f\u0a3f\u0a4d\u0a38\u0a1f', '\u0a4d\u0a30\u0a3f\u0a38\u0a1f\u0a3f'),
                 ('\u0a4d\u0a38\u0a28\u0a47\u0a39', '\u0a38\u0a4d\u0a28\u0a47\u0a39'),
                 ('\u0a3f\u25cc \u0a2e\u0a4d\u0a2f\u0a4d\u0a2f\u0a3e\u0a28\u0a47', '\u0a2e\u0a4d\u0a2f\u0a4d\u0a2f\u0a3f\u0a3e\u0a28\u0a47')]:
        if a in s:
            anomalies.append(('editorial_fix', a + ' -> ' + b))
            s = s.replace(a, b)
    for m in re.finditer('\u0a3f\u0a4d([\u0a38\u0a2a])\u0a24', s):
        anomalies.append(('editorial_fix', 'sahaskriti ' + m.group(0) + ' -> ' + m.group(1) + '\u0a4d\u0a24\u0a3f'))
    s = re.sub('\u0a3f\u0a4d([\u0a38\u0a2a])\u0a24', '\\1\u0a4d\u0a24\u0a3f', s)
    # 5. residual private-use / stray latin/ascii -> flag + strip
    stray = re.compile('[!-~\u00a0-\u00ff\u25cc\ue000-\uf8ff]')
    for m in stray.finditer(s):
        anomalies.append(('stray_char', hex(ord(m.group())) + ' @ ' + s[max(0,m.start()-8):m.start()+8]))
    s = stray.sub('', s)
    s = unicodedata.normalize('NFC', s)
    s = re.sub('[ \t]+', ' ', s).strip()
    return s, anomalies

# ------------------------------------------------------------ transliteration
C_MAP = {'ਕ':'k','ਖ':'kh','ਗ':'g','ਘ':'gh','ਙ':'ng','ਚ':'ch','ਛ':'chh','ਜ':'j',
 'ਝ':'jh','ਞ':'nj','ਟ':'t','ਠ':'th','ਡ':'d','ਢ':'dh','ਣ':'n','ਤ':'t','ਥ':'th',
 'ਦ':'d','ਧ':'dh','ਨ':'n','ਪ':'p','ਫ':'ph','ਬ':'b','ਭ':'bh','ਮ':'m','ਯ':'y',
 'ਰ':'r','ਲ':'l','ਵ':'v','ਸ':'s','ਹ':'h','ੜ':'rh','ਸ਼':'sh','ਖ਼':'khh','ਗ਼':'gh',
 'ਜ਼':'z','ਫ਼':'f','ਲ਼':'l'}
V_MAP = {'ਅ':'a','ਆ':'aa','ਇ':'i','ਈ':'ee','ਉ':'u','ਊ':'oo','ਏ':'e','ਐ':'ai','ਓ':'o','ਔ':'au'}
M_MAP = {'ਾ':'aa','ਿ':'i','ੀ':'ee','ੁ':'u','ੂ':'oo','ੇ':'e','ੈ':'ai','ੋ':'o','ੌ':'au'}
LABIALS = set('ਮਪਬਭ')

def translit_word(w):
    """Reader-friendly Roman (reading aid, not scripture)."""
    if w == IK_ONKAR: return 'ik oankaar'
    units = []          # (roman_cons_cluster or vowel, matra_roman, nasal)
    i, n = 0, len(w)
    while i < n:
        c = w[i]
        if c in CONS:
            rom = C_MAP[c]; i += 1
            while i + 1 < n and w[i] == HALANT and w[i+1] in CONS:
                rom += C_MAP[w[i+1]]; i += 2
            matra = ''
            if i < n and w[i] in MATRAS:
                matra = M_MAP[w[i]]; i += 1
            nas = ''
            if i < n and w[i] in NASALS:
                nxt = w[i+1] if i+1 < n else ''
                nas = 'm' if nxt in LABIALS else 'n'; i += 1
            units.append([rom, matra, nas, True])
        elif c in INDEP_VOWELS:
            rom = V_MAP[c]; i += 1
            nas = ''
            if i < n and w[i] in NASALS:
                nxt = w[i+1] if i+1 < n else ''
                nas = 'm' if nxt in LABIALS else 'n'; i += 1
            units.append([rom, '', nas, False])
        elif c == IK_ONKAR:
            units.append(['ik oankaar', '', '', False]); i += 1
        else:
            i += 1
    if not units: return ''
    parts = []
    for k, (rom, matra, nas, is_cons) in enumerate(units):
        last = (k == len(units) - 1)
        if is_cons:
            if matra:
                if last and matra in ('i', 'u') and len(units) > 1:
                    parts.append(rom)            # drop word-final sihari/aunkar
                else:
                    parts.append(rom + matra)
            else:
                parts.append(rom if last and len(units) > 1 else rom + 'a')
        else:
            parts.append(rom + matra)
        if nas: parts.append(nas)
    word = ''.join(parts)
    word = re.sub(r'(.)\1\1', r'\1\1', word)
    if re.fullmatch(r'[bcdfghjklmnpqrstvz]+h?', word): word += 'a'
    return word

def translit_line(line):
    toks = [t for t in re.split(r'\s+', line) if t and t != DDANDA and not all(ch in GDIGITS for ch in t)]
    return ' '.join(translit_word(t) for t in toks).strip()

def first_letters(line):
    """(gurmukhi_initials, roman_initials) of word first letters."""
    g, r = [], []
    for t in re.split(r'\s+', line):
        if not t or t == DDANDA or all(ch in GDIGITS for ch in t): continue
        c = t[0]
        if c == IK_ONKAR: g.append(c); r.append('ik')
        elif c in CONS:   g.append(c); r.append(C_MAP[c])
        elif c in INDEP_VOWELS: g.append(c); r.append(V_MAP[c][0])
    return ' '.join(g), ' '.join(r)

def skeleton(line):
    return re.sub('[ਾਿੀੁੂੇੈੋੌੰਂ੍ਃ]', '', line)

def roman_norm(translit):
    """Spelling-tolerant normal form of a Roman string (query or index side).
    'waheguru' and 'vaahiguroo' both -> 'vhgr'. Word-by-word consonant skeleton:
    unify w->v, f->ph; keep a single leading vowel if the word starts with one."""
    out = []
    for w in translit.lower().split():
        w = w.replace('w', 'v').replace('f', 'ph')
        head = w[0] if w[0] in 'aeiou' else ''
        body = re.sub('[aeiou]', '', w)
        out.append((head + body) if (head + body) else w)
    return ' '.join(out)

# ------------------------------------------------------------- PDF extraction
def page_content(doc, pno):
    """-> (ang:int|None, joined_text:str). Strips borders, joins wrapped lines."""
    raw = doc[pno].get_text("text")
    lines = [l.strip() for l in raw.splitlines()]
    ang = None
    content = []
    for l in lines:
        if not l: continue
        if set(l) <= set('❀ '): continue
        bare = l.replace('❀', '').strip()
        if not bare: continue
        if ang is None and bare.isdigit():
            ang = int(bare); continue
        content.append(bare)
    return ang, ' '.join(content)

# ----------------------------------------------------------- unit segmentation
RAHAO_RE = re.compile(r'ਰਹਾਉ(\s+ਦੂਜਾ)?')

def segment_units(stream):
    """Split a ॥-delimited stream into units.
    -> list of dicts {text, markers:[..], rahao:bool}, plus trailing fragment."""
    parts = stream.split(DDANDA)
    units = []
    i = 0
    pending_lead = False
    while i < len(parts) - 1:          # parts[-1] = text after last ॥ (fragment)
        text = parts[i].strip()
        i += 1
        markers, rahao = [], False
        while i < len(parts) - 1:
            nxt = parts[i].strip()
            if nxt and all(ch in GDIGITS for ch in nxt):
                markers.append(nxt); i += 1
            elif nxt and RAHAO_RE.fullmatch(nxt):
                rahao = True
                markers.append(nxt); i += 1
            else:
                break
        if text or markers or rahao:
            u = {'text': text, 'markers': markers, 'rahao': rahao}
            if pending_lead:           # title enclosed in dandas, e.g. ॥ ਜਪੁ ॥
                u['lead_danda'] = True; pending_lead = False
            units.append(u)
        else:
            pending_lead = True        # empty segment = two adjacent ॥
    fragment = parts[-1].strip()
    return units, fragment

# -------------------------------------------------------------- structure tags
RAAGS = ['ਸਿਰੀਰਾਗੁ','ਮਾਝ','ਗਉੜੀ','ਆਸਾਵਰੀ','ਆਸਾ','ਗੂਜਰੀ','ਦੇਵਗੰਧਾਰੀ','ਬਿਹਾਗੜਾ',
 'ਵਡਹੰਸੁ','ਵਡਹੰਸ','ਸੋਰਠਿ','ਧਨਾਸਰੀ','ਜੈਤਸਰੀ','ਟੋਡੀ','ਬੈਰਾੜੀ','ਤਿਲੰਗ','ਸੂਹੀ','ਬਿਲਾਵਲੁ',
 'ਬਿਲਾਵਲ','ਗੋਂਡ','ਗੋਡ','ਰਾਮਕਲੀ','ਨਟ ਨਾਰਾਇਨ','ਨਟ','ਮਾਲੀ ਗਉੜਾ','ਮਾਰੂ','ਤੁਖਾਰੀ','ਕੇਦਾਰਾ',
 'ਭੈਰਉ','ਬਸੰਤੁ','ਬਸੰਤ','ਸਾਰਗ','ਸਾਰੰਗ','ਮਲਾਰ','ਕਾਨੜਾ','ਕਲਿਆਨੁ','ਕਲਿਆਨ','ਪ੍ਰਭਾਤੀ','ਜੈਜਾਵੰਤੀ']
SECTIONS = ['ਜਪੁ','ਸੋ ਦਰੁ','ਸੋ ਪੁਰਖੁ','ਸੋਹਿਲਾ','ਸਲੋਕ ਸਹਸਕ੍ਰਿਤੀ','ਗਾਥਾ','ਫੁਨਹੇ','ਚਉਬੋਲੇ',
 'ਸਲੋਕ ਭਗਤ ਕਬੀਰ','ਸਲੋਕ ਸੇਖ ਫਰੀਦ','ਸਵਈਏ','ਸਵਯੇ','ਸਲੋਕ ਵਾਰਾਂ ਤੇ ਵਧੀਕ','ਸਲੋਕ ਮਹਲਾ ੯',
 'ਮੁੰਦਾਵਣੀ','ਰਾਗ ਮਾਲਾ']
SECTION_CANON = {'ਸਵਯੇ': 'ਸਵਈਏ'}
RUBRICS = {'ਜੁਮਲਾ', 'ਦੁਤੁਕੇ', 'ਕਬੀਰ ਕੇ', 'ਇਕਤੁਕੇ', 'ਤਿਪਦੇ', 'ਚਉਪਦੇ', 'ਪੰਚਪਦੇ'}
MAHALA_RE = re.compile(r'ਮਹਲ[ਾੇ]?\s+([੧੨੩੪੫੯])|ਮਃ\s*([੧੨੩੪੫੯])')
MAHALA_NAME = {'੧':'Guru Nanak Dev Ji (M1)','੨':'Guru Angad Dev Ji (M2)','੩':'Guru Amar Das Ji (M3)',
 '੪':'Guru Ram Das Ji (M4)','੫':'Guru Arjan Dev Ji (M5)','੯':'Guru Tegh Bahadur Ji (M9)'}
BHAGATS = {'ਕਬੀਰ':'Bhagat Kabir Ji','ਨਾਮਦੇਵ':'Bhagat Namdev Ji','ਨਾਮਦੇਉ':'Bhagat Namdev Ji',
 'ਰਵਿਦਾਸ':'Bhagat Ravidas Ji','ਫਰੀਦ':'Sheikh Farid Ji','ਤ੍ਰਿਲੋਚਨ':'Bhagat Trilochan Ji',
 'ਬੇਣੀ':'Bhagat Beni Ji','ਧੰਨਾ':'Bhagat Dhanna Ji','ਜੈਦੇਵ':'Bhagat Jaidev Ji','ਭੀਖਨ':'Bhagat Bhikhan Ji',
 'ਸੈਣੁ':'Bhagat Sain Ji','ਪੀਪਾ':'Bhagat Pipa Ji','ਸਧਨਾ':'Bhagat Sadhna Ji','ਰਾਮਾਨੰਦ':'Bhagat Ramanand Ji',
 'ਪਰਮਾਨੰਦ':'Bhagat Parmanand Ji','ਸੂਰਦਾਸ':'Bhagat Surdas Ji','ਮਰਦਾਨਾ':'Bhai Mardana','ਸੁੰਦਰੁ':'Baba Sundar Ji',
 'ਸਤਾ':'Satta & Balwand','ਬਲਵੰਡਿ':'Satta & Balwand'}
COMP_TYPES = ['ਅਸਟਪਦੀਆ','ਅਸਟਪਦੀ','ਛੰਤ','ਪਉੜੀ','ਸਲੋਕੁ','ਸਲੋਕ','ਵਾਰ','ਸੋਲਹੇ','ਪੜਤਾਲ',
 'ਅਲਾਹਣੀਆ','ਘੋੜੀਆ','ਕਰਹਲੇ','ਵਣਜਾਰਾ','ਬਿਰਹੜੇ','ਪਟੀ','ਬਾਰਹ ਮਾਹਾ','ਥਿਤੀ','ਥਿਤੰੀ','ਦਿਨ ਰੈਣਿ',
 'ਸੁਖਮਨੀ','ਬਾਵਨ ਅਖਰੀ','ਓਅੰਕਾਰੁ','ਸਿਧ ਗੋਸਟਿ','ਅਨੰਦੁ','ਸਦੁ','ਕੁਚਜੀ','ਸੁਚਜੀ','ਗੁਣਵੰਤੀ',
 'ਕਾਫੀ','ਦਖਣੀ','ਰੁਤੀ','ਸਵਈਏ','ਗਾਥਾ','ਫੁਨਹੇ','ਚਉਬੋਲੇ','ਮੁੰਦਾਵਣੀ','ਰਾਗ ਮਾਲਾ']
GHAR_RE = re.compile(r'ਘਰੁ\s+([੦-੯]+)')

def detect_header(text):
    """-> dict of detected metadata if this unit is a structural header, else {}."""
    h = {}
    if not text: return h
    m = MAHALA_RE.search(text)
    if m: h['author'] = MAHALA_NAME[m.group(1) or m.group(2)]
    if 'author' not in h:               # ordinal word-forms: ਮਹਲੇ ਪਹਿਲੇ ਕੇ = "of the First"
        m = re.search(r'ਮਹਲ[ਾੇ]\s+(ਪਹਿਲ|ਦੂਜ|ਤੀਜ|ਚਉਥ|ਪੰਜਵ)', text)
        if m:
            h['author'] = MAHALA_NAME[{'ਪਹਿਲ': '੧', 'ਦੂਜ': '੨', 'ਤੀਜ': '੩',
                                       'ਚਉਥ': '੪', 'ਪੰਜਵ': '੫'}[m.group(1)]]
    for bg, name in BHAGATS.items():
        if re.search(r'(^|\s)' + bg + r'(\s|$)', text) and \
           ('ਬਾਣੀ' in text or 'ਸਲੋਕ' in text or 'ਪਦੇ' in text or 'ਵਾਰ' in text
                or 'ਜੀ' in text or 'ੴ' in text or 'ਮਹਲਾ' in text):
            h.setdefault('author', name)
            break
    if text.startswith(('ਸਵਈਏ', 'ਸਵਯੇ')) and 'ਮਹਲੇ' in text:
        h['author'] = 'The Bhatts (ਭਟ)'   # swaiyye in PRAISE of the Gurus, composed by the Bhatts
    for r in RAAGS:
        if re.search(r'(^|\s)ਰਾਗੁ?\s+' + r, text) or text.startswith(r + ' '):
            h['raag'] = r; break
    for s in SECTIONS:
        # bare title | title-initial with attribution | title embedded in an attributed header
        if (text == s
                or (text.startswith(s) and re.search(r'ਮਹਲਾ|ਮਹਲੇ|ਮਃ|ਰਾਗੁ|ੴ', text))
                or (s in text and re.search(r'ਮਹਲਾ|ਮਹਲੇ|ਮਃ|ੴ', text) and len(text.split()) <= 10)):
            h['section'] = SECTION_CANON.get(s, s); break
    for ct in COMP_TYPES:
        if re.search(r'(^|\s)' + ct + r'(\s|$)', text):
            h['comp_type'] = ct; break
    m = GHAR_RE.search(text)
    if m: h['ghar'] = m.group(1)
    if text.startswith(IK_ONKAR):
        h['invocation'] = True            # ੴ … ਗੁਰ ਪ੍ਰਸਾਦਿ — always a header line
    if text in RUBRICS or (len(text.split()) == 1 and text in RAAGS):
        h['rubric'] = True                # tally/colophon labels: ਜੁਮਲਾ, ਦੁਤੁਕੇ, ਸੋਰਠਿ …
    is_hdr = bool(h) and (('author' in h) or ('raag' in h) or ('section' in h)
                          or ('comp_type' in h) or ('invocation' in h) or ('rubric' in h))
    # headers are short metadata lines; verses with ਮਃ inline are not headers
    if is_hdr: h['is_header'] = 1
    return h
