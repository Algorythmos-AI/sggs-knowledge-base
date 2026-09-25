// <!-- sggs:swatches --> renders docs/brand/tokens.json — the palette's source of truth — at build:
// every role with its light and dark value, a swatch, and its WCAG contrast against the paper it
// sits on (text roles) or of the ink on it (surfaces). Computed from the file, never typed, so the
// page cannot drift from the tokens. No JavaScript.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT } from './paths.mjs';
import { contrast } from './brand.mjs';

export { luminance, contrast } from './brand.mjs';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
const INK = ['#201A12', '#F3ECDD'];   // the wiki's ink, light and dark (plugins/brand.mjs)

const GROUPS = [
  ['surfaces', 'Surfaces', 'ink on it'],
  ['soul', 'Soul Gold', 'on paper'],
  ['brand', 'Brand', 'on paper'],
  ['status', 'Status', 'on paper'],
];

export function swatchesHtml(tokens) {
  const paper = tokens.surfaces.paper;
  // a label colour ("onAccent", "onRed") is measured on the fill it labels, not on paper
  const ON = { onAccent: ['soul', 'accentFill'], onRed: ['brand', 'red'] };
  const cell = (name, hex, i, surface) => {
    const on = ON[name];
    const ratio = surface ? contrast(INK[i], hex) : contrast(hex, on ? tokens[on[0]][on[1]][i] : paper[i]);
    const against = on ? ` on ${on[1]}` : '';
    return `<td><span class="swatch" style="background:${esc(hex)}" aria-hidden="true"></span><code>${esc(hex)}</code> <span class="swatch__ratio">${ratio.toFixed(2)}:1${esc(against)}</span></td>`;
  };
  return `<div class="swatches">${GROUPS.map(([key, label, against]) => {
    const rows = Object.entries(tokens[key] ?? {}).map(([name, legs]) =>
      `<tr><th scope="row"><code>${esc(key)}.${esc(name)}</code></th>${cell(name, legs[0], 0, key === 'surfaces')}${cell(name, legs[1], 1, key === 'surfaces')}</tr>`).join('');
    return `<table class="swatches__group"><caption>${esc(label)} <span class="swatch__ratio">— contrast ${esc(against)}</span></caption>` +
      `<thead><tr><th scope="col">Token</th><th scope="col">Light</th><th scope="col">Dark</th></tr></thead><tbody>${rows}</tbody></table>`;
  }).join('')}</div>`;
}

export function remarkSwatches(options = {}) {
  const file = options.file ?? path.join(REPO_ROOT, 'docs', 'brand', 'tokens.json');
  return (tree) => {
    visit(tree, 'html', (node) => {
      if (!/^<sggs-swatches\b[^>]*>\s*<\/sggs-swatches>$/.test(node.value.trim())) return;
      node.value = swatchesHtml(JSON.parse(readFileSync(file, 'utf8')));
    });
  };
}
