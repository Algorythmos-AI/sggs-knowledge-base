# SGGS Corpus Unicode & Transliteration Audit Report

**Corpus:** `/sessions/dreamy-brave-wozniak/mnt/ppt-universe/SGGS-KnowledgeBase/corpus/sggs.jsonl`  
**Total rows:** 60,675  
**Audited fields:** `text`, `translit`, `fl_g`, `fl_r`  
**Date:** 2026-06-10  
**Auditor:** Senior Audit Engineer (automated + expert review)

---

## CHECK 1 — Character Inventory of `text` Field

**Result: PASS (P0 = 0)**

Total distinct codepoints: **66**, all within allowed ranges.

| Range | Description | Count |
|---|---|---|
| U+0020 | SPACE | 339,375 occurrences |
| U+0A00–U+0A7F | Gurmukhi block (full consonant set, vowels, numerals, virama, tippi, bindi, visarga, ੴ) | all 65 Gurmukhi chars present |
| U+0965 | Danda | **0 — correctly absent from `text` field** (present only in `gurmukhi` field) |

No Arabic digits, no Latin letters, no stray punctuation, no BOM, no zero-width characters, no surrogate pairs, no U+0A3C nukta detected anywhere in `text`.

**Selected codepoint inventory:**

```
U+0A02 ਂ  BINDI          2,027
U+0A03 ਃ  VISARGA          947
U+0A3E ਾ  AA-SIGN       132,998
U+0A3F ਿ  I-SIGN        127,982
U+0A40 ੀ  II-SIGN        45,658
U+0A41 ੁ  U-SIGN         96,489
U+0A4D ੍  VIRAMA         13,497
U+0A70 ੰ  TIPPI          21,773
U+0A74 ੴ  EK ONKAR          568
```

---

## CHECK 2 — Illegal Sequences in `text`

### 2a. Double vowel-signs — P1

**Non-Sahaskriti double vowels: 2 occurrences**

| id | ang | word | analysis |
|---|---|---|---|
| 58072 | 1358 | `ਬਿਗ੍ਯ੍ਯਾਿ੍ਪਤ` | ਯ੍ਯ cluster + AA-sign (U+0A3E) + spurious I-sign (U+0A3F) before virama+ਪ. Intended: Sanskrit *vijnyaapit*. The ਾਿ is a spurious double-vowel. |
| 59167 | 1387 | `ਨਾਿ੍ਸਤ` | U+0A28+U+0A3E+U+0A3F+U+0A4D+U+0A38+U+0A24. Intended: Sanskrit *nasti* ("does not exist"). I-sign before virama cluster is spurious. |

**Sahaskriti-convention ਿਾ (sihari before AA-sign after ੍ਯ cluster): 4 occurrences** — These are the known sihari visual-reorder convention in logical-order encoding. PASS; noted for awareness.

### 2b. Vowel-sign at word start — P1

**34 occurrences (34 matches), 32 unique rows, 15 unique Angs**

**Pattern A — `ਓ ੁ` split (31 rows):** The U-sign (ੁ U+0A41) appears as a standalone space-separated token immediately after a word ending in U+0A13 (OO letter). A spurious space has split the `ਓੁ` diphthong. Affected root words: `ਗਾਓ`, `ਚਾਓ`, `ਪਾਓ`, `ਰਾਓ`, `ਨਾਓ`, `ਸਫਲਿਓ`, `ਲਇਓ`, `ਰਾਖਿਓ`, `ਮਾਖਿਓ`, `ਹੀਂਓ`.

Angs affected: 77, 214, 342, 698, 699, 897, 1173, 1201, 1203, 1204, 1205, 1249, 1367, 1379.

Sample:
```
id=3109  ang=77:   ਕਹੁ ਨਾਨਕ … ਸਫਲਿਓ ੁ ਰੈਣਿ ਭਗਤਾ ਦੀ
id=9250  ang=214:  ਓ ੁਹੀ ਪੀਓ ਓ ੁਹੀ ਖੀਓ  [ਓ+space+ੁਹੀ — reverse split]
id=50595 ang=1173: ਸਫਲਿਓ ੁ ਬਿਰਖੁ ਹਰਿ ਕੈ ਦੁਆਰਿ
```

