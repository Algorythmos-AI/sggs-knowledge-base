// After a build: every published Markdown page rendered completely. Astro's content loader logs a
// page that failed to render (a Mermaid renderer error, a plugin throwing) and still exits 0 with
// an empty body — so this check compares each source page with its built HTML: the body carries
// text, every Mermaid fence became a diagram, every poster image became a walkthrough figure.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import path from 'node:path';
import { REPO_ROOT, SITE_DIR, idForRepoPath, sitePathForId, NOT_PUBLISHED } from '../plugins/paths.mjs';

const dist = path.resolve(process.argv[2] ?? 'dist');
const pages = [];
const walk = (d) => { for (const n of readdirSync(d)) { const p = path.join(d, n); statSync(p).isDirectory() ? walk(p) : n.endsWith('.md') && pages.push(p); } };
walk(path.join(REPO_ROOT, 'docs'));
const sources = path.join(SITE_DIR, '.sources');
if (existsSync(sources)) walk(sources);

const problems = [];
let checked = 0, diagrams = 0, posters = 0;
for (const src of pages) {
  const rel = path.relative(REPO_ROOT, src).split(path.sep).join('/');
  if (NOT_PUBLISHED.some((p) => rel.startsWith(p))) continue;
  const id = idForRepoPath(rel);
  if (!id) continue;
  const out = path.join(dist, sitePathForId(id), 'index.html');
  if (!existsSync(out)) { problems.push(`${rel}: no built page at ${path.relative(dist, out)}`); continue; }
  const md = readFileSync(src, 'utf8');
  const html = readFileSync(out, 'utf8');
  const body = (html.match(/<div class="sl-markdown-content[^"]*">([\s\S]*?)<\/div>\s*<\/div>/) ?? [, html])[1];
  const text = body.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  const srcText = md.replace(/^---[\s\S]*?\n---\n/, '').replace(/```[\s\S]*?```/g, '').replace(/[#*_`>|\-\[\]()!]/g, ' ').replace(/\s+/g, ' ').trim();
  if (text.length < Math.min(200, srcText.length * 0.3)) problems.push(`${rel}: rendered body is empty or truncated (${text.length} chars of text for ${srcText.length} in the source) — a plugin or renderer failed for this page`);
  const fences = (md.match(/^```mermaid\b/gm) ?? []).length;
  const rendered = (html.match(/data-diagram="mermaid"/g) ?? []).length;
  if (fences !== rendered) problems.push(`${rel}: ${fences} Mermaid fence(s) in the source but ${rendered} rendered diagram(s)`);
  const prose = md.replace(/```[\s\S]*?```/g, '').replace(/`[^`\n]*`/g, '');   // examples in code do not count
  const refs = (prose.match(/!\[[^\]]*\]\([^)]*diagrams\/posters\/[^)]+\.svg\)/g) ?? []).length;
  const figs = (html.match(/<figure class="poster"/g) ?? []).length;
  if (refs !== figs) problems.push(`${rel}: ${refs} poster image(s) in the source but ${figs} walkthrough figure(s) in the page`);
  checked++; diagrams += rendered; posters += figs;
}
if (problems.length) { console.error(`check-render: ${problems.length} problem(s):\n  ` + problems.join('\n  ')); process.exit(1); }
console.log(`check-render: ${checked} pages rendered completely (${diagrams} diagrams, ${posters} posters)`);
