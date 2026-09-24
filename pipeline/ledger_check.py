# -*- coding: utf-8 -*-
"""Enforce the editorial ledger: scripture text changes only through a registered, reviewed entry.

    python3 pipeline/ledger_check.py [--base GIT_REF]

Checks (exit 1 on any failure):
  1. audit/editorial-ledger.jsonl is well-formed: one header, unique ids, every
     application names a registered editorial rule, and the evidence PDF hash equals
     validation/reconcile-attestation.json.
  2. Code == register: the editorial rules in pipeline/sggs_pipeline.py:fix_text
     (step 4: literal replacements + the Sahaskriti regex) are exactly the ledger's
     editorial rules — adding, changing or removing one in code without the ledger
     (or vice versa) fails.
  3. With --base: every line whose T0 fields (ang, gurmukhi, text, markers) differ
     between corpus/sggs.jsonl at GIT_REF and now must be a candidate line of an
     application entry added since GIT_REF; lines may never be added or removed.

Stdlib only; Python 3.9+. Reads the corpus from git for the base, never writes.
"""
import argparse
import ast
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEDGER = "audit/editorial-ledger.jsonl"
CORPUS = "corpus/sggs.jsonl"
PIPELINE = "pipeline/sggs_pipeline.py"
T0_FIELDS = ("ang", "gurmukhi", "text", "markers")


def parse_ledger(text):
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def check_ledger(entries, attested_pdf_sha):
    fails = []
    headers = [e for e in entries if e.get("kind") == "header"]
    if len(headers) != 1:
        fails.append(f"ledger must have exactly one header entry (found {len(headers)})")
    elif attested_pdf_sha not in headers[0].get("evidence", ""):
        fails.append("ledger evidence PDF sha256 != validation/reconcile-attestation.json pdf_sha256")
    ids = [e["id"] for e in entries if "id" in e]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    if dup:
        fails.append(f"duplicate ledger ids: {dup}")
    editorial = {e["id"] for e in entries if e.get("kind") == "rule" and e.get("class") == "editorial"}
    for e in entries:
        if e.get("kind") == "application":
            if e.get("rule") not in editorial:
                fails.append(f"{e.get('id')}: rule {e.get('rule')!r} is not a registered editorial rule")
            if not e.get("candidate_line_ids"):
                fails.append(f"{e.get('id')}: no candidate_line_ids")
            if not e.get("review"):
                fails.append(f"{e.get('id')}: no review status")
    return fails


def code_editorial_rules(source):
    """(match, before, after) triples from fix_text step 4, read with ast (no execution)."""
    lines = source.splitlines()
    start = next(i for i, ln in enumerate(lines, 1) if ln.strip().startswith("# 4. documented editorial corrections"))
    end = next(i for i, ln in enumerate(lines, 1) if i > start and ln.strip().startswith("# 5."))
    rules = set()
    for node in ast.walk(ast.parse(source)):
        if not (start < getattr(node, "lineno", 0) < end):
            continue
        if isinstance(node, ast.Tuple) and len(node.elts) == 2 and all(
                isinstance(x, ast.Constant) and isinstance(x.value, str) for x in node.elts):
            rules.add(("literal", node.elts[0].value, node.elts[1].value))
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "sub"
                and len(node.args) >= 2 and all(isinstance(a, ast.Constant) for a in node.args[:2])):
            rules.add(("regex", node.args[0].value, node.args[1].value))
    return rules


def check_code_matches_ledger(entries, source):
    in_code = code_editorial_rules(source)
    in_ledger = {(e["match"], e["before"], e["after"]) for e in entries
                 if e.get("kind") == "rule" and e.get("class") == "editorial"}
    fails = []
    for r in sorted(in_code - in_ledger):
        fails.append(f"editorial rule in fix_text is not registered in the ledger: {r[0]} {r[1]!r} -> {r[2]!r}")
    for r in sorted(in_ledger - in_code):
        fails.append(f"ledger editorial rule no longer in fix_text: {r[0]} {r[1]!r} -> {r[2]!r}")
    return fails


def t0_index(corpus_text):
    out = {}
    for line in corpus_text.splitlines():
        if line.strip():
            r = json.loads(line)
            out[r["id"]] = tuple(json.dumps(r.get(f), ensure_ascii=False) for f in T0_FIELDS)
    return out


def check_corpus_diff(base_corpus, head_corpus, base_entries, head_entries):
    fails = []
    a, b = t0_index(base_corpus), t0_index(head_corpus)
    if set(a) != set(b):
        added, removed = sorted(set(b) - set(a)), sorted(set(a) - set(b))
        fails.append(f"corpus lines added {added[:10]} / removed {removed[:10]} — never allowed")
    changed = sorted(i for i in set(a) & set(b) if a[i] != b[i])
    old_ids = {e.get("id") for e in base_entries}
    covered = set()
    for e in head_entries:
        if e.get("kind") == "application" and e.get("id") not in old_ids:
            covered.update(e.get("candidate_line_ids", []))
    uncovered = [i for i in changed if i not in covered]
    if uncovered:
        fails.append(f"{len(uncovered)} scripture line(s) changed without a new ledger application: {uncovered[:20]}")
    return fails, changed


def git_show(ref, path):
    r = subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    return r.stdout if r.returncode == 0 else None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", help="git ref to diff the corpus against (e.g. the PR base sha)")
    a = ap.parse_args(argv)
    head_text = (ROOT / LEDGER).read_text(encoding="utf-8")
    entries = parse_ledger(head_text)
    attested = json.loads((ROOT / "validation/reconcile-attestation.json").read_text())["pdf_sha256"]
    fails = check_ledger(entries, attested)
    fails += check_code_matches_ledger(entries, (ROOT / PIPELINE).read_text(encoding="utf-8"))
    changed = []
    if a.base:
        base_corpus = git_show(a.base, CORPUS)
        if base_corpus is None:
            fails.append(f"cannot read {CORPUS} at {a.base} (fetch the base commit)")
        else:
            base_ledger = git_show(a.base, LEDGER)
            f2, changed = check_corpus_diff(base_corpus, (ROOT / CORPUS).read_text(encoding="utf-8"),
                                            parse_ledger(base_ledger or ""), entries)
            fails += f2
    for f in fails:
        print("FAIL", f)
    n_rules = sum(1 for e in entries if e.get("kind") == "rule" and e.get("class") == "editorial")
    n_apps = sum(1 for e in entries if e.get("kind") == "application")
    scope = f"; {len(changed)} scripture line(s) changed vs {a.base}" if a.base else ""
    print(f"ledger check: {'FAIL' if fails else 'PASS'} — {n_rules} editorial rules == code, {n_apps} applications{scope}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
