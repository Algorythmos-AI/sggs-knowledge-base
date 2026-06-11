# SGGS Corpus Metadata Audit Report
**File:** sggs.jsonl — 60,675 rows  
**Date:** 2026-06-10

---

## Executive Summary

| Severity | Count |
|----------|-------|
| P0       | 0     |
| P1       | 6     |
| P2       | 4     |
| Clean    | 8 checks fully pass |

---

## Check 1 — Author Spans (20 distinct authors)

| Author | min_ang | max_ang | n |
|--------|---------|---------|---|
| NULL | 1 | 8 | 385 |
| Guru Nanak Dev Ji (M1) | 8 | 1412 | 11,745 |
| Guru Angad Dev Ji (M2) | 83 | 1290 | 510 |
| Guru Amar Das Ji (M3) | 26 | 1421 | 10,718 |
| Guru Ram Das Ji (M4) | 10 | 1424 | 5,784 |
| Guru Arjan Dev Ji (M5) | 10 | 1430 | 26,055 |
| Guru Tegh Bahadur Ji (M9) | 219 | 1429 | 605 |
| Bhagat Kabir Ji | 91 | 1377 | 3,312 |
| Bhagat Beni Ji | 93 | 1352 | 100 |
| Bhagat Parmanand Ji | 217 | 624 | 14 |
| Baba Sundar Ji | 240 | 785 | 34 |
| Bhagat Namdev Ji | 345 | 1351 | 670 |
| Bhagat Ravidas Ji | 345 | 1293 | 476 |
| Sheikh Farid Ji | 488 | 1383 | 93 |
| Bhagat Trilochan Ji | 525 | 695 | 70 |
| Bhagat Jaidev Ji | 526 | 527 | 16 |
| Bhai Mardana | 553 | 553 | 21 |
| Bhagat Bhikhan Ji | 659 | 659 | 16 |
| Satta & Balwand | 684 | 1214 | 35 |
| Bhagat Ramanand Ji | 1195 | 1195 | 16 |

Canonical sanity:
- M1-M5 throughout: PASS.
- M9 min=219, no M9 in Japji (1-13): PASS.
- Bhagat bani zones (Kabir/Namdev/Ravidas/Farid) all within known zones: PASS.
- NULL author confined to ang 1-8: PASS.

**P1-1 — S&B misattribution at ang 973 (23 rows):**
The corpus assigns Satta & Balwand to 23 rows at ang 973 (Ramkali, comp_type=Pati).
The text \u0a24\u0a40\u0a30\u0a25 \u0a26\u0a47\u0a16\u0a3f \u0a28 \u0a1c\u0a32 \u0a2e\u0a39\u0a3f \u0a2a\u0a48\u0a38\u0a09... is Bhagat Namdev Ji's Pati in Ramkali.
The row immediately before (same ang) is correctly tagged Bhagat Namdev Ji.
S&B have no canonical composition at ang 973. First mis-tagged row is is_header=1.
Correct author: Bhagat Namdev Ji.

**P1-2 — Ramkali Ki Vaar body (ang 966-968) wrongly attributed to M5 (90 body rows):**
Vaar title header at ang 966 explicitly names Satta and Balwand as composers.
All 90 subsequent body rows (nau karta kadar kare... / Dhann Dhann Ramdas Gur...)
are tagged Guru Arjan Dev Ji (M5). This explains why S&B show zero rows at ang 966-968.
Correct author for these 90 rows: Satta & Balwand.

---

## Check 2 — Null-Author Body Rows in ang 14-1430

Count: 0. PASS.

---

## Check 3 — ghar Values

Distribution: 1 (2487) through 17 (18), NULL (53059).
All non-null values within valid range 1-17. No invalid values. PASS.

---

## Check 4 — is_rahao / Rahao Distribution

4a. is_rahao=1 on is_header=1 rows: 0. PASS — P0 clean.

4b. Rahao gaps >=30 angs in raag zones 14-1352 (excl. Vaar zones):

  ang 263-295 (33 angs) — Gauri zone (Sukhmani, Anandu). Rahao-free forms expected. P2.
  ang 762-791 (30 angs) — Suhi zone (Chhant, Gunvanti). Lyrical forms; expected. P2.
  ang 1020-1101 (82 angs) — Maru zone (Solhe, Vanajaara, Dakhni). P1.
    Largest rahao gap in any active raag zone. Solhe is conventionally rahao-free but
    82 angs spans multiple comp_types. Text verification needed to confirm no rahao
    lines are present but untagged.

---

## Check 5 — comp_type Values

