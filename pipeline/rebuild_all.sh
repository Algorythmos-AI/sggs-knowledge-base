#!/bin/bash
# Full reproducible rebuild: source PDF -> verified corpus -> complete database.
# Usage:  bash pipeline/rebuild_all.sh [path-to-source-pdf]
# Builds in a temp location (SQLite cannot create DBs on some mounted folders),
# then installs to db/sggs.sqlite. Every stage gates on its verifier, and every
# install is atomic (pipeline/atomic_install.py): the committed corpus and DB are
# replaced only after their checks pass, never left half-written.
set -euo pipefail
cd "$(dirname "$0")/.."
PDF="${1:-../Siri-Guru-Granth-Sahib-in-Gurmukhi-with-Index.pdf}"
[ -f "$PDF" ] || { echo "source PDF not found: $PDF" >&2; exit 1; }

echo "── 0/8 pre-flight (free disk, toolchain)"
MIN_FREE_KB=$((5 * 1024 * 1024))          # 5 GiB: two DB builds + temp copies + headroom
for d in "$PWD" "${TMPDIR:-/tmp}"; do
  FREE_KB=$(df -Pk "$d" | awk 'NR==2 {print $4}')
  [ "$FREE_KB" -ge "$MIN_FREE_KB" ] || { echo "only $((FREE_KB / 1024)) MiB free on $d — need 5 GiB; aborting before any write" >&2; exit 1; }
done
python3 -c "import sys, sqlite3, fitz, numpy, scipy; print('python', sys.version.split()[0], '· sqlite', sqlite3.sqlite_version)"
# The source of record must be the exact PDF the committed corpus was reconciled
# against (validation/reconcile-attestation.json). A corrupted or different file is
# refused; a deliberately new source edition needs SGGS_ALLOW_NEW_PDF=1 and review.
python3 - "$PDF" <<'EOF'
import hashlib, json, os, sys
h = hashlib.sha256()
with open(sys.argv[1], 'rb') as f:
    for chunk in iter(lambda: f.read(1 << 20), b''): h.update(chunk)
want = json.load(open('validation/reconcile-attestation.json'))['pdf_sha256']
if h.hexdigest() == want:
    print('source PDF sha256 matches the reconcile attestation')
elif os.environ.get('SGGS_ALLOW_NEW_PDF') == '1':
    print(f'WARNING: source PDF differs from the attestation ({h.hexdigest()[:16]}… vs {want[:16]}…) — allowed by SGGS_ALLOW_NEW_PDF=1')
else:
    sys.exit(f'source PDF sha256 {h.hexdigest()} != attested {want}; refusing to build '
             '(set SGGS_ALLOW_NEW_PDF=1 only for a reviewed new source edition)')
EOF
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
TMPDB="$WORK/sggs.db"
CORPUS_NEW="$WORK/sggs.jsonl"

echo "── 1/8 corpus extraction (to a staging file; corpus/sggs.jsonl untouched until verified)"
python3 pipeline/build_corpus.py "$PDF" "$CORPUS_NEW"
echo "── 2/8 reconciliation (must be char-exact)"
python3 pipeline/reconcile.py "$PDF" "$CORPUS_NEW"
echo "── 3/8 golden suite"
python3 pipeline/golden_test.py "$PDF" "$CORPUS_NEW" >/dev/null && echo "ALL GOLDEN TESTS PASS"
python3 pipeline/atomic_install.py "$CORPUS_NEW" corpus/sggs.jsonl
echo "── 4/8 database + FTS"
python3 pipeline/build_db.py corpus/sggs.jsonl "$TMPDB"
echo "── 5/8 concepts + translations + variants + v2 structural columns"
python3 - "$TMPDB" <<'EOF'
import json, sqlite3, glob, collections, sys
con = sqlite3.connect(sys.argv[1]); cur = con.cursor()
allc = []
for f in sorted(glob.glob('validation/concepts_*.json')): allc += json.load(open(f, encoding='utf-8'))
t2c = collections.defaultdict(list)
for c in allc:
    terms = [t.get('term') or t.get('word') if isinstance(t, dict) else t for t in c['gurmukhi_terms']]
    terms = [t for t in terms if isinstance(t, str) and t.strip()]
    cur.execute('INSERT OR REPLACE INTO concepts VALUES(?,?,?)',
                (c['concept'], json.dumps(terms, ensure_ascii=False), c.get('description','')))
    for t in terms: t2c[t].append(c['concept'])
ins = []
for lid, text, hdr in cur.execute('SELECT id, text, is_header FROM lines'):
    if hdr: continue
    seen = set()
    for w in text.split():
        for cpt in t2c.get(w, ()):
            if cpt not in seen: seen.add(cpt); ins.append((cpt, lid, w))
