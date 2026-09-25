// <!-- sggs:repo-map --> becomes an expandable map of the three repositories, rendered at build
// from docs/reference/repo-map.json (tools/gen_repo_map.py --check proves every platform path
// exists). Plain nested <details>: keyboard-friendly, no JavaScript. On GitHub the fallback
// sentence links to the JSON.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT } from './paths.mjs';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

function renderEntries(entries, base) {
  return `<ul>${entries.map((e) => {
    const name = esc(e.path);
    const why = e.purpose ? ` <span class="repo-map__why">— ${esc(e.purpose)}</span>` : '';
    const link = base ? `<a href="${esc(base + e.path)}"><code>${name}</code></a>` : `<code>${name}</code>`;
    // a <summary> is itself a control, so a folder's link goes inside it as the first item (no nested interactive content)
    if (e.children?.length) return `<li><details><summary><code>${name}</code>${why}</summary><ul><li><a href="${esc(base + e.path)}">open <code>${name}</code> on GitHub</a></li></ul>${renderEntries(e.children, base)}</details></li>`;
    return `<li>${link}${why}</li>`;
  }).join('')}</ul>`;
}

export function repoMapHtml(map) {
  return `<div class="repo-map">${map.repositories.map((r, i) => {
    const base = `https://github.com/${r.repository}/tree/${r.ref}/`;
    return `<details class="repo-map__repo"${i === 0 ? ' open' : ''}><summary>${esc(r.repository)} <span class="repo-map__why">— ${esc(r.purpose)}</span></summary><ul><li><a href="${esc(base)}">open ${esc(r.repository)} on GitHub</a></li></ul>${renderEntries(r.entries, base)}</details>`;
  }).join('')}</div>`;
}

export function remarkRepoMap(options = {}) {
  const file = options.file ?? path.join(REPO_ROOT, 'docs', 'reference', 'repo-map.json');
  return (tree) => {
    visit(tree, 'html', (node) => {
      if (!/^<sggs-repo-map\b[^>]*>\s*<\/sggs-repo-map>$/.test(node.value.trim())) return;
      node.value = repoMapHtml(JSON.parse(readFileSync(file, 'utf8')));
    });
  };
}
