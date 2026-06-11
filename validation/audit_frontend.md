# SGGS Knowledge Base — Security & Robustness Audit
*Files reviewed: serve.py · static/index.html*
*Threat model: personal local app, 127.0.0.1-only, read-only SQLite, user wants production-grade robustness*

---

## Summary

| Severity | Count |
|----------|-------|
| P0       | 2     |
| P1       | 5     |
| P2       | 8     |

---

## P0 Findings (must fix)

### P0-1 — XSS via onclick attribute injection in themes() (index.html line 361)

**Location:** `index.html:361`

```js
<div class="tile" onclick="$('#q').value='${c.concept}';mode='theme';nav('search');go(0)">
```

`c.concept` is interpolated raw into a **single-quoted JS string inside an `onclick` attribute**. A concept name containing a single quote (e.g. `waheguru's grace`) closes the string and injects arbitrary JS. Data comes from the database which is trusted — but if any concept happens to contain `'`, the page breaks (even without malicious intent). If the build pipeline were ever compromised, this would be a full XSS vector.

`esc()` is not applied here and would not be sufficient alone — HTML-escaping `'` as `&#x27;` inside an unquoted onclick is not reliably safe; the fix is architectural.

**Fix:** Replace the inline onclick with a data attribute + event delegation:

```js
// tile template
`<div class="tile concept-tile" data-concept="${esc(c.concept)}">
  <div class="n">${esc(c.concept)}</div><div class="s">${esc(c.description)}</div></div>`

// one listener (bottom of script, replaces the inline onclick)
document.addEventListener('click', e => {
  const t = e.target.closest('.concept-tile');
  if (t) { $('#q').value = t.dataset.concept; mode='theme'; nav('search'); go(0); }
});
```

`dataset.concept` assignment is always safe regardless of content.

---

### P0-2 — Unhandled async exceptions: every API caller silently swallows errors (index.html lines 268–387)

**Location:** `index.html:268,295,342,358,371,380`

Every top-level async function (`go`, `ang`, `raags`, `themes`, `shabad`, `randomShabad`) calls `api()` which throws on non-OK responses — but **none have try/catch or .catch()**. A 500, network hiccup, or DB-gone-mid-session produces an unhandled promise rejection. The view silently freezes with no user feedback.

```js
async function go(off) {
  const d = await api(`search?...`);  // throws on error — no catch
  // ...
  $('#results').innerHTML = h;        // never reached; results stay stale
}
```

**Fix — minimal toast pattern:**

```js
function showErr(msg) {
  const t = document.createElement('div');
  t.textContent = msg;
  t.style.cssText = 'position:fixed;bottom:40px;left:50%;transform:translateX(-50%);' +
    'background:#9a3412;color:#fff;padding:10px 20px;border-radius:10px;z-index:9999;font-size:13px';
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 4000);
}

// Wrap every async function body:
async function go(off) {
  try {
    const d = await api(`search?...`);
    // ... existing logic ...
  } catch(e) { showErr('Search failed — ' + e.message); }
}
```

Apply the same try/catch to ang(), raags(), themes(), shabad(), randomShabad().

---

## P1 Findings (should fix soon)

### P1-1 — Race condition on rapid ang navigation overwrites newer view with stale response (index.html lines 295–328)

**Location:** `index.html:295`

Three concurrent fetches from arrow-key paging: whichever returns **last** wins. `curAng` is set immediately to the final value but `$('#angOut').innerHTML` can be set to ang 1's content after the user has navigated to ang 3.

```js
async function ang(n) {
  curAng = Math.max(1, Math.min(1430, n));  // updated immediately
  const d = await api('ang/' + curAng);     // n captured at call time, not current curAng
  // ... builds h from d ...
  $('#angOut').innerHTML = h;               // may be ang 1 when curAng===3
}
```

**Fix — generation counter:**

```js
let _angSeq = 0;
async function ang(n) {
  curAng = Math.max(1, Math.min(1430, n));
  $('#angIn').value = curAng;
  const seq = ++_angSeq;
  try {
    const d = await api('ang/' + curAng);
    if (seq !== _angSeq) return;  // superseded by a later call
    // ... rest of function ...
  } catch(e) { showErr('Could not load ang — ' + e.message); }
}
```

Apply the same pattern to `go()` to guard against rapid search re-submissions.

---

### P1-2 — Non-numeric path segments crash with implementation-detail error message (serve.py lines 155–174)

**Location:** `serve.py:156,173`

```python
if p[0] == 'ang':
    ang = max(1, min(1430, int(p[1])))   # int() raises ValueError on "/api/ang/foo"
if p[0] == 'shabad':
    cid = int(p[1])                       # same; also IndexError if path is "/api/shabad"
```

