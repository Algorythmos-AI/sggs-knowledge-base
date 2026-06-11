# Gurbani App v1.9.0 — Search Battery Report

**Date:** 2026-06-11 | **Endpoint:** http://127.0.0.1:7777 | **Version:** 1.9.0 | **Health:** OK (all 6 checks pass)

---

## (a) Historic Queries

| ID | Query | Mode | Top Result | Verdict |
|----|-------|------|------------|---------|
| A1 | `jeevat jo mara ha duttar so tara ha` | passage-match (quote spans lines) | **ang 741** (ਜੀਵਤ ਮਰੈ ਬੁਝੈ ਪ੍ਰਭੁ ਸੋਇ / ਦੁਤਰੁ ਤਰੀਐ) | **WEAK** |
| A1b | `ਜੀਵਤ ਜੋ ਮਰੈ ਹਾਂ` (Gurmukhi direct) | gurmukhi | ang 410 ✓ | GOOD |
| A2 | `nij bhakti sheelbanti naar` | variant-match | ਨਿਜ ਭਗਤੀ ਸੀਲਵੰਤੀ ਨਾਰਿ, ang 370 ✓ | GOOD |

**A1 detail:** The exact lines (id 18821/18822, ang 410: ਜੀਵਤ ਜੋ ਮਰੈ ਹਾਂ / ਦੁਤਰੁ ਸੋ ਤਰੈ ਹਾਂ) exist in the DB. The roman query activates `passage-match` but surfaces ang 741 (ਜੀਵਤ ਮਰੈ...ਦੁਤਰੁ ਤਰੀਐ) instead — a looser match outranked the exact one. ang 410 is **absent** from the roman-query results. This is a ranking failure in the passage-match tier.

---

## (b) NEW Feature Classes

### Terminal-ai / word-order
| ID | Query | Mode | Result | Verdict |
|----|-------|------|--------|---------|
| B1 | `man mera` | variant-match | ਮੇਰੈ ਮਨਿ ✓ (reversed and normalized) | GOOD |
| B1b | `mere man` | roman | ਮੇਰੇ ਮਨ ਅਗਮ ਅਗੋਚਰ ang 759 ✓ | GOOD |

### Nasal drops (mai / main)
| ID | Query | Mode | Result | Verdict |
|----|-------|------|--------|---------|
| B4 | `mai andhule ki tek` | variant-match | ਮੈ ਅੰਧੁਲੇ ਕੀ ਟੇਕ, ang 727 ✓ | GOOD |
| B5 | `main andhule ki tek` | passage-match | **ang 829-830** (ਅੰਧੁਲੇ ਟਿਕ ਨਿਰਧਨ...) | **WEAK** |

**B5 detail:** `main` (nasal variant) triggers passage-match that lands on a different ਅੰਧੁਲੇ occurrence at ang 830 instead of the canonical ang 727 line. The `mai` variant correctly finds 727; `main` does not. Nasal-drop normalization is only partial — `mai` works, `main` fails to reach the same line.

### Cross-line / couplet spanning ॥
| ID | Query | Mode | Result | Verdict |
|----|-------|------|--------|---------|
| B6 | `pavan guroo paanee pita` | variant-match | ਪਵਣੁ ਗੁਰੂ ਪਾਣੀ ਪਿਤਾ ang 8 ✓ (also ang 146, 1021) | GOOD |
| B7 | `satnam waheguru` | roman-spelling-tolerant | 0 results | **WEAK** |
| B8 | `ik oankar satnam kartaa purakh` | variant-match | ੴ ਸਤਿਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ, multiple angs ✓ | GOOD |
| B9 | `dhan dhan ramdas gur jini siria` (sloppy) | variant-match | ਧੰਨੁ ਧੰਨੁ ਰਾਮਦਾਸ ਗੁਰੁ ang 968 ✓ | GOOD |
| B10a | `ik onkaar satnam karta purakh nirbhau nirankaar` | roman-spelling-tolerant | **0 results** | **WEAK** |
| B10b | `ik oankaar satnam kartaa purkh` (shorter) | variant-match | ੴ ਸਤਿਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ✓ | GOOD |
| B11 | `vaahiguroo vaah jeeo sat saach sri nivaas` | variant-match | ਸਤਿ ਸਾਚੁ ਸ੍ਰੀ ਨਿਵਾਸੁ...ਵਾਹਿਗੁਰੂ ang 1402 ✓ | GOOD |

**B10a detail:** Adding `nirbhau nirankaar` to a long Mool Mantar query zeros out results in `roman-spelling-tolerant` mode. `nirbhau nirankaar` alone returns 4 correct results. Long multi-clause query causes OR-waterfall to over-filter or fail to cascade. Reproducible: `q=ik+onkaar+satnam+karta+purakh+nirbhau+nirankaar`.

---

## (c) Regression Sweep

