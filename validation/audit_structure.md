# SGGS Corpus Structural Audit Report
**File:** `sggs.jsonl` — 60,675 lines, Angs 1–1430  
**Audit date:** 2026-06-10  
**Auditor:** Automated structural check

---

## Summary Counts

| Severity | Count |
|----------|-------|
| P0 Critical | 2 |
| P1 Should-fix | 6 |
| P2 Cosmetic | 4 |

---

## Check 1 — Raag-Start Boundaries (31 boundaries)

### P1 — Boundary 594→595: ਸੁਧੁ raag field still set to ਵਡਹੰਸੁ, next ang opens ਸੋਰਠਿ

**Evidence:**
- `id=26065` `ang=594` `raag=ਵਡਹੰਸੁ` `comp_type=ਪਉੜੀ` — standalone `ਸੁਧੁ` (correct closer for ਵਡਹੰਸੁ ਵਾਰ ending at `id=26064` `॥੨੧॥੧॥`)
- `id=26066` `ang=595` `raag=ਵਡਹੰਸੁ` `is_header=1` — ੴ invocation (correct)
- `id=26067` `ang=595` `raag=ਸੋਰਠਿ` `is_header=1` — "ਸੋਰਠਿ ਮਹਲਾ ੧ ਘਰੁ ੧ ਚਉਪਦੇ ॥" (correct)

**Assessment:** The raag transition itself is clean — ੴ + raag title appear on ang 595. The ਸੁਧੁ marker is correctly standalone (no ॥) and correctly ends the ਵਡਹੰਸੁ block. The `raag` field on `id=26066` is still `ਵਡਹੰਸੁ` rather than `ਸੋਰਠਿ`, which is a metadata inconsistency (the ੴ header belongs to the new raag). **No text glue; boundary is structurally clean. Metadata fix needed on id=26066.**

**Suggested fix:** Set `raag=ਸੋਰਠਿ` on `id=26066`.

---

### P2 — Six raag-start angs (661, 877, 990, 1169, 1295, 1328) first unit is not is_header

**Evidence:**

| Ang | First id | Situation |
|-----|----------|-----------|
| 661 | 28736 | Composition continues mid-page from previous ang; raag title `id=28738` appears 3rd. Legitimate mid-page continuation. |
| 877 | 37453 | ਅਨੰਦੁ composition (ਰਾਮਕਲੀ) continues across ang boundary; ਰਾਮਕਲੀ raag start is ang 859, not 877. Ang 877 is mid-composition; the entry `877` in the raag table may be wrong or refers to a sub-section. |
| 990 | 42423 | ਮਾਰੂ ਸੋਲਹੇ sub-section continues mid-composition from ang 989. Legitimate. |
| 1169 | 50349 | ਬਸੰਤੁ composition continues from ang 1168. Legitimate mid-composition page break. |
| 1295 | 55622 | ਕਾਨੜਾ composition continues from ang 1294. Legitimate. |
| 1328 | 56795 | ਪ੍ਰਭਾਤੀ composition continues from ang 1327. Legitimate. |

**Assessment:** All six are legitimate mid-composition page breaks. The raag table first_angs for these entries mark the *start of the raag section*, not necessarily the first unit on that Ang. No corpus bug; the first-unit-not-header warning is expected behavior.

---

### CLEAN — Boundary 150→151 (ਮਾਝ ਵਾਰ → ਗਉੜੀ)

- `id=6275` `ang=150` standalone `ਸੁਧੁ` correctly closes ਮਾਝ ਵਾਰ
- `id=6276` `ang=151` `is_header=1` `raag=ਗਉੜੀ` — "ਰਾਗੁ ਗਉੜੀ ਗੁਆਰੇਰੀ ਮਹਲਾ ੧ ਚਉਪਦੇ ਦੁਪਦੇ" ✓
- `id=6277` `ang=151` `is_header=1` — ੴ ✓

No glue. All other 25 raag boundaries inspected: ੴ header present and clean on start ang.

---

## Check 2 — Units Without ॥

**Total without ॥: 482**

| Category | Count | Verdict |
|----------|-------|---------|
| `is_header=1` | 471 | Expected — raag titles, ੴ invocations, sub-section labels never carry ॥ |
| Standalone `ਸੁਧੁ` | 5 | Expected — vaar/composition closer; see Check 7 |
| One-word section labels without ॥ | 4 | See below |
| Multi-word compositional rubrics without ॥ | 2 | See below |

### P1 — Four one-word non-header units without ॥ that are NOT ਸੁਧੁ

