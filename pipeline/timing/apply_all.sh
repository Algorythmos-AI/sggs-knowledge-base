#!/usr/bin/env bash
# One-command apply of the raag-timing knowledge layer to db/sggs.sqlite:
#   migrate -> seed -> derive -> guard -> stamp MANIFEST.
# Refuses to run while serve.py holds the DB (immutable-mode safety).
# Usage: bash pipeline/timing/apply_all.sh [DB_PATH]
set -euo pipefail
cd "$(dirname "$0")/../.."
DB="${1:-db/sggs.sqlite}"

if lsof -t "$DB" >/dev/null 2>&1; then
  echo "ABORT: $DB is open in another process (serve.py?). Stop it first." >&2
  exit 1
fi

echo "── 1/5 migrate (additive, transactional, whitelisted)"
python3 pipeline/timing/apply_migration.py --db "$DB"
echo "── 2/5 seed timing claims (idempotent, every claim cited)"
python3 pipeline/timing/seed_timing.py --db "$DB"
echo "── 3/5 derive bani forms (headings only, never guessed)"
python3 pipeline/timing/derive_bani_forms.py --db "$DB"
echo "── 4/5 guard: prove scripture byte-identical to committed baseline"
python3 pipeline/timing/guard_scripture.py --db "$DB"
echo "── 5/5 re-stamp MANIFEST (db_sha256 + baseline pointer)"
python3 pipeline/timing/stamp_manifest.py --db "$DB"
echo "DONE — restart the server (webapp/serve.py holds the DB immutable)."
