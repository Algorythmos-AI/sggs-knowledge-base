#!/bin/bash
# Sri Guru Granth Sahib Knowledge Base — double-click to start.
# Stop with Ctrl-C in this window (or just close the window).
cd "$(dirname "$0")/webapp" || exit 1
echo "ੴ  Starting the SGGS Knowledge Base …"
exec python3 serve.py
