#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_banis.py — build the Nitnem / Gutka bani registry (migration 002) from
pipeline/banis/bani_seed.json + the ShabadOS open database.

Prime directive: scripture is never touched. Reads on `lines` are plain SELECTs;
writes go ONLY to the three new tables (whitelisted CREATE statements). The
scripture baseline is verified before and after unless --skip-baseline (sanctioned
only inside rebuild_all.sh, whose fresh DB is gated by reconcile + golden).

How a bani is built
  * ShabadOS `bani_lines` gives the SET of lines and their `line_group`s.
  * Every Sri Guru Granth Sahib Ji line is resolved to OUR `lines.id` by text match
    (exact → unique skeleton → fuzzy ≥ 0.92, over Ang±1; then 1→N / N→1 line-break
    repair). Anything unresolved is a HARD FAIL unless bani_overrides.json names it.
    Within a line_group the reading order is OUR printed order (`lines.id` ascending).
  * Non-SGGS lines (Sri Dasam Granth, Ardaas) are converted VERBATIM (no folding)
    into `extra_lines`, de-duplicated by ShabadOS line id, with `is_header` from the
    source's Manglacharan/Sirlekh line types.
  * Seed-declared `prepend_line_ranges` / `append_line_ranges` add SGGS ranges as
    their own groups (e.g. the ਗੁਰਦੇਵ ਮਾਤਾ salok around Sukhmani Sahib).
  * A bani with no `shabados_bani_id` is defined ENTIRELY by `sggs_line_ranges`
    (e.g. Asa Di Vaar as printed). Each range is one group of our own line ids in
    printed order, and every range carries TEXT ANCHORS (`first_text_prefix`,
    `last_text`, `markers_before_last`) that are re-checked on every build: if a
    future corpus rebuild ever shifts ids, the build FAILS loudly instead of
    silently pointing the bani at different verses.

Usage:
  python3 pipeline/banis/build_banis.py [--db PATH] [--shabados PATH] [--dry-run]
                                        [--skip-baseline] [--rollback]
