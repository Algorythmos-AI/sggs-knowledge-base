#!/bin/bash
# Sri Guru Granth Sahib Knowledge Base — double-click to start.
# Stop with Ctrl-C in this window (or just close the window).
cd "$(dirname "$0")" || exit 1
if ! head -c 16 db/sggs.sqlite 2>/dev/null | grep -q "SQLite format 3"; then
  echo "ੴ  Installing the pinned scripture database (first run, ~104 MiB, sha256-verified) …"
  python3 scripts/data/fetch_dataset.py || exit 1
fi
cd webapp || exit 1
echo "ੴ  Starting the SGGS Knowledge Base …"
# Local desktop launch: auto-open the browser (serve.py only opens it when this is set).
export SGGS_OPEN_BROWSER=1
exec python3 serve.py