**Pattern B — `ਮਿਲ੍ਯ੍ਯਿ ੋ` split (1 row, id=30084, ang=695):** OO-sign (ੋ U+0A4B) separated from its consonant cluster by spurious space.

### 2c. Halant not followed by consonant — PASS (0)

### 2d. Nasal (ੰ/ਂ) followed by vowel-sign — PASS (0)

### 2e. ਼ standalone — PASS (U+0A3C absent from corpus entirely)

### 2f. ੴ mid-word — PASS (0). All 568 instances at word boundary.

### 2g. Virama at word start — P1

**3 occurrences, all Sahaskriti section Ang 1354:**

| id | ang | token | full text |
|---|---|---|---|
| 57904 | 1354 | `੍ਸਨੇਹੰ` | `ਧ੍ਰਿਗ ੍ਸਨੇਹੰ ਬਨਿਤਾ ਬਿਲਾਸ ਸੁਤਹ` |
| 57905 | 1354 | `੍ਸਨੇਹੰ` | `ਧ੍ਰਿਗ ੍ਸਨੇਹੰ ਗ੍ਰਿਹਾਰਥ ਕਹ` |
| 57906 | 1354 | `੍ਸਨੇਹ` | `ਸਾਧਸੰਗ ੍ਸਨੇਹ ਸਤ੍ਯ੍ਯਿੰ ਸੁਖਯੰ ਬਸੰਤਿ ਨਾਨਕਹ` |

The word should be `ਸਨੇਹੰ` (*snehaN*). The leading virama has no consonant host — a data-entry error. Translit correctly renders `sanehn` by ignoring it; fl_g is off by 1 for id=57905.

---

## CHECK 3 — NFC Idempotence

**PASS — 0 violations across all 60,675 rows.**

---

## CHECK 4 — Visarga ਃ (U+0A03) Inventory

**Total rows with ਃ: 947**

| Category | Count | Judgment |
|---|---|---|
| `ਮਃ` Mahalla authorship marker | 943 | CORRECT — standard SGGS usage |
| Word-ending visarga (Sahaskriti, Ang 1361) | 4 | CORRECT — Sanskrit terminal visarga: `ਦ੍ਰਿੜੰਤਣਃ`, `ਲਿਖ੍ਯ੍ਯਣਃ`, `ਸੰਪੂਰਣਃ`, `ਰੰਗਣਃ` |

**Verdict: All 947 visarga usages contextually legitimate. No erroneous visarga.**

---

## CHECK 5 — Transliteration Integrity

### 5a. Empty translit with non-numeral text — PASS (0)

### 5b. Word count mismatch (text vs translit) — P2

**Total mismatches: 581**

| Category | Count | Severity |
|---|---|---|
| ੴ → "ik oankaar" (1 Gur word → 2 translit words) | 568 | By-design; documented below |
| Double-space in translit (isolated vowel produces blank) | 8 | P2 |
| Other genuine mismatches | 5 | P2 |

**Genuine mismatches (ang 1201, caused by `ਓ ੁ` split):**
ids 51892, 51893, 51895, 51897, 51899 — each has isolated ੁ adding +1 text token with no corresponding translit token (blank/double-space in translit).

id 57905 ang 1354: 4 text tokens, only 3 translit tokens (leading-virama token renders as empty).

### 5c. Translit character set — PASS

All translit values are `[a-z ]` only. No digits, diacritics, capitals, or punctuation in any row.

### 5d. Translit words with no vowel — PASS (0)

---

## CHECK 6 — Transliteration Spot-Grid (Expert Review)

### Japji (Ang 1, Pauris 1–15)

Scheme is consistent phonemic transliteration with final sihari (-i) and lavan (-u) elided throughout: `ਸਤਿ→sat`, `ਨਾਮੁ→naam`, `ਮੂਰਤਿ→moorat`, `ਪ੍ਰਸਾਦਿ→prasaad`, `ਹਰਿ→har`. This is a deliberate systematic scheme, not an error.

**Notable items:**
- `ੴ → ik oankaar` — correct.
- `ਸੈਭੰ → saibhn` — tippi rendered as final `n` without velar nasal `ng`. The *anusvara* context (pre-consonant nasalization) is lost. Internally consistent but lacks the `g`-sound: scholarly convention is *saibhaṁ* or *saibhang*.
- All Hukam pauri lines (lines 7–15): accurate.

