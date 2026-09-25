// The brand palette the wiki draws with, read from the source of truth (docs/brand/tokens.json).
// Legs: 0 light, 1 dark. Gold (accentFill) is fill-only and never text; red is never used here.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { REPO_ROOT } from './paths.mjs';

const T = JSON.parse(readFileSync(path.join(REPO_ROOT, 'docs/brand/tokens.json'), 'utf8'));
const leg = (group, name, i) => T[group][name][i];

export const BRAND = {
  ink: '#201A12',
  paper: leg('surfaces', 'paper', 0),
  paperWarm: leg('surfaces', 'paperWarm', 0),
  canvas: leg('surfaces', 'canvas', 0),
  card: leg('surfaces', 'card', 0),
  accentFill: leg('soul', 'accentFill', 0),
  accent: leg('soul', 'accent', 0),
  accentText: leg('soul', 'accentText', 0),
  onAccent: leg('soul', 'onAccent', 0),
  maroon: leg('brand', 'maroon', 0),
  kraft: leg('brand', 'kraft', 0),
  positive: leg('status', 'positive', 0),
  negative: leg('status', 'negative', 0),
  info: leg('status', 'info', 0),
  special: leg('status', 'special', 0),
};

export const BRAND_DARK = {
  ink: '#F3ECDD',
  paper: leg('surfaces', 'paper', 1),
  paperWarm: leg('surfaces', 'paperWarm', 1),
  canvas: leg('surfaces', 'canvas', 1),
  card: leg('surfaces', 'card', 1),
  accentFill: leg('soul', 'accentFill', 1),
  accent: leg('soul', 'accent', 1),
  accentText: leg('soul', 'accentText', 1),
  onAccent: leg('soul', 'onAccent', 1),
  maroon: leg('brand', 'maroon', 1),
  kraft: leg('brand', 'kraft', 1),
  positive: leg('status', 'positive', 1),
  negative: leg('status', 'negative', 1),
  info: leg('status', 'info', 1),
  special: leg('status', 'special', 1),
};

/** Every hex value a Mermaid fence or a poster may use (both legs, plus white and the two inks). */
export const ALLOWED_HEX = new Set(
  [...Object.values(BRAND), ...Object.values(BRAND_DARK), '#FFFFFF'].map((h) => h.toUpperCase()),
);

/** WCAG relative luminance and contrast ratio of two #RRGGBB colours. */
export function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
export function contrast(a, b) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}
