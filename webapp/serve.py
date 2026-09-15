#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sri Guru Granth Sahib — local search app.
Zero dependencies: Python 3 standard library only.

Run:   python3 serve.py        then open  http://localhost:7777
"""
import json, os, re, sqlite3, random, sys, threading, webbrowser, mimetypes, math
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
# Static frontend (Astro MPA build) lives under ./static. realpath here so the
# path-traversal guard in H._resolve_static compares fully-resolved prefixes.
STATIC_ROOT = os.path.realpath(os.path.join(HERE, 'static'))
# Some platforms' mimetypes tables miss types this offline build serves; pin them.
for _ext, _ct in (('.js', 'text/javascript'), ('.mjs', 'text/javascript'),
                   ('.css', 'text/css'), ('.svg', 'image/svg+xml'),
                   ('.json', 'application/json'), ('.woff2', 'font/woff2'),
                   ('.woff', 'font/woff'), ('.webmanifest', 'application/manifest+json')):
    mimetypes.add_type(_ct, _ext)
DB = os.path.join(HERE, '..', 'db', 'sggs.sqlite')
PORT = int(os.environ.get('PORT') or os.environ.get('SGGS_PORT') or '7777')

# Search-logic release stamp. Lives in code (not DB meta) so a search-only patch
# doesn't force an 86 MB DB re-commit. /api/meta and /api/health prefer these; the
# DB meta row is the fallback. Bump on every search-logic release so the UI footer
# (which reads /api/meta) reflects the running build.
APP_VERSION = '1.1.1'
APP_BUILT = '2026-09-15'


# The exact source commit of the running build, so a deploy can be verified by
# identity (not just version): Render injects RENDER_GIT_COMMIT for git-backed
# services; SGGS_COMMIT is a manual override for other hosts.
APP_COMMIT = os.environ.get('RENDER_GIT_COMMIT') or os.environ.get('SGGS_COMMIT') or 'unknown'


class ApiError(Exception):
    """Raised by an endpoint to return a specific HTTP status (e.g. 404) with a
    safe JSON body, instead of the generic 400/500 mapping."""
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message

import sys as _sys
_sys.path.insert(0, HERE)
from verify import verify as verify_claim     # Layer-3: quotation verification engine

GURMUKHI = re.compile('[਀-੿]')
_local = threading.local()

from romannorm import roman_norm   # shared fold (see romannorm.py); re-exported for gen_golden_vectors.py

def fold_match_alts(fn):
    """Exact-fold FTS clauses for a query token's fold, plus the casual-spelling twins a
    user is most likely to produce. All EXACT (never prefix) so they can't over-match — a
    twin only reaches words whose whole skeleton matches but for that one feature, and the
    multi-token AND + BM25 keep precision.
      • initial-vowel: roman_norm keeps the lead vowel and canonical long oo/ee fold to
        head o/e, but users type short u/i (oopar~upar, ootam~utam) -> swap o<->u, e<->i.
      • subjoined-h aspiration: the index keeps it (ਤੁਮ੍ਹ tumh->'dmh', ਚੀਨ੍ਹੇ cheenhe->'cnh')
        but casual typing drops it (tum->'dm', chine->'cn'). Insert an h after a nasal/l so
        the short query fold reaches the aspirated index fold (the one-directional gap —
        the index always carries the aspiration the user omits)."""
    if not fn or len(fn) < 2: return []
    variants = [fn]
    swap = {'o': 'u', 'u': 'o', 'e': 'i', 'i': 'e'}.get(fn[0])
    if swap: variants.append(swap + fn[1:])
    for i, ch in enumerate(fn):                       # subjoined-h reinsertion
        if ch in 'mnl' and (i + 1 >= len(fn) or fn[i + 1] != 'h'):
            variants.append(fn[:i + 1] + 'h' + fn[i + 1:])
    seen, uniq = set(), []
    for v in variants:
        if v not in seen: seen.add(v); uniq.append(v)
    return [f'translit_norm: "{v}"' for v in uniq[:5]]

def db():
    if not hasattr(_local, 'con'):
        _local.con = sqlite3.connect(f'file:{DB}?mode=ro&immutable=1', uri=True)
        _local.con.row_factory = sqlite3.Row
        # read-only tuning (pure stdlib PRAGMAs — no extensions): mmap the whole DB so
        # the growing analytics/neighbor tables stay zero-copy in the page cache.
        for pragma in ('mmap_size=268435456', 'cache_size=-32768', 'query_only=ON'):
            try: _local.con.execute('PRAGMA ' + pragma)
            except sqlite3.OperationalError: pass
    return _local.con

def have_fts():
    try:
        db().execute("SELECT count(*) FROM fts WHERE fts MATCH 'ਨਾਮੁ'").fetchone()
        return True
    except sqlite3.OperationalError:
        return False

HAVE_FTS = None
_META_CACHE = None        # /api/meta is read-only and changes only on DB rebuild -> cache it
_TIMING_CACHE = None      # /api/timing/clock ditto — the claims layer changes only via pipeline
LINE_COLS = ('id, ang, raag, section, author, comp_type, comp_id, line_no, '
             'is_rahao, is_header, gurmukhi, translit, '
             'stanza_index, pada_total, source_category')   # v2.0 structural metadata

def rows_to_list(rs):
    return [dict(r) for r in rs]

# Columns that may be interpolated into FTS5 SQL by name. Every call site passes a
# string literal from this set, so this is a defensive allowlist (a future refactor that
# ever lets user input reach `col` would otherwise be a structural injection point).
_FTS_COLS = frozenset({'text', 'translit', 'translit_norm', 'fl_g', 'fl_r', 'skeleton'})

def _fts_clean(s):
    """Strip the two characters that carry FTS5 operator meaning inside a quoted phrase:
    a stray " closes the phrase (syntax error / injection), and a trailing * silently
    turns an exact term into a prefix match. Tokens are otherwise passed verbatim."""
    return str(s).replace('"', '').replace('*', '')

_ID_MAX = 2**31 - 1

def _int_str(raw, lo, hi):
    """Parse one integer query value defensively: reject absurd digit strings (Python has no
    int-size limit, SQLite does → OverflowError → 500), then clamp into [lo, hi]."""
    t = (raw or '').strip()
    if len(t) > 12:
        raise ValueError('integer parameter too long')
    try:
        v = int(t)
    except (TypeError, ValueError, OverflowError):
        raise ValueError('integer parameter expected')
    return max(lo, min(hi, v))

def _int(qs, key, default, lo, hi):
    return _int_str(qs.get(key, [str(default)])[0], lo, hi)

def fts_query(tokens, phrase=False):
    toks = [_fts_clean(t) for t in tokens if _fts_clean(t)]
    if not toks: return None
    if phrase: return '"' + ' '.join(toks) + '"'
    return ' AND '.join(f'"{t}"' for t in toks)

def search_fts(col, q, phrase, limit, offset, no_headers=False):
    if col not in _FTS_COLS: raise ValueError(f'invalid column: {col}')
    m = fts_query(q.split(), phrase)
    if not m: return []
    # no_headers: the phonetic-fold tier (translit_norm) collapses distinct words to the
    # same skeleton (bihaagarhaa->'vhgr'==vaahiguroo), so raag/author HEADER lines that
    # never carry the real word still fold-match and pollute the results. Exclude headers
    # from this tier only — a seeker wants scripture lines, not metadata captions.
    wh = ' WHERE lines.is_header = 0' if no_headers else ''
    # BM25 relevance ranking; column weights: text, translit, translit_norm, fl_g, fl_r, skeleton
    sql = (f"SELECT {LINE_COLS} FROM lines JOIN "
           f"(SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk "
           f" FROM fts WHERE {col} MATCH ?) m ON lines.id = m.rowid{wh} "
           f"ORDER BY m.rk, lines.id LIMIT ? OFFSET ?")
    try:
        return rows_to_list(db().execute(sql, (m, limit, offset)).fetchall())
    except sqlite3.OperationalError:      # very old SQLite without bm25(): fall back
        hf = ' AND is_header = 0' if no_headers else ''
        sql = (f"SELECT {LINE_COLS} FROM lines WHERE id IN "
               f"(SELECT rowid FROM fts WHERE {col} MATCH ?){hf} ORDER BY id LIMIT ? OFFSET ?")
        return rows_to_list(db().execute(sql, (m, limit, offset)).fetchall())

# Curated seeker lexicon: what people type -> how the corpus says it.
# Values: ('theme', concept_key) or ('translit', [terms tried in order]).
SEEKER_LEXICON = {
    'ego': ('theme', 'haumai'), 'truth': ('theme', 'sach'), 'liberation': ('theme', 'mukti'),
    'moksha': ('theme', 'mukti'), 'salvation': ('theme', 'mukti'), 'love': ('theme', 'prem_pyar'),
    'mercy': ('translit', ['daiaa', 'kirapaa']), 'compassion': ('translit', ['daiaa']),
    'grace': ('translit', ['nadar', 'kirapaa']), 'peace': ('translit', ['saant', 'sukh']),
    'death': ('translit', ['kaal', 'maran']), 'bliss': ('translit', ['anand']),
    'fear': ('translit', ['bhau']), 'fearless': ('translit', ['nirabhau']),
    'soul': ('translit', ['aatam', 'jeeo']), 'light': ('translit', ['jot']),
    'mind': ('translit', ['man']), 'word': ('translit', ['sabad']),
    'karma': ('translit', ['karam']), 'bhakti': ('translit', ['bhagat']),
    'dhyan': ('translit', ['dhiaan']), 'gyan': ('translit', ['giaan']),
    # darshan folds to 'drsn' = trisanaa (thirst/desire) — opposite meaning; anchor to
    # the real word. sewa/seva fold to 'sv' which is dominated by sabh (all). Route both
    # to their canonical translit so these two most-searched terms resolve cleanly.
    'darshan': ('translit', ['darasan']), 'darshana': ('translit', ['darasan']),
    'sewa': ('translit', ['sevaa']), 'seva': ('translit', ['sevaa']), 'sewaa': ('translit', ['sevaa']),
    # Modern spoken Hindi/Punjabi verb perfectives -> Gurbani canonical forms. The variant
    # engine emits -iaa/-aaiaa but misses the -io ending (gaya->gaiaa but not gaio), so a
    # remembered line like 'kanthe rah gaya ram' (ਕਾਂਠੈ ਰਹਿ ਗਇਓ ਰਾਮੁ) failed to resolve.
    # Each maps to its two commonest canonical spellings (the per-token cap is 2).
    'gaya': ('translit', ['gaio', 'gaiaa']), 'gaiya': ('translit', ['gaio', 'gaiaa']),
    'gayi': ('translit', ['gaee', 'gaiaa']), 'gayee': ('translit', ['gaee', 'gaiaa']),
    'hua': ('translit', ['hoaa', 'hoiaa']), 'hoya': ('translit', ['hoaa', 'hoiaa']),
    'raha': ('translit', ['rahio', 'rahiaa']), 'rahaa': ('translit', ['rahio', 'rahiaa']),
    'kaha': ('translit', ['kahio', 'kahiaa']), 'kahaa': ('translit', ['kahio', 'kahiaa']),
    'kiya': ('translit', ['keeaa', 'keeo']), 'kia': ('translit', ['keeaa', 'keeo']),
    'kiaa': ('translit', ['keeaa', 'keeo']), 'keeya': ('translit', ['keeaa', 'keeo']),
    'aaya': ('translit', ['aaio', 'aaiaa']), 'aya': ('translit', ['aaio', 'aaiaa']),
    'diya': ('translit', ['deeo', 'deeaa']), 'dia': ('translit', ['deeo', 'deeaa']),
    'liya': ('translit', ['leeo', 'leeaa']), 'lia': ('translit', ['leeo', 'leeaa']),
    'bhaya': ('translit', ['bhaio', 'bhaiaa']), 'bhaia': ('translit', ['bhaio', 'bhaiaa']),
    'paya': ('translit', ['paaio', 'paaiaa']), 'paaya': ('translit', ['paaio', 'paaiaa']),
    # casual short renderings that otherwise resolve to the WRONG canonical and poison the
    # AND: 'sai' is a rare word, but the user means ਸਾਈ saaee / ਸਾਈਂ saaeen (Lord/Master).
    'sai': ('translit', ['saaee', 'saaeen']), 'sain': ('translit', ['saaeen', 'saaee']),
    'saeen': ('translit', ['saaeen', 'saaee']), 'saai': ('translit', ['saaee', 'saaeen']),
    'karoh': ('translit', ['karah']), 'karo': ('translit', ['karah', 'kar']),
    'farid': ('translit', ['phareed', 'phareedaa']), 'krishna': ('translit', ['krisan']),
    'sita': ('translit', ['seetaa']), 'dhru': ('translit', ['dhroo']),
    'prahlad': ('translit', ['prahilaad', 'prahalaad']), 'ravan': ('translit', ['raavan']),
    'brahma': ('translit', ['brahamaa']), 'shiva': ('translit', ['siv']), 'shiv': ('translit', ['siv']),
    'indra': ('translit', ['indr', 'ind']), 'yashoda': ('translit', ['jasodaa', 'jasudaa']),
    'yamuna': ('translit', ['jamunaa']), 'waheguru': ('translit', ['vaahiguroo']),
    'allah': ('translit', ['alah']), 'khuda': ('translit', ['khudaa', 'khudaae']),
    'satnam': ('translit', ['sat naam', 'satinaam']), 'satguru': ('translit', ['satigur']),
    'satnam waheguru': ('translit', ['vaahiguroo', 'sat naam']),
    # 'baba'/'sheikh' is a honorific before Farid; alone 'baba' drops to 1 token (no
    # honorific-drop) and 'farid' folds weakly, so the bigram resolved to a vrata line.
    # Anchor the whole phrase to the canonical 'phareed'. 'sheikh farid' already works.
    'baba farid': ('translit', ['phareed', 'phareedaa']),
    'baba fareed': ('translit', ['phareed', 'phareedaa']),
    # Hindi/Sanskrit spellings whose roman_norm collapses to a 1-char weak fold (maaya->'m',
    # kya->'g'), dropping the distinctive token; anchor to the Gurbani canonical form.
    'maaya': ('translit', ['maaiaa']), 'kya': ('translit', ['kiaa', 'kia']),
    # MODERN POSTPOSITION LAYER (closed class). Hindi/Punjabi का/के/की/को collapse to a weak
    # 1-char fold (ka/ke/ki->'g', ko/kau->'g') so they drop out of the AND, AND they differ
    # from the Gurbani spelling the line actually uses (ਕੈ kai / ਕਾ kaa / ਕੇ ke / ਕੀ kee /
    # ਕਉ kau). Anchoring each to its canonical translit restores a STRONG exact discriminator
    # — this is why `jamuna ka kul khel kelio` now resolves to Ang 1403 (jamunaa KAI kool khel
    # khelio) instead of a short BM25 decoy. These five recur on tens of thousands of lines.
    'ka': ('translit', ['kai', 'kaa']), 'ke': ('translit', ['ke', 'kai']),
    'ki': ('translit', ['kee', 'ki']), 'kau': ('translit', ['kau', 'ko']),
    'ko': ('translit', ['ko', 'kau']),
    # MODERN PRONOUN / PARTICLE + COMPOUND + NAMED-FIGURE layer (proactive hardening, v2.0.6).
    # Each casual form has 0 corpus lines (no hijack) and each target is canon-verified.
    'mein': ('translit', ['mah', 'vich']), 'me': ('translit', ['mah', 'vich']),  # में/मैं -> ਮਹਿ/ਵਿਚਿ (in)
    'ye': ('translit', ['ih', 'eh']),               # ये -> ਇਹੁ/ਏਹ (this)
    'main': ('translit', ['mai', 'hau']),           # मैं (I) -> ਮੈ/ਹਉ (bare 'main' is ਮੈਣ wax, 2 lines)
    'inka': ('translit', ['tin', 'tinhaa']),        # इनका -> ਤਿਨ (those/their)
    'jivan': ('translit', ['jeevan']),              # जीवन -> ਜੀਵਨੁ ('jivan' itself: 0 corpus lines)
    'mua': ('translit', ['mooaa', 'moaa']),         # मुआ -> ਮੂਆ (died); its fold 'm' was weak-dropped
    'keertan': ('translit', ['keeratan']),          # ਕੀਰਤਨ ('keertan' spelling resolved empty)
    'raidas': ('translit', ['ravidaas']),           # Bhagat ਰਵਿਦਾਸ — common alt spelling, was 0 results
    'waheguruji': ('translit', ['vaahiguroo']),     # space-collapsed जपੁ form
    'sachkhand': ('translit', ['sach khand']),      # ਸਚ ਖੰਡ — space-collapsed compound
    'kirtan sohila': ('translit', ['sohilaa']),     # bani name -> ਸੋਹਿਲਾ
    'onkar': ('translit', ['oankaar']), 'ikonkar': ('translit', ['oankaar']),
    'rabb': ('translit', ['har', 'raam']), 'rab': ('translit', ['har', 'raam']),
    'dard': ('translit', ['dukh']), 'dil': ('translit', ['man']),
    'khushi': ('translit', ['sukh']), 'satsang': ('translit', ['saadhasang', 'sang']),
    'ocean': ('translit', ['saagar']), 'name': ('translit', ['naam']),
}

def lexicon_search(q, limit, offset):
    entry = SEEKER_LEXICON.get(q.strip().lower())
    if not entry: return None
    kind, val = entry
    if kind == 'theme':
        t = theme_search(val, limit, offset)
        return t if t['results'] else None
    for term in val:
        res = search_fts('translit', term, False, limit, offset)
        if res: return {'mode': f'seeker-lexicon ({term})', 'results': res}
    return None

_TERM2CONCEPT = None
_concept_lock = threading.Lock()
def term_concepts(tokens):
    """Map any query token to its theme(s) — the corpus-verified concept index."""
    global _TERM2CONCEPT
    if _TERM2CONCEPT is None:
        # Double-checked lock: ThreadingHTTPServer can race two first-requests here, and
        # building into the module global directly would let a second thread observe a
        # half-built dict (silently missing concept hits). Build a local, publish atomically.
        with _concept_lock:
            if _TERM2CONCEPT is None:
                d = {}
                for name, terms in db().execute('SELECT concept, gurmukhi_terms FROM concepts'):
                    for t in json.loads(terms):
                        d.setdefault(t, []).append(name)
                _TERM2CONCEPT = d
    hits = []
    for t in tokens:
        for c in _TERM2CONCEPT.get(t, ()):
            if c not in hits: hits.append(c)
    return hits

def search_like(col, q, limit, offset):
    if col not in _FTS_COLS: raise ValueError(f'invalid column: {col}')
    pat = '%' + '%'.join(q.split()) + '%'
    sql = f"SELECT {LINE_COLS} FROM lines WHERE {col} LIKE ? ORDER BY id LIMIT ? OFFSET ?"
    return rows_to_list(db().execute(sql, (pat, limit, offset)).fetchall())

PUNCT_RE = re.compile(r'[॥।.,;:!?"\'()\[\]{}|/\\-]+')

def do_search(q, mode, limit, offset):
    if len(q) > 300: raise ValueError('query too long (max 300 chars)')
    q = PUNCT_RE.sub(' ', q).strip()          # dandas & punctuation are separators
    q = re.sub(r'\s+', ' ', q)
    if not q: return {'mode': mode, 'results': []}
    global HAVE_FTS
    if HAVE_FTS is None: HAVE_FTS = have_fts()
    toks = q.split()
    is_gurmukhi = bool(GURMUKHI.search(q))

    def run(col, phrase=False):
        if HAVE_FTS: return search_fts(col, q, phrase, limit, offset)
        return search_like('text' if col == 'text' else col, q, limit, offset)

    latin_present = bool(re.search('[a-zA-Z]', q))
    if mode == 'auto' and is_gurmukhi and latin_present:
        ms = mixed_search(q, limit, offset)
        if ms: return {'mode': 'mixed-script', 'results': ms}
        q_lat = ' '.join(t for t in toks if not GURMUKHI.search(t))
        if q_lat:
            sub = do_search(q_lat, 'auto', limit, offset)   # drop Gurmukhi tokens, retry
            if sub.get('results'):
                sub['mode'] = 'mixed-script (latin part: ' + sub['mode'] + ')'
                return sub
    # explicit modes
    if mode == 'gurmukhi':
        res = run('text'); used = 'gurmukhi'
        if not res and HAVE_FTS:
            res = search_like('skeleton', re.sub('[ਾਿੀੁੂੇੈੋੌੰਂ੍]', '', q), limit, offset); used = 'gurmukhi-skeleton'
    elif mode == 'roman':
        res = run('translit'); used = 'roman'
        if not res and HAVE_FTS:
            strong = ' '.join(t for t in roman_norm(q).split() if len(t) >= 2)
            if strong:
                res = search_fts('translit_norm', strong, False, limit, offset, no_headers=True)
                used = 'roman-spelling-tolerant'
    elif mode == 'first':
        col = 'fl_g' if is_gurmukhi else 'fl_r'
        res = run(col, phrase=True); used = 'first-letters'
    elif mode == 'theme':
        return theme_search(q, limit, offset)
    elif mode == 'english':
        res = search_en(q, limit, offset); used = 'english'
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
            if not res:                                   # curated seeker words
                lx = lexicon_search(q, limit, offset)
                if lx: return lx
            if not res:                                   # precomputed variant index
                vr = variant_search(q, limit, offset)
                if vr: return {'mode': 'variant-match', 'results': vr}
            if not res:                                   # English layer before fold:
                res = search_en(q, limit, offset)         # 'mercy' must hit translations,
                used = 'english-translation'              # not fold-collide with ਮੋਰਚਾ
            if not res:                                   # hallucinated honorifics: retry early
                kept = [t for t in toks if t.lower() not in
                        {'ji','jee','jeo','jio','sahib','maharaj','maharaaj','shri','shree','sri','baba','guru','dev','waale','wale'}]
                if 2 <= len(kept) < len(toks):
                    sub = do_search(' '.join(kept), 'auto', limit, offset)
                    if sub.get('results'):
                        sub['mode'] = sub['mode'] + ' (honorifics dropped)'
                        return sub
            if not res and len(toks) >= 3:                # quote spans ॥ lines —
                ps = passage_search(q, limit, offset)     # shabad-level AND is more
                if ps: return {'mode': 'passage-match (quote spans lines)', 'results': ps}   # precise than per-line fold
            if not res and HAVE_FTS:
                strong = ' '.join(t for t in roman_norm(q).split() if len(t) >= 2)
                if strong:
                    res = search_fts('translit_norm', strong, False, limit, offset, no_headers=True)
                    used = 'roman-spelling-tolerant'
            if not res and len(toks) <= 14:               # blob targets short/spaceless smash; only an
                bl = blob_search(q, limit, offset)        # absurd 15+ token paste can't collapse to one
                if bl: return {'mode': 'skeleton-blob', 'results': attach_translations(bl)}  # blob line — skip just those
            if not res and len(toks) == 1:
                t = theme_search(q, limit, offset)
                if t['results']: return t
    HONORIFICS = {'ji', 'jee', 'jeo', 'sahib', 'maharaj', 'maharaaj', 'shri', 'shree',
                  'sri', 'baba', 'guru', 'dev', 'waale', 'wale', 'jio'}
    if len(res) < 3 and mode == 'auto':
        kept = [t for t in toks if t.lower() not in HONORIFICS]
        if len(kept) >= 2 and len(kept) < len(toks):
            sub = do_search(' '.join(kept), 'auto', limit, offset)
            if sub.get('results'):
                seen = {r['id'] for r in res}
                merged = [r for r in sub['results'] if r['id'] not in seen]
                if not res:
                    sub['mode'] = sub['mode'] + ' (honorifics dropped)'
                    return sub
                res = (res + merged)[:limit]
                used = used + ' + honorific-dropped'
    out = {'mode': used, 'results': res}
    if is_gurmukhi:
        rel = term_concepts(toks)
        if rel: out['related_themes'] = rel[:3]
    return out

def variant_search(q, limit, offset):
    """Precomputed romanization-variant tier (03_Phonetic-Variant-Engine.md).
    HYBRID per-token resolution so one stubborn token can't kill the AND:
      1. variant-index hit        -> translit:(a OR b OR c)   (<=3 by freq*score)
      2. trailing-vowel retry     -> same ('naari' ~ canonical 'naar')
      3. canonical/exact token    -> translit:("t")
      4. otherwise phonetic fold  -> translit_norm:("fold(t)")
    All combined in ONE FTS expression."""
    toks = [t for t in q.lower().split() if t.isalnum()]
    if not toks or len(toks) > 10: return None
    groups = []
    try:
        def lookup(tok):
            return db().execute(
                'SELECT DISTINCT translit FROM variants WHERE variant = ? '
                'ORDER BY freq * score DESC LIMIT 3', (tok,)).fetchall()
        weak_skipped = 0
        for t in toks:
            # Token waterfall: EVERY token gets a full OR-group so a mislabeled
            # variant or a strict canonical coincidence can never poison the AND:
            #   (translit:"variant…" OR translit:"self" OR translit:"lexicon" OR translit_norm:"fold")
            alts = []
            rs = lookup(t)
            if not rs and len(t) > 3 and t[-1] in 'aeiou':
                rs = lookup(t[:-1])                  # dropped/extra terminal vowel
            if not rs and len(t) > 3 and t[-1] in 'nm' and t[-2] in 'aeiou':
                rs = lookup(t[:-1])                  # user-added nasal: main -> mai
            base_sfx = None
            if not rs:
                for suf in ('ing', 'ed', 'es', 'er', 's'):   # English morphology: boling -> bol
                    if t.endswith(suf) and len(t) > len(suf) + 2:
                        base_sfx = t[:-len(suf)]
                        rs = lookup(base_sfx)
                        if rs: break
            for r in rs:
                alts.append(f'translit: "{_fts_clean(r[0])}"')
            def is_canon(tok):
                try:
                    return db().execute('SELECT 1 FROM canon_tokens WHERE token = ?', (tok,)).fetchone()
                except sqlite3.OperationalError:
                    return db().execute('SELECT 1 FROM variants WHERE translit = ? LIMIT 1', (tok,)).fetchone()
            for cand in (t, t[:-1] if len(t) > 3 and t[-1] in 'aeiounm' else None, base_sfx):
                if cand and is_canon(cand):
                    alts.append(f'translit: "{cand}"')
            if t[-1] in 'aiu':                       # ki~kee, jo~joo, sada~sadaa
                long_v = t[:-1] + {'a': 'aa', 'i': 'ee', 'u': 'oo'}[t[-1]]
                if is_canon(long_v):
                    alts.append(f'translit: "{long_v}"')
            lx = SEEKER_LEXICON.get(t)               # satnam -> "sat naam" phrase
            if lx and lx[0] == 'translit':
                for term in lx[1][:2]:
                    alts.append(f'translit: "{term}"')
            fn = roman_norm(t)
            # EXACT folds, never prefix. A prefix wildcard on a short fold-skeleton
            # over-matches catastrophically: query 'dhara'->'dr' would prefix-match
            # 'teerath'->'drd', so `hamra dhara har` wrongly surfaced Ang 1142 above the
            # true Ang 366 (whose 'dharhaa' folds to exactly 'dr'). fold_match_alts adds
            # only the exact fold + its initial-vowel twin (oopar~upar). Typo-tail recall
            # is carried by the curated layers above (variants, canon_tokens, long-vowel
            # twins, nasal-trim, suffix-strip, lexicon) — not by a blunt wildcard.
            alts += fold_match_alts(fn)
            if alts:
                groups.append('(' + ' OR '.join(alts) + ')')
            elif fn:                                 # only a 1-char fold: weak token
                weak_skipped += 1                    # (jo/so/ha — skip, don't poison)
            else:
                return None
        # Dedupe identical OR-groups. A repeated mantra ("satnam waheguru satnam waheguru")
        # otherwise inflates len(groups) AND the all-but-one threshold (need=N-1), so no line
        # can clear it and the query crashes into the blob tier with junk. Collapse to uniques.
        seen_g, uniq_g = set(), []
        for g in groups:
            if g not in seen_g: seen_g.add(g); uniq_g.append(g)
        had_repeat = len(uniq_g) < len(groups)
        groups = uniq_g
        if not groups or (weak_skipped and len(groups) < 2): return None
        expr = ' AND '.join(groups)
        sql = (f"SELECT {LINE_COLS} FROM lines JOIN "
               f"(SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk "
               f" FROM fts WHERE fts MATCH ?) m ON lines.id = m.rowid "
               f"ORDER BY m.rk, lines.id LIMIT ? OFFSET ?")
        res = rows_to_list(db().execute(sql, (expr, limit, offset)).fetchall())
        if res: return res
        # GRACEFUL ALL-BUT-ONE FALLBACK. The strict AND above is brittle: if any single
        # token resolves to the wrong canonical (e.g. a casual short form we don't cover)
        # it zeroes out the whole multi-word query and the user is dumped into a worse
        # tier. Only when the strict AND found NOTHING, re-rank candidates by HOW MANY
        # groups they satisfy and accept lines matching all-but-one. A line matching every
        # token still wins (highest count); precision holds because we required ≥N-1.
        if len(groups) >= 3 or (had_repeat and len(groups) >= 2):
            or_rows = db().execute(
                f"SELECT {LINE_COLS}, translit_norm FROM lines JOIN "
                f"(SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk "
                f" FROM fts WHERE fts MATCH ?) m ON lines.id = m.rowid "
                f"ORDER BY m.rk LIMIT 150", (' OR '.join(groups),)).fetchall()
            gterms = [re.findall(r'(\w+): "([^"]+)"', g) for g in groups]
            need = len(groups) - 1
            scored = []
            for r in or_rows:
                d = dict(r)
                tw = set((d.get('translit') or '').split())
                nw = set((d.pop('translit_norm') or '').split())
                # a multi-word translit target (e.g. satnam -> "sat naam") matches when
                # all its words are present, not as a single set member
                hits = sum(1 for terms in gterms
                           if any((all(x in tw for x in t.split())) if c == 'translit'
                                  else (t in nw) for c, t in terms))
                if hits >= need: scored.append((hits, d))
            if scored:
                scored.sort(key=lambda x: -x[0])      # most tokens matched first; stable on bm25
                return [d for _, d in scored[offset:offset + limit]]
        return None
    except sqlite3.OperationalError:
        return None

def mixed_search(q, limit, offset):
    """Bilingual blender: Gurmukhi tokens match the text column; latin tokens
    resolve through variants/lexicon/fold — all in one AND expression."""
    toks = q.split()
    if len(toks) > 10: return None
    groups = []
    try:
        for t in toks:
            if GURMUKHI.search(t):
                clean = t.replace('"', '')
                groups.append(f'(text: "{clean}")')
                continue
            t = t.lower()
            if not t.isalnum(): continue
            alts = []
            rs = db().execute('SELECT DISTINCT translit FROM variants WHERE variant = ? '
                              'ORDER BY freq * score DESC LIMIT 3', (t,)).fetchall()
            for r in rs: alts.append(f'translit: "{_fts_clean(r[0])}"')
            try:
                if db().execute('SELECT 1 FROM canon_tokens WHERE token = ?', (t,)).fetchone():
                    alts.append(f'translit: "{t}"')
            except sqlite3.OperationalError: pass
            lx = SEEKER_LEXICON.get(t)
            if lx and lx[0] == 'translit':
                for term in lx[1][:2]: alts.append(f'translit: "{term}"')
            fn = roman_norm(t)
            alts += fold_match_alts(fn)                                      # exact fold + vowel twin
            if alts: groups.append('(' + ' OR '.join(alts) + ')')
        if len(groups) < 2: return None
        expr = ' AND '.join(groups)
        sql = (f"SELECT {LINE_COLS} FROM lines JOIN "
               f"(SELECT rowid, bm25(fts, 10.0, 5.0, 4.0, 3.0, 3.0, 1.0) AS rk "
               f" FROM fts WHERE fts MATCH ?) m ON lines.id = m.rowid "
               f"ORDER BY m.rk, lines.id LIMIT ? OFFSET ?")
        return attach_translations(rows_to_list(db().execute(sql, (expr, limit, offset)).fetchall())) or None
    except sqlite3.OperationalError:
        return None

def passage_search(q, limit, offset):
    """Cross-line passage tier: user quotes a couplet spanning ॥ boundaries
    (ਜੀਵਤ ਜੋ ਮਰੈ ਹਾਂ ॥ ਦੁਤਰੁ ਸੋ ਤਰੈ ਹਾਂ ॥ is TWO corpus lines). Folded tokens
    are matched at SHABAD level; the shabad's lines are returned in order."""
    toks = [roman_norm(t) for t in q.lower().split() if t.isalnum()]
    toks = [t for t in toks if len(t) >= 2]   # 1-char folds (jo→j, ha→h) are noise
    if len(toks) < 3: return None
    # EXACT folds, not prefix: 2-3 char skeletons (jvd/mr/dr) prefix-match hundreds
    # of words, exploding the match set and burying the true couplet — Ang 410 fell
    # from bm25 rank #20 to #42, out of the LIMIT-25 window. Typo-tail queries
    # resolve at the variant/waterfall tier before reaching here; the seq-gate below
    # stays prefix-aware so in-order verification still tolerates tails.
    m = ' AND '.join(f'"{t}"' for t in toks)
    try:
        cand = db().execute(
            'SELECT comp_id, tnorm, rank FROM fts_shabad WHERE fts_shabad MATCH ? '
            'ORDER BY rank LIMIT 60', (m,)).fetchall()   # 60 not 40: a true line can sit
        if not cand: return None                          # past rank 40 in a long shabad
        seq = re.compile(r'\b' + r'\w*\b.*?\b'.join(re.escape(t) for t in toks) + r'\w*')
        # Rank by the SPAN of the tightest in-order match (non-greedy `.*?` finds the
        # shortest). A genuine quote keeps its words contiguous; a coincidental scatter
        # across a long shabad spans hundreds. Score the span PER LINE — a quote normally
        # sits inside ONE line — and fall back to the whole-shabad tnorm only when no
        # single line carries the full in-order match, i.e. a true cross-line couplet
        # (Ang 410: ਜੀਵਤ ਜੋ ਮਰੈ ਹਾਂ ॥ / ਦੁਤਰੁ ਸੋ ਤਰੈ ਹਾਂ ॥). Per-line scoring stops one
        # incidental short-fold hit elsewhere in a long shabad from inflating the span and
        # sinking the real line (`jaisee aag…` Ang 921 fell to span 3495 / rank #4 before).
        comp_ids = [r[0] for r in cand]
        ph = ','.join('?' * len(comp_ids))
        line_norms = {}
        for cid, tn in db().execute(
                f'SELECT comp_id, translit_norm FROM lines '
                f'WHERE comp_id IN ({ph}) AND is_header = 0', comp_ids).fetchall():
            line_norms.setdefault(cid, []).append(tn or '')
        scored = []
        for r in cand:
            cid, shabad_tn = r[0], (r[1] or '')
            best = None
            for ln in line_norms.get(cid, ()):            # tightest single-line match
                mt = seq.search(ln)
                if mt:
                    s = len(mt.group(0))
                    if best is None or s < best: best = s
            if best is None:                              # cross-line couplet: whole shabad
                mt = seq.search(shabad_tn)
                if mt: best = len(mt.group(0))
            if best is not None:
                scored.append((best, r[2], cid))          # (span, bm25, comp_id)
        if not scored: return None                    # no in-order match: abstain, never junk
        scored.sort(key=lambda x: (x[0], x[1]))        # tightest span, then bm25 relevance
        cids = [s[2] for s in scored[:3]]
        fold_set = set(toks)
        out = []
        for cid in cids:
            lines = rows_to_list(db().execute(
                f'SELECT {LINE_COLS}, translit_norm FROM lines '
                f'WHERE comp_id = ? AND is_header = 0 ORDER BY id', (cid,)).fetchall())
            # BUBBLE the matched line(s) to the absolute top. A long Salok block is one
            # comp_id spanning dozens of lines; returning them chronologically buried the
            # real hit (e.g. ਕਾਂਠੈ ਰਹਿ ਗਇਓ ਰਾਮੁ was #6 under 5 preceding verses). Rank:
            #   1. the line that carries the full in-order quote (_seq) — the exact answer
            #   2. then by how many query folds the line carries (_hits)
            #   3. then reading order (id)
            # Non-matching lines follow as context in reading order. A true cross-line
            # couplet has _seq=0 on every single line (the match spans two) but _hits>0 on
            # both tuks, so both still lead, in order.
            for l in lines:
                tn = l.pop('translit_norm') or ''
                l['_hits'] = sum(1 for w in tn.split() if w in fold_set)
                l['_seq'] = 1 if seq.search(tn) else 0
            matched = [l for l in lines if l['_hits'] > 0]
            matched.sort(key=lambda l: (-l['_seq'], -l['_hits'], l['id']))
            context = sorted((l for l in lines if l['_hits'] == 0), key=lambda l: l['id'])
            per_comp = max(2, limit // max(len(cids), 1))   # every top shabad surfaces
            keep = (matched + context)[:per_comp]
            for l in keep: l.pop('_hits', None); l.pop('_seq', None)
            out += keep                                     # matched line(s) first, no re-sort
        return attach_translations(out[offset:offset + limit]) or None
    except sqlite3.OperationalError:
        return None

def blob_search(q, limit, offset):
    """Desperate tier: keyboard-smash / spaceless input. Collapse the whole query
    to a fold-skeleton blob; prefilter lines by the blob's head, then fuzzy-rank."""
    nb = ''.join(roman_norm(q).split())
    if len(nb) < 8: return None
    import difflib
    try:
        cands, seen_ids = [], set()
        for w in (nb[:5], nb[2:7], nb[4:9]):
            if len(w) < 4: continue
            for r in db().execute(
                    f"SELECT {LINE_COLS}, norm_blob FROM lines WHERE is_header=0 "
                    f"AND norm_blob LIKE ? LIMIT 300", ('%' + w + '%',)).fetchall():
                if r['id'] not in seen_ids:
                    seen_ids.add(r['id']); cands.append(r)
        scored = []
        for r in cands:
            ratio = difflib.SequenceMatcher(None, nb, r['norm_blob'] or '').ratio()
            if ratio >= 0.55: scored.append((ratio, dict(r)))
        if not scored: return None
        scored.sort(key=lambda x: -x[0])
        out = []
        for _, r in scored[:max(limit, 3)]:
            r.pop('norm_blob', None); out.append(r)
        return out[offset:offset + limit] or None
    except sqlite3.OperationalError:
        return None

def search_en(q, limit, offset):
    """Search the labeled English translation layer (Dr. Sant Singh Khalsa)."""
    m = fts_query(q.split())
    if not m: return []
    try:
        rs = db().execute(
            f"SELECT {LINE_COLS}, e.text AS en FROM "
            f"(SELECT line_id, text, bm25(fts_en) AS rk FROM fts_en WHERE fts_en MATCH ?) e "
            f"JOIN lines ON lines.id = e.line_id ORDER BY e.rk LIMIT ? OFFSET ?",
            (m, limit, offset)).fetchall()
        return rows_to_list(rs)
    except sqlite3.OperationalError:
        return []

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

def api(path, qs):
    p = [x for x in path.split('/') if x][1:]   # drop 'api'
    if not p:
        raise ValueError('missing endpoint')
    if p[0] in ('ang', 'shabad') and len(p) < 2:
        raise ValueError(f'/api/{p[0]} requires an id')
    global HAVE_FTS, _META_CACHE                 # ensure FTS detection for EVERY endpoint
    if HAVE_FTS is None: HAVE_FTS = have_fts()   # (not just /api/search) — /api/word needs it
    if p[0] == 'meta':
        if _META_CACHE is not None: return _META_CACHE   # built once; ~50ms join avoided per load
        m = {r['key']: r['value'] for r in db().execute('SELECT * FROM meta')}
        m['db_version'] = m.get('version')          # honest record of the DB build
        m['version'] = APP_VERSION or m.get('version')   # footer shows the running code build
        m['built'] = APP_BUILT or m.get('built')
        m['commit'] = APP_COMMIT
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
        _META_CACHE = m
        return m
    if p[0] == 'search':
        q = qs.get('q', [''])[0]
        # clamp both ends: a negative limit is `LIMIT -1` in SQLite = no limit (full-corpus
        # dump); a negative offset is silently treated as 0. Bound them to a sane window.
        limit = _int(qs, 'limit', 50, 0, 200)
        offset = _int(qs, 'offset', 0, 0, 1_000_000)      # corpus has 60,658 lines: lossless
        out = do_search(q, qs.get('mode', ['auto'])[0], limit, offset)
        attach_translations(out.get('results'))     # en for EVERY mode (FTS/variant/theme tiers
        out.setdefault('related_themes', [])         # skipped it); uniform contract for the UI
        return out
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
        cid = _int_str(p[1], 0, _ID_MAX)
        rs = db().execute(f'SELECT {LINE_COLS} FROM lines WHERE comp_id = ? ORDER BY id', (cid,)).fetchall()
        if not rs:
            raise ApiError(404, f'no composition with comp_id {cid}')
        return {'comp_id': cid, 'lines': attach_translations(rows_to_list(rs))}
    if p[0] == 'health':
        h = {'version': None, 'checks': {}, 'ok': True}
        def check(name, cond):
            h['checks'][name] = bool(cond)
            if not cond: h['ok'] = False
        m = {k: v for k, v in db().execute('SELECT * FROM meta')}
        h['version'] = APP_VERSION or m.get('version')
        h['db_version'] = m.get('version')
        h['built'] = APP_BUILT or m.get('built')
        h['commit'] = APP_COMMIT
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
        return hukam_package()                  # complete structural unit, not a comp fragment
    if p[0] == 'verify':
        q = qs.get('q', [''])[0].strip()
        if not q: raise ValueError('empty claim')
        ang_q = qs.get('ang', [None])[0]
        ang_n = int(ang_q) if ang_q else None
        return verify_claim(q, ang=ang_n, db_path=DB)
    if p[0] == 'word':
        w = _fts_clean(qs.get('w', [''])[0].strip())   # a bare " in MATCH -> OperationalError 500
        n = db().execute('SELECT n FROM word_freq WHERE word = ?', (w,)).fetchone()
        rs = db().execute(f"SELECT {LINE_COLS} FROM lines WHERE id IN "
                          f"(SELECT rowid FROM fts WHERE text MATCH ?) ORDER BY id LIMIT 100",
                          (f'"{w}"',)).fetchall() if HAVE_FTS else []
        return {'word': w, 'count': n['n'] if n else 0, 'lines': rows_to_list(rs)}
    # ---- Insight Engine (v2.1.0): pure cached SELECTs over the offline-precomputed analytics
    # tables. Additive — these never touch the search path. Each degrades gracefully if the
    # analytics tables are absent (an older DB build). NEVER a ranking/judgement of scripture.
    if p[0] == 'themes' and len(p) >= 2 and p[1] == 'network':
        concept = qs.get('concept', [None])[0]
        try:
            min_ppmi = float(qs.get('min_ppmi', ['0'])[0])
        except (TypeError, ValueError):
            min_ppmi = 0.0
        if not math.isfinite(min_ppmi):     # NaN/inf survive max(min()) (compare False) -> clamp explicitly
            min_ppmi = 0.0
        min_ppmi = max(0.0, min(1.0, min_ppmi))
        lim = _int(qs, 'limit', 200, 1, 2000)
        try:
            if concept:
                rows = db().execute(
                    "SELECT source, target, shabad_count, ppmi, jaccard FROM theme_network "
                    "WHERE source=? AND ppmi>=? ORDER BY ppmi DESC, jaccard DESC LIMIT ?",
                    (concept, min_ppmi, lim)).fetchall()
            else:
                rows = db().execute(
                    "SELECT source, target, shabad_count, ppmi, jaccard FROM theme_network "
                    "WHERE source < target AND ppmi>=? ORDER BY ppmi DESC LIMIT ?",
                    (min_ppmi, lim)).fetchall()
            return {'concept': concept, 'edges': rows_to_list(rows), 'metric': 'ppmi+jaccard',
                    'note': 'theme co-occurrence within shabads; PPMI controls base-rate bias'}
        except sqlite3.OperationalError:
            return {'edges': [], 'note': 'analytics tables not present in this DB build'}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'author':
        author = qs.get('author', [None])[0]
        try:
            if not author:
                rows = db().execute(
                    "SELECT author, n_lines, n_shabads, n_raags, mattr_100, avg_words_line, "
                    "is_reliable FROM author_analytics ORDER BY n_lines DESC").fetchall()
                return {'authors': rows_to_list(rows)}
            st = db().execute("SELECT * FROM author_analytics WHERE author=?", (author,)).fetchone()
            out = dict(st) if st else {}
            if out.get('top_themes'):
                try: out['top_themes'] = json.loads(out['top_themes'])
                except Exception: pass
            fp_lim = 60 if qs.get('full', [None])[0] else 12   # full=1 -> every concept (for radar axes)
            fp = db().execute("SELECT concept, n_tagged, entity_rate, corpus_rate, lift FROM theme_fingerprint "
                              "WHERE entity_type='author' AND entity_id=? ORDER BY lift DESC LIMIT ?", (author, fp_lim)).fetchall()
            dt = db().execute("SELECT term, z_score, rank FROM author_distinctive_terms "
                              "WHERE author=? ORDER BY rank LIMIT 12", (author,)).fetchall()
            return {'author': author, 'stylometry': out, 'theme_fingerprint': rows_to_list(fp),
                    'distinctive_terms': rows_to_list(dt),
                    'note': 'theme emphasis = lift vs corpus baseline; stylometry on the English '
                            'translation; descriptive only, never a ranking of scripture'}
        except sqlite3.OperationalError:
            return {'author': author, 'note': 'analytics tables not present in this DB build'}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'raag':
        raag = qs.get('raag', [None])[0]
        try:
            if not raag:
                return {'raags': rows_to_list(db().execute(
                    "SELECT * FROM raag_analytics ORDER BY n_lines DESC").fetchall())}
            st = db().execute("SELECT * FROM raag_analytics WHERE raag=?", (raag,)).fetchone()
            out = dict(st) if st else {}
            if out.get('top_themes'):
                try: out['top_themes'] = json.loads(out['top_themes'])
                except Exception: pass
            fp = db().execute("SELECT concept, lift, n_tagged FROM theme_fingerprint "
                              "WHERE entity_type='raag' AND entity_id=? ORDER BY lift DESC LIMIT 12", (raag,)).fetchall()
            return {'raag': raag, 'analytics': out, 'theme_fingerprint': rows_to_list(fp)}
        except sqlite3.OperationalError:
            return {'raag': raag, 'note': 'analytics tables not present in this DB build'}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'progression':  # /api/analytics/progression?raag=X
        raag = qs.get('raag', [None])[0]
        bins = _int(qs, 'bins', 36, 8, 80)
        top = _int(qs, 'top', 7, 2, 10)
        if not raag:
            raise ValueError('progression requires a raag')
        try:
            ordered = db().execute(
                "SELECT id, ang FROM lines WHERE raag=? ORDER BY ang, id", (raag,)).fetchall()
            M = len(ordered)
            if M == 0:
                return {'raag': raag, 'concepts': [], 'series': {}, 'bins': 0, 'note': 'no lines in this raag'}
            bins = min(bins, M)
            pos = {r['id']: i for i, r in enumerate(ordered)}
            angs = [r['ang'] for r in ordered]
            # the raag's most-present concepts (volume → readable bands)
            concepts = [r[0] for r in db().execute(
                "SELECT cl.concept, COUNT(*) c FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
                "WHERE l.raag=? GROUP BY cl.concept ORDER BY c DESC LIMIT ?", (raag, top)).fetchall()]
            series = {c: [0] * bins for c in concepts}
            cset = set(concepts)
            for lid, concept in db().execute(
                    "SELECT cl.line_id, cl.concept FROM concept_lines cl JOIN lines l ON l.id=cl.line_id "
                    "WHERE l.raag=?", (raag,)):
                if concept in cset and lid in pos:
                    series[concept][min(bins - 1, pos[lid] * bins // M)] += 1
            lines_per_bin = [0] * bins
            for i in range(M):
                lines_per_bin[min(bins - 1, i * bins // M)] += 1
            ang_axis = [angs[min(M - 1, int((b + 0.5) * M / bins))] for b in range(bins)]
            roman = db().execute("SELECT roman FROM raags WHERE name=?", (raag,)).fetchone()
            return {'raag': raag, 'roman': (roman[0] if roman else ''), 'n_lines': M, 'bins': bins,
                    'concepts': concepts, 'series': series, 'lines_per_bin': lines_per_bin,
                    'ang_axis': ang_axis,
                    'note': 'concept-tag density along the raag in reading order; descriptive only'}
        except sqlite3.OperationalError:
            return {'raag': raag, 'concepts': [], 'series': {}, 'note': 'analytics tables not present'}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'resonance':   # /api/analytics/resonance
        min_lines = _int(qs, 'min_lines', 250, 1, _ID_MAX)
        min_lift = float(qs.get('min_lift', ['1.0'])[0])
        min_edges = _int(qs, 'min_edges', 8, 1, _ID_MAX)
        try:
            nodes = rows_to_list(db().execute(
                "SELECT name AS author, n_lines, first_ang FROM authors WHERE n_lines >= ? "
                "ORDER BY n_lines DESC", (min_lines,)).fetchall())
            names = [n['author'] for n in nodes]
            if not names:
                return {'nodes': [], 'edges': [], 'note': 'no voices meet the size threshold'}
            ph = ','.join('?' * len(names))
            edges = rows_to_list(db().execute(
                f"SELECT src_author AS source, dst_author AS target, edges, mean_score, lift "
                f"FROM author_resonance WHERE src_author <> dst_author AND lift >= ? AND edges >= ? "
                f"AND src_author IN ({ph}) AND dst_author IN ({ph}) ORDER BY lift DESC",
                [min_lift, min_edges] + names + names).fetchall())
            return {'nodes': nodes, 'edges': edges, 'metric': 'lift',
                    'note': 'how often a voice’s lines land semantically nearest another voice’s, '
                            'relative to corpus share (lift); descriptive, never a ranking of scripture'}
        except sqlite3.OperationalError:
            return {'nodes': [], 'edges': [], 'note': 'resonance table not present in this DB build'}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'vaars':      # /api/analytics/vaars (list)
        try:
            rows = rows_to_list(db().execute(
                "SELECT vaar_id, raag, roman, first_ang, last_ang, n_pauris, n_saloks, "
                "pauri_author, salok_authors, cross_author, title FROM vaars ORDER BY first_ang"))
            for r in rows:
                try: r['salok_authors'] = json.loads(r['salok_authors'] or '[]')
                except Exception: r['salok_authors'] = []
            return {'vaars': rows,
                    'note': 'the Vaars — heroic ballads of numbered pauris with flanking saloks; '
                            'structural metadata only, never a ranking of scripture'}
        except sqlite3.OperationalError:
            return {'vaars': [], 'note': 'vaar tables not present in this DB build'}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'vaar':       # /api/analytics/vaar?id=N (anatomy)
        try: vid = _int(qs, 'id', 0, 0, _ID_MAX)
        except ValueError: return {'vaar': None, 'units': []}
        try:
            head = db().execute("SELECT * FROM vaars WHERE vaar_id=?", (vid,)).fetchone()
            if not head:
                return {'vaar': None, 'units': []}
            head = dict(head)
            try: head['salok_authors'] = json.loads(head['salok_authors'] or '[]')
            except Exception: head['salok_authors'] = []
            units = rows_to_list(db().execute(
                "SELECT seq, kind, author, n_lines, pauri_no, first_line_id, ang, theme "
                "FROM vaar_units WHERE vaar_id=? ORDER BY seq", (vid,)))
            return {'vaar': head, 'units': units,
                    'note': 'salok + pauri anatomy in reading order; saloks by a different Guru than the '
                            'pauris are the famous cross-voice editorial structure'}
        except sqlite3.OperationalError:
            return {'vaar': None, 'units': []}
    if p[0] == 'analytics' and len(p) >= 2 and p[1] == 'constellation':   # Concept Constellation
        # No ?concept= → the dropdown list (every concept + its verse count).
        # ?concept=X → X's verses grouped into sub-constellations by each verse's co-themes.
        # Purely read-only over the existing concepts / concept_lines tables; capped (top-k).
        c = qs.get('concept', [''])[0].strip()
        au = qs.get('author', [''])[0].strip()       # optional filter: only verses by this author
        rg = qs.get('raag', [''])[0].strip()          # optional filter: only verses in this raag
        try:
            if not c:
                concepts = rows_to_list(db().execute(
                    "SELECT concept, n FROM ("
                    "  SELECT concept, COUNT(DISTINCT line_id) n FROM concept_lines GROUP BY concept"
                    ") ORDER BY n DESC"))
                authors = [r[0] for r in db().execute(
                    "SELECT DISTINCT author FROM lines WHERE author IS NOT NULL AND author <> '' ORDER BY author")]
                raags = rows_to_list(db().execute("SELECT name, roman FROM raags ORDER BY rowid"))
                return {'concepts': concepts, 'authors': authors, 'raags': raags,
                        'note': 'corpus-verified theme tags; counts are descriptive only'}
            # filter the concept's verses by author/raag if requested (parameterized — no injection)
            where, params = "cl.concept=?", [c]
            if au:
                where += " AND l.author=?"; params.append(au)
            if rg:
                where += " AND l.raag=?"; params.append(rg)
            total = db().execute(
                f"SELECT COUNT(DISTINCT cl.line_id) FROM concept_lines cl JOIN lines l ON l.id=cl.line_id WHERE {where}",
                params).fetchone()[0]
            if not total:
                return {'concept': c, 'author': au, 'raag': rg, 'total': 0, 'clusters': []}
            MAX_CLUSTERS, PER = 9, 40
            rows = db().execute(
                "SELECT co.concept co, l.id, l.ang, l.comp_id, l.gurmukhi "
                "FROM concept_lines cl JOIN concept_lines co ON co.line_id=cl.line_id AND co.concept<>cl.concept "
                f"JOIN lines l ON l.id=cl.line_id WHERE {where} ORDER BY co.concept, l.id", params).fetchall()
            buckets = {}
            for r in rows:
                buckets.setdefault(r['co'], []).append(
                    {'id': r['id'], 'ang': r['ang'], 'comp_id': r['comp_id'], 'gurmukhi': r['gurmukhi']})
            clusters = sorted(({'co': k, 'n': len(v), 'verses': v[:PER]} for k, v in buckets.items()),
                              key=lambda x: x['n'], reverse=True)[:MAX_CLUSTERS]
            return {'concept': c, 'author': au, 'raag': rg, 'total': total, 'clusters': clusters,
                    'note': 'verses carrying this theme (optionally filtered by author/raag), grouped by the '
                            'other theme they most often share; descriptive structure, never a ranking of scripture'}
        except sqlite3.OperationalError:
            return {'concepts': [], 'clusters': [], 'note': 'concept tables not present in this DB build'}
    if p[0] == 'related':                                   # /api/related?comp_id=N
        cid = _int(qs, 'comp_id', 0, 0, _ID_MAX)
        try:
            rows = db().execute(
                "SELECT n.neighbor_comp_id AS comp_id, n.rank, n.score, "
                "(SELECT ang FROM lines WHERE comp_id=n.neighbor_comp_id ORDER BY id LIMIT 1) AS ang, "
                "(SELECT raag FROM lines WHERE comp_id=n.neighbor_comp_id AND raag IS NOT NULL LIMIT 1) AS raag, "
                "(SELECT gurmukhi FROM lines WHERE comp_id=n.neighbor_comp_id AND is_header=0 ORDER BY id LIMIT 1) AS first_line "
                "FROM shabad_neighbors n WHERE n.comp_id=? ORDER BY n.rank", (cid,)).fetchall()
            return {'comp_id': cid, 'related': rows_to_list(rows),
                    'note': 'shabads with the most similar theme profile (corpus-verified themes)'}
        except sqlite3.OperationalError:
            return {'comp_id': cid, 'related': [], 'note': 'analytics tables not present in this DB build'}
    if p[0] == 'lines':                                      # /api/lines?ids=1,2,3  (verbatim text by id)
        raw = qs.get('ids', [''])[0]
        ids = [int(x) for x in raw.split(',') if x.strip().isdigit() and len(x.strip()) <= 12][:300]
        rows = []
        if ids:
            ph = ','.join('?' * len(ids))
            rows = rows_to_list(db().execute(
                f"SELECT id, ang, comp_id, gurmukhi, translit FROM lines WHERE id IN ({ph}) ORDER BY id", ids))
        return {'lines': rows, 'note': 'verbatim Gurmukhi by line id, cited by Ang'}
    if p[0] == 'line_concepts':                              # /api/line_concepts?ids=1,2,3  (Study Trail)
        raw = qs.get('ids', [''])[0]
        ids = [int(x) for x in raw.split(',') if x.strip().isdigit() and len(x.strip()) <= 12][:300]
        out = {}
        if ids:
            ph = ','.join('?' * len(ids))
            try:
                for lid, concept in db().execute(
                        f"SELECT line_id, concept FROM concept_lines WHERE line_id IN ({ph})", ids):
                    out.setdefault(str(lid), []).append(concept)
            except sqlite3.OperationalError:
                pass
        return {'concepts': out, 'note': 'corpus-verified theme tags per line; descriptive only'}
    if p[0] == 'neighbors':                                  # /api/neighbors?line_id=N  (Phase 2: semantic)
        lid = _int(qs, 'line_id', 0, 0, _ID_MAX)
        lim = _int(qs, 'limit', 10, 1, 50)
        srow = db().execute("SELECT id, ang, raag, author, comp_id, gurmukhi, translit "
                            "FROM lines WHERE id=?", (lid,)).fetchone()
        src_line = attach_translations([dict(srow)])[0] if srow else None   # the queried verse itself
        try:                                                 # preferred: line-level embedding neighbours
            rows = db().execute(
                "SELECT n.neighbor_id AS id, n.score, l.ang, l.raag, l.author, l.comp_id, "
                "l.gurmukhi, l.translit FROM line_neighbors n JOIN lines l ON l.id = n.neighbor_id "
                "WHERE n.line_id = ? ORDER BY n.score DESC LIMIT ?", (lid, lim)).fetchall()
            if rows:
                src = db().execute(
                    "SELECT value FROM analytics_meta WHERE key='line_neighbors_source'").fetchone()
                return {'line_id': lid, 'level': 'line', 'source': (src[0] if src else 'unknown'),
                        'line': src_line, 'neighbors': attach_translations(rows_to_list(rows)),
                        'note': 'lines whose English meaning is closest by embedding cosine; '
                                'descriptive, never a ranking of scripture'}
        except sqlite3.OperationalError:
            pass
        try:                                                 # fallback: composition-level theme profile
            row = db().execute("SELECT comp_id FROM lines WHERE id=?", (lid,)).fetchone()
            if not row:
                return {'line_id': lid, 'level': 'none', 'neighbors': []}
            cid = row[0]
            rows = db().execute(
                "SELECT n.neighbor_comp_id AS comp_id, n.rank, n.score, "
                "(SELECT ang FROM lines WHERE comp_id=n.neighbor_comp_id ORDER BY id LIMIT 1) AS ang, "
                "(SELECT raag FROM lines WHERE comp_id=n.neighbor_comp_id AND raag IS NOT NULL LIMIT 1) AS raag, "
                "(SELECT gurmukhi FROM lines WHERE comp_id=n.neighbor_comp_id AND is_header=0 ORDER BY id LIMIT 1) AS gurmukhi "
                "FROM shabad_neighbors n WHERE n.comp_id=? ORDER BY n.rank LIMIT ?", (cid, lim)).fetchall()
            return {'line_id': lid, 'level': 'composition', 'source': 'shabad-theme-profile',
                    'line': src_line, 'neighbors': rows_to_list(rows),
                    'note': 'line-level semantic vectors not built yet — showing compositions with the '
                            'closest theme profile. Run pipeline/build_semantic_vectors.py for line-level results'}
        except sqlite3.OperationalError:
            return {'line_id': lid, 'level': 'none', 'line': src_line, 'neighbors': []}
    # ---- Raag Timing knowledge layer (v2.12.0): attributed CLAIMS with citations,
    # never facts — divergent traditions coexist as rows. Pure cached SELECTs over
    # additive tables; degrades to {'available': False} when the layer is absent
    # (older DB build / iOS-derived DB). Metadata about raags only — never scripture.
    if p[0] == 'timing' and len(p) >= 2 and p[1] == 'clock':
        global _TIMING_CACHE
        if _TIMING_CACHE is not None: return _TIMING_CACHE
        try:
            rows = rows_to_list(db().execute(
                "SELECT c.raag_name, r.roman, r.first_ang, r.seq, c.claim_type, c.pahar, "
                "       c.time_start, c.time_end, c.season, c.occasion, c.confidence, c.notes, "
                "       s.name AS source_name, s.tradition, s.url AS source_url "
                "FROM raag_timing_claims c "
                "JOIN timing_sources s ON s.id = c.source_id "
                "JOIN raags r ON r.name = c.raag_name "
                "ORDER BY r.seq, c.claim_type, c.pahar").fetchall())
            out = {'available': True,
                   'pahar_convention': 'pahar 1 = 06:00-09:00 ... pahar 8 = 03:00-06:00 '
                                       '(fixed-clock rendering, 6 AM anchor); pahar 7 '
                                       '(00:00-03:00) deliberately has no raags',
                   'claims': {t: [c for c in rows if c['claim_type'] == t]
                              for t in ('primary', 'variant', 'seasonal', 'ceremonial')},
                   'note': 'attributed scholarly claims with citations; divergence is '
                           'preserved, never adjudicated'}
            _TIMING_CACHE = out
            return out
        except sqlite3.OperationalError:
            return {'available': False, 'note': 'timing layer not present in this DB build'}
    if p[0] == 'timing' and len(p) >= 2 and p[1] == 'raag':    # /api/timing/raag?name=<roman|gurmukhi>
        name = qs.get('name', [''])[0].strip()
        if not name:
            raise ValueError('timing/raag requires ?name=')
        try:
            r = db().execute("SELECT name, roman, first_ang FROM raags WHERE name=? OR roman=?",
                             (name, name.lower())).fetchone()
            if not r:
                return {'available': True, 'raag': name, 'claims': [],
                        'note': 'no such raag'}
            claims = rows_to_list(db().execute(
                "SELECT c.claim_type, c.pahar, c.time_start, c.time_end, c.season, "
                "       c.occasion, c.confidence, c.notes, s.name AS source_name, "
                "       s.tradition, s.url AS source_url "
                "FROM raag_timing_claims c JOIN timing_sources s ON s.id = c.source_id "
                "WHERE c.raag_name = ? ORDER BY c.claim_type, c.pahar", (r['name'],)).fetchall())
            return {'available': True, 'raag': r['name'], 'roman': r['roman'],
                    'first_ang': r['first_ang'], 'claims': claims}
        except sqlite3.OperationalError:
            return {'available': False, 'raag': name, 'claims': []}
    if p[0] == 'timing' and len(p) >= 2 and p[1] == 'divergence':
        try:
            names = [r[0] for r in db().execute(
                "SELECT raag_name FROM raag_timing_claims "
                "WHERE claim_type IN ('primary','variant') "
                "GROUP BY raag_name "
                # divergence = different SOURCES disagreeing; a same-source
                # multi-pahar row (e.g. Bilaval extending 1st->2nd) is an
                # extension, not a dispute
                "HAVING SUM(claim_type = 'variant') > 0 "
                "    OR (COUNT(DISTINCT COALESCE(pahar, -1)) > 1 "
                "        AND COUNT(DISTINCT source_id) > 1) "
                "ORDER BY MIN((SELECT seq FROM raags WHERE name = raag_name))").fetchall()]
            out = []
            for n in names:
                claims = rows_to_list(db().execute(
                    "SELECT c.claim_type, c.pahar, c.time_start, c.time_end, c.occasion, "
                    "       c.confidence, c.notes, s.name AS source_name, s.tradition, "
                    "       s.url AS source_url "
                    "FROM raag_timing_claims c JOIN timing_sources s ON s.id = c.source_id "
                    "WHERE c.raag_name = ? AND c.claim_type IN ('primary','variant') "
                    "ORDER BY c.claim_type, c.pahar", (n,)).fetchall())
                r = db().execute("SELECT roman, first_ang, seq FROM raags WHERE name=?",
                                 (n,)).fetchone()
                out.append({'raag': n, 'roman': r['roman'], 'first_ang': r['first_ang'],
                            'claims': claims})
            return {'available': True, 'raags': out,
                    'note': 'raags where traditions disagree on timing; every claim '
                            'cited — disagreement is preserved scholarship, not error'}
        except sqlite3.OperationalError:
            return {'available': False, 'raags': []}
    if p[0] == 'forms':                                        # /api/forms?comp_id=N
        cid = _int(qs, 'comp_id', 0, 0, _ID_MAX)
        if cid <= 0:
            raise ValueError('forms requires ?comp_id=')
        try:
            row = db().execute(
                "SELECT m.comp_id, m.raag_name, m.first_ang, "
                "       mm.ghar, mm.partaal, mm.has_rahao, mm.has_rahao_dooja, "
                "       mm.dhunni, mm.jati, "
                "       sf.form, sf.pada_count, pg.genre, mm.source_label "
                "FROM shabd_raag_map m "
                "LEFT JOIN shabd_musical_markers mm ON mm.comp_id = m.comp_id "
                "LEFT JOIN shabd_structural_form sf ON sf.comp_id = m.comp_id "
                "LEFT JOIN shabd_poetic_genre pg ON pg.comp_id = m.comp_id "
                "WHERE m.comp_id = ?", (cid,)).fetchone()
            if not row:
                return {'available': True, 'comp_id': cid, 'forms': None}
            return {'available': True, 'comp_id': cid, 'forms': dict(row),
                    'note': 'derived only from headings present in the verified text; '
                            'NULL means the heading states no form — never guessed'}
        except sqlite3.OperationalError:
            return {'available': False, 'comp_id': cid, 'forms': None}
    raise ValueError('unknown endpoint')

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _sec_headers(self):
        # Defence-in-depth for the local app. No strict CSP on purpose: the UI relies on
        # inline event handlers + an inline pre-paint theme script, which a strict policy
        # would break; nosniff/frame-deny/no-referrer are safe and unconditional.
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Referrer-Policy', 'no-referrer')

    def _respond(self, status, body, ct):
        self.send_response(status)
        self.send_header('Content-Type', ct)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self._sec_headers()
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    # ---- static-file serving (Astro MPA build under ./static) ----
    _TEXTY = ('text/html', 'text/css', 'text/javascript', 'application/javascript',
              'application/json', 'application/manifest+json', 'image/svg+xml')

    def _static_error(self, code):
        # Prefer the styled Astro 404 page when the build provides it; fall back to plain text.
        if code == 404:
            page = os.path.join(STATIC_ROOT, '404.html')
            if os.path.isfile(page):
                with open(page, 'rb') as f:
                    body = f.read()
                self.send_response(404)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.send_header('Cache-Control', 'no-store')
                self._sec_headers()
                self.end_headers()
                if self.command != 'HEAD':
                    self.wfile.write(body)
                return
        msg = {403: b'403 Forbidden', 404: b'404 Not Found'}.get(code, b'error')
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', str(len(msg)))
        self.send_header('Cache-Control', 'no-store')
        self._sec_headers()
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(msg)

    def _resolve_static(self, url_path):
        """Map a URL path to a real file under STATIC_ROOT, or None.
        Resolves MPA routes (/reader -> reader/index.html, / -> index.html) and
        guards against path traversal by requiring the realpath to stay inside
        STATIC_ROOT (the os.sep test avoids a /static-sibling prefix false match;
        realpath defeats '..' and symlink escapes; %-encoded dots are never decoded
        here, so they simply fail to resolve)."""
        rel = url_path.lstrip('/')
        cands = ['index.html'] if rel == '' else [rel, os.path.join(rel, 'index.html')]
        for c in cands:
            full = os.path.realpath(os.path.join(STATIC_ROOT, c))
            if full != STATIC_ROOT and not full.startswith(STATIC_ROOT + os.sep):
                continue                                   # outside the jail — reject
            if os.path.isfile(full):
                return full
        return None

    def _serve_static(self, url_path):
        full = self._resolve_static(url_path)
        if not full:
            return self._static_error(404)
        ct = mimetypes.guess_type(full)[0] or 'application/octet-stream'
        if ct in self._TEXTY:
            ct += '; charset=utf-8'
        # hashed build assets are content-addressed -> cache forever; HTML must revalidate
        rel = os.path.relpath(full, STATIC_ROOT)
        top = rel.split(os.sep)[0]
        if top == '_astro':
            cache = 'public, max-age=31536000, immutable'
        elif top == 'fonts':                       # unhashed filename → revalidate daily, not immutable
            cache = 'public, max-age=86400'
        elif rel == 'contributors.json':
            cache = 'public, max-age=3600'
        else:
            cache = 'no-store'
        with open(full, 'rb') as f:
            body = f.read()
        self.send_response(200)
        self.send_header('Content-Type', ct)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', cache)
        self._sec_headers()
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
            return self._serve_static(u.path)
        except ApiError as e:                                  # explicit status (e.g. 404 unknown comp_id)
            msg = json.dumps({'error': e.message}).encode()
            return self._respond(e.status, msg, 'application/json')
        except (ValueError, IndexError, OverflowError) as e:   # bad ang/shabad/params
            msg = json.dumps({'error': 'invalid request: ' + str(e)}).encode()
            return self._respond(400, msg, 'application/json')
        except Exception as e:
            import sys, traceback
            traceback.print_exc(file=sys.stderr)        # visible in server log
            try:                                        # drop a possibly-broken DB handle
                if hasattr(_local, 'con'): _local.con.close(); del _local.con
            except Exception: pass
            # Generic body to the client (full detail is on stderr above); don't leak
            # exception type / internals (e.g. sqlite schema hints) over the wire.
            msg = json.dumps({'error': 'internal server error'}).encode()
            return self._respond(500, msg, 'application/json')

    def do_GET(self): self._handle()
    def do_HEAD(self): self._handle()

if __name__ == '__main__':
    global_fts = None
    if not os.path.exists(DB):
        sys.exit(f'Database not found: {DB}\nRun the pipeline first (see ../01_Production-Architecture.md).')
    # Fail-fast on a Git-LFS *pointer* file (130-byte text stub instead of the ~109 MB DB):
    # os.path.exists() would pass but every /api query would then 500. Catch it at boot with a
    # clear message rather than serving errors. (Real SQLite files start with "SQLite format 3\x00".)
    with open(DB, 'rb') as _f:
        if _f.read(16) != b'SQLite format 3\x00':
            sys.exit(f'Not a valid SQLite file (Git-LFS pointer?): {DB}\nRun `git lfs pull` to fetch the real database.')
    HAVE_FTS = None
    # Bind 0.0.0.0 so the app is reachable when hosted (e.g. behind a Vercel /api rewrite);
    # the platform's $PORT is honoured via the PORT env at the top of this file.
    srv = ThreadingHTTPServer(('0.0.0.0', PORT), H)
    url = f'http://localhost:{PORT}'
    print(f'ੴ  SGGS Knowledge Base serving at {url}   (Ctrl-C to stop)')
    # Only pop a browser for local desktop use; never on a headless host. Opt in with SGGS_OPEN_BROWSER=1.
    if os.environ.get('SGGS_OPEN_BROWSER') == '1':
        try: threading.Timer(0.8, lambda: webbrowser.open(url)).start()
        except Exception: pass
    try: srv.serve_forever()
    except KeyboardInterrupt: print('\nstopped.')
