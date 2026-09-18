#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
review_pack.py — generate the scholar review pack for the Nitnem NON-SGGS text.

Writes one Markdown file per bani that contains `extra_lines` (Sri Dasam Granth /
Ardaas) into docs/nitnem/review-pack/, listing every line in reading order with its
source page, so a Granthi / Gurbani scholar can compare it against a printed SGPC
Nitnem Gutka. SGGS lines are summarised by Ang range only (they are already proven).

Read-only. Usage: python3 pipeline/banis/review_pack.py [--db PATH] [--out DIR]
"""
import argparse
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=str(ROOT / 'db' / 'sggs.sqlite'))
    ap.add_argument('--out', default=str(ROOT / 'docs' / 'nitnem' / 'review-pack'))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect('file:%s?mode=ro' % Path(args.db).resolve(), uri=True)
    con.row_factory = sqlite3.Row
    index = ['# Nitnem review pack — non-SGGS text', '',
             'Each file lists the Sri Dasam Granth / Ardaas lines of one bani in reading order, '
             'for comparison against a printed SGPC Nitnem Gutka. Sri Guru Granth Sahib Ji lines '
             'are not listed: they come from the reconciled corpus and are cited by Ang.', '',
             '| Bani | Non-SGGS lines | Status |', '|---|---|---|']
    for b in con.execute('SELECT * FROM banis WHERE has_extra=1 ORDER BY order_no, variant'):
        rows = con.execute(
            'SELECT bl.seq, bl.line_group, bl.line_id, l.ang, e.source, e.panna, e.gurmukhi, e.is_header, '
            'e.review_status, e.shabados_line_id FROM bani_lines bl '
            'LEFT JOIN lines l ON l.id = bl.line_id LEFT JOIN extra_lines e ON e.extra_id = bl.extra_id '
            'WHERE bl.bani_id = ? ORDER BY bl.seq', (b['bani_id'],)).fetchall()
        name = b['key'] + (('-' + b['variant']) if b['variant'] else '')
        md = ['# %s — %s' % (b['title_en'], b['title_gm']), '',
              'Key `%s`%s · %d lines · %d groups' % (
                  b['key'], (' · variant `%s`' % b['variant']) if b['variant'] else '',
                  b['n_lines'], b['n_groups']), '',
              'Reviewer: ______________   Date: ____________   Edition compared: ______________', '',
              'Mark each non-SGGS line ✓ (matches the gutka) or note the correction. '
              'Corrections are applied by editing `pipeline/banis/` inputs and rebuilding — never by hand in the DB.', '']
        n_extra = 0
        cur_group = None
        run_start = run_end = None

        def flush_sggs():
            if run_start is not None:
                md.append('- *Sri Guru Granth Sahib Ji · Ang %s%s* (verbatim corpus, not reviewed here)' % (
                    run_start, ('–%d' % run_end) if run_end != run_start else ''))
        for r in rows:
            if r['line_group'] != cur_group:
                flush_sggs()
                run_start = run_end = None
                cur_group = r['line_group']
                md += ['', '## Group %d' % cur_group, '']
            if r['line_id'] is not None:
                if run_start is None:
                    run_start = r['ang']
                run_end = r['ang']
                continue
            flush_sggs()
            run_start = run_end = None
            n_extra += 1
            src = 'Sri Dasam Granth · Panna %s' % r['panna'] if r['source'] == 'dasam' else 'Ardaas'
            md.append('- [ ] `%d` %s%s  \n  **%s**  \n  <sub>%s · %s · ShabadOS %s</sub>' % (
                r['seq'], '(heading) ' if r['is_header'] else '', '',
                r['gurmukhi'], src, r['review_status'], r['shabados_line_id']))
        flush_sggs()
        (out / ('%s.md' % name)).write_text('\n'.join(md) + '\n', encoding='utf-8')
        status = 'reviewed' if all(r['review_status'] == 'reviewed' for r in rows if r['line_id'] is None) else 'unreviewed'
        index.append('| [%s](%s.md) | %d | %s |' % (b['title_en'], name, n_extra, status))
    (out / 'README.md').write_text('\n'.join(index) + '\n', encoding='utf-8')
    print('review pack -> %s (%d banis)' % (out, len(index) - 6))


if __name__ == '__main__':
    main()