Non-numeric input raises `ValueError` or `IndexError` which bubbles to `do_GET`'s bare `except Exception` and returns `{"error": "invalid literal for int() with base 10: 'foo'"}` — leaking Python internals. The bigger issue is that `/api/ang` (no segment) raises `IndexError: list index out of range` from `p[1]`, also caught and returned verbatim.

**Fix:**

```python
def _int_seg(p, idx, lo=None, hi=None, name='param'):
    if idx >= len(p):
        raise ValueError(f'Missing {name} in URL path')
    try:
        v = int(p[idx])
    except ValueError:
        raise ValueError(f'Invalid {name}: expected integer, got {p[idx]!r}')
    if lo is not None and v < lo:
        raise ValueError(f'{name} {v} below minimum {lo}')
    if hi is not None and v > hi:
        raise ValueError(f'{name} {v} above maximum {hi}')
    return v

# usage:
ang = _int_seg(p, 1, lo=1, hi=1430, name='ang')
cid = _int_seg(p, 1, lo=1, name='comp_id')
```

Also add a guard at the top of `api()`:

```python
if not p:
    raise ValueError('missing endpoint')
```

And return 400 instead of 500 for ValueError:

```python
except ValueError as e:
    msg = json.dumps({'error': str(e)}).encode()
    self.send_response(400)
    ...
```

---

### P1-3 — Arrow-key ang navigation fires behind open panel; Escape not handled (index.html lines 239–242)

**Location:** `index.html:239`

```js
document.addEventListener('keydown', e => {
  if (curView !== 'ang' || e.target.tagName === 'INPUT') return;
  if (e.key === 'ArrowRight') { ang(curAng+1) }
  if (e.key === 'ArrowLeft')  { ang(curAng-1) }
});
```

When the shabad panel (`.panel.on`) is open, `curView` is still `'ang'`, so arrow keys navigate the reader behind the modal. There is also no Escape handler to close the panel.

**Fix:**

```js
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && $('#panel').classList.contains('on')) {
    closePanel(); return;
  }
  if (curView !== 'ang' || e.target.tagName === 'INPUT') return;
  if ($('#panel').classList.contains('on')) return;  // block nav while panel open
  if (e.key === 'ArrowRight') { ang(curAng+1) }
  if (e.key === 'ArrowLeft')  { ang(curAng-1) }
});
```

---

### P1-4 — DB deleted at runtime: broken thread-local connection persists silently (serve.py lines 30–34, 189)

**Location:** `serve.py:30–34,189`

`_local.con` is never reset on error. If the DB is deleted while the server is running, all subsequent requests on that thread raise `OperationalError` forever. Additionally `log_message` is fully suppressed (line 189), so the user gets no console indication of the problem.

**Fix — reset connection on error + restore minimal error logging:**

```python
def db():
    con = getattr(_local, 'con', None)
    if con is None:
        try:
            _local.con = sqlite3.connect(f'file:{DB}?mode=ro&immutable=1', uri=True)
            _local.con.row_factory = sqlite3.Row
        except sqlite3.OperationalError as e:
            raise RuntimeError(f'Cannot open database: {e}') from e
    return _local.con

# In do_GET's except block, add:
except Exception as e:
    print(f'[SGGS] ERROR {self.path}: {e}', file=sys.stderr)
    if 'database' in str(e).lower():
        _local.con = None  # force reconnect next request
    msg = json.dumps({'error': str(e)}).encode()
    ...
```

---

### P1-5 — Favicon requests served as 200 HTML, polluting logs and wasting bytes (serve.py lines 197–199)

**Location:** `serve.py:197`

`/favicon.ico` falls through to the `else` branch which reads and returns the full `index.html` as `text/html; charset=utf-8` with a 200 status. This sends ~12 KB on every browser page load as a "favicon".

**Fix:**

```python
elif u.path == '/favicon.ico':
    self.send_response(404)
    self.send_header('Content-Length', '0')
    self.end_headers()
    return
```

---

## P2 Findings (polish / improve)

### P2-1 — `color-mix()` used without fallback; older Safari sees transparent backgrounds (index.html lines 35, 49, 69, 77, 146)

`color-mix(in srgb, ...)` is unsupported in Safari < 16.2 (released Dec 2022). Nav, toolbar, and footer backgrounds become **fully transparent** — text may be unreadable over scrolled content.

**Fix — @supports guard for each usage:**

```css
nav { background: rgba(255,255,255,0.88); }  /* fallback first */
@supports (background: color-mix(in srgb, white 88%, transparent)) {
  nav { background: color-mix(in srgb, var(--card) 88%, transparent); }
}
```

Apply same pattern to `.toolbar`, `footer`, `.themedesc` border, `.searchbar input:focus` box-shadow.

---

### P2-2 — Toggle lacks role/aria-pressed; search input lacks label (index.html lines 87–92, 172)