| id | ang | text | Assessment |
|----|-----|------|------------|
| 10634 | 242 | `ਜੁਮਲਾ` | Colophon/rubric line ("total") between two compositions. No ॥ is correct for a counting label. But `is_header` should be 1, not 0. |
| 21645 | 478 | `ਦੁਤੁਕੇ` | Sub-section label ("two-line verses"). Should be `is_header=1`. |
| 28540 | 656 | `ਸੋਰਠਿ` | Raag name rubric within a bhagat collection. Should be `is_header=1`. |
| 55592 | 1293 | `ਮਲਾਰ` | Raag name rubric. Should be `is_header=1`. |

All four sit immediately before an ੴ invocation, confirming they are section-divider labels. They are not split bugs. **is_header flag is wrong (0 instead of 1).**

**Suggested fix:** Set `is_header=1` on ids 10634, 21645, 28540, 55592.

### P1 — Two multi-word non-header units without ॥

| id | ang | text | Assessment |
|----|-----|------|------------|
| 21808 | 481 | `ਬਾਈਸ ਚਉਪਦੇ ਤਥਾ ਪੰਚਪਦੇ ਆਸਾ ਸ੍ਰੀ ਕਬੀਰ ਜੀਉ ਕੇ ਤਿਪਦੇ ੮ ਦੁਤੁਕੇ ੭ ਇਕਤੁਕਾ ੧` | Colophon/count rubric for Kabir's ਆਸਾ section. Should be `is_header=1`. |
| 33849 | 792 | `ਕਬੀਰ ਕੇ` | Partial rubric "of Kabir" — section attribution line. Should be `is_header=1`. |

**Suggested fix:** Set `is_header=1` on ids 21808, 33849.

---

## Check 3 — Adjacent Duplicate Units

**Total adjacent duplicate pairs: 1**

### P0 — Double extraction: ids 54060 / 54061, ang 1256

**Evidence:**
```
id=54060  ang=1256  markers=['੧']  'ਵੈਦ ਨ ਭੋਲੇ ਦਾਰੂ ਲਾਇ ॥੧॥'
id=54061  ang=1256  markers=[]    'ਵੈਦ ਨ ਭੋਲੇ ਦਾਰੂ ਲਾਇ ॥'          ← DUPLICATE
id=54062  ang=1256  markers=[]    'ਦਰਦੁ ਹੋਵੈ ਦੁਖੁ ਰਹੈ ਸਰੀਰ ॥'
id=54063  ang=1256  markers=['੧','ਰਹਾਉ']  '...ਰਹਾਉ ॥'
```

`id=54061` is an exact duplicate of `id=54060` with the marker `੧॥` stripped. This is a double-extraction bug: the same physical line was extracted once with the closing marker and once without (possibly a verse-number stripping pass that created an extra record). The corpus flow from id=54059→54060→54062→54063 reads coherently; id=54061 disrupts it.

**Downstream impact:** Any line-count or verse-number based query will mis-sequence this shabad (ਮਲਾਰ ਮਹਲਾ ੧, comp near ang 1256).

**Suggested fix:** Delete `id=54061` from the corpus.

---

## Check 4 — Length Outliers

### No units > 35 words

**Verdict:** No merge bugs detected by word-count. The longest non-header lines are all within expected bounds for long ਵਾਰ pauris.

### 1-word non-header units: 206 total

**Breakdown:**

| Category | Count | Verdict |
|----------|-------|---------|
| Standalone `ਸੁਧੁ` (no ॥) | 5 | Expected (see Check 7) |
| Section/raag name labels (`ਆਸਾ ॥`, `ਛੰਤੁ ॥`, `ਗਉੜੀ ॥`, etc.) | ~155 | Expected within-composition sub-type markers. Text is `[name] ॥`. Should be `is_header=1` (see Check 2 findings for overlap). |
| Pure digit markers (`੧ ॥`, `੨ ॥`, `੩ ॥`, etc.) | 16 | P1: These appear to be orphaned numbering lines (e.g., the numeral at end of a stanza isolated into its own record). Verify these are legitimate stand-alone stanza-count lines rather than split records. Sample: `id=1313 ang=32 '੨ ॥'`, `id=7330 ang=176 '੧ ॥'`. |
| `ਰਹਾਉ ॥` | 4 | Expected — rahao sub-section labels |
| `ਡਖਣਾ ॥`, `ਪਵੜੀ ॥` | 15 | Expected section labels |

### P1 — 16 pure-digit 1-word lines: verify not split artifacts

