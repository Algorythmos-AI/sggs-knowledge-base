// <sggs-code file="…" symbol="…"> (written as `<!-- sggs:code … -->`, turned into the element by
// remark-widgets) becomes a real code block read from the repository at build time: this repository
// at the documented commit, or a sibling pinned in sources.lock.json. The build fails when the file
// or the symbol is missing, so an excerpt can never drift into a pasted copy. No JavaScript on the page.
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT, SOURCES_DIR, PLATFORM_REPO, PLATFORM_REF, loadSources } from './paths.mjs';

const TAG = /^<sggs-code((?:\s+[a-z-]+="[^"]*")*)\s*>\s*<\/sggs-code>$/;
const ATTR = /([a-z-]+)="([^"]*)"/g;
export const MAX_LINES = 120;

const LANG = { py: 'python', mjs: 'js', js: 'js', ts: 'ts', swift: 'swift', sh: 'bash', json: 'json', yml: 'yaml', yaml: 'yaml', toml: 'toml' };

/** Where the file lives and how to link it: { abs, display, url(lines) } */
export function resolveTarget(attrs, sources = loadSources(), commit = process.env.PUBLIC_DOCS_COMMIT) {
  const file = attrs.file;
  if (!file || file.includes('..') || file.startsWith('/')) throw new Error(`sggs:code: bad file "${file}"`);
  if (attrs.repo) {
    const src = sources[attrs.repo];
    if (!src) throw new Error(`sggs:code: unknown repo "${attrs.repo}" (sources.lock.json names ${Object.keys(sources).join(', ') || 'none'})`);
    if (!src.files[file]) throw new Error(`sggs:code: ${attrs.repo} does not pin "${file}" (add it to include and run tools/fetch_sibling_docs.py --update ${attrs.repo})`);
    return {
      abs: path.join(REPO_ROOT, SOURCES_DIR, attrs.repo, file), display: `${attrs.repo}/${file}`, sha: src.commit,
      url: (a, b) => `https://github.com/${src.repository}/blob/${src.commit}/${file}#L${a}-L${b}`,
    };
  }
  const ref = commit && /^[0-9a-f]{40}$/.test(commit) ? commit : PLATFORM_REF;
  return { abs: path.join(REPO_ROOT, file), display: file, sha: ref, url: (a, b) => `https://github.com/${PLATFORM_REPO}/blob/${ref}/${file}#L${a}-L${b}` };
}

const SYMBOL = {
  python: (n) => new RegExp(`^([ \\t]*)(?:(?:async\\s+)?(?:def|class)\\s+${n}\\b|${n}\\s*(?::[^=]+)?=(?!=))`),
  js: (n) => new RegExp(`^([ \\t]*)(?:export\\s+)?(?:default\\s+)?(?:async\\s+)?(?:function\\*?\\s+${n}\\b|class\\s+${n}\\b|(?:const|let|var)\\s+${n}\\b)`),
  ts: (n) => SYMBOL.js(n),
  swift: (n) => new RegExp(`^([ \\t]*)(?:(?:public|private|internal|fileprivate|open|static|final|override|mutating|@\\w+)\\s+)*(?:func|struct|class|enum|protocol|extension|actor|var|let)\\s+${n}\\b`),
  bash: (n) => new RegExp(`^([ \\t]*)(?:function\\s+)?${n}\\s*\\(\\)`),
};

