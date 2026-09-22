#!/usr/bin/env bash
# subset-serif.sh — regenerate frontend/public/fonts/SourceSerif4-latin.woff2
#
# Documentation + reproducible recipe for the Latin subset of Source Serif 4 used by the
# Gurbani Soul marketing site (Brand.heading / navigation + hero lines; see marketing.css).
# Source: ios/App/Resources/SourceSerif4.ttf (variable, SIL OFL 1.1 —
# ios/App/Resources/OFL-SourceSerif4.txt, copied to frontend/public/fonts/OFL-SourceSerif4.txt).
#
# Nothing is installed system-wide: fonttools + brotli run in a throwaway uvx environment.
# Result must stay <= 130 KB (currently ~29 KB).
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

# 1) Pin the variable axes to the weights/optical size the site uses.
uvx --from fonttools --with brotli fonttools varLib.instancer \
  ios/App/Resources/SourceSerif4.ttf wght=400:700 opsz=40 -o /tmp/ss4.ttf

# 2) Subset to the Latin glyphs the marketing copy needs and flavour as woff2.
uvx --from fonttools --with brotli pyftsubset /tmp/ss4.ttf \
  --unicodes="U+0020-007E,U+00A0-00FF,U+0152-0153,U+2010-2015,U+2018-201D,U+2022,U+2026,U+2039-203A,U+00B7" \
  --layout-features="kern,liga" \
  --flavor=woff2 --no-hinting \
  --output-file=frontend/public/fonts/SourceSerif4-latin.woff2

# 3) Ship the licence alongside the font.
cp ios/App/Resources/OFL-SourceSerif4.txt frontend/public/fonts/OFL-SourceSerif4.txt

wc -c frontend/public/fonts/SourceSerif4-latin.woff2
