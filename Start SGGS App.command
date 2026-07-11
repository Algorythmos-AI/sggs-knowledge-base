#!/bin/bash
# Sri Guru Granth Sahib Knowledge Base — double-click to start.
# Stop with Ctrl-C in this window (or just close the window).
cd "$(dirname "$0")/webapp" || exit 1
echo "ੴ  Starting the SGGS Knowledge Base …"
# Local desktop launch: auto-open the browser (serve.py only opens it when this is set).
export SGGS_OPEN_BROWSER=1
exec python3 serve.py
