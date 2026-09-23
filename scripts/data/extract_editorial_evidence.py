#!/usr/bin/env python3
"""Re-derive, from the source PDF, every place the pipeline applies a text transform.

    PATH=/usr/bin:$PATH python3 scripts/data/extract_editorial_evidence.py [PDF] > evidence.json

Runs the pipeline's own page_content + fix_text over PDF pages 54-1483 (Angs
1-1430) and emits the anomaly log fix_text produces: per transform kind, the
number of applications, and for every `editorial_fix` its Ang, PDF page and
rule. Candidate corpus line ids are the lines on that Ang whose Gurmukhi
contains the corrected form (a rule is applied page-wide, so more than one line
can carry it). This is how audit/editorial-ledger.jsonl was populated; a
reviewer with the PDF can reproduce it exactly. Read-only. Needs PyMuPDF.
"""
import collections
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))
import fitz  # noqa: E402
from sggs_pipeline import fix_text, page_content  # noqa: E402

DEFAULT_PDF = ROOT.parent / "Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf"


def main(argv):
    pdf = argv[1] if len(argv) > 1 else str(DEFAULT_PDF)
    doc = fitz.open(pdf)
    rows = [json.loads(line) for line in open(ROOT / "corpus" / "sggs.jsonl", encoding="utf-8")]
    by_ang = collections.defaultdict(list)
    for r in rows:
        by_ang[r["ang"]].append(r)
    counts = collections.Counter()
    editorial = []
    for p in range(53, 1483):
        ang, raw = page_content(doc, p)
        _, anomalies = fix_text(raw)
        for kind, detail in anomalies:
            counts[kind] += 1
            if kind == "editorial_fix":
                after = detail.split(" -> ", 1)[1]
                editorial.append({
                    "ang": ang, "pdf_page": p + 1, "rule_detail": detail,
                    "candidate_line_ids": [r["id"] for r in by_ang[ang] if after in r["gurmukhi"]],
                })
    json.dump({"counts": dict(sorted(counts.items())), "editorial": editorial},
              sys.stdout, ensure_ascii=False, indent=1)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
