#!/usr/bin/env node
// gen-pahar-vectors.mjs — emit contract/golden_pahar.ndjson from the REAL pahar.js.
//
// Converts the in-file assertions of test-pahar.mjs (47-case gate) into a
// cross-language contract the Swift port (GurbaniSearchKit/Pahar.swift) asserts
// against exactly, plus exhaustive sweeps the hand-written gate samples:
//   - fixed:        pahar for EVERY minute 0..1439 (total function, no gaps)
//   - window/label/range/fmt12: all 8 pahars + formatting edges
//   - suntimes:     NOAA sunrise/sunset for pinned (date, lat, lon, tz) tuples
//   - solar:        pahar sweep + all 8 windows for pinned sunrise/sunset pairs
//   - boundary:     nextPaharBoundary fixed + solar samples
//
// MUST run with TZ=UTC (enforced below): sunTimes() derives day-of-year from a
// local-midnight Date subtraction, which wobbles ±1 on machines whose local TZ
// has a DST jump between Jan 1 and the date. Generating under UTC pins doy to
// the exact calendar ordinal — which is what the Swift port computes.
//
// Usage:  TZ=UTC node frontend/scripts/gen-pahar-vectors.mjs
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  paharFromMinutes, paharWindow, paharLabel, paharRange, fmt12,
  sunTimes, paharSolar, paharSolarWindow, nextPaharBoundary,
} from '../src/scripts/pahar.js';

if (new Date(2026, 0, 1).getTimezoneOffset() !== 0 || new Date(2026, 6, 1).getTimezoneOffset() !== 0) {
  console.error('ERROR: run with TZ=UTC (e.g. `TZ=UTC node frontend/scripts/gen-pahar-vectors.mjs`)');
  process.exit(1);
}

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'contract', 'golden_pahar.ndjson');
const rows = [];

// — fixed clock: total over the whole day (property: every minute has exactly one pahar) —
for (let m = 0; m < 1440; m++) rows.push({ kind: 'fixed', m, pahar: paharFromMinutes(m) });
// negative/overflow wrap probes (the JS modulo-wrap is part of the contract)
for (const m of [-1, -360, 1440, 1441, 2880, 10000]) {
  rows.push({ kind: 'fixed', m, pahar: paharFromMinutes(m) });
}

// — windows / labels / ranges —
for (let p = 1; p <= 8; p++) {
  const w = paharWindow(p);
  rows.push({ kind: 'window', p, start: w.start, end: w.end });
  rows.push({ kind: 'label', p, label: paharLabel(p) });
  rows.push({ kind: 'range', p, range: paharRange(p) });
}
for (const s of ['15:00', '00:30', '00:00', '12:00', '12:30', '23:59', '06:00', '9:05', '']) {
  rows.push({ kind: 'fmt12', in: s, out: fmt12(s) });
}

// — NOAA sunTimes: pinned tuples (tz follows getTimezoneOffset convention: UTC+5:30 -> -330) —
const SUN = [
  // Amritsar (31.63N 74.87E, IST): equinoxes + solstices + ordinary days
  [2026, 2, 20, 31.63, 74.87, -330], [2026, 8, 23, 31.63, 74.87, -330],
  [2026, 5, 21, 31.63, 74.87, -330], [2026, 11, 21, 31.63, 74.87, -330],
  [2026, 0, 1, 31.63, 74.87, -330], [2026, 6, 11, 31.63, 74.87, -330],
  // London across its DST dates (wall-clock offsets differ by season)
  [2026, 2, 28, 51.5, -0.13, 0], [2026, 2, 30, 51.5, -0.13, -60],
  [2026, 9, 24, 51.5, -0.13, -60], [2026, 9, 26, 51.5, -0.13, 0],
  // Southern hemisphere (Sydney): seasons inverted
  [2026, 5, 21, -33.87, 151.21, -600], [2026, 11, 21, -33.87, 151.21, -660],
  // Equator (Quito): near-constant 12h day
  [2026, 2, 20, -0.18, -78.47, 300], [2026, 5, 21, -0.18, -78.47, 300],
  // Polar guard: Longyearbyen never-sets / never-rises
  [2026, 5, 21, 78.22, 15.65, -120], [2026, 11, 21, 78.22, 15.65, -60],
];
const sunPairs = [];
for (const [y, mo, d, lat, lon, tz] of SUN) {
  const s = sunTimes(new Date(y, mo, d), lat, lon, tz);
  rows.push({ kind: 'suntimes', y, mo: mo + 1, d, lat, lon, tz,
              sunrise: s.sunrise, sunset: s.sunset, polar: s.polar });
  if (!s.polar) sunPairs.push([s.sunrise, s.sunset]);
}

// — solar pahars: sweep + windows for three representative day lengths —
// (June-solstice Amritsar = long day; December = short day; equinox ≈ equal.)
const solarPairs = [sunPairs[2], sunPairs[3], sunPairs[0]];
for (const [sr, ss] of solarPairs) {
  for (let m = 0; m < 1440; m += 7) {
    rows.push({ kind: 'solar', m, sunrise: sr, sunset: ss, pahar: paharSolar(m, sr, ss) });
  }
  // exact edges: sunrise/sunset themselves and the minute before each
  for (const m of [sr, (sr - 1 + 1440) % 1440, ss % 1440, (ss - 1 + 1440) % 1440]) {
    rows.push({ kind: 'solar', m, sunrise: sr, sunset: ss, pahar: paharSolar(m, sr, ss) });
  }
  for (let p = 1; p <= 8; p++) {
    const w = paharSolarWindow(p, sr, ss);
    rows.push({ kind: 'solar_window', p, sunrise: sr, sunset: ss, start: w.start, end: w.end });
  }
}

// — next-boundary countdown —
for (const m of [0, 179, 180, 300, 359, 360, 539, 540, 719, 720, 1079, 1080, 1439]) {
  const r = nextPaharBoundary(m, 'fixed');
  rows.push({ kind: 'boundary', mode: 'fixed', m, nextPahar: r.nextPahar, minutes: r.minutes });
}
for (const [sr, ss] of solarPairs) {
  for (const m of [sr, sr + 1, ss - 1, ss % 1440, (ss + 40) % 1440, 0, 1439]) {
    const r = nextPaharBoundary(m, 'solar', sr, ss);
    rows.push({ kind: 'boundary', mode: 'solar', m, sunrise: sr, sunset: ss,
                nextPahar: r.nextPahar, minutes: r.minutes });
  }
}

// stable serialization: sorted keys, one record per line (repo ndjson convention)
const sorted = rows.map((r) => JSON.stringify(Object.fromEntries(Object.entries(r).sort())));
writeFileSync(OUT, sorted.join('\n') + '\n');
console.log(`golden_pahar vectors: ${rows.length} -> ${OUT}`);
