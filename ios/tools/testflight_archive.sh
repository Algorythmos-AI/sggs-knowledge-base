#!/usr/bin/env bash
# testflight_archive.sh — build the TestFlight / App Store candidate the *only* sanctioned way.
#
# What it does, in order (every step is a gate; the script stops on the first failure):
#   1. Derives the iOS DB for the chosen PROFILE from db/sggs.sqlite (scripture checksum proven
#      by pipeline/build_ios_db.py) into a STAGING directory under ios/App/build/. The developer's
#      ios/Resources/sggs-ios.sqlite + manifest pair is never read, written or restored.
#   2. Runs pipeline/check_release_license.sh on THAT artifact — a public build must be
#      Gurmukhi-only, or the English translation must be attested LICENSED: true.
#   3. Generates SGGS-TestFlight.xcodeproj with XcodeGen from a temporary sibling spec that is
#      project.yml with exactly three lines changed (name + the two DB resource paths → staging).
#      Your own SGGS.xcodeproj is not repointed; neither project is ever committed.
#   4. Archives the Release configuration with the Team ID and build number passed on the
#      command line (project.yml is not edited), automatic signing.
#   5. Exports for App Store Connect; with SGGS_UPLOAD=1 the export *is* the upload.
#   6. Proves what was built: the Info.plist version/build and the manifest INSIDE the .app.
#
# Usage (macOS with Xcode ≥ 16, XcodeGen, python3, git-lfs; run from anywhere):
#   SGGS_TEAM_ID=ABCDE12345 SGGS_BUILD_NUMBER=4 ios/tools/testflight_archive.sh
#   SGGS_TEAM_ID=… SGGS_BUILD_NUMBER=5 SGGS_UPLOAD=1 ios/tools/testflight_archive.sh
#
# Environment:
#   SGGS_TEAM_ID        (required) Apple Developer Team ID.
#   SGGS_BUILD_NUMBER   (required) CFBundleVersion for this upload. Must be > every build already
#                       uploaded for this MARKETING_VERSION (App Store Connect rejects reuse).
#   SGGS_DB_PROFILE     public (default) | personal. `personal` bundles the English layer and is
#                       accepted only with LICENSED: true in ios/Resources/TRANSLATION-LICENSE.md.
#   SGGS_RELEASE_CHANNEL testflight (default) | appstore. A TestFlight binary and an App Store binary are
#                       the same upload, so the channel is declared up front: `appstore` makes
#                       pipeline/check_release_license.sh REQUIRE the scholar review of the Nitnem
#                       non-SGGS text (ios/Resources/NITNEM-REVIEW.md → REVIEWED: true) and requires
#                       the in-app "under review" label to be off. Only a build recorded with
#                       channel=appstore may be submitted (make appstore-preflight checks the ledger).
#   SGGS_UPLOAD         1 → export destination "upload" (straight to App Store Connect).
#                       0 (default) → write an .ipa under ios/App/build/ for Transporter.
#   SGGS_ASC_KEY_PATH / SGGS_ASC_KEY_ID / SGGS_ASC_ISSUER_ID
#                       App Store Connect API key (all three, or none). Needed for CI / an
#                       unattended upload; a logged-in Xcode account suffices locally.
#   SGGS_SKIP_CI_CHECK  1 → with SGGS_UPLOAD=1, skip waiting for green CI on the commit (offline /
#                       pipeline-outage use only; the candidate record notes it).
#   SGGS_ARCHIVE_DRY_RUN 1 → stop after step 3 (stage + gate + generate); nothing is signed,
#                       archived or uploaded. Used by webapp/tests/test_ios_archive.py.
#
# Tracked files this script may touch: only — and only with SGGS_UPLOAD=1 — the append-only
# ios/testflight-builds.json ledger, which you then commit with the release. It runs no git
# command that changes the working tree. Everything else it writes is git-ignored and lives under
# ios/App/build/ (staging, archive, export, lock) or is the temporary ios/App/SGGS-TestFlight.yml
# + SGGS-TestFlight.xcodeproj. NEVER commit ios/App/build/ or ios/Resources/*.sqlite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$1"; }
fail() { printf '\n\033[1;31mFAIL: %s\033[0m\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "this must run on macOS with Xcode (uname: $(uname -s))"
command -v xcodebuild >/dev/null || fail "xcodebuild not found (install Xcode, run xcode-select)"
command -v xcodegen  >/dev/null || fail "xcodegen not found (brew install xcodegen)"
command -v python3   >/dev/null || fail "python3 not found"

TEAM_ID="${SGGS_TEAM_ID:-}";        [ -n "$TEAM_ID" ] || fail "SGGS_TEAM_ID is required"
BUILD="${SGGS_BUILD_NUMBER:-}";     [ -n "$BUILD" ]   || fail "SGGS_BUILD_NUMBER is required"
[[ "$BUILD" =~ ^[0-9]+$ ]]                             || fail "SGGS_BUILD_NUMBER must be an integer"
PROFILE="${SGGS_DB_PROFILE:-public}"
case "$PROFILE" in public|personal) ;; *) fail "SGGS_DB_PROFILE must be public or personal" ;; esac
UPLOAD="${SGGS_UPLOAD:-0}"
CHANNEL="${SGGS_RELEASE_CHANNEL:-testflight}"
case "$CHANNEL" in testflight|appstore) ;; *) fail "SGGS_RELEASE_CHANNEL must be testflight or appstore" ;; esac
export SGGS_RELEASE_CHANNEL="$CHANNEL"          # read by pipeline/check_release_license.sh (step 2)
# Apple rejects uploads built with an older SDK (Xcode 26 / iOS 26 SDK required since 2026-04-28).
# One constant: raise it when developer.apple.com/news/upcoming-requirements raises the floor.
MIN_XCODE_MAJOR=26

