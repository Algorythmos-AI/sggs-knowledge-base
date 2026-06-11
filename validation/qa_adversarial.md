# Adversarial QA Report — SGGS Knowledge Base Web App
**Date:** 2026-06-10  
**Target:** http://127.0.0.1:7777  
**Tester:** Adversarial red-team agent (Claude Sonnet 4.6)  
**Total attacks:** 25 | **PASS:** 25 | **FAIL:** 0

---

## Attack 1 — Correctness Probes

| ID | Description | Endpoint | Input | Expected | Actual | Verdict |
|----|-------------|----------|-------|----------|--------|---------|
| C1 | ਮੂਰਤਿ search includes Ang 1 | `/api/search?mode=gurmukhi&limit=5` | `q=ਮੂਰਤਿ` | Results non-empty, Ang 1 present | Ang 1 present (angs=[1,13,53,78,94]) | **PASS** |
| C2 | ਭਉ results all contain ਭਉ as substring | `/api/search?mode=gurmukhi&limit=5` | `q=ਭਉ` | All 5 results contain ਭਉ | All 5 gurmukhi fields contain ਭਉ | **PASS** |
| C3 | First-letter mode ਸ ਨ ਕ ਪ finds Ang 1 (Mool Mantar) | `/api/search?mode=first&limit=5` | `q=ਸ ਨ ਕ ਪ` | Ang 1 in results | Ang 1 present (angs=[1,37,94,137,150]) | **PASS** |

---

## Attack 2 — Injection / Robustness

All tests: must not 500 with stack-trace, must not hang (>8s), must not corrupt DB.

| ID | Description | Input `q` | Status | Latency | Leak? | Verdict |
|----|-------------|-----------|--------|---------|-------|---------|
| I1 | Double-quote | `"` | 200 | 0.00s | No | **PASS** |
| I2 | SQL injection (gurmukhi) | `ਨਾਮੁ" OR 1=1--` | 200 | 0.02s | No | **PASS** |
| I3 | DROP TABLE injection | `'; DROP TABLE lines;--` | 200 | 0.00s | No | **PASS** |
| I4 | Unbalanced parenthesis | `ਨਾਮੁ AND (` | 200 | 0.02s | No | **PASS** |
| I5 | Asterisk wildcard | `*` | 200 | 0.00s | No | **PASS** |
| I6 | Ik Onkar symbol | `ੴ` | 200 | 0.00s | No | **PASS** |
| I7 | Empty query | `` | 200 | 0.00s | No | **PASS** |
| I8 | Spaces only | `   ` | 200 | 0.00s | No | **PASS** |
| I9 | 500-char repeat (ਨ×500) | ਨਨਨ… | 200 | 0.02s | No | **PASS** |
| I10 | Emoji prayer | `🙏` | 200 | 0.00s | No | **PASS** |
| I11 | Mixed Gurmukhi+Roman | `ਨਾਮੁ naam` | 200 | 0.02s | No | **PASS** |

**DB integrity check post-injection:** `SELECT count(*) FROM lines` = 60,193 (unchanged). DB is opened read-only (`mode=ro&immutable=1`), so write-based injections are structurally impossible.

---

## Attack 3 — Boundary / Edge Cases

| ID | Description | Endpoint | Expected | Actual | Verdict |
|----|-------------|----------|----------|--------|---------|
| B1 | `/api/ang/0` | Clamp to ang=1 | 200, ang=1 | 200, ang=1, 23 lines returned | **PASS** |
| B2 | `/api/ang/1431` | Clamp to ang=1430 | 200, ang=1430 | 200, ang=1430 | **PASS** |
| B3 | `/api/ang/-5` | Clamp/clean error | 200, ang=1 (clamped via `max(1,min(1430,int(-5)))`) | 200, ang=1, 23 lines | **PASS** |
| B4 | `/api/ang/abc` | Clean error, no Traceback | 500, JSON error | `{"error": "invalid literal for int() with base 10: 'abc'"}` — no Traceback | **PASS** |
| B5 | `/api/shabad/999999` | Empty lines list | 200, lines=[] | 200, lines=[] | **PASS** |
| B6 | `offset=100000` | Empty results | 200, results=[] | 200, results=[] | **PASS** |

**Note on B3:** `/api/ang/-5` silently clamps to ang=1 — same as ang/0. Consistent behaviour, acceptable for local tool.

---

## Attack 4 — Performance (10 Sequential Searches)

