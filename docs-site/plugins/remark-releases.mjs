// <!-- sggs:releases --> becomes the release timeline, read at build from CHANGELOG.md:
// every `## [X.Y.Z] — date — title` section (the Keep-a-Changelog part), with how many Added /
// Changed / Fixed bullets it has and a link to the GitHub release. The older prose sections are
// listed by heading. <sggs-releases> adds a filter box on the site.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT, PLATFORM_REPO } from './paths.mjs';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

export function parseChangelog(text) {
  const out = [];
  let cur = null;
  for (const line of text.split('\n')) {
    let m = /^## \[(\d+\.\d+\.\d+)\]\s*—\s*(\d{4}-\d{2}-\d{2})(?:\s*—\s*(.+))?$/.exec(line);
    if (m) { cur = { version: m[1], date: m[2], title: (m[3] ?? '').trim(), kinds: {}, legacy: false }; out.push(cur); continue; }
    m = /^## (?:v|iOS )(\S.*?)\s*—\s*(\d{4}-\d{2}-\d{2})\s*—\s*(.+)$/.exec(line);
    if (m) { cur = { version: m[1], date: m[2], title: m[3].trim(), kinds: {}, legacy: true }; out.push(cur); continue; }
    if (/^## /.test(line)) { cur = null; continue; }
    if (!cur) continue;
    const k = /^### (\w+)/.exec(line);
    if (k) { cur._kind = k[1]; cur.kinds[k[1]] ??= 0; continue; }
    if (/^- /.test(line) && cur._kind) cur.kinds[cur._kind]++;
  }
  for (const r of out) delete r._kind;
  return out;
}

export function releasesHtml(releases) {
  return `<sggs-releases><ol class="releases">${releases.map((r) => {
    const tag = r.legacy ? '' : `https://github.com/${PLATFORM_REPO}/releases/tag/v${r.version}`;
    const kinds = Object.entries(r.kinds).map(([k, n]) => `${n} ${k.toLowerCase()}`).join(' · ');
    const text = `${r.version} ${r.date} ${r.title}`.toLowerCase();
    return `<li class="release" data-text="${esc(text)}"><span class="release__v">${tag ? `<a href="${esc(tag)}">v${esc(r.version)}</a>` : esc(r.version)}</span><span class="release__d">${esc(r.date)}</span><span class="release__t">${esc(r.title || '—')}${kinds ? ` <span class="release__k">· ${esc(kinds)}</span>` : ''}</span></li>`;
  }).join('')}</ol></sggs-releases>`;
}

export function remarkReleases(options = {}) {
  const file = options.file ?? path.join(REPO_ROOT, 'CHANGELOG.md');
  return (tree) => {
    visit(tree, 'html', (node) => {
      if (!/^<sggs-releases\b[^>]*>\s*<\/sggs-releases>$/.test(node.value.trim())) return;
      node.value = releasesHtml(parseChangelog(readFileSync(file, 'utf8')));
    });
  };
}
