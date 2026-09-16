#!/usr/bin/env bash
# testflight_archive.sh — build the TestFlight / App Store candidate the *only* sanctioned way.
#
# What it does, in order (every step is a gate; the script stops on the first failure):
#   1. Derives the iOS DB for the chosen PROFILE from db/sggs.sqlite (scripture checksum proven
#      by pipeline/build_ios_db.py) into the path the app bundles (ios/Resources/sggs-ios.sqlite).
#   2. Runs pipeline/check_release_license.sh on THAT artifact — a public build must be
#      Gurmukhi-only, or the English translation must be attested LICENSED: true.
#   3. Regenerates SGGS.xcodeproj with XcodeGen (the project is never committed).
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
#   SGGS_UPLOAD         1 → export destination "upload" (straight to App Store Connect).
#                       0 (default) → write an .ipa under ios/App/build/ for Transporter.
#   SGGS_ASC_KEY_PATH / SGGS_ASC_KEY_ID / SGGS_ASC_ISSUER_ID
#                       App Store Connect API key (all three, or none). Needed for CI / an
#                       unattended upload; a logged-in Xcode account suffices locally.
#
# The only tracked file this script touches is ios/Resources/sggs-ios.manifest.json, which
# build_ios_db.py rewrites next to the DB; it is restored from git on exit so the committed
# (personal-profile) manifest is never accidentally replaced. NEVER commit the artifacts.
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
RES_DIR="ios/Resources"
DB="$RES_DIR/sggs-ios.sqlite"
MANIFEST="$RES_DIR/sggs-ios.manifest.json"
VERSION=$(python3 -c "import re;print(re.search(r'MARKETING_VERSION:\s*\"([^\"]+)\"',open('$PROJECT_DIR/project.yml').read()).group(1))")
ARCHIVE="$BUILD_DIR/SGGS-$VERSION-$BUILD.xcarchive"
EXPORT_DIR="$BUILD_DIR/export-$VERSION-$BUILD"
OPTIONS="$BUILD_DIR/ExportOptions-$VERSION-$BUILD.plist"

say "SGGS TestFlight candidate — version $VERSION build $BUILD · profile $PROFILE · team $TEAM_ID"

say "0/6 preflight"
head -c 16 db/sggs.sqlite | grep -q "SQLite format 3" || fail "db/sggs.sqlite is an LFS pointer — run: git lfs pull"
if [ -n "$(git status --porcelain -- ios/App/Sources ios/App/Shared ios/App/Widgets ios/App/project.yml ios/Packages)" ]; then
  echo "  WARNING: uncommitted iOS source changes — a TestFlight build should come from a committed SHA"
fi
echo "  source commit: $(git rev-parse --short HEAD) ($(git branch --show-current))"
mkdir -p "$BUILD_DIR"

# Restore the committed manifest whatever happens after this point.
restore_manifest() { git checkout --quiet -- "$MANIFEST" 2>/dev/null || true; }
trap restore_manifest EXIT

say "1/6 derive the $PROFILE iOS DB (scripture checksum proven by build_ios_db.py)"
python3 pipeline/build_ios_db.py --profile "$PROFILE" db/sggs.sqlite "$DB"

say "2/6 release gate on the artifact that will ship"
bash pipeline/check_release_license.sh "$MANIFEST" "$DB"
BUNDLED_SHA=$(python3 -c "import json;print(json.load(open('$MANIFEST'))['db_sha256'])")
EN=$(python3 -c "import json;print(json.load(open('$MANIFEST'))['en_bundled'])")
echo "  bundling profile=$PROFILE en_bundled=$EN db_sha256=${BUNDLED_SHA:0:16}…"

say "3/6 generate SGGS.xcodeproj"
xcodegen generate --spec "$PROJECT_DIR/project.yml" --project "$PROJECT_DIR" --quiet

say "4/6 archive (Release, automatic signing)"
rm -rf "$ARCHIVE"
xcodebuild -project "$PROJECT_DIR/SGGS.xcodeproj" -scheme SGGS -configuration Release \
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

cat > "$BUILD_DIR/candidate-$VERSION-$BUILD.json" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "profile": "$PROFILE",
  "en_bundled": "$EN",
  "db_sha256": "$SHIPPED_SHA",
  "source_commit": "$(git rev-parse HEAD)",
  "archive": "$ARCHIVE",
  "uploaded": $([ "$UPLOAD" = 1 ] && echo true || echo false)
}
JSON

echo
echo "OK  SGGS $VERSION ($BUILD) · profile $PROFILE · db_sha256 ${SHIPPED_SHA:0:16}… · commit $(git rev-parse --short HEAD)"
echo "    archive: $ARCHIVE"
if [ "$UPLOAD" = 1 ]; then
  echo "    uploaded to App Store Connect — it appears under TestFlight after processing (10–30 min)."
else
  echo "    ipa: $(find "$EXPORT_DIR" -name '*.ipa' | head -1)  (upload with Transporter, or rerun with SGGS_UPLOAD=1)"
fi
echo "    record: $BUILD_DIR/candidate-$VERSION-$BUILD.json  (paste into the TestFlight build log)"
echo "    NEVER commit ios/App/build/ or ios/Resources/*.sqlite."
