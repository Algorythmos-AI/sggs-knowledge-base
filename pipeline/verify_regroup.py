#!/usr/bin/env python3
"""
verify_regroup.py — mechanical proof that the header-run regroup (build_corpus.py
post-pass 1b) changed ONLY comp_id / line_no and nothing scriptural.

Usage:  python3 pipeline/verify_regroup.py OLD.sqlite NEW.sqlite

It (a) asserts every `lines` column except comp_id and line_no is byte-identical
per id between the two DBs, (b) INDEPENDENTLY recomputes the regroup from the OLD
db and asserts the NEW db's comp_id / line_no match that computation exactly, and
(c) checks the structural invariants. Analytics/derived tables that are *expected*
to change are reported, never asserted. Exit 0 on success, 1 on any failure.

This is the release gate for any rebuild that touches corpus/db and a permanent
CI tool (scripture-integrity workflow).
"""
import sys, hashlib, json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "timing"))
import baseline_lib as bl   # connect_ro, table_data_sha256, list_tables

EXPECT_LINES = 60658
EXPECT_ANGS = 1430
EXPECT_DISTINCT_OLD = 5380
EXPECT_FOLDED = 674
EXPECT_DISTINCT_NEW = EXPECT_DISTINCT_OLD - EXPECT_FOLDED   # 4706
# v1.1.4: 233 verses the detector had mistaken for headers no longer open a composition
# (their comp_ids are burned as permanent gaps, ids 5377-5380 among them), so the
# current DB carries 4527 distinct comps. The two-DB mode above still proves the
# v1.1.0 regroup from a pre-regroup DB; --invariants gates the current DB.
EXPECT_DEMOTED = 179          # 233 demoted lines, 54 of which had already been folded into a run
EXPECT_DISTINCT_CURRENT = EXPECT_DISTINCT_NEW - EXPECT_DEMOTED   # 4527
RUBRICS = {'ਜੁਮਲਾ', 'ਦੁਤੁਕੇ', 'ਏਹੁ ਸਲੋਕੁ ਆਦਿ ਅੰਤਿ ਪੜਣਾ'}
IGNORE_COLS = {'comp_id', 'line_no'}
# derived/analytics tables that legitimately differ after a regroup rebuild
EXPECT_DIFFER = {'raags', 'meta', 'analytics_meta', 'timing_migrations',
                 'shabd_raag_map', 'shabd_musical_markers',
                 'shabd_structural_form', 'shabd_poetic_genre'}

fails = []
def check(cond, msg):
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        fails.append(msg)

def content_multiset_sha(con, table):
    """Order-independent hash of a table's rows (robust to nondeterministic
    INSERT order, e.g. canon_tokens built from a Python set)."""
    rows = []
    for row in con.execute(f'SELECT * FROM "{table}"'):
        rows.append(json.dumps([bl._cell(v) for v in row], ensure_ascii=False,
                               separators=(",", ":")))
    rows.sort()
    return hashlib.sha256("\n".join(rows).encode("utf-8")).hexdigest()


def cols_of(con, table):
    return [r[1] for r in con.execute(f'PRAGMA table_info("{table}")')]

def load_lines(con):
    cols = cols_of(con, 'lines')
    rows = con.execute(f'SELECT {",".join(cols)} FROM lines ORDER BY id').fetchall()
    return cols, rows

