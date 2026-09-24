# -*- coding: utf-8 -*-
"""Shared kernel of the API: the one database handle, the shared mutable state, parameter
parsing and helpers every bounded context uses. Every other module reaches shared state as
`core.NAME` — never a copy — so `serve.DB = …` (proxied here) redirects all of them."""
import os, sqlite3, sys, threading

WEBAPP_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if WEBAPP_DIR not in sys.path:
    sys.path.insert(0, WEBAPP_DIR)   # romannorm.py, verify.py live beside serve.py
DB = os.path.join(WEBAPP_DIR, '..', 'db', 'sggs.sqlite')
APP_VERSION = APP_BUILT = APP_COMMIT = None   # set by serve.py (the composition root)
STATE = ('DB', 'HAVE_FTS', '_META_CACHE', '_TIMING_CACHE', '_TERM2CONCEPT', '_concept_lock')   # proxied by serve: serve.DB = ... writes here


class ApiError(Exception):
    """Raised by an endpoint to return a specific HTTP status (e.g. 404) with a
    safe JSON body, instead of the generic 400/500 mapping."""
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


_local = threading.local()


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


_TERM2CONCEPT = None


_concept_lock = threading.Lock()


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


_FALLTHROUGH = object()   # returned by a handler whose branch did not return (old ladder fell through)
