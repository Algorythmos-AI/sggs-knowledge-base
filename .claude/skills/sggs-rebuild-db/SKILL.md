---
name: sggs-rebuild-db
description: Scripture-safe rebuild of the SGGS Knowledge Base corpus and database from the source PDF, with every proof the project requires — toolchain check, backups, rebuild_all.sh, byte-level scripture diff, re-baseline, guard, timing tests, contract vectors, iOS DBs, reconcile attestation — before any commit. Use whenever a change touches corpus/sggs.jsonl, db/sggs.sqlite, corpus/by-raag, or pipeline code that produces them (build_corpus, sggs_pipeline, build_db, enrich, analytics, vaars, timing), or the user asks to rebuild/regenerate the DB. Gurmukhi text must never change.
---

# Scripture-safe DB rebuild

Prime directive (CLAUDE.md): the Gurmukhi is verbatim from the source Bir and is **never** edited.
A rebuild is acceptable only when proofs show exactly the intended columns changed and nothing
scriptural did — and a human reviews any text-level diff before it lands.

Use a scratch dir for backups: `S=<session scratchpad>`.

## 1. Toolchain + backups
```bash
make doctor        # pipeline needs PyMuPDF/numpy/scipy → /usr/bin/python3 (3.9), NOT Homebrew python3
cp db/sggs.sqlite "$S/pre.sqlite"; cp corpus/sggs.jsonl "$S/pre.jsonl"; cp MANIFEST.json "$S/pre-MANIFEST.json"
rm -rf corpus/by-raag/*      # the generator doesn't clear stale files
```

## 2. Rebuild (15–45 min — run in background)
```bash
PATH=/usr/bin:$PATH bash pipeline/rebuild_all.sh > "$S/rebuild.log" 2>&1
```
The log must contain: `RECONCILED: corpus == source, character for character`, `ALL GOLDEN TESTS PASS`,
`missing angs: NONE`, `vaars=22, vaar_units=1423` (or an explained, reviewed change). If a stage fails,
restore from `$S` and stop.

## 3. Prove scripture is untouched
```bash
python3 .claude/skills/sggs-rebuild-db/scripts/diff_scripture.py "$S/pre.sqlite" db/sggs.sqlite --allow <intended cols…>
python3 pipeline/verify_regroup.py --invariants db/sggs.sqlite
```
`diff_scripture.py` fails if row count/ids change or any `lines` column outside `--allow` differs for
any id; it lists which columns changed and how many rows. `gurmukhi`, `text`, `ang` must never be in
`--allow`. Unexpected diffs → stop and show the user.

## 4. Re-baseline, guard, timing
`step0_baseline.py` refuses a DB that already has the timing tables, so baseline a copy without them:
```bash
bash .claude/skills/sggs-rebuild-db/scripts/rebaseline_pretiming.sh "$S"
python3 pipeline/timing/guard_scripture.py          # must print GUARD PASS
python3 pipeline/timing/test_timing_layer.py        # 21/21
python3 pipeline/timing/stamp_manifest.py
```
If you edit the DB in place afterwards (e.g. re-run build_vaars.py), re-stamp `MANIFEST.json`
`db_sha256`/`corpus_sha256` from the files.

## 5. Behaviour + contract + clients
```bash
(cd webapp && SGGS_OPEN_BROWSER=0 python3 serve.py &) ; curl -s localhost:7777/api/health   # all true
python3 pipeline/roundtrip_harness.py; python3 pipeline/casual_quote_harness.py
python3 pipeline/gen_golden_vectors.py      # Homebrew python3 (matches contract/_meta.json); review `git diff --stat contract/`
make ios-db && (cd ios/Packages/GurbaniSearchKit && swift test)
(cd frontend && npm run build:deploy)       # only if webapp/static should change
make reconcile                              # writes validation/reconcile-attestation.json (needs the PDF)
```
Search/verify/roman-norm vectors should be unchanged unless search itself changed.

## 6. Land it
- Confirm the DB is an LFS pointer when staged: `git show :db/sggs.sqlite | head -1` → `version https://git-lfs…`.
- Present the proof summary and any text-level diff for **human review** before committing.
- Bump the version + CHANGELOG `### Data` section, then ship via **sggs-ship**.
