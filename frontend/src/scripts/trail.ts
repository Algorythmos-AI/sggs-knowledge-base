// trail.ts — the Semantic Trail Reader (/trail).
// Walk verse → verse along semantic neighbours; each step is a real MPA navigation
// (/trail?line_id=N) so browser back/forward work. The path is remembered in
// sessionStorage to render a clickable breadcrumb. Data: extended /api/neighbors.
import { $, esc, api, guard, relChip } from './core';

const TRAILKEY = 'sggs_trail';
type Stop = { id: number; ang: number; gm: string; author: string };

function readTrail(): Stop[] { try { return JSON.parse(sessionStorage.getItem(TRAILKEY) || '[]'); } catch { return []; } }
function writeTrail(t: Stop[]) { try { sessionStorage.setItem(TRAILKEY, JSON.stringify(t)); } catch {} }

// record a visit: if the verse is already on the path, truncate back to it (a breadcrumb
// jump); otherwise append. Keeps the trail loop-free and the breadcrumb honest.
function recordVisit(stop: Stop): Stop[] {
  let t = readTrail();
  const at = t.findIndex((s) => s.id === stop.id);
  if (at >= 0) t = t.slice(0, at + 1);
  else t.push(stop);
  if (t.length > 40) t = t.slice(t.length - 40);
  writeTrail(t);
  return t;
}

const chip = (txt: string) => `<span class="t-chip">${esc(txt)}</span>`;

function renderBreadcrumb(trail: Stop[], curId: number) {
  const el = $('#trailCrumbs'); if (!el) return;
  if (trail.length <= 1) { el.innerHTML = ''; return; }
  el.innerHTML = trail.map((s, i) => {
    const on = s.id === curId;
    const sep = i ? '<span class="t-sep">→</span>' : '';
    return `${sep}<a class="t-crumb${on ? ' on' : ''}" href="/trail?line_id=${s.id}" title="Ang ${s.ang}">${i + 1}</a>`;
  }).join('') + ` <button id="trailReset" class="t-reset" type="button">reset trail</button>`;
  ($('#trailReset') as HTMLElement | null)?.addEventListener('click', () => {
    writeTrail([]); location.href = '/trail';
  });
}

function stoneCard(n: any): string {
  const t = n.translit ? `<div class="t">${esc(n.translit)}</div>` : '';
  const e = n.en ? `<div class="e">${esc(n.en)}</div>` : '';
  const score = (n.score != null) ? relChip(n.score) : '';
  const meta = [n.ang ? `Ang ${n.ang}` : '', n.raag ? esc(n.raag) : '', n.author ? esc(n.author) : ''].filter(Boolean).join(' · ');
  return `<a class="stone" href="/trail?line_id=${n.id}" aria-label="Step to Ang ${n.ang}">
      <div class="g gm">${esc(n.gurmukhi || '')}</div>${t}${e}
      <div class="rm">${score}<span>${meta}</span></div>
      <div class="step">continue →</div></a>`;
}

function renderCurrent(line: any) {
  const host = $('#trailNow'); if (!host) return;
  if (!line) { host.innerHTML = '<div class="hint">This verse has no text on record.</div>'; return; }
  const t = line.translit ? `<div class="t">${esc(line.translit)}</div>` : '';
  const e = line.en ? `<div class="e">${esc(line.en)}</div>` : '';
  const meta = [line.ang ? `Ang ${line.ang}` : '', line.raag ? esc(line.raag) : '', line.author ? esc(line.author) : ''].filter(Boolean).join(' · ');
  host.innerHTML = `<div class="now-meta">${meta}</div>
    <div class="g gm">${esc(line.gurmukhi || '')}</div>${t}${e}
    <div class="now-actions">
      <button onclick="goReader(${line.ang || 1})" class="now-btn">Open in Reader →</button>
    </div>`;
}

const load = guard(async (lineId: number | null) => {
  const now = $('#trailNow'); if (now) now.innerHTML = '<div class="rel-loading">Loading the trail…</div>';
  const stones = $('#trailStones'); if (stones) stones.innerHTML = '';

  // no starting verse → draw one from the corpus so the trail can begin
  if (!lineId) {
    const r = await api('random');
    const body = (r.lines || []).find((l: any) => !l.is_header) || (r.lines || [])[0];
    if (body) { location.href = '/trail?line_id=' + body.id; return; }
  }

  const d = await api('neighbors?line_id=' + lineId + '&limit=8');
  const line = d.line;
  renderCurrent(line);
  if (line) renderBreadcrumb(recordVisit({ id: line.id, ang: line.ang, gm: line.gurmukhi, author: line.author }), line.id);

  const items = d.neighbors || [];
  const lvl = d.level === 'composition' ? 'closest compositions (theme profile)' : 'closest verses by meaning';
  const head = $('#trailStonesHead'); if (head) head.textContent = `Continue the trail · ${lvl}`;
  if (stones) stones.innerHTML = items.length
    ? items.map(stoneCard).join('')
    : '<div class="hint">This verse stands apart — no close echo was found above the relatedness floor. Try a ✦ Random start.</div>';
});

// bootstrap from ?line_id
(function () {
  const p = new URLSearchParams(location.search);
  const lid = p.get('line_id');
  load(lid ? parseInt(lid) : null);
  ($('#trailRandom') as HTMLElement | null)?.addEventListener('click', () => { location.href = '/trail'; });
})();
