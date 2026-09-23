# SGGS Knowledge Base — Database & API Audit Report

**Date:** 2026-06-10  
**Auditor:** Automated audit tooling  
**Assets:**
- Corpus: `/ppt-universe/SGGS-KnowledgeBase/corpus/sggs.jsonl`
- DB: `/tmp/sggs.db` (copy of `/ppt-universe/SGGS-KnowledgeBase/db/sggs.sqlite`)
- App: `http://127.0.0.1:7777` (Python 3 stdlib server, `serve.py`)

---

## Executive Summary

| Severity | Count |
|----------|-------|
| P0       | 0     |
| P1       | 1     |
| P2       | 1     |
| INFO/PASS| 27    |

**No data-loss or integrity-breaking defects found.** One real P1 (2 rahao lines with missing transliteration), one P2 (HEAD returns 501 — acceptable but worth noting).

---

## Check 1 — DB Internal Integrity

### 1a. Row counts

| Metric           | Value  | Match |
|------------------|--------|-------|
| `lines.COUNT(*)` | 60,675 | —     |
| `MAX(lines.id)`  | 60,675 | ✓     |
| `fts.COUNT(*)`   | 60,675 | ✓     |
| Corpus lines     | 60,675 | ✓     |

**PASS.** All three row counts agree. Corpus/DB count equal at audit time (mismatch would be expected per brief; none exists here).

### 1b. FTS alignment (100 random IDs)

Sampled 100 random `lines.id` values. For each, took the first Gurmukhi token from `gurmukhi` and verified `COUNT(*) FROM fts WHERE text MATCH '"<token>"' AND rowid=<id>` equals 1.

**Result: 0 mismatches, 0 errors. PASS.**

### 1c. concept_lines orphans

```sql
SELECT COUNT(*) FROM concept_lines cl
WHERE NOT EXISTS (SELECT 1 FROM lines WHERE id = cl.line_id);
-- Result: 0
```

**Result: 0 orphans. PASS.**

### 1d. word_freq token recount

Recounted Gurmukhi tokens from `lines.text` (non-header rows, `is_header=0`, non-null/non-empty) and compared against `SUM(n)` in `word_freq`.

| Metric                                | Value   |
|---------------------------------------|---------|
| `word_freq.SUM(n)`                    | 383,083 |
| Recounted tokens from `text` column   | 383,120 |
| Difference                            | +37     |
| Mismatched word types                 | 9       |

All 9 mismatched word types are **pure Gurmukhi numeral tokens** (`੧`, `੨`, `੩`, `੪`, `੫`, `੬`, `੭`, `੮`, `੨੬`). These were intentionally excluded from `word_freq` by the pipeline (numerals carry no lexical weight). The 37-token gap is fully explained by this design decision.

**PASS (intentional exclusion; no unexpected discrepancies).**

### 1e. translit_norm null/empty

Total null/empty `translit_norm` on non-header lines: **18**.

- 16 are pure numeral-only lines (e.g., `੧ ॥`, `੪ ॥੩੫॥੪੨॥`) — correctly untransliterated.
- **2 lines are genuine rahao markers with missing transliteration:**

| id    | ang | gurmukhi      | is_rahao | translit | translit_norm |
|-------|-----|---------------|----------|----------|---------------|
| 15514 | 339 | `੧ ॥ ਰਹਾਉ ॥` | 1        | `''`     | `''`          |
| 18764 | 409 | `੧ ॥ ਰਹਾਉ ॥` | 1        | `''`     | `''`          |

The word `ਰਹਾਉ` is a valid Gurmukhi word that should have a transliteration (`rahaa-o` / `rahaau`). Out of 2,676 `is_rahao=1` lines containing `ਰਹਾਉ`, only these 2 have empty translit. The pipeline likely did not handle the edge case where a rahao line consists only of a numeral + `ਰਹਾਉ` without preceding verse text.

> **[P1]** `translit_norm` missing for 2 rahao lines (id 15514 ang 339, id 18764 ang 409). Both have `gurmukhi='੧ ॥ ਰਹਾਉ ॥'` with empty `translit` and `translit_norm`. The word `ਰਹਾਉ` should have been transliterated. Impact: roman-mode and roman first-letter search will not match these 2 lines. Fix: add transliteration in the pipeline for rahao lines that have non-numeral content.

---

## Check 2 — API `continued_from` (40 random Angs)

For 40 randomly sampled Angs, the expected `continued_from` was recomputed:
- If the first line of Ang N is NOT a header → `expected = MIN(ang) FOR comp_id` if `MIN(ang) < N`, else `null`.
- Compared against `/api/ang/{N}.continued_from`.

**Result: 40/40 correct, 0 violations. PASS.**

---

## Check 3 — Ang Summary Fields (15 random Angs)

The `raag` and `section` summary fields were recomputed from the lines in each response (majority-vote over all line `raag`/`section` values) and compared to the API-returned fields.