| # | Query / Endpoint | Mode | Status | Latency |
|---|-----------------|------|--------|---------|
| 1 | `q=ਨਾਮੁ` | gurmukhi | 200 | 0.004s |
| 2 | `q=naam` | roman | 200 | 0.002s |
| 3 | `q=ਸ ਨ ਕ ਪ` | first | 200 | 0.008s |
| 4 | `q=haumai` | theme | 200 | 0.029s |
| 5 | `/api/ang/1` | — | 200 | 0.001s |
| 6 | `/api/ang/500` | — | 200 | 0.001s |
| 7 | `/api/ang/1430` | — | 200 | 0.001s |
| 8 | `/api/random` | — | 200 | 0.013s |
| 9 | `q=ਵਾਹੇਗੁਰੂ` | auto | 200 | 0.020s |
| 10 | `/api/word/?w=ਨਾਮੁ` | — | 200 | 0.005s |

**Max latency: 0.029s** (theme search). All well under the 10s threshold.

| ID | Description | Verdict |
|----|-------------|---------|
| P1 | All 10 sequential searches complete under 10s | **PASS** |

---

## Attack 5 — Concurrency (8 Parallel Requests)

| ID | Description | Endpoint | Threads | Responses | Verdict |
|----|-------------|----------|---------|-----------|---------|
| CONC1 | 8 simultaneous requests | `/api/search?q=ਨਾਮੁ&mode=gurmukhi&limit=5` | 8 | [200,200,200,200,200,200,200,200] | **PASS** |

The server uses `ThreadingHTTPServer` with thread-local SQLite connections, correctly handling concurrent load without contention.

---

## Attack 6 — Fidelity Spot Checks

| ID | Description | Expected | Actual | Verdict |
|----|-------------|----------|--------|---------|
| F1 | Ang 1 first line is Mool Mantar verbatim | `ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ ਅਜੂਨੀ ਸੈਭੰ ਗੁਰ ਪ੍ਰਸਾਦਿ ॥` | Byte-exact match confirmed | **PASS** |
| F2 | Ang 1430 last line contains `ਅਠਾਰਹ ਦਸ ਬੀਸ` | Substring present | `ਸਭੈ ਪੁਤ੍ਰ ਰਾਗੰਨ ਕੇ ਅਠਾਰਹ ਦਸ ਬੀਸ ॥੧॥੧॥` | **PASS** |

---

## Attack 7 — Theme Search

| ID | Description | Endpoint | Expected | Actual | Verdict |
|----|-------------|----------|----------|--------|---------|
| T1 | haumai theme — concept metadata present, results non-empty, terms in lines | `/api/search?q=haumai&mode=theme&limit=5` | concept obj with terms, results non-empty, first 3 lines contain a concept term | concept=`haumai`, terms=[`ਹਉਮੈ`,`ਹੰਉਮੈ`], total=628 results, all 3 spot-checked lines verified | **PASS** |

**Sample theme results verified:**
- `ਨਾਨਕ ਹੁਕਮੈ ਜੇ ਬੁਝੈ ਤ ਹਉਮੈ ਕਹੈ ਨ ਕੋਇ ॥੨॥` — matched_term=ਹਉਮੈ ✓
- `ਸਾਕਤ ਹਰਿ ਰਸ ਸਾਦੁ ਨ ਜਾਣਿਆ ਤਿਨ ਅੰਤਰਿ ਹਉਮੈ ਕੰਡਾ ਹੇ ॥` — matched_term=ਹਉਮੈ ✓
- `ਭਲੀ ਸਰੀ ਜਿ ਉਬਰੀ ਹਉਮੈ ਮੁਈ ਘਰਾਹੁ ॥` — matched_term=ਹਉਮੈ ✓

---

## Observations & Recommendations

1. **Security posture is solid:** DB opened `mode=ro&immutable=1` — all SQL/DROP injections are structurally impossible.
2. **No stack-trace leakage:** The one 500 case (`/api/ang/abc`) returns clean `{"error":"..."}` JSON with no Traceback exposed.
3. **Silent boundary clamping:** `/api/ang/-5` and `/api/ang/0` silently return ang=1. Acceptable for a local tool; consider a 400 response for out-of-range inputs if this becomes a shared API.
4. **Performance is excellent:** Max latency 29ms across all query types on warm DB. FTS5 is active and functioning.
5. **Mool Mantar fidelity confirmed:** Byte-exact match against canonical `ੴ ਸਤਿ ਨਾਮੁ...` text on Ang 1.
6. **DB integrity intact:** 60,193 lines remain after all injection attempts.

---

*Report generated by adversarial red-team agent. All 25 attacks PASS. No failures.*
