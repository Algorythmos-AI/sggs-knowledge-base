#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sri Guru Granth Sahib — local search app.
Zero dependencies: Python 3 standard library only.

Run:   python3 serve.py        then open  http://localhost:7777
"""
import json, os, re, sqlite3, sys, threading, webbrowser, mimetypes, hashlib, time, types, uuid
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
PORT = int(os.environ.get('PORT') or os.environ.get('SGGS_PORT') or '7777')

# Search-logic release stamp. Lives in code (not DB meta) so a search-only patch
# doesn't force an 86 MB DB re-commit. /api/meta and /api/health prefer these; the
# DB meta row is the fallback. Bump on every search-logic release so the UI footer
# (which reads /api/meta) reflects the running build.
APP_VERSION = '1.3.10'
APP_BUILT = '2026-09-25'


# The exact source commit of the running build, so a deploy can be verified by
# identity (not just version): Render injects RENDER_GIT_COMMIT for git-backed
# services; SGGS_COMMIT is a manual override for other hosts.
APP_COMMIT = os.environ.get('RENDER_GIT_COMMIT') or os.environ.get('SGGS_COMMIT') or 'unknown'


import sys as _sys
_sys.path.insert(0, HERE)
from verify import verify as verify_claim     # noqa: F401  Layer-3 engine; re-exported (serve.verify_claim)


from romannorm import roman_norm   # noqa: F401  shared fold; re-exported for gen_golden_vectors.py

# ---------------------------------------------------------------------------------------------
# Composition root. The API is split into bounded-context modules (webapp/sggs/: core, search,
# reader, verification, insights, knowledge — the services of the platform split). This file
# wires them: it owns the build identity, the route table, the HTTP layer and startup, and
# re-exports the modules' names so existing callers (serve.api, serve.do_search,
# serve.hukam_package, the golden-vector generator, harnesses, tests) are unchanged.
# ---------------------------------------------------------------------------------------------
from sggs import core
core.APP_VERSION, core.APP_BUILT, core.APP_COMMIT = APP_VERSION, APP_BUILT, APP_COMMIT
from sggs.core import (ApiError, LINE_COLS, _FALLTHROUGH, _ID_MAX, _int, _int_str, _local,   # noqa: F401
    attach_translations, db, have_fts, rows_to_list)   # noqa: F401  (re-exported)
from sggs.search import (GURMUKHI, PUNCT_RE, SEEKER_LEXICON, _FTS_COLS, _fts_clean, _route_search,   # noqa: F401
    _route_word, blob_search, do_search, fold_match_alts, fts_query, lexicon_search, mixed_search,   # noqa: F401
    passage_search, search_en, search_fts, search_like, term_concepts, theme_search, variant_search)   # noqa: F401  (re-exported)
from sggs.reader import (_BANI_KEY_RE, _BANI_VARIANTS, _route_ang, _route_bani, _route_banis,   # noqa: F401
    _route_health, _route_lines, _route_meta, _route_random, _route_shabad, hukam_package)   # noqa: F401  (re-exported)
from sggs.verification import (MAX_CLAIM_CHARS, _route_verify)   # noqa: F401  (re-exported)
from sggs.insights import (_route_analytics_author, _route_analytics_constellation,   # noqa: F401
    _route_analytics_progression, _route_analytics_raag, _route_analytics_resonance,   # noqa: F401
    _route_analytics_vaar, _route_analytics_vaars, _route_line_concepts, _route_neighbors,   # noqa: F401
    _route_related, _route_themes_network)   # noqa: F401  (re-exported)
from sggs.knowledge import (_route_forms, _route_timing_clock, _route_timing_divergence,   # noqa: F401
    _route_timing_raag)   # noqa: F401  (re-exported)

from sggs import search as _search, reader as _reader, verification as _verification, insights as _insights, knowledge as _knowledge
# Tables each bounded context reads — the source for per-service database slices.
CONTEXT_TABLES = {'search': _search.TABLES, 'reader': _reader.TABLES, 'verify': _verification.TABLES,
                  'insights': _insights.TABLES, 'knowledge': _knowledge.TABLES}


def parse_modules(raw):
    """SGGS_MODULES -> the contexts this process serves. 'all' (the default) is the monolith,
    exactly as before; a comma list (e.g. 'search' or 'insights,knowledge') runs one service of
    the platform split from the same image. Unknown names are an error, never ignored."""
    raw = (raw or 'all').strip().lower()
    if raw == 'all':
        return frozenset(CONTEXT_TABLES)
    sel = frozenset(x.strip() for x in raw.split(',') if x.strip())
    bad = sorted(sel - set(CONTEXT_TABLES))
    if bad or not sel:
        raise ValueError(f'SGGS_MODULES: unknown context(s) {bad} — choose from {sorted(CONTEXT_TABLES)} or "all"')
    return sel


ENABLED = parse_modules(os.environ.get('SGGS_MODULES'))


def split_mode():
    return ENABLED != frozenset(CONTEXT_TABLES)


def readiness(db_path=None):
    """Is the database complete for every enabled context? (every declared table present)"""
    con = sqlite3.connect(f"file:{db_path or core.DB}?mode=ro&immutable=1", uri=True)
    try:
        have = {n for (n,) in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    finally:
        con.close()
    missing = sorted({t for c in ENABLED for t in CONTEXT_TABLES[c]} - have)
    return {'ready': not missing, 'contexts': sorted(ENABLED), 'missing_tables': missing,
            'version': APP_VERSION, 'commit': APP_COMMIT}

class _ServeModule(types.ModuleType):
    """Shared mutable state (DB path, FTS flag, caches) has exactly one home: sggs.core.
    Reading or assigning serve.DB / serve.HAVE_FTS / serve._TIMING_CACHE … goes there, so a test
    or harness that redirects the DB redirects every bounded context at once."""
    def __getattr__(self, name):
        if name in core.STATE:
            return getattr(core, name)
        raise AttributeError(f"module 'serve' has no attribute {name!r}")

    def __setattr__(self, name, value):
        if name in core.STATE:
            setattr(core, name, value)
        else:
            super().__setattr__(name, value)


sys.modules[__name__].__class__ = _ServeModule


# Route table: (first path segment, second segment or None) -> (handler, bounded context).
# The context names the service each route moves to in the platform split (reader, search,
# verify, insights, knowledge). Handler bodies are the former api() branches, verbatim.
ROUTES = {
    ('meta', None): (_route_meta, 'reader'),
    ('search', None): (_route_search, 'search'),
    ('ang', None): (_route_ang, 'reader'),
    ('shabad', None): (_route_shabad, 'reader'),
    ('health', None): (_route_health, 'reader'),
    ('random', None): (_route_random, 'reader'),
    ('verify', None): (_route_verify, 'verify'),
    ('word', None): (_route_word, 'search'),
    ('themes', 'network'): (_route_themes_network, 'insights'),
    ('analytics', 'author'): (_route_analytics_author, 'insights'),
    ('analytics', 'raag'): (_route_analytics_raag, 'insights'),
    ('analytics', 'progression'): (_route_analytics_progression, 'insights'),
    ('analytics', 'resonance'): (_route_analytics_resonance, 'insights'),
    ('analytics', 'vaars'): (_route_analytics_vaars, 'insights'),
    ('analytics', 'vaar'): (_route_analytics_vaar, 'insights'),
    ('analytics', 'constellation'): (_route_analytics_constellation, 'insights'),
    ('related', None): (_route_related, 'insights'),
    ('lines', None): (_route_lines, 'reader'),
    ('line_concepts', None): (_route_line_concepts, 'insights'),
    ('neighbors', None): (_route_neighbors, 'insights'),
    ('timing', 'clock'): (_route_timing_clock, 'knowledge'),
    ('timing', 'raag'): (_route_timing_raag, 'knowledge'),
    ('timing', 'divergence'): (_route_timing_divergence, 'knowledge'),
    ('banis', None): (_route_banis, 'reader'),
    ('bani', None): (_route_bani, 'reader'),
    ('forms', None): (_route_forms, 'knowledge'),
}


def api(path, qs):
    p = [x for x in path.split('/') if x][1:]   # drop 'api'
    if not p:
        raise ValueError('missing endpoint')
    if p[0] in ('ang', 'shabad') and len(p) < 2:
        raise ValueError(f'/api/{p[0]} requires an id')
    if core.HAVE_FTS is None:                    # ensure FTS detection for EVERY endpoint
        core.HAVE_FTS = have_fts()               # (not just /api/search) — /api/word needs it
    route = (len(p) >= 2 and ROUTES.get((p[0], p[1]))) or ROUTES.get((p[0], None))
    if route is None:
        raise ValueError('unknown endpoint')
    if route[1] not in ENABLED:      # split mode: this route belongs to another service
        raise ApiError(404, f'/api/{p[0]} is not served by this service')
    result = route[0](p, qs)
    if result is _FALLTHROUGH:       # a branch that did not return: same as the old ladder falling off
        raise ValueError('unknown endpoint')
    return result

# Responses that depend only on the immutable DB: safe for the browser and the CDN in front of
# the API to cache. Everything else (health, meta, random, search, verify) stays no-store.
_CACHEABLE = ('ang', 'shabad', 'lines', 'bani', 'banis', 'word', 'analytics', 'themes', 'timing',
              'forms', 'neighbors', 'related', 'line_concepts')
_CACHE_IMMUTABLE = 'public, max-age=300, s-maxage=3600'
_ACCESS_LOG = os.environ.get('SGGS_ACCESS_LOG', '1') != '0'
# A request id is echoed on every response (X-Request-Id) and written to the access log, so one
# request can be followed from Vercel to this service. An incoming X-Request-Id or Vercel's own
# x-vercel-id is reused when it is a plain token; anything else is replaced, never logged as sent.
_RID_OK = re.compile(r'[A-Za-z0-9._:-]{8,128}')

class H(BaseHTTPRequestHandler):
    # A client that connects and then sends nothing (or trickles bytes) used to hold its thread
    # and SQLite connection forever: socketserver applies this to the socket before reading.
    timeout = 15

    def log_message(self, *a): pass

    def log_request(self, code='-', size='-'):
        # One JSON line per request on stderr (the host's log stream). The path only — never the
        # query string, so what people search for is not written anywhere.
        if not _ACCESS_LOG: return
        t0 = getattr(self, '_t0', None)
        ms = round((time.monotonic() - t0) * 1000, 1) if t0 else None
        code = getattr(code, 'value', code)
        sys.stderr.write(json.dumps({'m': self.command, 'p': urlparse(self.path).path,
                                     's': code, 'ms': ms, 'id': getattr(self, '_rid', None)}) + '\n')

    def _request_id(self):
        for h in ('X-Request-Id', 'x-vercel-id'):
            v = (self.headers.get(h) or '').strip()
            if _RID_OK.fullmatch(v):
                return v
        return uuid.uuid4().hex

    def _sec_headers(self):
        # Defence-in-depth for the local app. No strict CSP on purpose: the UI relies on
        # inline event handlers + an inline pre-paint theme script, which a strict policy
        # would break; nosniff/frame-deny/no-referrer are safe and unconditional.
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Referrer-Policy', 'no-referrer')
        # Honoured only over HTTPS (the hosted API); browsers ignore it on http://localhost.
        self.send_header('Strict-Transport-Security', 'max-age=31536000')
        rid = getattr(self, '_rid', None)
        if rid: self.send_header('X-Request-Id', rid)
        # Which service answered: 'all' for the single API, else the contexts this service runs.
        # The gateway's routing is verified by this header (it carries no user data).
        self.send_header('X-Service', 'all' if ENABLED == frozenset(CONTEXT_TABLES) else ','.join(sorted(ENABLED)))

    def _respond(self, status, body, ct, cache='no-store'):
        etag = None
        if cache != 'no-store' and status == 200:
            etag = '"' + hashlib.sha256(body).hexdigest()[:32] + '"'
            if self.headers.get('If-None-Match') == etag:
                status, body = 304, b''
        self.send_response(status)
        self.send_header('Content-Type', ct)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', cache)
        if etag: self.send_header('ETag', etag)
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
        self._t0 = time.monotonic()
        self._rid = self._request_id()
        u = urlparse(self.path)
        if u.path == '/favicon.ico':
            return self._respond(404, b'', 'image/x-icon')
        if u.path in ('/healthz', '/readyz'):      # liveness / readiness for platform health checks
            try:
                body = {'ok': True} if u.path == '/healthz' else readiness()
            except Exception:
                body = {'ready': False, 'error': 'database unavailable'}
            status = 200 if body.get('ok') or body.get('ready') else 503
            return self._respond(status, json.dumps(body).encode(), 'application/json')
        if u.path.startswith('/api/v1/'):
            return self._handle_v1(u)
        try:
            if u.path.startswith('/api/'):
                body = json.dumps(api(u.path, parse_qs(u.query)), ensure_ascii=False).encode()
                seg = u.path.split('/')[2] if u.path.count('/') >= 2 else ''
                cache = _CACHE_IMMUTABLE if seg in _CACHEABLE else 'no-store'
                return self._respond(200, body, 'application/json; charset=utf-8', cache)
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

    def _handle_v1(self, u):
        """/api/v1/* — the same routes and bodies as /api/*, with strict semantics: an unknown
        endpoint is 404 (not 400), and every error is {"error": {"code", "message", "request_id"}}.
        The legacy /api/* responses stay byte-identical (the golden contract pins them)."""
        def err(status, code, message):
            body = {'error': {'code': code, 'message': message, 'request_id': self._rid}}
            return self._respond(status, json.dumps(body).encode(), 'application/json')
        legacy = '/api/' + u.path[len('/api/v1/'):]
        try:
            body = json.dumps(api(legacy, parse_qs(u.query)), ensure_ascii=False).encode()
            seg = legacy.split('/')[2] if legacy.count('/') >= 2 else ''
            cache = _CACHE_IMMUTABLE if seg in _CACHEABLE else 'no-store'
            return self._respond(200, body, 'application/json; charset=utf-8', cache)
        except ApiError as e:
            return err(e.status, 'not_found' if e.status == 404 else 'error', e.message)
        except (ValueError, IndexError, OverflowError) as e:
            if str(e) in ('unknown endpoint', 'missing endpoint'):
                return err(404, 'not_found', f'no such endpoint: {u.path}')
            return err(400, 'invalid_request', str(e))
        except Exception:
            import traceback
            traceback.print_exc(file=sys.stderr)
            try:
                if hasattr(_local, 'con'): _local.con.close(); del _local.con
            except Exception: pass
            return err(500, 'internal', 'internal server error')

    def do_GET(self): self._handle()
    def do_HEAD(self): self._handle()


class BoundedThreadingHTTPServer(ThreadingHTTPServer):
    """ThreadingHTTPServer with a ceiling on live handler threads.

    The stock server starts a thread — and, here, a SQLite connection with its page cache — per
    connection with no upper bound. When every slot is busy the accept loop waits, so extra clients
    queue in the listen backlog instead of multiplying memory. With `H.timeout` an idle or
    trickling connection gives its slot back within seconds."""
    daemon_threads = True
    request_queue_size = 128

    def __init__(self, *args, max_workers=None, **kwargs):
        super().__init__(*args, **kwargs)
        self._slots = threading.BoundedSemaphore(max_workers or int(os.environ.get('SGGS_MAX_WORKERS', '48')))

    def process_request(self, request, client_address):
        self._slots.acquire()
        try:
            super().process_request(request, client_address)
        except BaseException:
            self._slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self._slots.release()

if __name__ == '__main__':
    global_fts = None
    if not os.path.exists(core.DB):
        sys.exit(f'Database not found: {core.DB}\nRun `make dataset` to install the pinned database (see docs/engineering/local-setup.md).')
    # Fail-fast on a Git-LFS *pointer* file (130-byte text stub instead of the ~109 MB core.DB):
    # os.path.exists() would pass but every /api query would then 500. Catch it at boot with a
    # clear message rather than serving errors. (Real SQLite files start with "SQLite format 3\x00".)
    with open(core.DB, 'rb') as _f:
        if _f.read(16) != b'SQLite format 3\x00':
            sys.exit(f'Not a valid SQLite file (Git-LFS pointer?): {core.DB}\nRun `make dataset` to install the pinned database.')
    core.HAVE_FTS = None
    if split_mode():                     # a service must never serve with part of its data missing
        _r = readiness()
        if not _r['ready']:
            sys.exit(f"SGGS_MODULES={','.join(_r['contexts'])}: database {core.DB} lacks declared tables "
                     f"{_r['missing_tables']} — refusing to start")
        print(f"serving contexts: {', '.join(_r['contexts'])}")
    # Bind 0.0.0.0 so the app is reachable when hosted (e.g. behind a Vercel /api rewrite);
    # the platform's $PORT is honoured via the PORT env at the top of this file.
    srv = BoundedThreadingHTTPServer(('0.0.0.0', PORT), H)
    url = f'http://localhost:{PORT}'
    print(f'ੴ  SGGS Knowledge Base serving at {url}   (Ctrl-C to stop)')
    try:                                   # one identity line per process; request lines carry only the id
        _dbv = core.db().execute("SELECT value FROM meta WHERE key = 'version'").fetchone()
    except Exception:
        _dbv = None
    print(json.dumps({'event': 'start', 'version': APP_VERSION, 'commit': APP_COMMIT,
                      'dataset': _dbv[0] if _dbv else None, 'modules': sorted(ENABLED)}), flush=True)
    # Only pop a browser for local desktop use; never on a headless host. Opt in with SGGS_OPEN_BROWSER=1.
    if os.environ.get('SGGS_OPEN_BROWSER') == '1':
        try: threading.Timer(0.8, lambda: webbrowser.open(url)).start()
        except Exception: pass
    try: srv.serve_forever()
    except KeyboardInterrupt: print('\nstopped.')