KEY_PATH="${SGGS_ASC_KEY_PATH:-}"; KEY_ID="${SGGS_ASC_KEY_ID:-}"; ISSUER="${SGGS_ASC_ISSUER_ID:-}"
AUTH_ARGS=()
if [ -n "$KEY_PATH$KEY_ID$ISSUER" ]; then
  [ -n "$KEY_PATH" ] && [ -n "$KEY_ID" ] && [ -n "$ISSUER" ] \
    || fail "set all of SGGS_ASC_KEY_PATH, SGGS_ASC_KEY_ID, SGGS_ASC_ISSUER_ID (or none)"
  [ -f "$KEY_PATH" ] || fail "API key file not found: $KEY_PATH"
  KEY_PATH="$(cd "$(dirname "$KEY_PATH")" && pwd)/$(basename "$KEY_PATH")"
  AUTH_ARGS=(-authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER")
fi

PROJECT_DIR="ios/App"
BUILD_DIR="$PROJECT_DIR/build"
DRY_RUN="${SGGS_ARCHIVE_DRY_RUN:-0}"
VERSION=$(python3 -c "import re;print(re.search(r'MARKETING_VERSION:\s*\"([^\"]+)\"',open('$PROJECT_DIR/project.yml').read()).group(1))")
ARCHIVE="$BUILD_DIR/SGGS-$VERSION-$BUILD.xcarchive"
EXPORT_DIR="$BUILD_DIR/export-$VERSION-$BUILD"
OPTIONS="$BUILD_DIR/ExportOptions-$VERSION-$BUILD.plist"
# The artifact that ships is staged here — never in ios/Resources (the developer's own pair).
STAGE_REL="build/stage-$VERSION-$BUILD"          # relative to $PROJECT_DIR, as the spec needs it
STAGE="$PROJECT_DIR/$STAGE_REL"
DB="$STAGE/sggs-ios.sqlite"
MANIFEST="$STAGE/sggs-ios.manifest.json"
TF_NAME="SGGS-TestFlight"
TF_SPEC="$PROJECT_DIR/$TF_NAME.yml"
LOCK="$BUILD_DIR/.archive.lock"

say "SGGS candidate — version $VERSION build $BUILD · channel $CHANNEL · profile $PROFILE · team $TEAM_ID"

say "0/6 preflight"
head -c 16 db/sggs.sqlite | grep -q "SQLite format 3" || fail "db/sggs.sqlite is an LFS pointer — run: git lfs pull"
DIRTY="$(git status --porcelain -- ios/App/Sources ios/App/Shared ios/App/Widgets ios/App/project.yml ios/App/Resources ios/Packages pipeline)"
if [ -n "$DIRTY" ]; then
  # What is uploaded must be reproducible from a commit: an upload from a dirty tree is refused.
  [ "$UPLOAD" = 1 ] && fail "uncommitted changes in shipping sources — an upload must come from a committed SHA:
$DIRTY"
  echo "  WARNING: uncommitted iOS source changes — an upload from this tree would be refused"
fi
XCODE_VERSION="$(xcodebuild -version | awk 'NR==1{print $2}')"
[ "${XCODE_VERSION%%.*}" -ge "$MIN_XCODE_MAJOR" ] 2>/dev/null \
  || fail "Xcode $XCODE_VERSION is too old — App Store Connect requires Xcode $MIN_XCODE_MAJOR+ (select it with xcode-select)"
echo "  Xcode $XCODE_VERSION"
if [ "$UPLOAD" = 1 ]; then
  # The commit must be on the trunk or the production branch — never a local-only or feature SHA.
  git fetch -q origin integration main 2>/dev/null || echo "  (could not fetch origin; using local remote-tracking refs)"
  if ! git merge-base --is-ancestor HEAD origin/integration 2>/dev/null && ! git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
    fail "HEAD $(git rev-parse --short HEAD) is not on origin/integration or origin/main — merge it first, then build from that commit"
  fi
  # One-number policy: an App Store binary is the released commit — HEAD must be on main and carry the
  # exact tag v$VERSION, so the ledger's source_commit is always what web+API serve. TestFlight
  # rehearsals from integration set SGGS_ALLOW_UNTAGGED=1 to skip this (they are not App Store builds).
  if [ "$CHANNEL" = appstore ] && [ "${SGGS_ALLOW_UNTAGGED:-0}" != 1 ]; then
    git merge-base --is-ancestor HEAD origin/main 2>/dev/null \
      || fail "channel=appstore upload must build from origin/main — HEAD $(git rev-parse --short HEAD) is not on main (or set SGGS_ALLOW_UNTAGGED=1 for a TestFlight rehearsal)"
    EXACT_TAG="$(git describe --exact-match --tags HEAD 2>/dev/null || true)"
    [ "$EXACT_TAG" = "v$VERSION" ] \
      || fail "channel=appstore upload must build from the release tag v$VERSION — HEAD is tagged '${EXACT_TAG:-<none>}'. Tag the release first (sggs-release), then build from it (or SGGS_ALLOW_UNTAGGED=1 to rehearse)."
  fi
  if [ "${SGGS_SKIP_CI_CHECK:-0}" = 1 ]; then
    echo "  WARNING: SGGS_SKIP_CI_CHECK=1 — not waiting for green CI on this commit"
  else
    command -v gh >/dev/null || fail "gh not found — needed to confirm CI is green on this commit (or set SGGS_SKIP_CI_CHECK=1 in a pipeline outage)"
    # wait_for_checks reads --repo or $GITHUB_REPOSITORY; a local `make testflight` run has neither,
    # so default it from the git remote (CI sets GITHUB_REPOSITORY itself).
    if [ -z "${GITHUB_REPOSITORY:-}" ]; then
      GITHUB_REPOSITORY="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
      export GITHUB_REPOSITORY
    fi
    python3 scripts/ci/wait_for_checks.py "$(git rev-parse HEAD)" --extra parity app --timeout 60 \
      || fail "required checks (incl. the iOS parity + app jobs) are not green on $(git rev-parse --short HEAD)"
  fi
fi
echo "  source commit: $(git rev-parse --short HEAD) ($(git branch --show-current))"
mkdir -p "$BUILD_DIR"

say "0b/6 version + build-number gates (before any work)"
python3 scripts/release/check_versions.py >/dev/null \
  || fail "version strings are not unified — run scripts/release/bump.py, or fix the mismatch (scripts/release/check_versions.py shows it)"
LEDGER_STRICT=(); [ "$UPLOAD" = 1 ] && LEDGER_STRICT=(--strict)
python3 ios/tools/testflight_ledger.py check "$VERSION" "$BUILD" ${LEDGER_STRICT[@]+"${LEDGER_STRICT[@]}"} \
  || fail "build number $BUILD is not valid for $VERSION (see above; run: python3 ios/tools/testflight_ledger.py next $VERSION)"

# One archive at a time per checkout (mkdir is atomic). A lock whose PID is dead is reclaimed.
if ! mkdir "$LOCK" 2>/dev/null; then
  HOLDER=$(cat "$LOCK/pid" 2>/dev/null || true)
  if [ -n "$HOLDER" ] && kill -0 "$HOLDER" 2>/dev/null; then
    fail "another archive is running in this checkout (pid $HOLDER, lock $LOCK)"
  fi
  echo "  reclaiming stale lock (pid ${HOLDER:-unknown} is gone)"
  rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null || true
  mkdir "$LOCK" || fail "could not take the archive lock: $LOCK"
fi
echo $$ > "$LOCK/pid"

# Remove only what this run created, by explicit path. No git command, no glob.
cleanup() {
  rm -f "$DB" "$DB.tmp" "$MANIFEST.tmp" "$TF_SPEC"
  rm -rf "$PROJECT_DIR/$TF_NAME.xcodeproj"
  rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

say "1/6 derive the $PROFILE iOS DB into staging (scripture checksum proven by build_ios_db.py)"
mkdir -p "$STAGE"
python3 pipeline/build_ios_db.py --profile "$PROFILE" db/sggs.sqlite "$DB"

say "2/6 release gate on the artifact that will ship"
bash pipeline/check_release_license.sh "$MANIFEST" "$DB"
if [ "$CHANNEL" = appstore ]; then
  # The gate above proved the attestation; the binary must agree with it, or the App Store build
  # would still say "Under scholarly review" to the reviewer and to every reader.
  grep -qE '^[[:space:]]*static let extraTextReviewed = true[[:space:]]*$' ios/App/Sources/Data/NitnemSchedule.swift \
    || fail "channel=appstore but NitnemReview.extraTextReviewed is not true (ios/App/Sources/Data/NitnemSchedule.swift) — flip it in the commit that signs NITNEM-REVIEW.md"
fi
BUNDLED_SHA=$(python3 -c "import json;print(json.load(open('$MANIFEST'))['db_sha256'])")
EN=$(python3 -c "import json;print(json.load(open('$MANIFEST'))['en_bundled'])")
echo "  bundling profile=$PROFILE en_bundled=$EN db_sha256=${BUNDLED_SHA:0:16}…"

say "3/6 generate $TF_NAME.xcodeproj (project.yml with the DB resources pointed at staging)"
sed -e "s|^name: SGGS\$|name: $TF_NAME|" \
    -e "s|path: \.\./Resources/sggs-ios\.sqlite\$|path: $STAGE_REL/sggs-ios.sqlite|" \
    -e "s|path: \.\./Resources/sggs-ios\.manifest\.json\$|path: $STAGE_REL/sggs-ios.manifest.json|" \
    "$PROJECT_DIR/project.yml" > "$TF_SPEC"
CHANGED=$(diff "$PROJECT_DIR/project.yml" "$TF_SPEC" | grep -c '^>' || true)
[ "$CHANGED" = 3 ] || fail "expected exactly 3 rewritten lines in $TF_SPEC, got $CHANGED — project.yml's name/DB resource lines changed shape; update the sed above"
if grep -q 'Resources/sggs-ios' "$TF_SPEC"; then fail "$TF_SPEC still bundles the developer DB pair"; fi
xcodegen generate --spec "$TF_SPEC" --project "$PROJECT_DIR" --quiet
# pbxproj stores the staging dir as a group path and the file by basename — check both, and that
# nothing in the generated project points back at ios/Resources.
PBX="$PROJECT_DIR/$TF_NAME.xcodeproj/project.pbxproj"
grep -q "stage-$VERSION-$BUILD" "$PBX" && grep -q "sggs-ios.sqlite in Resources" "$PBX" \
  || fail "generated project does not bundle the staged DB"
if grep -q '\.\./Resources' "$PBX"; then fail "generated project still references ../Resources"; fi

if [ "$DRY_RUN" = 1 ]; then
  echo
  echo "OK  DRY RUN — staged + gated + generated; nothing archived, signed or uploaded."
  echo "    staged: channel=$CHANNEL profile=$PROFILE db_sha256=${BUNDLED_SHA:0:16}…"
  exit 0
fi

say "4/6 archive (Release, automatic signing)"
rm -rf "$ARCHIVE"
xcodebuild -project "$PROJECT_DIR/$TF_NAME.xcodeproj" -scheme SGGS -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$BUILD" CODE_SIGNING_ALLOWED=YES \
  -allowProvisioningUpdates ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} | tail -30
[ -d "$ARCHIVE" ] || fail "archive was not produced"

say "5/6 export for App Store Connect (destination: $([ "$UPLOAD" = 1 ] && echo upload || echo export))"
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$([ "$UPLOAD" = 1 ] && echo upload || echo export)</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
  -exportPath "$EXPORT_DIR" -allowProvisioningUpdates ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} | tail -20

say "6/6 prove what was built"
APP="$ARCHIVE/Products/Applications/SGGS.app"
[ -d "$APP" ] || fail "SGGS.app missing from the archive"
GOT_V=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Info.plist")
GOT_B=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Info.plist")
[ "$GOT_V" = "$VERSION" ] && [ "$GOT_B" = "$BUILD" ] || fail "archived app is $GOT_V ($GOT_B), expected $VERSION ($BUILD)"
WIDGET_PLIST=$(find "$APP/PlugIns" -name Info.plist -path '*SGGSWidgets*' | head -1)
[ -n "$WIDGET_PLIST" ] || fail "widget extension missing from the archive"
W_V=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$WIDGET_PLIST")
W_B=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$WIDGET_PLIST")
[ "$W_V" = "$VERSION" ] && [ "$W_B" = "$BUILD" ] || fail "widget is $W_V ($W_B) — must match the app (App Store validation rejects a mismatch)"
SHIPPED_SHA=$(python3 -c "import json;print(json.load(open('$APP/sggs-ios.manifest.json'))['db_sha256'])")
SHIPPED_PROFILE=$(python3 -c "import json;print(json.load(open('$APP/sggs-ios.manifest.json'))['profile'])")
[ "$SHIPPED_SHA" = "$BUNDLED_SHA" ] || fail "manifest inside the .app ($SHIPPED_SHA) != gated artifact ($BUNDLED_SHA)"
[ "$SHIPPED_PROFILE" = "$PROFILE" ] || fail "profile inside the .app is $SHIPPED_PROFILE, expected $PROFILE"
ACTUAL_SHA=$(shasum -a 256 "$APP/sggs-ios.sqlite" | cut -d' ' -f1)
[ "$ACTUAL_SHA" = "$SHIPPED_SHA" ] || fail "DB inside the .app does not hash to its manifest"
# The SDK the binary was actually built with (what App Store Connect validates), not what we hoped.
DT_XCODE=$(/usr/libexec/PlistBuddy -c 'Print DTXcode' "$APP/Info.plist")
DT_SDK=$(/usr/libexec/PlistBuddy -c 'Print DTSDKName' "$APP/Info.plist")
SDK_MAJOR=$(printf '%s' "$DT_SDK" | sed -E 's/^[a-z]+([0-9]+).*/\1/')
[ "$SDK_MAJOR" -ge "$MIN_XCODE_MAJOR" ] 2>/dev/null || fail "archived app was built with SDK $DT_SDK — App Store Connect requires the iOS $MIN_XCODE_MAJOR SDK or later"
# dSYM UUIDs: what a MetricKit / Organizer crash report must match to be symbolicated later.
DSYM_UUIDS=$(find "$ARCHIVE/dSYMs" -name '*.dSYM' -maxdepth 1 -exec dwarfdump --uuid {} \; 2>/dev/null | awk '{print $2":"$NF}' | paste -sd, -)
APP_MB=$(du -sm "$APP" | cut -f1)
echo "  built with Xcode build $DT_XCODE · SDK $DT_SDK · .app ${APP_MB} MB"

cat > "$BUILD_DIR/candidate-$VERSION-$BUILD.json" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "profile": "$PROFILE",
  "channel": "$CHANNEL",
  "en_bundled": "$EN",
  "db_sha256": "$SHIPPED_SHA",
  "source_commit": "$(git rev-parse HEAD)",
  "xcode": "$XCODE_VERSION",
  "sdk": "$DT_SDK",
  "app_mb": $APP_MB,
  "dsym_uuids": "$DSYM_UUIDS",
  "ci_check_skipped": $([ "${SGGS_SKIP_CI_CHECK:-0}" = 1 ] && echo true || echo false),
  "archive": "$ARCHIVE",
  "uploaded": $([ "$UPLOAD" = 1 ] && echo true || echo false)
}
JSON