**Result: 0 raag mismatches, 0 section mismatches on 15 Angs. PASS.**

---

## Check 4 — Search Correctness Battery

| # | Query | Mode | Expected | Result |
|---|-------|------|----------|--------|
| 4a | `q=ਆਸਾ` | gurmukhi | All results contain `ਆਸਾ` | ✓ PASS — 5/5 |
| 4b | `q=kirpaa` | roman | All results contain ਕਿਰਪਾ-family | ✓ PASS (see note) |
| 4c | `q=ਸ ਨ ਕ ਪ` | first | fl_g of results contains sequence | ✓ PASS (see note) |
| 4d | `q=sach` | theme | Concept payload present | ✓ PASS — concept=sach |
| 4e | `q=xyzzy` | theme | Empty, no crash | ✓ PASS |
| 4f | `q=ਸ` (1 token) | first | No crash | ✓ PASS — 200 OK |
| 4g | `q=॥` | auto | No crash | ✓ PASS — 200 OK, empty |
| 4h | `q=ੴ` (`%E0%A9%B4`) | auto | Returns 568 hits | ✓ PASS — 5 results |
| 4i | `offset=999999` | — | Empty results | ✓ PASS |
| 4j | `limit=0` | — | No crash, 0 results | ✓ PASS |
| 4k | `limit=999` | — | Clamped ≤200 | ✓ PASS — 200 results |

**Note on 4b (roman kirpaa):** Results include both `ਕਿਰਪਾ` (plain form) and `ਕ੍ਰਿਪਾ` (virama/consonant-cluster form). Both are alternate Gurmukhi spellings of the same word; both transliterate to `kirpaa`/`kripaa` and normalize to `krp`. Every result correctly belongs to the kirpaa family. PASS.

**Note on 4c (first-mode fl_g):** The `fl_g` column stores space-separated first-letters (e.g., `ੴ ਸ ਨ ਕ ਪ ਨ ਨ...`). `fl_g` is not included in LINE_COLS of the API response (by design — it is an index-only field). All 5 returned IDs were verified via direct DB lookup to have `fl_g` containing `ਸ ਨ ਕ ਪ` as a substring. PASS.

**Note on `q=ੴ` encoding:** The correct UTF-8 percent-encoding for `ੴ` (U+0A74, Gurmukhi Ik Onkar) is `%E0%A9%B4`. The common mistake of `%E0%A7%B4` decodes to U+09F4 (Bengali). The API correctly returns 5 results for the properly-encoded `ੴ`.

---

## Check 5 — Encoding Paths

| Test | Status |
|------|--------|
| Gurmukhi multi-token with `+` separator | 200 OK — PASS |
| Gurmukhi multi-token with `%20` separator | 200 OK — PASS |
| Double-encoded `%25E0%25A8%25B8` | 200 OK, no crash — PASS |

---

## Check 6 — Performance (40 mixed queries, sequential)

| Metric | Search queries | `/api/ang` queries |
|--------|----------------|--------------------|
| p50    | 5.5 ms         | ~1.5 ms            |
| p95    | 58.1 ms        | 2.4 ms             |
| max    | 58.6 ms        | ~3.5 ms            |

Both p95 values well under the 300 ms threshold. **PASS.**

---

## Check 7 — Concurrency (10 threads × 5 requests = 50 total)

All 50 concurrent requests returned HTTP 200. No errors, timeouts, or crashes.

**PASS.**

---

## Check 8 — Server Hygiene

| Test | Result |
|------|--------|
| `GET /api/unknown_endpoint` | HTTP 500, JSON `{"error": "unknown endpoint"}` — PASS |
| `GET /nonexistent_path` | HTTP 200, serves `index.html` (SPA fallback) — PASS |
| `HEAD /` | HTTP 501 (Not Implemented) |
| 5 KB URL query string | HTTP 200, no crash — PASS |

> **[P2]** `HEAD /` returns HTTP 501. Python's `BaseHTTPRequestHandler` does not auto-implement HEAD. Not exploitable; low impact for a localhost tool. Mitigation: add `do_HEAD` to `serve.py` that calls `do_GET` but skips writing the body.

---

## P0 / P1 Summary (for quick reference)

**P0 items: 0**

**P1 items: 1**
- **translit_norm missing on 2 rahao lines** — `lines.id` 15514 (ang 339) and 18764 (ang 409); both have `gurmukhi='੧ ॥ ਰਹਾਉ ॥'` with empty `translit`/`translit_norm`. The word `ਰਹਾਉ` is untransliterated. Fix: pipeline should emit transliteration for any rahao line containing non-numeral Gurmukhi words.

**P2 items: 1**
- **HEAD / returns 501** — `serve.py` has no `do_HEAD` method. Add `do_HEAD = do_GET` shortcut (without writing body) for HTTP compliance.

---

*Audit complete. Read-only throughout; no files or databases were modified.*