def invariants_only(db_p):
    """Structural invariants on a single (already-regrouped) DB — for CI, where the
    pre-regroup DB is not available. Scripture *unchangedness* is proven separately
    by guard_scripture.py against the committed baseline."""
    con = bl.connect_ro(db_p)
    print(f"DB = {db_p}  (invariants-only)\n")
    cols = cols_of(con, 'lines')
    rows = con.execute(f'SELECT {",".join(cols)} FROM lines ORDER BY id').fetchall()
    idx = {c: i for i, c in enumerate(cols)}
    check(len(rows) == EXPECT_LINES, f"lines == {EXPECT_LINES} (got {len(rows)})")
    ids = [r[idx['id']] for r in rows]
    check(ids == list(range(1, EXPECT_LINES + 1)), "ids dense 1..N")
    check(len({r[idx['ang']] for r in rows}) == EXPECT_ANGS, f"distinct angs == {EXPECT_ANGS}")
    from collections import defaultdict
    cl = defaultdict(list)
    for r in rows:
        cl[r[idx['comp_id']]].append(r)
    check(len(cl) == EXPECT_DISTINCT_CURRENT, f"distinct comps == {EXPECT_DISTINCT_CURRENT} (got {len(cl)})")
    bad_first = hab = 0; header_only = []
    for c, ls in cl.items():
        ls.sort(key=lambda r: r[idx['id']])
        if not ls[0][idx['is_header']]:
            bad_first += 1
        prefix = True
        for r in ls:
            if r[idx['is_header']] and not prefix: hab += 1
            if not r[idx['is_header']]: prefix = False
        if all(r[idx['is_header']] for r in ls):
            header_only.append(ls[0][idx['text']])
    check(bad_first == 0, f"every comp's first line is a header ({bad_first} bad)")
    check(hab == 0, f"no header follows a body line within a comp ({hab} bad)")
    check(set(header_only) <= RUBRICS and len(header_only) == 3,
          f"header-only comps == the 3 trailing rubrics (got {sorted(set(header_only))})")
    # line_no contiguity
    seen = {}; lnbad = 0
    for r in rows:
        c = r[idx['comp_id']]; seen[c] = seen.get(c, 0) + 1
        if r[idx['line_no']] != seen[c]: lnbad += 1
    check(lnbad == 0, f"line_no contiguous within every comp ({lnbad} bad)")
    con.close()
    print()
    if fails:
        print(f"RESULT: FAIL — {len(fails)} invariant(s) failed"); return 1
    print("RESULT: PASS — structural invariants hold on the current DB."); return 0


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--invariants':
        return invariants_only(sys.argv[2])
    if len(sys.argv) != 3:
        print(__doc__ + "\n  or:  python3 pipeline/verify_regroup.py --invariants NEW.sqlite")
        return 1
    old_p, new_p = sys.argv[1], sys.argv[2]
    old = bl.connect_ro(old_p); new = bl.connect_ro(new_p)
    print(f"OLD = {old_p}\nNEW = {new_p}\n")

    oc, orows = load_lines(old)
    nc, nrows = load_lines(new)
    print("── shape")
    check(oc == nc, f"schema columns identical ({len(oc)} cols)")
    check(len(orows) == EXPECT_LINES, f"OLD lines == {EXPECT_LINES} (got {len(orows)})")
    check(len(nrows) == EXPECT_LINES, f"NEW lines == {EXPECT_LINES} (got {len(nrows)})")
    idx = {c: i for i, c in enumerate(oc)}
    oid = [r[idx['id']] for r in orows]; nid = [r[idx['id']] for r in nrows]
    check(oid == list(range(1, EXPECT_LINES + 1)), "OLD ids dense 1..N")
    check(nid == list(range(1, EXPECT_LINES + 1)), "NEW ids dense 1..N")
    check(len({r[idx['ang']] for r in nrows}) == EXPECT_ANGS, f"NEW distinct angs == {EXPECT_ANGS}")

    print("── per-id byte-identity of every column except comp_id/line_no")
    keep = [i for i, c in enumerate(oc) if c not in IGNORE_COLS]
    diff_ids = []
    for oro, nro in zip(orows, nrows):
        if any(oro[i] != nro[i] for i in keep):
            diff_ids.append(oro[idx['id']])
            if len(diff_ids) <= 5:
                bad = [oc[i] for i in keep if oro[i] != nro[i]]
                print(f"     id {oro[idx['id']]}: differs in {bad}")
    check(not diff_ids, f"all non-(comp_id,line_no) columns identical for every id "
                        f"({len(diff_ids)} differing ids)")

    print("── scripture hash (id + gurmukhi)")
    def scr_hash(rows):
        h = hashlib.sha256()
        for r in rows:
            h.update(f"{r[idx['id']]}\x1f{r[idx['gurmukhi']]}\n".encode('utf-8'))
        return h.hexdigest()
    oh, nh = scr_hash(orows), scr_hash(nrows)
    check(oh == nh, f"scripture hash unchanged ({nh[:16]}…)")
    manp = Path('ios/Resources/sggs-ios.manifest.json')
    if manp.exists():
        try:
            man = json.loads(manp.read_text())
            print(f"     (ios manifest scripture_sha256 = {man.get('scripture_sha256','?')[:16]}… — "
                  "informational; regenerated by build_ios_db.py)")
        except Exception:
            pass

    print("── independent recompute of the regroup from OLD, compared to NEW")
    cid_i, hdr_i, txt_i = idx['comp_id'], idx['is_header'], idx['text']
    def is_run_header(r):
        return r[hdr_i] and r[txt_i] not in RUBRICS
    expected_comp = {r[idx['id']]: r[cid_i] for r in orows}   # identity baseline
    n = len(orows); i = 0; folded = 0
    while i < n:
        if not is_run_header(orows[i]):
            i += 1; continue
        j = i
        while j + 1 < n and is_run_header(orows[j + 1]):
            j += 1
        if j > i:
            k_keep = orows[j][cid_i]
            for k in range(i, j):
                expected_comp[orows[k][idx['id']]] = k_keep
                folded += 1
        i = j + 1
    check(folded == EXPECT_FOLDED, f"OLD yields {EXPECT_FOLDED} folded header lines (got {folded})")
    new_comp = {r[idx['id']]: r[cid_i] for r in nrows}
    mism = [lid for lid in expected_comp if expected_comp[lid] != new_comp[lid]]
    check(not mism, f"NEW comp_id == independently-recomputed comp_id for all ids "
                    f"({len(mism)} mismatches)")
    # body comps (lines never involved in a fold) keep their comp_id
    body_changed = [r[idx['id']] for r in orows
                    if not is_run_header(r) and new_comp[r[idx['id']]] != r[cid_i]]
    check(not body_changed, f"no non-run-header (body/rubric) line changed comp_id "
                            f"({len(body_changed)} changed)")

    print("── line_no is 1..N within each NEW comp (id order)")
    seen = {}; ln_bad = 0
    for r in nrows:
        c = r[cid_i]; seen[c] = seen.get(c, 0) + 1
        if r[idx['line_no']] != seen[c]:
            ln_bad += 1
    check(ln_bad == 0, f"line_no contiguous within every comp ({ln_bad} bad)")

    print("── comp counts + header-position invariants (NEW)")
    from collections import defaultdict
    comp_lines = defaultdict(list)
    for r in nrows:
        comp_lines[r[cid_i]].append(r)
    check(len({r[cid_i] for r in orows}) == EXPECT_DISTINCT_OLD,
          f"OLD distinct comps == {EXPECT_DISTINCT_OLD}")
    check(len(comp_lines) == EXPECT_DISTINCT_NEW,
          f"NEW distinct comps == {EXPECT_DISTINCT_NEW} (got {len(comp_lines)})")
    max_old = max(r[cid_i] for r in orows); max_new = max(comp_lines)
    check(max_new == max_old, f"max comp_id unchanged ({max_new}) — gaps, not renumber")
    bad_first = header_after_body = 0
    header_only = []
    for c, ls in comp_lines.items():
        ls.sort(key=lambda r: r[idx['id']])
        if not ls[0][hdr_i]:
            bad_first += 1
        prefix = True
        for r in ls:
            if r[hdr_i] and not prefix:
                header_after_body += 1
            if not r[hdr_i]:
                prefix = False
        if all(r[hdr_i] for r in ls):
            header_only.append((c, ls[0][txt_i]))
    check(bad_first == 0, f"every comp's first line is a header ({bad_first} bad)")
    check(header_after_body == 0, f"no header follows a body line within a comp ({header_after_body} bad)")
    rub_texts = {t for _, t in header_only}
    check(len(header_only) == 3 and rub_texts <= RUBRICS,
          f"header-only comps == the 3 trailing rubrics (got {len(header_only)}: {sorted(rub_texts)})")

    print("── derived/analytics table diffs (reported; expected where noted)")
    ot = bl.list_tables(old); nt = bl.list_tables(new)
    common = sorted(set(ot) & set(nt))
    for t in common:
        if ot[t]['virtual'] or nt[t]['virtual']:
            continue
        try:
            oh2, on = bl.table_data_sha256(old, t)
            nh2, nn = bl.table_data_sha256(new, t)
        except Exception as e:
            print(f"     {t:26s} (skipped: {e})"); continue
        same = oh2 == nh2
        tag = "identical" if same else ("DIFFERS (expected)" if t in EXPECT_DIFFER else "DIFFERS")
        DETERMINISTIC = ('translations', 'concept_lines', 'word_freq', 'canon_tokens')
        if not same or t in DETERMINISTIC:
            print(f"     {t:26s} {tag:20s} rows {on}->{nn}")
        # hard-assert the deterministic text-derived companion tables by CONTENT
        # (order-independent — canon_tokens et al. have nondeterministic row order)
        if t in DETERMINISTIC:
            csame = content_multiset_sha(old, t) == content_multiset_sha(new, t)
            check(csame, f"[{t}] content identical (deterministic, text-derived; order-independent)")

    old.close(); new.close()
    print()
    if fails:
        print(f"RESULT: FAIL — {len(fails)} assertion(s) failed:")
        for m in fails: print("  -", m)
        return 1
    print("RESULT: PASS — regroup changed only comp_id/line_no; scripture byte-identical.")
    return 0

if __name__ == '__main__':
    sys.exit(main())
