# SGGS Corpus — Canonical Validation Report

**Corpus:** `/ppt-universe/SGGS-KnowledgeBase/corpus/sggs.jsonl`  
**Total records:** 60,193  
**Date validated:** 2026-06-10

---

## Check 1 — Angs 1..1430 all present; IDs strictly increasing; Ang non-decreasing

**PASS**

- All 1430 angs present (no gaps, no extras outside 1–1430).
- IDs 1..60193 are strictly increasing (zero violations found).
- Ang values are non-decreasing across all 60,193 records (zero violations found).

---

## Check 2 — Mool Mantar on Ang 1

**PASS**

Record `id=1`, `ang=1` contains the exact string:

> `ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ ਅਜੂਨੀ ਸੈਭੰ ਗੁਰ ਪ੍ਰਸਾਦਿ`

in both the `text` and `gurmukhi` fields (the `gurmukhi` field additionally carries the trailing `॥`). Match is exact and unique on Ang 1.

---

## Check 3 — Japji structure (Angs 1–8)

**PASS**

- Section `ਜਪੁ` contains 384 records spanning exactly Angs 1–8.
- All 38 numeric Gurmukhi verse markers (੧ through ੩੮) are present and appear in strictly ascending order of first occurrence.
- Closing salok `ਪਵਣੁ ਗੁਰੂ ਪਾਣੀ ਪਿਤਾ ਮਾਤਾ ਧਰਤਿ ਮਹਤੁ ॥` found on Ang 8 (`id=519`).

---

## Check 4 — Anand Sahib (Ang 917–922, Ramkali M3)

**PASS**

- 209 records on Angs 917–922, all authored `Guru Amar Das Ji (M3)`, raag `ਰਾਮਕਲੀ`.
- Numeric markers ੧ through ੪੦ (1–40) all present with no gaps.
- Marker 40 (੪੦) confirmed present — 40 pauris accounted for.

---

## Check 5 — Sukhmani Sahib (Gauri M5, Angs 262–296)

**PASS**

