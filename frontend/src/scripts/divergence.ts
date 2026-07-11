// divergence.ts — the divergence table page (/divergence): every raag with 2+
// conflicting timing claims, side-by-side with source citations and tradition
// labels. Real <table> semantics (caption, scope, rowspan); collapses to
// stacked cards under 640px via CSS only. All API text passes esc().
import { $, esc, api, guard } from './core';
import { paharLabel, paharRange, fmt12 } from './pahar.js';

function when(c: any): string {
  if (c.pahar) return `${paharLabel(c.pahar)} (${paharRange(c.pahar)})`;
  if (c.time_start) return `${fmt12(c.time_start)}–${fmt12(c.time_end)}`;
  return esc(c.season || c.occasion || '—');
}

guard(async () => {
  const out = $('#divOut'); if (!out) return;
  const d = await api('timing/divergence');
  if (!d.available) { out.innerHTML = '<div class="hint">The timing knowledge layer is not present in this database build.</div>'; return; }
  if (!d.raags?.length) { out.innerHTML = '<div class="hint">No divergent claims recorded.</div>'; return; }

  const body = d.raags.map((r: any) => r.claims.map((c: any, i: number) => `<tr class="${i === 0 ? 'rfirst' : ''}">
      ${i === 0 ? `<th scope="rowgroup" rowspan="${r.claims.length}" class="rcell">
        <a href="/reader?ang=${r.first_ang}&raag=${encodeURIComponent(r.raag)}" aria-label="Read raag ${esc(r.roman)} from Ang ${r.first_ang}">
          <span class="gm" lang="pa">${esc(r.raag)}</span><span class="tr">${esc(r.roman)}</span></a></th>` : ''}
      <td data-l="Claim"><span class="cbadge cb-${esc(c.claim_type)}">${esc(c.claim_type)}</span></td>
      <td data-l="When"><b>${when(c)}</b>${c.notes ? `<div class="cnotes">${esc(c.notes)}</div>` : ''}</td>
      <td data-l="Tradition"><span class="tbadge tb-${esc(c.tradition)}">${esc(c.tradition === 'hindustani' ? 'Hindustani' : 'Gurmat Sangeet')}</span></td>
      <td data-l="Confidence"><span class="conf conf-${esc(c.confidence)}">${esc(c.confidence)}</span></td>
      <td data-l="Source">${c.source_url
        ? `<a href="${esc(c.source_url)}" rel="noopener" target="_blank">${esc(c.source_name)}</a>`
        : esc(c.source_name)}</td>
    </tr>`).join('')).join('');

  out.innerHTML = `<table class="claims-table div-table">
    <caption>${d.raags.length} raags with conflicting timing claims. Each row is one attributed claim; nothing is merged or adjudicated.</caption>
    <thead><tr><th scope="col">Raag</th><th scope="col">Claim</th><th scope="col">When</th>
      <th scope="col">Tradition</th><th scope="col">Confidence</th><th scope="col">Source</th></tr></thead>
    <tbody>${body}</tbody></table>
    <p class="cnotes divnote">${esc(d.note || '')}</p>`;
})();