**Verdict: CORRECT scheme.** One scheme note: tippi→`n` vs `ng/ṁ` should be documented.

### Vaar Salok (Ang 463)

```
ਜੇ ਸਉ ਚੰਦਾ ਉਗਵਹਿ ਸੂਰਜ ਚੜਹਿ ਹਜਾਰ → je sau chandaa ugavah sooraj charhah hajaar  ✓
ਏਤੇ ਚਾਨਣ ਹੋਦਿਆਂ ਗੁਰ ਬਿਨੁ ਘੋਰ ਅੰਧਾਰ → ete chaanan hodiaan gur bin ghor andhaar  ✓
ਮਹਲਾ ੨ → mahalaa  [numeral dropped — by design]  ✓
ਮਃ ੧ → ma  [visarga + numeral dropped]  ✓
```

**Verdict: CORRECT.** Minor inconsistency: 2 headers at Ang 142–143 give `ma salok` vs `ma` everywhere else (P2).

### Bhagat Kabir (Ang 1158)

```
ਰਾਮੁ ਰਾਜਾ ਨਉ ਨਿਧਿ ਮੇਰੈ → raam raajaa nau nidh merai  ✓
ਲੰਕਾ ਗਢੁ ਸੋਨੇ ਕਾ ਭਇਆ → lankaa gadh sone kaa bhaiaa  ✓
```

**Verdict: CORRECT.**

### Sheikh Farid (Ang 1378)

```
ਬੰਨ੍ਹਿ ਉਠਾਈ ਪੋਟਲੀ ਕਿਥੈ ਵੰਞਾ ਘਤਿ → bannh uthaaee potalee kithai vannjaa ghat  ✓
ਸਾਂਈਂ ਮੇਰੈ ਚੰਗਾ ਕੀਤਾ ਨਾਹੀ ਤ ਹੰ ਭੀ ਦਝਾਂ ਆਹਿ → saaneen merai changaa keetaa naahee ta han bhee dajhaan aah  ✓
```

**Verdict: CORRECT.** `ਵੰਞਾ → vannjaa` correctly doubles ਞ cluster.

### Sahaskriti (Ang 1354)

```
ਧ੍ਰਿਗੰਤ ਮਾਤ ਪਿਤਾ ਸਨੇਹੰ → dhrigant maat pitaa sanehn  ✓
ਧ੍ਰਿਗ ੍ਸਨੇਹੰ ਬਨਿਤਾ ਬਿਲਾਸ ਸੁਤਹ → dhrig sanehn banitaa bilaas sutah  [leading virama silently ignored — OK]
ਧ੍ਰਿਗ ੍ਸਨੇਹੰ ਗ੍ਰਿਹਾਰਥ ਕਹ → dhrig sanehn grihaarath kah  [4 text tokens, 3 translit — fl_g off by 1]  P2
```

**Verdict: Mostly correct.** Visarga endings correctly dropped in translit (`ਦ੍ਰਿੜੰਤਣਃ → drirhantan`).

### Swaiyye (Ang 1402)

```
ਸਤਿਗੁਰੁ ਗੁਰੁ ਸੇਵਿ ਅਲਖ ਗਤਿ ਜਾ ਕੀ ਸ੍ਰੀ ਰਾਮਦਾਸੁ ਤਾਰਣ ਤਰਣੰ
→ satigur gur sev alakh gat jaa kee sree raamadaas taaran tarann  ✓
```

**Verdict: CORRECT.**

### Tilang / Persian-influenced (Ang 721–727)

```
ਯਕ ਅਰਜ ਗੁਫਤਮ ਪੇਸਿ ਤੋ ਦਰ ਗੋਸ ਕੁਨ ਕਰਤਾਰ → yak araj guphatam pes to dar gos kun karataar  ✓
ਹਕਾ ਕਬੀਰ ਕਰੀਮ ਤੂ ਬੇਐਬ ਪਰਵਦਗਾਰ → hakaa kabeer kareem too beaib paravadagaar  ✓
ਮਮ ਸਰ ਮੂਇ ਅਜਰਾਈਲ ਗਿਰਫਤਹ ਦਿਲ ਹੇਚਿ ਨ ਦਾਨੀ → mam sar mooi ajaraaeel giraphatah dil hech na daanee  ✓
ਆਖਿਰ ਬਿਅਫਤਮ ਕਸ ਨ ਦਾਰਦ ਚੂੰ ਸਵਦ ਤਕਬੀਰ → aakhir biaphatam kas na daarad choon savad takabeer  ✓
```