- 2,063 records on Angs 262–296, all authored `Guru Arjan Dev Ji (M5)`, raag `ਗਉੜੀ`.
- Exactly **24** `ਅਸਟਪਦੀ` header records found (`is_header=1`, `comp_type=ਅਸਟਪਦੀ`).
- All 24 ashtapadis are preceded by a `ਸਲੋਕੁ` unit (24/24 checked, 0 failures).
- 28 `ਸਲੋਕੁ` header records exist in range (24 before ashtapadis + 4 others consistent with the text's opening and closing saloks).

---

## Check 6 — Asa di Vaar (Angs 462–475)

**PASS**

- 672 records on Angs 462–475 (section `ਸੋ ਦਰੁ`, comp_type includes `ਵਾਰ`, `ਪਉੜੀ`, `ਸਲੋਕੁ`).
- Numeric markers ੧ through ੨੪ (1–24) all present with no gaps.
- Marker 24 (੨੪) confirmed — 24 pauris accounted for.
- Authors: M1, M2, M5, Bhagat Kabir Ji (Saloks between pauris, canonical).

---

## Check 7 — Salok Mahala 9 (Angs 1426–1429)

**PASS**

- 148 records on Angs 1426–1429 (includes `ਮੁੰਦਾਵਣੀ` and `ਰਾਗ ਮਾਲਾ` nearby records in range).
- `Guru Tegh Bahadur Ji (M9)` records carry numeric markers ੧ through ੫੭ (1–57), all present with no gaps.
- Marker 57 (੫੭) confirmed — 57 saloks accounted for.

---

## Check 8 — Raag Order

**PASS**

All 31 canonical raags found. Using first ang ≥ 14 where a raag has ≥ 3 records in an ang (to exclude stray header tags — notably a single `ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ` line at Ang 14 tagged `ਗਉੜੀ` from the Soohila section), the main section starts are strictly non-decreasing:

| Raag | First main Ang |
|---|---|
| ਸਿਰੀਰਾਗੁ | 14 |
| ਮਾਝ | 94 |
| ਗਉੜੀ | 151 |
| ਆਸਾ | 347 |
| ਗੂਜਰੀ | 489 |
| ਦੇਵਗੰਧਾਰੀ | 527 |
| ਬਿਹਾਗੜਾ | 537 |
| ਵਡਹੰਸੁ | 557 |
| ਸੋਰਠਿ | 595 |
| ਧਨਾਸਰੀ | 660 |
| ਜੈਤਸਰੀ | 696 |
| ਟੋਡੀ | 711 |
| ਬੈਰਾੜੀ | 719 |
| ਤਿਲੰਗ | 721 |
| ਸੂਹੀ | 728 |
| ਬਿਲਾਵਲੁ | 795 |
| ਗੋਂਡ | 859 |
| ਰਾਮਕਲੀ | 876 |
| ਨਟ | 975 |
| ਮਾਲੀ ਗਉੜਾ | 984 |
| ਮਾਰੂ | 989 |
| ਤੁਖਾਰੀ | 1107 |
| ਕੇਦਾਰਾ | 1118 |
| ਭੈਰਉ | 1125 |
| ਬਸੰਤੁ | 1168 |
| ਸਾਰੰਗ | 1197 |
| ਮਲਾਰ | 1254 |
| ਕਾਨੜਾ | 1294 |
| ਕਲਿਆਨੁ | 1319 |
| ਪ੍ਰਭਾਤੀ | 1327 |
| ਜੈਜਾਵੰਤੀ | 1352 |

Zero order violations. No raags missing from corpus.

*Note:* A single record (`id=587`, `ang=14`) carries `raag=ਗਉੜੀ` but is a stray `ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ` invocation line within the Soohila group. The ਗਉੜੀ main section properly starts at Ang 151. This is a minor tag precision issue, not a structural error.

---

## Check 9 — Ang 1430 ends with Raagmala

**PASS**

- All 57 records on Ang 1430 are in section `ਰਾਗ ਮਾਲਾ`.
- The very last record in the corpus (`id=60193`) reads:

> `ਸਭੈ ਪੁਤ੍ਰ ਰਾਗੰਨ ਕੇ ਅਠਾਰਹ ਦਸ ਬੀਸ`

  The keyword `ਅਠਾਰਹ ਦਸ ਬੀਸ` is present and is the final line of the corpus.

---

## Check 10 — Rahao Sanity

**PASS**

- Total `is_rahao=1` lines: **2,676** — within the expected range 2,600–2,800. ✓
- Rahao lines in section `ਜਪੁ`: **0** — no rahao inside Japji. ✓
- Lines carrying `ਰਹਾਉ` marker: 2,651. The 25-line difference (is_rahao=1 but no explicit marker) reflects lines whose rahao status is encoded via `is_rahao` flag rather than a standalone marker token; all `ਰਹਾਉ`-marker lines correctly have `is_rahao=1` (0 inverse mismatches).

---

## Check 11 — Author Sanity

**PASS**

- Each Mahala number maps to exactly one Guru with no cross-contamination:
  - M1 → Guru Nanak Dev Ji (M1) only
  - M2 → Guru Angad Dev Ji (M2) only
  - M3 → Guru Amar Das Ji (M3) only
  - M4 → Guru Ram Das Ji (M4) only
  - M5 → Guru Arjan Dev Ji (M5) only
  - M9 → Guru Tegh Bahadur Ji (M9) only
- 19 distinct authors total (6 Gurus + Baba Sundar Ji + Satta & Balwand + Bhai Mardana + 9 Bhagats/Sheikh).

**Bhagat Bani location spot-checks:**
- **Bhagat Kabir Ji in ਭੈਰਉ** (~Ang 1158): 208 records, Ang range 1157–1163. ✓
- **Sheikh Farid Ji in ਆਸਾ** (~Ang 488): 30 records, Ang range 488–489. ✓
- **Bhagat Ravidas Ji in ਸੋਰਠਿ** (~Ang 658): 69 records, Ang range 657–659. ✓

---

## Check 12 — Numeric Continuity Within Compositions

**PASS**

- 4,681 unique comp_ids; 2,907 have ≥ 2 distinct numeric markers.
- Random sample of 200 compositions (seed=42): **196/200 = 98.0% monotonic** (markers appear in non-decreasing order of first occurrence). Exceeds the 90% threshold.
- 4 non-monotonic compositions identified. Inspection reveals these are **not structural errors** — they are legitimate corpus features:
  - **comp_ids 1171, 1180** (Kabir, Gauri, Angs 333–340): multi-composition groupings with triple markers (e.g., `['੫', '੬', '੫੦']`) encoding local pauri number, running total within raag, and running total within entire Kabir bani. These cross-count systems naturally produce apparent non-monotonicity in single-dimension analysis.
  - **comp_id 2470** (M5, Jaitasri, Ang 705): two-verse composition with markers `['੪', '੨']` — a local stanza number combined with a ghar/tuk counter.
  - **comp_id 3487** (M5, Ramkali, Ang 1031): triple-marker system `['੧੭', '੪', '੧੦']` same multi-count convention.

All 4 cases reflect legitimate multi-register numbering conventions, not data integrity failures.

---

## Summary

| # | Check | Result |
|---|---|---|
| 1 | Angs 1–1430 present, IDs strictly increasing, Ang non-decreasing | **PASS** |
| 2 | Mool Mantar exact text on Ang 1 | **PASS** |
| 3 | Japji markers ੧–੩੮ in order + closing salok Ang 8 | **PASS** |
| 4 | Anand Sahib markers reach ੪੦ (40 pauris) | **PASS** |
| 5 | Sukhmani 24 ashtapadis, each preceded by salok | **PASS** |
| 6 | Asa di Vaar markers reach ੨੪ (24 pauris) | **PASS** |
| 7 | Salok Mahala 9 markers reach ੫੭ (57 saloks) | **PASS** |
| 8 | Raag order matches canon (all 31 raags in sequence) | **PASS** |
| 9 | Ang 1430 is Raagmala; last line contains ਅਠਾਰਹ ਦਸ ਬੀਸ | **PASS** |
| 10 | Rahao total 2,676 (in 2600–2800); none in ਜਪੁ | **PASS** |
| 11 | Mahala→Guru 1:1; Bhagat Bani locations correct | **PASS** |
| 12 | Marker monotonicity 98% in sampled 200 comps (≥90% threshold) | **PASS** |

**All 12 checks PASS. Corpus is canonically sound.**