"""
import argparse
import collections
import json
import re
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'pipeline'))
sys.path.insert(0, str(ROOT / 'pipeline' / 'timing'))
import anmol  # noqa: E402
import match_lib as ml  # noqa: E402
import baseline_lib as bl  # noqa: E402
from sggs_pipeline import translit_line  # noqa: E402

NEW_TABLES = bl.BANI_LAYER_TABLES
NEW_INDEXES = {'ix_bani_lines_line', 'ix_bani_lines_extra'}
KEY_RE = re.compile(r'^[a-z0-9_]{1,32}$')
SHABADOS_SOURCE = {1: 'sggs', 2: 'dasam', 9: 'ardaas'}
HEADER_TYPES = {1, 2}          # ShabadOS line_types: Manglacharan, Sirlekh
CREATE_TABLE_RE = re.compile(r'^\s*CREATE\s+TABLE\s+"?(\w+)"?\s*\(', re.I | re.S)
CREATE_INDEX_RE = re.compile(r'^\s*CREATE\s+INDEX\s+"?(\w+)"?\s+ON\s+"?(\w+)"?', re.I | re.S)
DROP_TABLE_RE = re.compile(r'^\s*DROP\s+TABLE\s+IF\s+EXISTS\s+"?(\w+)"?\s*$', re.I | re.S)
# For the reading-aid transliteration only: the shared transliterator has no entry
# for the nukta sign, so non-SGGS spellings are folded for the ROMAN string alone.
TRANSLIT_FOLD = str.maketrans({'਼': '', 'ੱ': '', 'ੑ': '', '…': ''})


def split_statements(sql_text):
    lines = [line.split('--', 1)[0] for line in sql_text.splitlines()]
    return [s.strip() for s in '\n'.join(lines).split(';') if s.strip()]


def whitelist(statements, rollback):
    errors = []
    for st in statements:
        if rollback:
            m = DROP_TABLE_RE.match(st)
            if m and m.group(1) in NEW_TABLES:
                continue
            errors.append('NOT WHITELISTED (rollback): %r' % st[:80])
            continue
        m = CREATE_TABLE_RE.match(st)
        if m and m.group(1) in NEW_TABLES:
            continue
        m = CREATE_INDEX_RE.match(st)
        if m and m.group(1) in NEW_INDEXES and m.group(2) in NEW_TABLES:
            continue
        errors.append('NOT WHITELISTED: %r' % st[:80])
    return errors


def load_seed():
    seed = json.loads((HERE / 'bani_seed.json').read_text(encoding='utf-8'))
    seen = set()
    for b in seed['banis']:
        assert KEY_RE.match(b['key']), 'bad key %r' % b['key']
        assert (b['key'], b['variant']) not in seen, 'duplicate %r' % ((b['key'], b['variant']),)
        seen.add((b['key'], b['variant']))
    for key in {b['key'] for b in seed['banis']}:
        defaults = [b for b in seed['banis'] if b['key'] == key and b['is_default']]
        assert len(defaults) == 1, 'key %r needs exactly one default variant' % key
    return seed


def load_overrides():
    p = HERE / 'bani_overrides.json'
    if not p.exists():
        return {}
    data = json.loads(p.read_text(encoding='utf-8'))
    return {o['shabados_line_id']: o for o in data.get('overrides', [])}


def shabados_lines(sha, bani_id):
    """[(line_group, shabados_line_id, order_id, ascii, type_id, page, source)]"""
    rows = sha.execute(
        'SELECT bl.line_group, l.id, l.order_id, l.gurmukhi, l.type_id, l.source_page, sh.source_id '
        'FROM bani_lines bl JOIN lines l ON l.id = bl.line_id '
        'JOIN shabads sh ON sh.id = l.shabad_id '
        'WHERE bl.bani_id = ? ORDER BY bl.line_group, l.order_id', (bani_id,)).fetchall()
    out = []
    for lg, lid, oid, g, tid, page, src in rows:
        if src not in SHABADOS_SOURCE:
            raise SystemExit('bani %s: line %s from unsupported ShabadOS source %s' % (bani_id, lid, src))
        out.append((lg, lid, oid, g, tid, page, SHABADOS_SOURCE[src]))
    return out


REVIEW = []   # every non-exact placement, for docs/nitnem/review-pack


def resolve_sggs_group(group_rows, by_ang, overrides, unknown, stats, report):
    """Map one line_group's SGGS rows -> ordered list of OUR line ids."""
    ids = []
    i = 0
    rows = group_rows
    cursor = 0     # last line id placed — repeated short lines advance, never repeat
    while i < len(rows):
        lg, slid, oid, g, tid, page, src = rows[i]
        if slid in overrides:
            o = overrides[slid]
            ids.extend(o['line_ids'])
            if o['line_ids']:
                cursor = max(o['line_ids'])
            stats['override'] += 1
            i += 1
            continue
        u = anmol.to_unicode(g, fold=True, unknown=unknown)
        cands = ml.candidates(by_ang, page)
        lid, q = ml.match_one(cands, u, after=cursor)
        if lid is not None:
            ids.append(lid)
            cursor = lid
            stats[q] += 1
            if q != 'exact':
                REVIEW.append({'shabados_line_id': slid, 'ang': page, 'quality': q,
                               'shabados': u, 'line_ids': [lid]})
            i += 1
            continue
        split, q = ml.match_split(cands, u, after=cursor)
        if split:
            ids.extend(split)
            cursor = split[-1]
            stats[q] += 1
            REVIEW.append({'shabados_line_id': slid, 'ang': page, 'quality': q,
                           'shabados': u, 'line_ids': split})
            i += 1
            continue
        # N->1: this + following ShabadOS lines joined == one of ours
        joined = None
        for k in (2, 3):
            if i + k <= len(rows):
                us = [anmol.to_unicode(r[3], fold=True) for r in rows[i:i + k]]
                jl, q = ml.match_joined(cands, us, after=cursor)
                if jl is not None:
                    joined = (jl, k, q)
                    break
        if joined:
            jl, k, q = joined
            ids.append(jl)
            cursor = jl
            stats[q] += 1
            REVIEW.append({'shabados_line_id': slid, 'ang': page, 'quality': q,
                           'shabados': ' / '.join(us), 'line_ids': [jl]})
            i += k
            continue
        stats['unmatched'] += 1
        report.append((slid, page, u))
        i += 1
    return ids