The `.tgl` div is a custom toggle with no `role="switch"`, no `aria-checked`, no keyboard activation, and no `tabindex`. Screen readers announce it as a generic div.

The search `<input id="q">` has only a placeholder — no `<label>` and no `aria-label`.

**Fix:**

```html
<div class="tgl" id="tglT" role="switch" aria-checked="true" tabindex="0"
     onclick="toggleT()"
     onkeydown="if(event.key===' '||event.key==='Enter'){toggleT();event.preventDefault()}">

<!-- toggleT() — add: -->
$('#tglT').setAttribute('aria-checked', String(!document.body.classList.contains('hide-t')));

<!-- search label: -->
<label for="q" class="sr-only">Search Gurbani</label>
<input id="q" ...>
```

```css
.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
```

---

### P2-3 — No prefers-reduced-motion guard (index.html lines 39, 61, 131)

Cards, tiles, and nav buttons animate `transform:translateY` unconditionally. Users with vestibular disorders who have enabled "Reduce Motion" in OS settings will still see these transitions.

**Fix — add at end of `<style>` block:**

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { transition: none !important; animation: none !important; }
}
```

---

### P2-4 — No visible focus styles for keyboard navigation (index.html)

`outline:none` is set on `.searchbar input:focus` without a compensating custom outline. Nav buttons, mode spans, tiles, and cards have no `:focus-visible` styles and no `tabindex`, making them keyboard-unreachable entirely.

**Fix:**

```css
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
/* Add tabindex="0" to .card, .tile, .modes span, .tgl divs acting as buttons */
```

---

### P2-5 — Modal panel has no focus trap, no aria-modal, no aria-labelledby (index.html lines 216–222)

The panel overlay has no `role="dialog"`, no `aria-modal="true"`, no `aria-labelledby`, and no focus trap. Keyboard users can Tab behind the modal while it is open.

**Fix:**

```html
<div class="panel" id="panel" role="dialog" aria-modal="true" aria-labelledby="ptitle">
```

```js
// After panel opens, move focus in:
$('#panel .x').focus();

// Focus trap: in panel keydown listener, cycle Tab between focusable children only
```

---

### P2-6 — FTS boolean operators (AND/OR/NOT/NEAR) not stripped from user query (serve.py lines 50–54)

FTS5 interprets bare `AND`, `OR`, `NOT`, `NEAR` as boolean operators. A search for `naam OR haumai` returns the union rather than a phrase match. In a read-only DB this cannot cause harm, but results are surprising.

**Fix:**

```python
_FTS_OPS = re.compile(r'\b(AND|OR|NOT|NEAR)\b', re.I)
def fts_query(tokens, phrase=False):
    toks = [_FTS_OPS.sub('', t).replace('"','').strip() for t in tokens]
    toks = [t for t in toks if t]
    if not toks: return None
    if phrase: return '"' + ' '.join(toks) + '"'
    return ' AND '.join(f'"{t}"' for t in toks)
```

---

### P2-7 — No Cache-Control header: browsers may cache stale index.html after restart (serve.py lines 200–204)

Neither API responses nor the HTML file set `Cache-Control`. After restarting the server with an updated `index.html`, users may see a cached old version until the browser's heuristic TTL expires.

**Fix:**

```python
# In do_GET, after send_response(200):
if u.path.startswith('/api/'):
    self.send_header('Cache-Control', 'no-store')
else:
    self.send_header('Cache-Control', 'no-cache')
```

---

### P2-8 — HEAD requests return 501 Not Implemented (serve.py line 190)

`BaseHTTPRequestHandler` only defines `do_GET`. HEAD returns 501. Acceptable for personal use but trivial to fix.

**Fix:**

```python
def do_HEAD(self):
    self.do_GET()  # body write is harmlessly discarded for HEAD
```

---

## Confirmed Safe (no action needed)

- **SQL parameterization:** All user-controlled values use `?` placeholders throughout. No string-format SQL injection found. ✓
- **esc() coverage:** All Gurmukhi/translit/author/raag/section data passed through `esc()` before innerHTML insertion. Integer DB values (`ang`, `comp_id`) inserted directly into onclick numeric args — safe. ✓
- **localStorage:** `store` helper wraps both `getItem` and `setItem` in try/catch for private-mode safety. ✓
- **openRaag JSON.stringify:** Low risk — raag names are Gurmukhi and do not contain single quotes in practice, but structurally brittle (see P0-1 fix pattern for the principled solution). ✓
- **Threading:** Thread-local DB connections, no shared mutable state beyond `HAVE_FTS` (set once). ✓
- **Port binding:** `127.0.0.1` only — not network-accessible. ✓
- **Performance:** ~80 lines/ang, O(n) grouping and majority(), no quadratic operations. Full innerHTML rebuild is fine at this scale. ✓