**Scheme issue (not error):** ਫ→`ph` (not `f`) throughout; no `f`-phoneme in scheme. Persian/Arabic loanword phonemes mapped to nearest Gurmukhi equivalents. Acceptable given scope; must be documented.

**Verdict: CORRECT for Gurmukhi phonetics. Scheme limitation for Persian loanwords.**

---

## CHECK 7 — First-Letter Fields (fl_g / fl_r)

**Total fl_g/fl_r word count mismatches vs text (excl. numerals): 35 rows**

| Category | Count |
|---|---|
| Caused by P1-1 isolated ੁ/ੋ split (+1 text token vs fl_g) | 33 |
| id=51893 ang=1201 (`ਚਾਓ ੁ` split) | 1 |
| id=57905 ang=1354 (leading-virama token not counted in fl_g) | 1 |

---

## CONSOLIDATED FINDINGS

### P0 (Critical)
*None.*

### P1 (Serious — fix required)

| # | Issue | Rows | Angs |
|---|---|---|---|
| P1-1 | **Isolated vowel-sign token** (ੁ or ੋ as standalone space-separated word; spurious space splits ਓੁ/cluster+vowel) | 32 unique rows, 34 occurrences | 15 Angs: 77, 214, 342, 695, 698, 699, 897, 1173, 1201, 1203–1205, 1249, 1367, 1379 |
| P1-2 | **Virama at word start** (੍ as first char of space-separated token; host-less virama) | 3 occurrences, 2 rows | Ang 1354 (ids 57904, 57905, 57906) |
| P1-3 | **Spurious double vowel ਾਿ** (AA+I sign sequence outside ੍ਯ sihari-reorder context) | 2 occurrences | Ang 1358 (id 58072), Ang 1387 (id 59167) |

### P2 (Moderate)

| # | Issue | Count |
|---|---|---|
| P2-1 | **ੴ word-count offset** (1 Gur→2 translit; downstream alignment impact) | 568 rows |
| P2-2 | **fl_g/fl_r word count mismatch** | 35 rows |
| P2-3 | **Translit double-space** (blank from isolated vowel token) | 8 rows |
| P2-4 | **Mahalla header translit inconsistency** (`ma salok` vs `ma`) | 2 rows (ids 5839, 5884) |
| P2-5 | **Tippi→`n` not `ng`** (systematic; loses velar distinction; must be documented) | corpus-wide |
| P2-6 | **Final sihari/lavan elision** (systematic; must be documented) | corpus-wide |
| P2-7 | **Persian phoneme mapping** (ਫ→`ph` not `f`; scheme limitation in Tilang) | Ang 721–727+ |

---

## RECOMMENDED FIXES

1. **P1-1 (Highest priority):** For each of the 32 affected rows, remove the spurious space that splits `ਓ ੁ` → `ਓੁ` (and similarly for `ਮਿਲ੍ਯ੍ਯਿ ੋ`). Consider normalizing `ਓੁ` → `ਔ` (U+0A14) where appropriate.

2. **P1-2:** Remove leading virama from tokens `੍ਸਨੇਹੰ` / `੍ਸਨੇਹ` at ids 57904, 57905, 57906 → `ਸਨੇਹੰ` / `ਸਨੇਹ`.

3. **P1-3:** For id 59167 (`ਨਾਿ੍ਸਤ`): remove spurious I-sign → `ਨਾ੍ਸਤ` or re-encode as `ਨਾਸਤਿ`. For id 58072 (`ਬਿਗ੍ਯ੍ਯਾਿ੍ਪਤ`): verify against source PDF; remove spurious I-sign if confirmed.

4. **P2-1:** Document and handle the ੴ→`ik oankaar` +1 offset in all word-alignment, concordance, and search code.

5. **P2-4:** Normalize ids 5839 and 5884 translit from `ma salok` → `ma`.

6. **Scheme documentation:** Publish explicit rules for: (a) final sihari/lavan elision, (b) tippi→`n`, (c) Persian phoneme mapping, (d) ੴ expansion, (e) numeral tokens excluded from translit, (f) Mahalla numeral dropped.
