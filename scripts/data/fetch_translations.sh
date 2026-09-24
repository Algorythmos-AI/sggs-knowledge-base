#!/usr/bin/env bash
# fetch_translations.sh [TAG] — restore the English translation sources (the pipeline inputs
# pipeline/translations/*.jsonl + pipeline/translations_en_raw_sample.jsonl) from the PRIVATE
# Algorythmos-AI/sggs-source release. They are not redistributable (see NOTICE.md), so they are
# not tracked here. Every file is verified against the committed pipeline/translations.SHA256SUMS
# before anything is written into pipeline/; a mismatch changes nothing. Needs `gh` with access.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
TAG="${1:-translations-en-v1}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
gh release download "$TAG" --repo Algorythmos-AI/sggs-source --dir "$TMP" \
  --pattern 'translations-en-v1.tar.gz' --pattern 'translations-en.SHA256SUMS'
(cd "$TMP" && grep 'tar.gz$' translations-en.SHA256SUMS | shasum -a 256 -c -)
mkdir -p "$TMP/x"
tar -xzf "$TMP/translations-en-v1.tar.gz" -C "$TMP/x"
(cd "$TMP/x" && shasum -a 256 -c "$OLDPWD/pipeline/translations.SHA256SUMS" >/dev/null) \
  || { echo "fetched files do not match pipeline/translations.SHA256SUMS — nothing written" >&2; exit 1; }
mkdir -p pipeline/translations
cp "$TMP"/x/pipeline/translations/*.jsonl pipeline/translations/
cp "$TMP/x/pipeline/translations_en_raw_sample.jsonl" pipeline/
shasum -a 256 -c pipeline/translations.SHA256SUMS >/dev/null
echo "translations restored and verified ($(wc -l < pipeline/translations.SHA256SUMS | tr -d ' ') files, $TAG)"