cur.executemany('INSERT INTO concept_lines VALUES(?,?,?)', ins)
con.commit(); con.close()
print(f'concepts: {len(allc)}, links: {len(ins)}')
EOF
python3 pipeline/load_translations.py "$TMPDB" --source=ssk-shabados "pipeline/translations/en_full_shabados.jsonl"
python3 pipeline/load_translations.py "$TMPDB" "pipeline/translations/en_0*.jsonl" "pipeline/translations/en_9*.jsonl"
python3 pipeline/build_variants.py "$TMPDB"
python3 pipeline/enrich_orchestrator.py merge "$TMPDB"
python3 pipeline/enrich_v2.py --db "$TMPDB" --apply                            # v2.0 structural columns: stanza_index, pada_total, source_category (serve.py LINE_COLS + build_vaars.py require these)
echo "── 6/8 auxiliary indexes (english FTS, shabad passage FTS, trigram, canon tokens)"
python3 - "$TMPDB" <<'EOF'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1]); cur = con.cursor()
cur.execute('DROP TABLE IF EXISTS fts_en')
cur.execute("CREATE VIRTUAL TABLE fts_en USING fts5(text, line_id UNINDEXED)")
cur.execute("INSERT INTO fts_en(text, line_id) SELECT text, line_id FROM translations WHERE lang='en'")
cur.execute('DROP TABLE IF EXISTS fts_shabad')
cur.execute("CREATE VIRTUAL TABLE fts_shabad USING fts5(tnorm, comp_id UNINDEXED)")
cur.execute("INSERT INTO fts_shabad(tnorm, comp_id) SELECT GROUP_CONCAT(translit_norm,' '), comp_id FROM lines WHERE is_header=0 GROUP BY comp_id")
# The trigram index is required (search-tier contract): an SQLite without the
# trigram tokenizer must fail the build, not ship a DB that silently lacks it.
cur.execute('DROP TABLE IF EXISTS fts_tri')
cur.execute("CREATE VIRTUAL TABLE fts_tri USING fts5(translit, line_id UNINDEXED, tokenize='trigram')")
cur.execute("INSERT INTO fts_tri(translit, line_id) SELECT translit, id FROM lines WHERE is_header=0")
cur.execute('DROP TABLE IF EXISTS canon_tokens')
cur.execute('CREATE TABLE canon_tokens(token TEXT PRIMARY KEY)')
toks = set()
for (t,) in cur.execute('SELECT translit FROM lines'): toks.update((t or '').split())
cur.executemany('INSERT OR IGNORE INTO canon_tokens VALUES(?)', [(t,) for t in toks])
con.commit(); con.close()
print('aux indexes built')
EOF
echo "── 7/8 Insight Engine: analytics + semantic neighbors + resonance + vaars (additive; never alters scripture)"
ANALYTICS_DB="$WORK/sggs_full.db"
python3 pipeline/ml_analytics_builder.py --db "$TMPDB" --out "$ANALYTICS_DB"   # theme_network, fingerprints, author/raag analytics, shabad_neighbors, analytics_meta
python3 pipeline/build_semantic_vectors_lite.py --db "$ANALYTICS_DB"           # line_neighbors (tfidf-randproj-lite)
python3 pipeline/build_resonance.py --db "$ANALYTICS_DB"                       # author_resonance (uses line_neighbors)
python3 pipeline/build_vaars.py --db "$ANALYTICS_DB"                           # vaars + vaar_units (22 Vaars, detected by title header)

echo "── 7b/8 raag-timing knowledge layer (additive NEW tables only; scripture untouched)"
# --skip-baseline is sanctioned ONLY here: the fresh build is already gated by
# reconcile.py + golden_test.py, and its derived tables legitimately differ
# from the committed baseline. After install, re-baseline as a conscious act:
#   python3 pipeline/timing/step0_baseline.py --force   (then commit audit/…)
python3 pipeline/timing/apply_migration.py  --db "$ANALYTICS_DB" --allow-live --skip-baseline
python3 pipeline/timing/seed_timing.py      --db "$ANALYTICS_DB" --skip-baseline
python3 pipeline/timing/derive_bani_forms.py --db "$ANALYTICS_DB" --skip-baseline

echo "── 7c/8 Nitnem bani registry (additive NEW tables: banis, bani_lines, extra_lines; scripture untouched)"
# Needs the ShabadOS database.sqlite in the repo root (git-ignored; NOTICE.md says how to fetch it).
python3 pipeline/banis/build_banis.py --db "$ANALYTICS_DB" --skip-baseline --report docs/nitnem/review-pack/sggs-placements.json
python3 pipeline/banis/guard_banis.py --db "$ANALYTICS_DB"

echo "── 8/8 integrity gate + atomic install + manifest"
python3 pipeline/db_integrity_gate.py "$ANALYTICS_DB"
python3 pipeline/atomic_install.py "$ANALYTICS_DB" db/sggs.sqlite
python3 - <<'EOF'
import json, hashlib, datetime, sqlite3, os, tempfile
def sha(p):
    h = hashlib.sha256()
    with open(p,'rb') as f:
        for ch in iter(lambda: f.read(1<<20), b''): h.update(ch)
    return h.hexdigest()
con = sqlite3.connect('file:db/sggs.sqlite?mode=ro&immutable=1', uri=True)
n_var = con.execute('SELECT count(*) FROM variants').fetchone()[0]
n_en = con.execute("SELECT count(*) FROM translations WHERE lang='en'").fetchone()[0]
con.close()
m = json.load(open('MANIFEST.json'))
av = None
try:
    import re
    av = re.search(r"APP_VERSION\s*=\s*'([^']+)'", open('webapp/serve.py').read()).group(1)
except Exception: pass
m.update({'version': av or m.get('version'),
          'built': datetime.date.today().isoformat(), 'variants': n_var,
          'translations_en': n_en, 'corpus_sha256': sha('corpus/sggs.jsonl'),
          'db_sha256': sha('db/sggs.sqlite')})
fd, tmp = tempfile.mkstemp(prefix='.MANIFEST.json.', dir='.')
with os.fdopen(fd, 'w') as f:
    json.dump(m, f, indent=2); f.flush(); os.fsync(f.fileno())
os.replace(tmp, 'MANIFEST.json')
print(f'installed: variants={n_var}, en={n_en}')
EOF
echo "DONE — start the app: cd webapp && python3 serve.py"
