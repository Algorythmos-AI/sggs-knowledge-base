// <!-- sggs:adr-timeline --> becomes the decisions on a timeline, read at build from docs/adr/*.md:
// the title, the status line (`**Status:** accepted (2026-09-24…)` or `- Status: accepted (…)`)
// and the date. Static HTML; on GitHub the fallback sentence points at the directory.
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT, idForRepoPath, sitePathForId } from './paths.mjs';

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

export function readAdrs(dir = path.join(REPO_ROOT, 'docs', 'adr')) {
  const out = [];
  for (const f of readdirSync(dir).filter((n) => /^\d{4}-.*\.md$/.test(n)).sort()) {
    const text = readFileSync(path.join(dir, f), 'utf8');
    const title = /^title:\s*"(.+?)"\s*$/m.exec(text)?.[1] ?? f;
    const st = /^(?:\*\*Status:\*\*|-\s*Status:)\s*([a-z]+)(?:\s*\(([0-9]{4}-[0-9]{2}-[0-9]{2})[^)]*\))?/m.exec(text);
    const status = st?.[1] ?? 'unknown', date = st?.[2] ?? '';
    const id = idForRepoPath(`docs/adr/${f}`);
    out.push({ file: f, number: f.slice(0, 4), title: title.replace(/^ADR-\d{4}:\s*/, ''), status, date, href: id ? sitePathForId(id) : '' });
  }
  return out;
}

export function adrTimelineHtml(adrs) {
  const sorted = [...adrs].sort((a, b) => (a.date || '9999').localeCompare(b.date || '9999') || a.number.localeCompare(b.number));
  return `<ol class="adrs">${sorted.map((a) => `<li class="adr"><span class="adr__d">${esc(a.date || '—')}</span> · <a href="${esc(a.href)}">ADR-${esc(a.number)}: ${esc(a.title)}</a><span class="chip adr__s">${esc(a.status)}</span></li>`).join('')}</ol>`;
}

export function remarkAdrTimeline() {
  return (tree) => {
    visit(tree, 'html', (node) => {
      if (!/^<sggs-adr-timeline\b[^>]*>\s*<\/sggs-adr-timeline>$/.test(node.value.trim())) return;
      node.value = adrTimelineHtml(readAdrs());
    });
  };
}
