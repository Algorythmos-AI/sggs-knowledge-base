#!/usr/bin/env bash
# check_release_license.sh — the mechanical NOTICE.md hard-gate for any PUBLIC iOS release.
#
# Fails (exit 1) if:
#   (a) the manifest says en_bundled=true AND the licence attestation file
#       (ios/Resources/TRANSLATION-LICENSE.md, override with $SGGS_LICENSE_ATTESTATION)
#       does not contain the line `LICENSED: true` — the Khalsa English translation is
#       PERSONAL, LOCAL, NON-COMMERCIAL use only until licensed in writing; a public /
#       TestFlight / App Store build must either be built with `--profile public` or
#       carry a filled-in attestation;
#   (b) scripture_sha256 differs from the certified corpus value — scripture must be
#       byte-identical to the proven corpus, always;
#   (c) the DB artifact's sha256 doesn't match its manifest;
#   (d) any golden-vector suite recorded in contract/_meta.json is missing or empty;
#   (e) the bundled DB carries the Nitnem registry with NON-SGGS text (extra_lines) and
#       either that table has an English column (never allowed) or the scholar review
#       is not attested with `REVIEWED: true` in ios/Resources/NITNEM-REVIEW.md
#       (override with $SGGS_NITNEM_ATTESTATION) — Sri Dasam Granth / Ardaas text is
#       not covered by the SGGS reconcile proof. Unreviewed text is a WARNING for
#       TestFlight builds (the app labels it "under review") and a hard FAIL when
#       SGGS_RELEASE_CHANNEL=appstore (App Store submission).
#
# Usage:  pipeline/check_release_license.sh [manifest] [db]
#   defaults: ios/Resources/sggs-ios-public.manifest.json + its sibling .sqlite
#   (pass the personal manifest to CONFIRM it is blocked — that's the negative test)
set -euo pipefail
cd "$(dirname "$0")/.."

MANIFEST="${1:-ios/Resources/sggs-ios-public.manifest.json}"
DB="${2:-${MANIFEST%.manifest.json}.sqlite}"
CERTIFIED_SCRIPTURE_SHA="0eff4bae60cfcf1c63ae4ac14c2ecf255a9457edc0bebaf627aa28dedb89c84f"
ATTESTATION="${SGGS_LICENSE_ATTESTATION:-ios/Resources/TRANSLATION-LICENSE.md}"
NITNEM_ATTESTATION="${SGGS_NITNEM_ATTESTATION:-ios/Resources/NITNEM-REVIEW.md}"

fail=0
say() { echo "  $1"; }

echo "release gate: $MANIFEST"

[ -f "$MANIFEST" ] || { echo "FAIL: manifest not found: $MANIFEST"; exit 1; }

EN=$(python3 -c "import json;print(json.load(open('$MANIFEST')).get('en_bundled', False))")
if [ "$EN" = "True" ]; then
  if [ -f "$ATTESTATION" ] && grep -qE '^LICENSED:[[:space:]]*true[[:space:]]*$' "$ATTESTATION"; then
    say "✓ en_bundled=true and the translation licence is attested ($ATTESTATION)"
  else
    say "✗ en_bundled=true — the Khalsa English layer is personal-use only (NOTICE.md)."
    say "  A public/TestFlight release must be built with --profile public, or the licence"
    say "  must be attested with 'LICENSED: true' in $ATTESTATION."
    fail=1
  fi
else
  say "✓ no restricted translation layer bundled"
fi

SCRIPT_SHA=$(python3 -c "import json;print(json.load(open('$MANIFEST')).get('scripture_sha256',''))")
if [ "$SCRIPT_SHA" != "$CERTIFIED_SCRIPTURE_SHA" ]; then
  say "✗ scripture_sha256 differs from the certified corpus value — scripture must never change"
  fail=1
else
  say "✓ scripture_sha256 matches the certified corpus"
fi

if [ -f "$DB" ]; then
  WANT=$(python3 -c "import json;print(json.load(open('$MANIFEST')).get('db_sha256',''))")
  GOT=$(shasum -a 256 "$DB" | cut -d' ' -f1)
  if [ "$WANT" != "$GOT" ]; then
    say "✗ DB sha256 does not match its manifest ($GOT != $WANT)"
    fail=1
  else
    say "✓ DB artifact matches its manifest"
  fi
else
  say "✗ DB artifact missing: $DB (build it: python3 pipeline/build_ios_db.py --profile public)"
  fail=1
fi

BANIS=$(python3 -c "import json;print(json.load(open('$MANIFEST')).get('banis_bundled', False))")
if [ "$BANIS" = "True" ] && [ -f "$DB" ]; then
  EXTRA_EN=$(sqlite3 "$DB" "SELECT count(*) FROM pragma_table_info('extra_lines') WHERE name IN ('en','english','translation');")
  N_EXTRA=$(sqlite3 "$DB" "SELECT count(*) FROM extra_lines;")
  if [ "$EXTRA_EN" != "0" ]; then
    say "✗ extra_lines carries an English column — non-SGGS text must never bundle a translation"
    fail=1
  elif [ "$N_EXTRA" != "0" ]; then
    if [ -f "$NITNEM_ATTESTATION" ] && grep -qE '^REVIEWED:[[:space:]]*true[[:space:]]*$' "$NITNEM_ATTESTATION"; then
      say "✓ Nitnem non-SGGS text ($N_EXTRA lines) is scholar-reviewed ($NITNEM_ATTESTATION)"
    elif [ "${SGGS_RELEASE_CHANNEL:-testflight}" = "appstore" ]; then
      say "✗ Nitnem non-SGGS text ($N_EXTRA lines: Sri Dasam Granth / Ardaas) is NOT yet scholar-reviewed."
      say "  An App Store submission needs docs/nitnem/review-pack/ completed and 'REVIEWED: true' in $NITNEM_ATTESTATION."
      fail=1
    else
      say "⚠ Nitnem non-SGGS text ($N_EXTRA lines) is NOT yet scholar-reviewed — allowed for TestFlight only."
      say "  The app labels these lines 'under review'. Set SGGS_RELEASE_CHANNEL=appstore to enforce the gate."
    fi
  else
    say "✓ Nitnem registry bundled with SGGS pointers only"
  fi
fi

python3 - <<'PY' || fail=1
import json, os, sys
meta = json.load(open('contract/_meta.json'))
bad = []
for fname, want in meta.get('files', {}).items():
    path = os.path.join('contract', fname)
    if not os.path.exists(path):
        bad.append(f"{fname}: missing"); continue
    n = sum(1 for _ in open(path, encoding='utf-8'))
    if n != want:
        bad.append(f"{fname}: {n} vectors != {want} in _meta.json")
if bad:
    print("  ✗ golden-vector contract incomplete:"); [print(f"    - {b}") for b in bad]
    sys.exit(1)
print(f"  ✓ golden-vector contract complete ({len(meta.get('files', {}))} suites)")
PY

if [ "$fail" -ne 0 ]; then
  echo "RELEASE GATE: BLOCKED"
  exit 1
fi
echo "RELEASE GATE: OK (this artifact is eligible for public distribution)"