**Sample:**
```
id=981   ang=24  comp_type=ਪਉੜੀ   '੩ ॥੨੬॥'
id=1313  ang=32  comp_type=ਅਨੰਦੁ  '੨ ॥'
id=4307  ang=107 comp_type=ਗੁਣਵੰਤੀ '੪ ॥੩੫॥੪੨॥'
id=4704  ang=116 comp_type=ਅਸਟਪਦੀਆ '੬ ॥'
```

**Assessment:** `id=981` (`੩ ॥੨੬॥`) and `id=4307` (`੪ ॥੩੫॥੪੨॥`) carry multi-number closing strings that match the multi-register pattern (`੩||੨੬||` = stanza 3, composition 26). These are legitimate end-markers extracted as separate lines from the preceding line. The others (`੧ ॥`, `੨ ॥`) are stanza-terminal markers. All appear to be genuine record separations from the source, not split bugs, though they inflate line counts. Flag for review: should these be merged back into the preceding stanza's closing line?

---

## Check 5 — comp_id Sanity

### 5a — 666 compositions with headers but zero body lines

**Assessment:** All 666 are single-unit comps (`is_header=1` only). Inspection confirms these are inter-section divider headers (raag titles, ੴ invocations, colophons, sub-section rubrics) assigned isolated comp_ids. Pattern is consistent across the whole corpus. **Not a bug — expected corpus design.**

No orphaned headers were found splitting body lines of another comp_id (zero cases where prev_comp_id == next_comp_id ≠ header_comp_id).

### 5b — Non-ਵਾਰ/ਸਲੋਕੁ compositions spanning ≥3 Angs: 55 found

**Sample (top 10 by ang-span):**

| comp_id | type | ang range | span | verdict |
|---------|------|-----------|------|---------|
| 5231 | ਸਵਈਏ | 1396–1406 | 11 angs | Expected — Svaiye collection spans multiple angs |
| 5175 | ਸਲੋਕ | 1353–1360 | 8 angs | Expected — Salok M9 collection |
| 3534 | ਅਨੰਦੁ | 917–921 | 5 angs | Expected — Anand Sahib (40 stanzas) |
| 3564 | ਅਨੰਦੁ | 934–938 | 5 angs | Expected |
| 3569 | ਵਣਜਾਰਾ | 942–946 | 5 angs | Expected |
| 5229 | ਸਵਈਏ | 1392–1396 | 5 angs | Expected |
| 8 | ਰੁਤੀ | 4–7 | 4 angs | Expected — Patti/Ruti baramah |
| 366 | ਅਨੰਦੁ | 133–136 | 4 angs | Expected |
| 1238 | ਅਸਟਪਦੀ | 334–337 | 4 angs | Expected |
| 1248 | ਬਾਵਨ ਅਖਰੀ | 340–343 | 4 angs | Expected |

**Assessment:** All 10 sampled are legitimate long-form compositions. No suspicious splits.

---

## Check 6 — Marker Sequence Violations

**Potential violations (marker drops > 5 from prev to cur): 16**

**Assessment of all 16:**

All 16 are **legitimate multi-register closings**, not out-of-order stanzas. The pattern is:
- A stanza ends with `॥੮॥੧॥` or `॥੮॥੨॥੪॥` (stanza 8 / composition 1 / running total)
- The next stanza begins a new composition numbering at `॥੧॥`
- The algorithm treats this as "8 → 1" which trips the violation threshold

Example: `comp_id=1584` (ਬਿਰਹੜੇ) — confirmed multi-composition block; each block counts 1–8, then resets. The final line `id=19859` has markers `['੮', '੩', '੨੨', '੧੫', '੨', '੪੨']` — a six-number closing chain (stanza / block / total / etc.), completely normal for ਗੁਰਮਤਿ ਸੰਗੀਤ notation.

Notable: `comp_id=4316` `id=50247` has a `28 → 1` reset — this is ਅਨੰਦੁ type `ang=1166`, where a 28-stanza composition closes and a new one starts at 1.

**No genuine marker-sequence bugs found. All 16 are false positives from multi-register notation.**

---

## Check 7 — ਸੁਧੁ Analysis

### Standalone ਸੁਧੁ (5 occurrences)

All 5 are correctly structured: no ॥, positioned as the final unit on their ang, immediately followed by ੴ invocation starting the next composition or raag section.