if [ "$UPLOAD" = 1 ]; then
  python3 ios/tools/testflight_ledger.py record "$BUILD_DIR/candidate-$VERSION-$BUILD.json" \
    || fail "uploaded to App Store Connect but could NOT record the build in ios/testflight-builds.json — add it by hand before the next upload"
  echo "    ledger: recorded in ios/testflight-builds.json — commit it with the release."
else
  echo "    ledger: NOT recorded (no upload). After a Transporter upload, run:"
  echo "            python3 ios/tools/testflight_ledger.py record $BUILD_DIR/candidate-$VERSION-$BUILD.json --force"
fi

echo
echo "OK  SGGS $VERSION ($BUILD) · channel $CHANNEL · profile $PROFILE · db_sha256 ${SHIPPED_SHA:0:16}… · commit $(git rev-parse --short HEAD)"
echo "    archive: $ARCHIVE"
if [ "$UPLOAD" = 1 ]; then
  echo "    uploaded to App Store Connect — it appears under TestFlight after processing (10–30 min)."
else
  echo "    ipa: $(find "$EXPORT_DIR" -name '*.ipa' | head -1)  (upload with Transporter, or rerun with SGGS_UPLOAD=1)"
fi
echo "    record: $BUILD_DIR/candidate-$VERSION-$BUILD.json  (paste into the TestFlight build log)"
echo "    NEVER commit ios/App/build/ or ios/Resources/*.sqlite."