def check_range_anchors(spec, line_text, line_markers, key, failures):
    """Verify a seed range still points at the intended verses (ids can shift on a rebuild).

    Anchors are verbatim text from our own corpus, never edited here: the first line must
    START WITH `first_text_prefix`, the last line must EQUAL `last_text`, and the line before
    the last must carry `markers_before_last`. Any mismatch is a hard build failure.
    """
    lo, hi = spec['first'], spec['last']
    if lo > hi:
        failures.append('%s: range %d..%d is inverted' % (key, lo, hi))
        return
    missing = [lid for lid in (lo, hi) if lid not in line_text]
    if missing:
        failures.append('%s: range line id(s) %r are not in the corpus' % (key, missing))
        return
    pref = spec.get('first_text_prefix')
    if pref and not line_text[lo].startswith(pref):
        failures.append('%s: line %d no longer starts with %r (found %r)' % (key, lo, pref, line_text[lo][:40]))
    last = spec.get('last_text')
    if last is not None and line_text[hi] != last:
        failures.append('%s: line %d is no longer %r (found %r)' % (key, hi, last, line_text[hi][:40]))
    want = spec.get('markers_before_last')
    if want is not None:
        got = line_markers.get(hi - 1)
        if got != want:
            failures.append('%s: line %d markers %r != expected %r' % (key, hi - 1, got, want))