/** 1-based inclusive [start, end] of `symbol` in `text`, or null. */
export function findSymbol(text, symbol, lang) {
  const mk = SYMBOL[lang];
  if (!mk) throw new Error(`sggs:code: symbol= is not supported for ${lang}; use lines=`);
  const rx = mk(symbol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  const lines = text.split('\n');
  const i = lines.findIndex((l) => rx.test(l));
  if (i < 0) return null;
  let start = i;
  while (start > 0 && /^\s*@/.test(lines[start - 1])) start--;   // decorators / attributes above
  let end = i;
  if (lang === 'python') {
    const indent = rx.exec(lines[i])[1].length;
    end = i + 1;
    while (end < lines.length) {
      const l = lines[end];
      if (l.trim() !== '' && (l.length - l.trimStart().length) <= indent) break;
      end++;
    }
    end--;
  } else {
    let depth = 0, seen = false;
    for (let k = i; k < lines.length; k++) {
      const code = lines[k].replace(/(["'`])(?:\\.|(?!\1).)*\1/g, '').replace(/\/\/.*$/, '').replace(/#.*$/, '');
      for (const ch of code) { if (ch === '{') { depth++; seen = true; } else if (ch === '}') depth--; }
      end = k;
      if (seen && depth <= 0) break;
      if (!seen && /;\s*$/.test(code) && k >= i) break;
      if (!seen && lines[k].trim() === '' && k > i) { end = k - 1; break; }
    }
  }
  while (end > start && lines[end].trim() === '') end--;
  return [start + 1, end + 1];
}

export function parseLines(spec) {
  const m = /^(\d+)-(\d+)$/.exec(spec ?? '');
  if (!m || +m[1] < 1 || +m[2] < +m[1]) throw new Error(`sggs:code: lines= must be "A-B" with 1 ≤ A ≤ B (got "${spec}")`);
  return [+m[1], +m[2]];
}

/** The mdast nodes that replace one <sggs-code> element. */
export function excerptNodes(attrs, { sources, commit, where = 'page' } = {}) {
  const t = resolveTarget(attrs, sources, commit);
  if (!existsSync(t.abs)) throw new Error(`${where}: sggs:code: ${t.display} is not on disk (sibling sources are installed by tools/fetch_sibling_docs.py)`);
  const text = readFileSync(t.abs, 'utf8');
  const lang = LANG[path.extname(t.abs).slice(1)] ?? 'text';
  let range;
  if (attrs.lines) range = parseLines(attrs.lines);
  else if (attrs.symbol) {
    range = findSymbol(text, attrs.symbol, lang);
    if (!range) throw new Error(`${where}: sggs:code: symbol "${attrs.symbol}" not found in ${t.display}`);
  } else throw new Error(`${where}: sggs:code: give symbol= or lines=`);
  const all = text.split('\n');
  if (range[1] > all.length) throw new Error(`${where}: sggs:code: ${t.display} has ${all.length} lines, not ${range[1]}`);
  if (range[1] - range[0] + 1 > MAX_LINES) throw new Error(`${where}: sggs:code: ${t.display} ${attrs.symbol ?? attrs.lines} is ${range[1] - range[0] + 1} lines; excerpts are at most ${MAX_LINES} — use lines= for a shorter range`);
  const value = all.slice(range[0] - 1, range[1]).join('\n');
  const what = attrs.symbol ? ` · ${attrs.symbol}` : '';
  const title = `${t.display}${what} · lines ${range[0]}–${range[1]}`;
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  return [
    { type: 'code', lang, meta: `title="${title.replace(/"/g, "'")}" startLineNumber=${range[0]}`, value },
    { type: 'html', value: `<p class="excerpt__source">Read from the source at build time — <a href="${esc(t.url(range[0], range[1]))}" rel="noopener">view these lines on GitHub at ${esc(t.sha.slice(0, 7))}</a>.</p>` },
  ];
}

export function parseElement(html) {
  const m = TAG.exec(html.trim());
  if (!m) return null;
  const attrs = {};
  for (const a of m[1].matchAll(ATTR)) attrs[a[1]] = a[2].replace(/&quot;/g, '"').replace(/&amp;/g, '&');
  return attrs;
}

export function remarkCodeExcerpt() {
  const sources = loadSources();
  return (tree, file) => {
    visit(tree, 'html', (node, index, parent) => {
      const attrs = parseElement(node.value);
      if (!attrs) return;
      const nodes = excerptNodes(attrs, { sources, where: file.path ?? 'page' });
      parent.children.splice(index, 1, ...nodes);
      return index + nodes.length;
    });
  };
}
