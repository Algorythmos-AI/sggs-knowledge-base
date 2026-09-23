# Scripture Integrity

Textual fidelity is the single most important property of this project and
overrides everything else. The Gurmukhi text is **verbatim** from the source Bir
and is **never** edited, paraphrased, normalized, reordered, or guessed at.

## The guarantee chain

```mermaid
flowchart LR
    pdf[(Source Bir PDF)] -->|build_corpus.py| corpus[corpus/sggs.jsonl]
    corpus -->|reconcile.py| g1{char-exact<br/>vs PDF?}
    corpus -->|golden_test.py| g2{structural<br/>golden checks?}
    g1 -->|no| stop[ABORT rebuild]
    g2 -->|no| stop
    g1 -->|yes| db[db/sggs.sqlite]
    g2 -->|yes| db
    db -->|verify_regroup.py| g3{only comp_id/line_no<br/>changed?}
    db -->|guard_scripture.py| g4{pre-existing tables<br/>byte-identical to baseline?}
    g3 --> ok[commit + release]
    g4 --> ok
    classDef gate fill:#7a1f1f,color:#fff;
    class g1,g2,g3,g4 gate;
```

## The only sanctioned text transforms
1. PDF **visual → logical** Unicode reordering of the sihari (`ਿਕ੍ਰਪਾ → ਕ੍ਰਿਪਾ`).
2. Editorial Unicode-repair corrections where the source font emitted impossible
   sequences. The complete register is `audit/editorial-ledger.jsonl` — **4 rules,
   11 applications**: Angs 573, 586, 727 (itemised from the start) and Angs 1354, 1358,
   1387, 1398, 1402, 1406, 1408, 1409 (same `fix_text` step-4 rules; itemised 2026-09-23,
   **pending scholarly review, gate G3**). Every decoding transform (timestamps, halant
   order, glyph restorations, vowel re-attachment, stray-character strip) is registered too.

Any new transform must be registered in the ledger and reviewed by a human. The English
translations are a **separate, labelled layer** (Dr. Sant Singh Khalsa via
BaniDB/ShabadOS) and are never blended into the Gurmukhi.

## Proof tools
| Tool | Proves | When |
|---|---|---|
| `pipeline/reconcile.py` | corpus == PDF, character for character | every rebuild (gate) |
| `pipeline/golden_test.py` | canonical structural checks | every rebuild (gate) |
| `pipeline/sggs_integrity.py` | the committed DB's content equals `audit/dataset-fingerprint.json` — every table (build stamps blanked), every FTS5 index (via `fts5vocab`), `scripture_sha256` (the iOS definition) and `t0_sha256`; stable across SQLite versions | every PR (CI gate); written by every rebuild |
| `pipeline/ledger_check.py` | `fix_text` editorial rules == the ledger; any scripture (T0) change is covered by a new, reviewed ledger entry | every PR (CI gate) |
| `pipeline/verify_regroup.py` | a corpus change touched only `comp_id`/`line_no`; scripture byte-identical | any PR touching corpus/db |
| `pipeline/timing/guard_scripture.py` | pre-existing tables byte-identical to the committed baseline | after any DB write |
| `validation/reconcile-attestation.json` | the corpus in this commit reconciled char-exact locally (the PDF never enters CI) | `make reconcile` |
| `/api/health` | 60,658 lines, 1,430 Angs, FTS live, verbatim Mool Mantar, ≥560 ੴ, live verify | after any DB change |

## The hash chain
`MANIFEST.json` carries `corpus_sha256` + `db_sha256`; `contract/_meta.json` carries
its own `db_sha256`; the iOS manifest carries `db_sha256` + `scripture_sha256`.
`scripture-integrity` CI asserts these agree, so a DB rebuild that forgets to
regenerate the contract or the attestation fails the gate rather than silently
shipping drift.

## If text looks wrong
**Flag it, do not change it.** Open a *Scripture fidelity concern* issue with the
Ang and the verbatim line; a Granthi/scholar reviews. Known items awaiting review:
the 3 `TRAILING_RUBRICS` (`ਜੁਮਲਾ`, `ਦੁਤੁਕੇ`, `ਏਹੁ ਸਲੋਕੁ ਆਦਿ ਅੰਤਿ ਪੜਣਾ`), ~20
verse lines the source mis-tags as headings, and the source-faithful isolated-matra
rows (Angs ~695–699, 1354/1358/1387).