37 distinct non-null values + 4 null rows. All non-null are valid Gurmukhi labels. No junk.

Null comp_type (4 rows at ang 1):
  - Mool Mantar header: acceptable.
  - Jap title header: acceptable.
  - Aadi Sach body row: P2 — should be Saloky.
  - Hai Bhi Sach body row: P2 — should be Saloky.

Asa di Vaar 462-475 check: correct M1/M2 author switches on saloks and paurhis. No attribution lag. PASS.

---

## Check 6 — raag + section Both Set Outside 1-13

Count: 1 row. ang=14, is_header=1, raag=Gauri, section=Soheila.
Schema contract violation on Soheila opening header. P1.
Fix: strip raag from this header row (section alone is sufficient).

---

## Check 7 — Section Coverage

7a. Rows 1353-1430 with null section: 5 rows, all at ang 1353.
Tail of Jaijavanti M9 shabad (comp_type=Anandu, author=M9) that begins at ang 1352
and spills onto ang 1353. Section Salok Sahskritee begins on the very next row at 1353.
P1 — section must be assigned to all 1353-1430 rows without exception.

7b. Rows 14-1352 with non-null section: 1 row (same ang-14 boundary row as Check 6). P2.

---

## Check 8 — Swaiyye Zone 1385-1409

780 rows. section=Swaiyye (779), Chaubolay (1, correctly the opener at 1385).
ALL 780 rows tagged Guru Arjan Dev Ji (M5).

Sub-zones:
  ang 1385-1388: Swaiye Sri Mukhbak Mahla 5 — M5's own Swaiyye. M5 correct here.
  ang 1389-1409: Swaiye Mahle Pahile Ke through Panjve Ke — Bhatt compositions
    in praise of M1-M5. These are NOT M5 compositions. M5 is the subject of praise.

P1 — ang 1389-1409 should be tagged Bhatts (or a collective label).
The spec acknowledges per-Bhatt tagging is a known limit, but tagging these as M5
is a positive misattribution (not merely untagged). Applies to all 5 sub-sections
(M1 through M5 Swaiyye alike — M5 did not compose praise of M1-M4).

---

## Check 9 — comp_id Monotone & line_no Restart

9a. comp_id non-monotone violations: 0. PASS.

9b. line_no is a per-ang-page absolute line number (1-indexed).
Headers always carry line_no=1. Body rows start from line_no=2.
No body row has line_no=1. Within-page ordering strictly increasing for body rows.
Resets at new header on same ang (correct). PASS.

---

## P0 / P1 / P2 Index

### P0 (0): None.

### P1 (6):

| ID | Ang / Rows | Description |
|----|------------|-------------|
| P1-1 | ang 973, 23 rows | S&B on Namdev Pati shabad. First row is_header=1. Fix: tag Bhagat Namdev Ji. |
| P1-2 | ang 966-968, 90 body rows | Ramkali Ki Vaar body tagged M5 instead of Satta & Balwand. |
| P1-3 | ang 1020-1101, 82-ang gap | Zero rahao in Maru zone. Largest untagged span; text verification needed. |
| P1-4 | ang 1353, 5 rows | Null section on Jaijavanti shabad tail in 1353-1430 zone. |
| P1-5 | ang 1389-1409 | Bhatt Swaiyye tagged M5. Should be Bhatts. |
| P1-6 | ang 14, 1 row | raag + section both set outside 1-13 (schema violation on Soheila opener). |

### P2 (4):

| ID | Ang / Rows | Description |
|----|------------|-------------|
| P2-1 | ang 14, 1 row | section set in 14-1352 zone (same boundary row as P1-6). |
| P2-2 | ang 1, 2 body rows | Null comp_type on Aadi Sach / Hai Bhi Sach salok rows. |
| P2-3 | ang 263-295 | 33-ang rahao gap in Gauri (Sukhmani/Anandu). Expected for these forms. |
| P2-4 | ang 762-791 | 30-ang rahao gap in Suhi (Chhant/Gunvanti). Expected for lyrical forms. |

---

## Checks That Fully Pass (8)

1. No M9 before ang 219; no M9 in Japji (1-13).
2. Zero null-author body rows in ang 14-1430.
3. All non-null ghar values in 1-17; no junk.
4. is_rahao never on is_header=1 rows (P0 clean).
5. All comp_type values valid Gurmukhi labels; no junk.
6. Asa di Vaar M1/M2 author switches correct; no lag.
7. comp_id strictly monotone, all 60,675 rows.
8. line_no=1 only on is_header=1; within-page ordering clean.
