# -*- coding: utf-8 -*-
"""Audit W1: prove the corpus contains EXACTLY the PDF's scripture text —
no loss, no duplication, no reordering — by char-stream equality.

PDF side : pages 54..1483 -> page_content -> fix_text -> join
Corpus side: rows in id order -> gurmukhi display form -> join
Both sides then drop spaces; streams must be identical.
"""
import sys, json, fitz
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from sggs_pipeline import fix_text, page_content

PDF, JSONL = sys.argv[1], sys.argv[2]
doc = fitz.open(PDF)

pdf_parts = []
for p in range(53, 1483):
    _, raw = page_content(doc, p)
    fixed, _ = fix_text(raw)
    pdf_parts.append(fixed)
pdf_stream = ''.join(pdf_parts).replace(' ', '')

rows = [json.loads(l) for l in open(JSONL, encoding='utf-8')]
corpus_stream = ''.join(r['gurmukhi'] for r in rows).replace(' ', '')

print(f'pdf chars   : {len(pdf_stream):,}')
print(f'corpus chars: {len(corpus_stream):,}')
if pdf_stream == corpus_stream:
    print('RECONCILED: corpus == source, character for character.')
    sys.exit(0)

# locate first divergence
lo, hi = 0, min(len(pdf_stream), len(corpus_stream))
while lo < hi:
    mid = (lo + hi) // 2
    if pdf_stream[:mid] == corpus_stream[:mid]: lo = mid + 1
    else: hi = mid
i = max(0, lo - 1)
print(f'FIRST DIVERGENCE at char {i:,}')
print('pdf   :', repr(pdf_stream[max(0,i-30):i+40]))
print('corpus:', repr(corpus_stream[max(0,i-30):i+40]))
# locate the ang: walk corpus rows accumulating lengths
acc = 0
for r in rows:
    acc += len(r['gurmukhi'].replace(' ', ''))
    if acc >= i:
        print(f'near corpus id={r["id"]} ang={r["ang"]}: {r["gurmukhi"][:70]}')
        break
sys.exit(1)
