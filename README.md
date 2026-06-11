# ੴ Sri Guru Granth Sahib — Knowledge Base & Study App

A **sovereign, verifiable Gurbani corpus** with a zero-dependency local web app. Built from a 1,483-page Unicode Gurmukhi edition of Sri Guru Granth Sahib Ji — every line verbatim, every line carrying its Ang, with a machine-verification engine so no AI (or human) can misquote scripture unchecked.

> Scripture is shown verbatim with its Ang. Transliteration and translations are reading aids, clearly labeled — never the scripture itself.

## Quick start

```bash
cd webapp && python3 serve.py     # or double-click "Start SGGS App.command" (macOS)
```

Opens `http://localhost:7777`. Python 3 standard library only — nothing to install. Self-test: `/api/health`.

## What's inside

| | |
|---|---|
| **Corpus** | 60,658 lines · all 1,430 Angs · char-for-char reconciled with the source edition (1,643,385 chars, zero loss/dup/reorder — `pipeline/reconcile.py`) |
| **Metadata** | Raag (31, canonical order) · author (Gurus, Bhagats, per-Bhatt Swaiyye attribution, Vaar-correct pauris) · bani/section · composition · ਰਹਾਉ · Ang |
| **Search** | Gurmukhi FTS (BM25-ranked) · spelling-tolerant Roman (*waheguru* works) · first-letter (ਧ ਧ ਰ ਗ / *dh dh r g*) · 53 corpus-verified themes · concordance |
| **Verify engine** | `/api/verify` — any claimed quote → VERIFIED_EXACT / VERIFIED / VERIFIED_PARTIAL / PROBABLE / AMBIGUOUS / NOT_FOUND + Ang cross-check + confidence |
| **English layer** | **58,039 lines — the full Granth** (Dr. Sant Singh Khalsa, via the ShabadOS open database — see NOTICE.md), labeled "EN ·", never mixed with scripture |
| **Reader** | Shabad-grouped pages, ੴ invocations as printed, translit toggle, font size, ←/→ keys, dark mode |

## Architecture (the 5 layers)

1. **Canonical data** — SQLite + FTS5 (`db/sggs.sqlite`), versioned builds, `MANIFEST.json` checksums
2. **Search** — BM25 + unified cross-script query layer + theme expansion
3. **Verification** — rule-engine cascade with confidence (`webapp/verify.py`)
4. **Explanation** — LLMs may only explain; quotes must pass the verifier (`Answer-Protocol.md`)
5. **Governance** — mandatory citation, source registry, `CHANGELOG.md`, audit reports in `validation/`

Full design docs: `00_Build-Plan.md` → `01_Production-Architecture.md` → `02_Sovereign-Architecture-Assessment.md`. Quality evidence: `Validation-Report.md`.

## Rebuild from source

```bash
python3 pipeline/build_corpus.py <the-source-pdf> corpus/sggs.jsonl
python3 pipeline/reconcile.py   <the-source-pdf> corpus/sggs.jsonl   # must print RECONCILED
python3 pipeline/golden_test.py <the-source-pdf>                     # 49 checks
python3 pipeline/build_db.py corpus/sggs.jsonl /tmp/sggs.db          # then copy to db/sggs.sqlite
python3 pipeline/load_translations.py /tmp/sggs.db "pipeline/translations/en_*.jsonl"
```

The source PDF is **not** included in this repository.

## ⚠️ Keep this repository PRIVATE

See `NOTICE.md` — the English translation layer is licensed for personal, non-commercial use with attribution and must not be redistributed publicly.