| id | ang | Raag / context | Following unit |
|----|-----|----------------|----------------|
| 3679 | 91 | ਸਿਰੀਰਾਗੁ ਵਾਰ (ਪਉੜੀ ੨੧) | id=3680: ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ (Kabir ਸਿਰੀਰਾਗੁ section) |
| 6275 | 150 | ਮਾਝ ਵਾਰ (ਪਉੜੀ ੨੭, final pauri) | id=6276: ਰਾਗੁ ਗਉੜੀ title on ang 151 |
| 21533 | 475 | ਆਸਾ ਵਾਰ (ਪਉੜੀ ੨੪) | id=21534: ੴ invocation for Kabir ਆਸਾ |
| 26065 | 594 | ਵਡਹੰਸੁ ਵਾਰ (ਪਉੜੀ ੨੧) | id=26066: ੴ on ang 595 (ਸੋਰਠਿ raag start) |
| 55534 | 1291 | ਮਲਾਰ ਵਾਰ (ਪਉੜੀ ੨੮) | id=55535: ੴ for bhagat section |

**Assessment:** All 5 ਸੁਧੁ instances are correctly placed and correctly left without ॥. The known "glue" bug pattern (ਸੁਧੁ + next-raag text merged) is **not present** in this corpus — each ਸੁਧੁ is its own discrete record.

### P0 — ਸੁਧੁ at ang 594 (id=26065): raag metadata leaks to first unit of ang 595

**Evidence:** `id=26066` `ang=595` `is_header=1` has `raag=ਵਡਹੰਸੁ` (wrong — should be `ਸੋਰਠਿ`). The ੴ invocation on ang 595 is the opening of ਸੋਰਠਿ, not a continuation of ਵਡਹੰਸੁ. This is a metadata tag error caused by the ਸੁਧੁ closer not resetting the raag context before writing the next header.

