// A poster written as a plain image — `![alt](../diagrams/posters/01-slug.svg)` — is a picture on
// GitHub and a walkthrough on the site: the SVG is inlined (ids scoped to the page), its steps
// sidecar is embedded as JSON for <sggs-walkthrough>, and a caption links to the raw file.
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT, repoRelOf } from './paths.mjs';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export function posterHtml(svgPath, alt) {
  const base = path.basename(svgPath, '.svg');
  let svg = readFileSync(svgPath, 'utf8');
  const sidecar = svgPath.replace(/\.svg$/, '.steps.json');
  const steps = existsSync(sidecar) ? JSON.parse(readFileSync(sidecar, 'utf8')) : [];
  // scope ids so two posters on one page never collide (the sidecar keeps the plain step ids)
  svg = svg.replace(/\bid="([^"]+)"/g, `id="${base}--$1"`)
    .replace(/url\(#([^)]+)\)/g, `url(#${base}--$1)`)
    .replace(/aria-labelledby="([^"]+)"/g, (m, v) => `aria-labelledby="${v.split(' ').map((x) => `${base}--${x}`).join(' ')}"`);
  return `<figure class="poster" data-poster="${base}"><sggs-walkthrough data-poster="${base}" data-steps="${steps.length}">` +
    `<div class="poster__canvas">${svg}</div>` +
    `<script type="application/json" class="poster__steps">${JSON.stringify(steps).replace(/</g, '\\u003c')}</script>` +
    `</sggs-walkthrough><figcaption>${esc(alt)} · <a href="/posters/${base}.svg" target="_blank" rel="noopener">open full size</a></figcaption></figure>`;
}

export function remarkPosters() {
  return (tree, file) => {
    const fromRepoRel = file.path ? repoRelOf(file.path) : null;
    if (!fromRepoRel) return;
    visit(tree, 'paragraph', (node, index, parent) => {
      if (node.children.length !== 1 || node.children[0].type !== 'image') return;
      const img = node.children[0];
      if (!/diagrams\/posters\/[^/]+\.svg$/.test(img.url)) return;
      const abs = path.join(REPO_ROOT, path.posix.normalize(path.posix.join(path.posix.dirname(fromRepoRel), img.url)));
      if (!existsSync(abs)) throw new Error(`${file.path}: poster not found: ${img.url}`);
      parent.children[index] = { type: 'html', value: posterHtml(abs, img.alt ?? '') };
    });
  };
}
