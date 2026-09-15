## What & why
<!-- One paragraph. Link the issue: Closes #NN -->

## Scripture-safety checklist (delete if this PR does not touch corpus/db/contract)
- [ ] Gurmukhi text is unchanged (no edit/normalize/reorder of `corpus/sggs.jsonl` or `db/sggs.sqlite`).
- [ ] `python3 pipeline/verify_regroup.py OLD.sqlite db/sggs.sqlite` passes (only comp_id/line_no changed), OR `--invariants` passes and no data changed.
- [ ] `make reconcile` re-run and `validation/reconcile-attestation.json` updated (if the corpus was rebuilt).
- [ ] `python3 pipeline/timing/guard_scripture.py` PASS; `contract/` regenerated and committed.
- [ ] A human reviewed the text-level diff.

## Definition of Done
- [ ] Tests updated/added and green locally (`make ci`).
- [ ] `python3 scripts/release/check_versions.py` passes (versions unified).
- [ ] CHANGELOG entry added under the unreleased/next version.
- [ ] Docs updated (`docs/`, `CLAUDE.md`) if behaviour or invariants changed.
- [ ] Verified on staging (attach a note/screenshot) before the release PR to `main`.
