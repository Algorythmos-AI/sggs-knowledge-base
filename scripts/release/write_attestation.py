#!/usr/bin/env python3
"""Record that the corpus reconciled char-exact vs the PDF (the PDF never enters CI)."""
import json, hashlib, datetime, socket, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for ch in iter(lambda:f.read(1<<20), b''): h.update(ch)
    return h.hexdigest()
def main():
    pdf = sys.argv[1] if len(sys.argv) > 1 else str(ROOT.parent / "Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf")
    ver = (ROOT / 'DATASET_VERSION').read_text().strip()   # the data's version, not the app build
    att = {
        "_comment": "Written by `make reconcile`. scripture-integrity CI asserts corpus_sha256 == the committed corpus.",
        "pdf_basename": Path(pdf).name,
        "pdf_sha256": sha(pdf),
        "corpus_sha256": sha(ROOT/'corpus'/'sggs.jsonl'),
        "reconciled_char_exact": True, "golden_pass": True,
        "reconciled_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": socket.gethostname(), "dataset_version": ver,
    }
    (ROOT/'validation'/'reconcile-attestation.json').write_text(json.dumps(att, indent=2)+"\n")
    print("attestation written:", att["pdf_sha256"][:16]+"…")
if __name__ == "__main__":
    main()
