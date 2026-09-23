#!/usr/bin/env bash
# rebaseline_pretiming.sh SCRATCH_DIR — re-record audit/scripture-baseline.json after a
# deliberate rebuild. step0_baseline.py refuses a DB with the timing tables, so baseline a
# copy of db/sggs.sqlite with only those 7 tables dropped (the real DB is not modified).
set -euo pipefail
S="${1:?usage: rebaseline_pretiming.sh <scratch-dir>}"
cd "$(git rev-parse --show-toplevel)"
cp db/sggs.sqlite "$S/pretiming.sqlite"
python3 - "$S/pretiming.sqlite" <<'PY'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
for t in ["timing_sources","raag_timing_claims","shabd_raag_map","shabd_musical_markers",
          "shabd_structural_form","shabd_poetic_genre","timing_migrations"]:
    c.execute(f"DROP TABLE IF EXISTS {t}")
c.commit(); c.execute("VACUUM"); c.close()
PY
python3 pipeline/timing/step0_baseline.py --db "$S/pretiming.sqlite" --force --skip-backup | tail -3
rm -f "$S/pretiming.sqlite"
echo "baseline re-recorded — now run: python3 pipeline/timing/guard_scripture.py"