def build(args):
    seed = load_seed()
    overrides = load_overrides()
    db_path = Path(args.db).resolve()
    sha = sqlite3.connect('file:%s?mode=ro' % Path(args.shabados).resolve(), uri=True)
    con = sqlite3.connect(str(db_path), isolation_level=None)
    con.execute('PRAGMA foreign_keys=ON')
    by_ang = ml.load_corpus_index(con)
    line_meta = {lid: (ang, comp) for lid, ang, comp in con.execute('SELECT id, ang, comp_id FROM lines')}
    line_text = {lid: g for lid, g in con.execute('SELECT id, gurmukhi FROM lines')}
    line_markers = {lid: json.loads(m or '[]') for lid, m in con.execute('SELECT id, markers FROM lines')}

    unknown = collections.Counter()
    plan = []          # (bani_seed, [(seq, line_group, line_id|None, extra_key|None)], extras)
    extras = {}        # shabados_line_id -> dict(row)
    failures = []
    for b in seed['banis']:
        stats = collections.Counter()
        report = []
        rows = shabados_lines(sha, b['shabados_bani_id']) if b.get('shabados_bani_id') else []
        entries = []   # (line_group, line_id, extra_slid)
        gno = 0
        for lo, hi in b.get('prepend_line_ranges', []):
            gno += 1
            entries += [(gno, lid, None) for lid in range(lo, hi + 1)]
        for spec in b.get('sggs_line_ranges', []):
            check_range_anchors(spec, line_text, line_markers, b['key'], failures)
            gno += 1
            entries += [(gno, lid, None) for lid in range(spec['first'], spec['last'] + 1)]
        for lg, grp in _groupby(rows):
            gno += 1
            srcs = {r[6] for r in grp}
            if srcs == {'sggs'}:
                ids = resolve_sggs_group(grp, by_ang, overrides, unknown, stats, report)
                ordered = sorted(ids)
                if ordered != ids:
                    stats['reordered_groups'] += 1
                if len(set(ids)) != len(ids):
                    failures.append('%s: duplicate line ids in group %d' % (b['key'], lg))
                entries += [(gno, lid, None) for lid in ordered]
            elif 'sggs' not in srcs:
                for r in grp:
                    slid = r[1]
                    if slid not in extras:
                        u = anmol.to_unicode(r[3], fold=False, unknown=unknown)
                        extras[slid] = {
                            'source': r[6], 'panna': r[5] if r[6] == 'dasam' else None,
                            'gurmukhi': u,
                            'translit': translit_line(u.translate(TRANSLIT_FOLD)),
                            'is_header': 1 if r[4] in HEADER_TYPES else 0,
                            'shabados_line_id': slid,
                        }
                    entries.append((gno, None, slid))
                    stats['extra'] += 1
            else:
                failures.append('%s: group %d mixes SGGS and non-SGGS sources' % (b['key'], lg))
        for lo, hi in b.get('append_line_ranges', []):
            gno += 1
            entries += [(gno, lid, None) for lid in range(lo, hi + 1)]
        if report:
            failures.append('%s: %d unmatched SGGS line(s): %s' % (
                b['key'], len(report), '; '.join('%s@Ang%s %s' % (s, p, u[:40]) for s, p, u in report[:6])))
        if not entries:
            failures.append('%s: no lines — needs shabados_bani_id or sggs_line_ranges' % b['key'])
        n_extra = sum(1 for e in entries if e[2])
        angs = sorted({line_meta[e[1]][0] for e in entries if e[1]})
        print('  %-20s %-7s lines=%4d groups=%2d extra=%4d  angs=%s  %s' % (
            b['key'], b['variant'] or '-', len(entries), gno, n_extra,
            ('%d–%d' % (angs[0], angs[-1])) if angs else '-',
            dict(stats)))
        plan.append((b, entries))

    if unknown:
        failures.append('unknown ASCII characters in ShabadOS text: %r' % dict(unknown.most_common(20)))
    if args.report:
        ours = {}
        need = {lid for r in REVIEW for lid in r['line_ids']}
        for lid, g in con.execute('SELECT id, gurmukhi FROM lines'):
            if lid in need:
                ours[lid] = g
        for r in REVIEW:
            r['ours'] = [ours[lid] for lid in r['line_ids']]
        Path(args.report).write_text(json.dumps(
            {'_comment': 'Every SGGS placement that was not a byte-exact match; reviewer confirms '
                         'each pair is the same text. Rendered text is ALWAYS ours.',
             'placements': REVIEW}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        print('  review report: %s (%d non-exact placements)' % (args.report, len(REVIEW)))
    if failures:
        print('\nBUILD FAILED — nothing written:', file=sys.stderr)
        for f in failures:
            print('  ' + f, file=sys.stderr)
        return 1
    if args.dry_run:
        print('\n--dry-run: plan is complete and consistent; nothing written.')
        return 0

    # ---- write (one transaction) -------------------------------------------
    statements = split_statements((HERE / 'migrate_002_banis.sql').read_text(encoding='utf-8'))
    errs = whitelist(statements, rollback=False)
    if errs:
        print('ABORT: migration SQL failed the whitelist check:', file=sys.stderr)
        for e in errs:
            print('  ' + e, file=sys.stderr)
        return 1
    existing = NEW_TABLES & set(bl.list_tables(con))
    con.execute('BEGIN IMMEDIATE')
    try:
        if existing:
            for st in split_statements((HERE / 'rollback_002.sql').read_text(encoding='utf-8')):
                con.execute(st)
        for st in statements:
            con.execute(st)
        extra_ids = {}
        for slid, e in sorted(extras.items(), key=lambda kv: kv[0]):
            cur = con.execute(
                'INSERT INTO extra_lines(source, panna, gurmukhi, translit, is_header, shabados_line_id) '
                'VALUES (?,?,?,?,?,?)',
                (e['source'], e['panna'], e['gurmukhi'], e['translit'], e['is_header'], e['shabados_line_id']))
            extra_ids[slid] = cur.lastrowid
        for b, entries in plan:
            has_extra = int(any(e[2] for e in entries))
            n_groups = max(e[0] for e in entries)
            src = ('Sri Guru Granth Sahib Ji (verbatim corpus)' if not has_extra
                   else 'Sri Guru Granth Sahib Ji (verbatim corpus) + non-SGGS text via ShabadOS'
                   if any(e[1] for e in entries) else 'Non-SGGS text via ShabadOS')
            cur = con.execute(
                'INSERT INTO banis(key, variant, is_default, title_gm, title_en, category, order_no, '
                'n_lines, n_groups, has_extra, estimated_minutes, description_en, source_label) '
                'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
                (b['key'], b['variant'], b['is_default'], b['title_gm'], b['title_en'], b['category'],
                 b['order'], len(entries), n_groups, has_extra, b.get('estimated_minutes'),
                 b.get('description_en'), src))
            bid = cur.lastrowid
            con.executemany(
                'INSERT INTO bani_lines(bani_id, seq, line_group, line_id, extra_id) VALUES (?,?,?,?,?)',
                [(bid, i + 1, lg, lid, extra_ids[slid] if slid else None)
                 for i, (lg, lid, slid) in enumerate(entries)])
        # NOTE: no writes to `meta` / `sources` — every pre-existing table stays byte-identical
        # to the scripture baseline (guard_scripture.py); provenance lives in banis.source_label
        # and NOTICE.md.
        con.execute('COMMIT')
    except Exception as e:
        con.execute('ROLLBACK')
        print('ABORT: write failed, rolled back cleanly: %s' % e, file=sys.stderr)
        return 1
    fk = con.execute('PRAGMA foreign_key_check').fetchall()
    con.close()
    sha.close()
    if fk:
        print('ABORT: foreign_key_check violations after write: %r' % fk[:5], file=sys.stderr)
        return 1
    print('\nwrote %d banis, %d extra lines -> %s' % (len(plan), len(extras), db_path))
    return 0


def _groupby(rows):
    out = collections.OrderedDict()
    for r in rows:
        out.setdefault(r[0], []).append(r)
    return out.items()


def rollback(args):
    db_path = Path(args.db).resolve()
    statements = split_statements((HERE / 'rollback_002.sql').read_text(encoding='utf-8'))
    errs = whitelist(statements, rollback=True)
    if errs:
        for e in errs:
            print(e, file=sys.stderr)
        return 1
    con = sqlite3.connect(str(db_path), isolation_level=None)
    con.execute('BEGIN IMMEDIATE')
    for st in statements:
        con.execute(st)
    con.execute("DELETE FROM meta WHERE key='banis'")                    # legacy rows from the first build
    con.execute("DELETE FROM sources WHERE source_id='shabados-nitnem'")
    con.execute('COMMIT')
    con.close()
    print('[ROLLBACK] bani registry dropped.')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=str(ROOT / 'db' / 'sggs.sqlite'))
    ap.add_argument('--shabados', default=str(ROOT / 'database.sqlite'))
    ap.add_argument('--baseline', default=str(ROOT / 'audit' / 'scripture-baseline.json'))
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--rollback', action='store_true')
    ap.add_argument('--report', default=None, help='write the non-exact-placement review JSON here')
    ap.add_argument('--skip-baseline', action='store_true',
                    help='ONLY for rebuild_all.sh temp DBs (fresh build already gated)')
    args = ap.parse_args()
    if not args.rollback and not Path(args.shabados).exists():
        print('ShabadOS database not found: %s (see NOTICE.md to re-download)' % args.shabados, file=sys.stderr)
        return 1
    if not args.skip_baseline and not args.dry_run:
        bl.require_baseline_ok(args.db, args.baseline, when='(pre-banis)')
    rc = rollback(args) if args.rollback else build(args)
    if rc == 0 and not args.skip_baseline and not args.dry_run:
        bl.require_baseline_ok(args.db, args.baseline, when='(post-banis)')
        print('scripture baseline PASS — pre-existing tables byte-identical.')
    return rc


if __name__ == '__main__':
    sys.exit(main())
