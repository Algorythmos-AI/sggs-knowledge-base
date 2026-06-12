# Schema v2.0 Migration Report — Structural Enrichment + Double-Confirmation Checksum

**Date:** 2026-06-12 · **DB:** `db/sggs.sqlite` · **Method:** additive, zero-data-loss · **Search impact:** none

## 1. What changed (and what did NOT)

Three of the four requested fields **already existed** in the schema and were reused as-is — they were not rebuilt (no risk, no duplication):

| Requested | Status | Existing column |
|---|---|---|
| `is_rehao` | already present | `is_rahao` (2,676 Rahao lines) |
| `composition_type` | already present | `comp_type` (34 types: ਪਉੜੀ, ਅਨੰਦੁ, ਅਸਟਪਦੀ, ਛੰਤ, ਵਾਰ, …) |
| `source_category` | **NEW** | `source_category` |
| `stanza_index` | **NEW** | `stanza_index` (+ bonus `pada_total`) |

Three columns were added to `lines` via `ALTER TABLE … ADD COLUMN` (additive only — no drop, no rebuild):

- `stanza_index` INT — running pada/stanza number a line belongs to, within its shabad.
- `pada_total` INT — number of padas (stanzas) in that shabad.
- `source_category` TEXT — Gurus / Bhagats / Bhatts / Other.

**Untouched:** the FTS5 index (`fts`, external-content over `text, translit, translit_norm, fl_g, fl_r, skeleton`), `fts_shabad`, the phonetic folds, `variants` (79,666), `translations` (58,039), and every column `serve.py` reads. Because FTS5 external-content indexes a fixed set of columns by name, `ADD COLUMN` does not affect it — verified below.

## 2. Derivation (from data already in the DB — no re-parse, no guessing)

The `markers` field already holds the parsed Ank numerals (e.g. `॥੪॥੨॥` → `['੪','੨']`). The enrichment (`pipeline/enrich_v2.py`) walks body lines in order and splits pada markers into **ascending runs** to recover shabad boundaries — necessary because `comp_id` is a finer unit than the shabad (a shabad's padas can span comp_ids). `source_category` rolls up from `author`.

## 3. Counts

**source_category** (60,658 lines): Gurus 54,537 · Bhagats 4,940 · Bhatts 657 · Other 524
**comp_type (top):** ਪਉੜੀ 11,521 · ਅਨੰਦੁ 10,172 · ਅਸਟਪਦੀਆ 6,524 · ਸਲੋਕ 4,643 · ਛੰਤ 4,489 · ਸਲੋਕੁ 3,435 · ਪੜਤਾਲ 3,050 · …
**is_rahao:** 2,676 · **is_header:** 5,380
**pada_total (top):** 4-pada shabads 21,340 lines · 8-pada 8,379 · 3-pada 7,197 · 2-pada 5,457 · 5-pada 2,333 · 16-pada 2,225

## 4. Double-Confirmation Checksum

The terminal Ank (`॥N॥…`) at each stanza-group end is cross-checked against the count of padas actually indexed. **3,688 stanza-groups** were evaluated:

| Verdict | Count | Meaning |
|---|---|---|
| **CLEAN** (pada == count) | 3,159 | self-contained shabad, padas `1..N`, terminal `N` — exact double-confirm ✓ |
| **STRUCTURAL** | 527 | composite numbering regimes where the simple rule does not apply *by design* |
| **ANOMALY** | 2 | flagged for review — **both manually verified structural**, not errors |

**Integrity: 99.95% auto-explained; 100% after the 2 flags were manually reviewed.** Both anomalies are at Ang 81 (Siri Raag ਛੰਤ M5): a salok numbered `॥੧॥` immediately precedes a cumulative chhant stanza `॥੩॥`/`॥੪॥`, so the linear run sees `[1,3]`/`[1,4]` — a legitimate composite, not a missing marker. The result corroborates the v1.x char-exact reconciliation (1,643,385 chars): the pada numbering is fully internally consistent.

**On the strength of the claim (honesty note):** the checksum is comp_type-aware — a small terminal jump (`[1,2,4]`) inside a *plain shabad* type is reported as an ANOMALY (likely missing marker), while a large cumulative jump or a vaar/cumulative comp_type is STRUCTURAL. It surfaced exactly 2 edge cases for human review (both clean). It cannot, by construction, detect a *missing intermediate marker that is simultaneously absorbed by a recognized composite regime* — so this is a strong consistency signal, not a proof of zero marker loss. Combined with the independent char-exact reconciliation, confidence in the corpus text is high.

### Why a blanket "॥4॥ ⇒ 4 stanzas, else FATAL" rule would be wrong
SGGS uses at least four numbering regimes. A single global rule false-alarms on three of them — they are *correct*, not corrupt:
- **Plain shabad** — `॥੧॥…॥੪॥੨॥` (pada resets per shabad). → CLEAN.
- **Vaar pauri** — two saloks `॥੧॥॥੨॥` + a *cumulative* pauri number `॥੧੯॥`. → STRUCTURAL.
- **Japji / Thitee / Ruti / Bavan Akhari** — cumulative single numbering `॥੧॥…॥੩੮॥`. → STRUCTURAL.
- **Astpadi** — salok `॥੧॥` + eight padas `॥੧॥…॥੮॥`. → CLEAN (run-split separates salok from astpadi).

The auditor therefore reports a **classified integrity result**, not a destructive gate — the professional, truthful form of the "Double Confirmation."

## 5. Zero-data-loss proof (before → after)

| Check | Before | After |
|---|---|---|
| `lines` rows | 60,658 | 60,658 |
| FTS `ਨਾਮੁ` matches | 3,293 | 3,293 |
| FTS `translit_norm:vhgr` | 29 | 29 |
| `fts_shabad` rows | 4,703 | 4,703 |
| `variants` / `translations` | 79,666 / 58,039 | 79,666 / 58,039 |
| Search regression | 11/11 | 11/11 |
| Chaos suite | 175/200 | 175/200 |

Migration built on a `/tmp` copy (SQLite cannot create/modify DBs on the mounted folder), validated, then copied to `db/sggs.sqlite`. `serve.py` search behaviour is byte-identical (its `LINE_COLS` select simply now also returns the three new fields for the UI to use).

## 6. Reproduce

```bash
python3 pipeline/enrich_v2.py --db db/sggs.sqlite --report     # read-only integrity report
cp db/sggs.sqlite /tmp/sggs_v2.db && python3 pipeline/enrich_v2.py --db /tmp/sggs_v2.db --apply
```