**Severity upgrade to P0:** This is the same class of bug described in the original known-bug example (vaar-closing word affecting the next raag's metadata). Here the ਸੁਧੁ unit itself is correct but the raag field on the immediately following ੴ header was not updated.

**Suggested fix:** Set `raag=ਸੋਰਠਿ` on `id=26066`.

### Units containing ' ਸੁਧੁ' as a word mid-text: 22

All 22 are verified as the Punjabi/Sanskrit word ਸੁਧੁ meaning "pure/clean" used in gurbani verse, not the vaar-closing marker. All end with ॥. No false positives.

---

## Check 8 — Mundavani / Raagmala / Salok M9 Region (angs 1426–1430)

**Unit-by-unit walkthrough:**

### Ang 1426: Salok M5 (continuing from earlier angs), transitions to Salok M9

- Lines `id=60471–60485`: Salok M5 continuation (couplets ending ॥੧੫॥ through ॥੨੨॥) — clean
- `id=60486`: `is_header=1` ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥ — invocation for Salok M9 section ✓
- `id=60487`: `is_header=1` "ਸਲੋਕ ਮਹਲਾ ੯ ॥" — correct header ✓
- `id=60488–60505`: Salok M9 stanzas ੧–੯, all correctly marked `author=Guru Tegh Bahadur Ji (M9)` ✓

### Ang 1427: Salok M9 continues (stanzas ੧੦–੨੭)
All body lines `id=60506–60543` — clean sequential numbering, correct author ✓

### Ang 1428: Salok M9 continues (stanzas ੨੮–੪੭)
`id=60544–60581` — clean ✓

### Ang 1429: Salok M9 concludes (stanzas ੪੮–੫੭), then Mundavani and Salok M5 closing, then Raagmala opens

- Stanzas ੪੮–੫੭ (ids 60582–60602) — final stanza `id=60602` ends `॥੫੭॥੧॥` ✓
- `id=60603`: `is_header=1` `comp_type=ਮੁੰਦਾਵਣੀ` "ਮੁੰਦਾਵਣੀ ਮਹਲਾ ੫ ॥" ✓
- `id=60604–60608`: Mundavani body (5 lines, last `॥੧॥`) ✓
- `id=60609`: `is_header=1` "ਸਲੋਕ ਮਹਲਾ ੫ ॥" ✓
- `id=60610–60613`: Salok M5 (4 lines, `॥੧॥` close) ✓
- `id=60614`: ੴ invocation for Raagmala ✓
- `id=60615`: "ਰਾਗ ਮਾਲਾ ॥" header ✓
- `id=60616–60618`: Raagmala body opens ✓

### Ang 1430: Raagmala continues to end of SGGS

`id=60619–60675`: Raagmala body, concludes at `id=60675` `'ਸਭੈ ਪੁਤ੍ਰ ਰਾਗੰਨ ਕੇ ਅਠਾਰਹ ਦਸ ਬੀਸ ॥੧॥੧॥'` — correct final closure ✓

**Assessment: Region 1426–1430 is CLEAN. Ordering is correct: Salok M5 → ੴ → Salok M9 → Mundavani → Salok M5 closure → ੴ → Raagmala. No glue, no missing headers, no duplicate units.**

### P2 — Note on comp_type consistency in this region

Several Raagmala lines within ang 1430 have `is_header=1` mid-body (ids 60632, 60634, 60666) for sub-stanza labels like "ਧਨਾਸਰੀ ਏ ਪਾਚਉ ਗਾਈ ॥" and "ਮਾਰੂ ਮਸਤਅੰਗ ਮੇਵਾਰਾ ॥". These are raag-name introductory lines within the Raagmala poem, not section headers. Setting `is_header=1` here is debatable but not harmful; no text is missing.

---

## P1 — Check 4 Addendum: 16 Orphaned Stanza-Numeral Lines

Lines like `id=981 '੩ ॥੨੬॥'`, `id=1313 '੨ ॥'`, etc. appear to be stanza-closing numerals extracted as separate records rather than kept as the last token of the stanza's final verse line. This inflates line-count statistics and may cause verse-numbering lookups to mis-fire. They are not split-corruption bugs (the preceding verse is intact), but they represent an extraction design choice that should be documented or corrected.

**Sample of 10:**
```
id=981   ang=24   '੩ ॥੨੬॥'
id=1313  ang=32   '੨ ॥'
id=4307  ang=107  '੪ ॥੩੫॥੪੨॥'
id=4704  ang=116  '੬ ॥'
id=4837  ang=119  '੫ ॥'
id=7330  ang=176  '੧ ॥'
id=9691  ang=224  '੪ ॥'
id=10580 ang=241  '੨ ॥'
id=15239 ang=332  '੧ ॥'
id=15514 ang=339  '੧ ॥ ਰਹਾਉ ॥'
```

**Suggested fix:** Merge each of these into the preceding verse line (append the numeral string to the prior record's gurmukhi/text fields and delete the orphan record).

---

## Consolidated Finding List

| # | Severity | Check | ids | Description |
|---|----------|-------|-----|-------------|
| F1 | **P0** | 3 | 54060, 54061 | Adjacent duplicate extraction: `ਵੈਦ ਨ ਭੋਲੇ ਦਾਰੂ ਲਾਇ` appears twice at ang 1256. Delete id=54061. |
| F2 | **P0** | 7 | 26066 | ੴ invocation opening ਸੋਰਠਿ (ang 595) has raag=ਵਡਹੰਸੁ (raag context not reset after ਸੁਧੁ closer). Set raag=ਸੋਰਠਿ on id=26066. |
| F3 | P1 | 1 | 26066 | Same record: also fix in Check 1 boundary note (duplicate fix with F2). |
| F4 | P1 | 2 | 10634, 21645, 28540, 55592 | Four one-word rubric lines (ਜੁਮਲਾ, ਦੁਤੁਕੇ, ਸੋਰਠਿ, ਮਲਾਰ) without ॥, incorrectly marked `is_header=0`. Set `is_header=1`. |
| F5 | P1 | 2 | 21808, 33849 | Two multi-word rubric lines without ॥, `is_header=0`. Set `is_header=1`. |
| F6 | P1 | 4 | 16 ids (see above) | 16 orphaned single-numeral lines that should be merged into preceding stanza's closing line. |
| F7 | P2 | 1 | 26067 | Raag field on second header of ang 595 confirms ਸੋਰਠਿ correctly; note for completeness. |
| F8 | P2 | 8 | 60632, 60634, 60666 | Raagmala sub-stanza intro lines marked `is_header=1`; debatable but harmless. |
| F9 | P2 | 4 | ~155 section labels | Section labels (`ਆਸਾ ॥`, `ਛੰਤੁ ॥`, `ਗੋਂਡ ॥`, etc.) marked `is_header=0`; should be reviewed for `is_header=1` upgrade. |
| F10 | P2 | 5 | 666 header-only comp_ids | Header-only comp_ids (all `is_header=1`) are corpus design, not bugs. Document as expected. |

---

## Notes on Checks with No Findings

- **Check 3 (adjacent duplicates):** Only 1 pair found (F1 above). Corpus is otherwise clean.
- **Check 6 (marker sequences):** 16 apparent violations; all confirmed as legitimate multi-register closing notation (`॥੮॥੧॥੩॥` etc.). Zero genuine marker-order bugs.
- **Check 7 (ਸੁਧੁ mid-text):** 22 occurrences of ਸੁਧੁ as a vocabulary word within verse; all correct. No vaar-closer confused with vocabulary ਸੁਧੁ.
- **Check 8 (1426–1430):** Region fully clean; correct order M5/M9/Mundavani/Salok/Raagmala.