| Query | Mode | Top Result | Verdict |
|-------|------|------------|---------|
| waheguru | seeker-lexicon (vaahiguroo) | ਵਾਹਿਗੁਰੂ ਵਾਹਿਗੁਰੂ ang 1402 ✓ | GOOD |
| wahiguru | variant-match | ਵਾਹਿਗੁਰੂ ang 1402 ✓ | GOOD |
| gyan | seeker-lexicon (giaan) | ਗਿਆਨ ਖੰਡ ਮਹਿ ਗਿਆਨੁ ਪਰਚੰਡੁ ang 7 ✓ | GOOD |
| yashoda | seeker-lexicon (jasudaa) | ਜਸੁਦਾ ਘਰਿ ਕਾਨੁ ang 75 ✓ | GOOD |
| mercy | seeker-lexicon (daiaa) | ਦਇਆ ਦਇਆ ਕਰਿ ✓ | GOOD |
| kirtan | variant-match | ਕੀਰਤਨੰ ✓ | GOOD |
| bhakti | seeker-lexicon (bhagat) | ਭਗਤਿ ਵਛਲੁ ✓ | GOOD |
| shakti | variant-match | ਸਕਤੀ ✓ | GOOD |
| krishna | seeker-lexicon (krisan) | ਕ੍ਰਿਸਨ ✓ | GOOD |
| farid | seeker-lexicon (phareed) | ਸਲੋਕ ਸੇਖ ਫਰੀਦ ✓ | GOOD |
| satnam | seeker-lexicon (sat naam) | ਸਤਿ ਨਾਮੁ ✓ | GOOD |
| hukum | variant-match | ਹੁਕਮੀ ਹੁਕਮੁ ang 2 ✓ | GOOD |
| swami | variant-match | ਸ੍ਵਾਮੀ ✓ | GOOD |
| ਸਤਿ ਨਾਮੁ (Gurmukhi) | gurmukhi | ਨਾਮੁ ਸਤਿ ਸਤਿ ✓ | GOOD |
| ਧ ਧ ਰ ਗ (first letters) | first-letters | ਧੰਧਾ ਧਾਵਤ ਰਹਿ ਗਏ ✓ + ਧੰਨੁ ਧੰਨੁ ਰਾਮਦਾਸ ✓ | GOOD |
| pavan guroo paanee (Ang 8) | roman | ਪਵਣੁ ਗੁਰੂ ਪਾਣੀ ਪਿਤਾ ang 8 ✓ | GOOD |
| compassion mercy (English) | english-translation | ਕ੍ਰਿਪਾ ਨਿਧਾਨ ਦਇਆਲ ✓ | GOOD |
| satnam waheguru | roman-spelling-tolerant | 0 results | **WEAK** |

---

## (d) Junk / Robustness

| Query | Mode | Result | Verdict |
|-------|------|--------|---------|
| `zzz qqq` | variant-match | Returns 4 random unrelated Gurbani lines | **WEAK** |
| 🙏🙏 (emoji) | roman-spelling-tolerant | 0 results, no crash | GOOD |
| 800-char `aaa...` | variant-match | **Identical results to single `a`** — silent truncation | WEAK |
| `a` | variant-match | Returns 4 lines (degenerate but graceful) | WEAK |

**D1 detail (`zzz qqq`):** `variant-match` returns 4 genuine Gurbani lines that have no semantic relation to the junk input. This misleads users into thinking results are relevant. Should return 0 results or a "not found" signal. Repro: `GET /api/search?q=zzz+qqq&limit=4`.

**D3 detail (800-char):** Engine silently truncates to single-letter degenerate query, returns same 4 lines as `q=a`. No 400 error, no truncation warning. Repro: `GET /api/search?q=<800 'a' chars>&limit=4`.

---

## (e) Health Check

```
ok: True | version: 1.9.0
checks: lines_60658, angs_1430, fts5, mool_mantar, ik_onkar_568, verify_engine — ALL PASS
```

---

## Summary

| Category | GOOD | WEAK | BAD |
|----------|------|------|-----|
| (a) Historic | 1 (A2) | 1 (A1 roman→wrong ang) | 0 |
| (b) NEW classes | 7 | 3 (B5, B7, B10a) | 0 |
| (c) Regression | 16 | 1 (satnam waheguru=0) | 0 |
| (d) Junk | 1 (emoji) | 3 (zzz, 800-char, single-a) | 0 |
| (e) Health | 1 | 0 | 0 |
| **TOTAL** | **26** | **8** | **0** |

### BAD Issues (blocking): NONE

### WEAK Issues (should fix before next release):

1. **A1 RANKING** — `jeevat jo mara ha duttar so tara ha` → passage-match returns ang 741 (inexact), misses ang 410 (exact). Repro: `q=jeevat+jo+mara+ha+duttar+so+tara+ha`.
2. **B5 NASAL** — `main andhule ki tek` → passage-match at ang 829-830 (wrong); `mai andhule ki tek` correctly hits ang 727. `main` nasal form not collapsing to same result as `mai`.
3. **B7/C_SATNAM_WAHEGURU** — Two-word cross-lexicon query `satnam waheguru` returns 0 in roman-spelling-tolerant mode; each word individually works. OR-waterfall fails to cascade to single-term fallback.
4. **B10a LONG MOOL MANTAR** — `ik onkaar satnam karta purakh nirbhau nirankaar` returns 0; truncating to `ik oankaar satnam kartaa purkh` works. Long multi-clause OR-waterfall over-filters.
5. **D1 JUNK RESULTS** — `zzz qqq` returns 4 genuine Gurbani lines via variant-match fall-through. Should yield 0/not-found rather than misleading random hits.
6. **D3 800-CHAR** — Silent truncation to single-letter degenerate query; identical results to `q=a`. Input should be sanitized/limited with a 400 or graceful empty response.

---

**VERDICT: SHIP WITH CAUTION** — No BADs, 26 GOODs. The 6 WEAKs are search quality and UX issues (not crashes or data corruption). A1 ranking and B5 nasal are the most user-visible. The junk/degenerate query issues (D1, D3) could confuse users but are not harmful. Recommend fixing A1 passage-match ranking and B5 nasal normalization before public release; defer junk-input hardening to a patch.
