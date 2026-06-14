// lineage.ts — Contributor Timeline & Lineage Ribbon (/lineage).
// Merges a hand-authored public-domain chronology (public/contributors.json) with the
// live corpus (Ang spans, line counts via /api/meta; distinctive terms via
// /api/analytics/author) into a chronological, kind-coloured vertical timeline.
import { $, esc, api } from './core';

type C = {
  name: string; roman: string; kind: string; seq: number | null;
  born: number; died: number | null; circa: boolean;
  era: string; region: string; tradition: string; blurb: string;
  first_ang?: number; last_ang?: number; n_lines?: number;
};

const KIND_LABEL: Record<string, string> = { guru: 'Guru', bhagat: 'Bhagat', bhatt: 'Bhatt', gursikh: 'Gursikh' };

async function load() {
  const host = $('#timeline'); if (!host) return;
  let data: any, meta: any;
  try {
    [data, meta] = await Promise.all([
      fetch('/contributors.json').then((r) => r.json()),
      api('meta'),
    ]);
  } catch { host.innerHTML = '<div class="hint">Could not load the contributor data.</div>'; return; }

  const live: Record<string, any> = {};
  (meta.authors || []).forEach((a: any) => { live[a.name] = a; });
  const list: C[] = (data.contributors || []).map((c: C) => ({
    ...c,
    first_ang: live[c.name]?.first_ang, last_ang: live[c.name]?.last_ang, n_lines: live[c.name]?.n_lines,
  })).sort((a: C, b: C) => a.born - b.born);

  const maxLines = Math.max(1, ...list.map((c) => c.n_lines || 0));
  const bar = (n: number) => Math.round(100 * Math.sqrt((n || 0) / maxLines));   // sqrt so small voices stay visible

  host.innerHTML = list.map((c, i) => {
    const yr = (c.circa ? 'c.' : '') + c.born;
    const lines = c.n_lines ? `${c.n_lines.toLocaleString()} lines · Angs ${c.first_ang}–${c.last_ang}` : 'in the corpus';
    return `<button class="tl-node kind-${c.kind}" data-i="${i}" type="button" aria-label="${esc(c.roman)} — details">
        <span class="tl-dot"></span>
        <span class="tl-year">${esc(yr)}</span>
        <span class="tl-card">
          <span class="tl-row"><span class="tl-name">${esc(c.roman)}</span><span class="tl-kind">${KIND_LABEL[c.kind] || c.kind}${c.seq ? ' · M' + c.seq : ''}</span></span>
          <span class="tl-era">${esc(c.era)} · ${esc(c.region)}</span>
          <span class="tl-bar"><i style="width:${bar(c.n_lines || 0)}%"></i></span>
          <span class="tl-lines">${esc(lines)}</span>
        </span>
      </button>`;
  }).join('');

  // filter chips
  const chips = $('#tlFilter');
  if (chips) chips.querySelectorAll('span').forEach((s: any) => {
    s.onclick = () => {
      chips.querySelectorAll('span').forEach((x: any) => x.classList.toggle('on', x === s));
      const k = s.dataset.k;
      host.querySelectorAll('.tl-node').forEach((n: any) => {
        n.style.display = (k === 'all' || n.classList.contains('kind-' + k)) ? '' : 'none';
      });
    };
  });

  // open detail in the shared modal
  host.querySelectorAll('.tl-node').forEach((n: any) => {
    n.onclick = () => openDetail(list[+n.dataset.i]);
  });
}

async function openDetail(c: C) {
  const pt = $('#ptitle'); const pb = $('#pbody');
  if (pt) pt.textContent = c.roman;
  const lifespan = c.died ? `${c.circa ? 'c.' : ''}${c.born}–${c.died}` : `${c.circa ? 'c.' : ''}${c.born}`;
  const span = c.n_lines ? `${c.n_lines.toLocaleString()} lines · Angs ${c.first_ang}–${c.last_ang}` : '—';
  if (pb) pb.innerHTML = `
    <div class="ld-chips">
      <span class="ld-chip kind-${c.kind}">${KIND_LABEL[c.kind] || c.kind}${c.seq ? ' · M' + c.seq : ''}</span>
      <span class="ld-chip">${esc(lifespan)}</span>
      <span class="ld-chip">${esc(c.region)}</span>
      <span class="ld-chip">${esc(c.tradition)}</span>
    </div>
    <p class="ld-blurb">${esc(c.blurb)}</p>
    <div class="ld-span">In the Granth: <b>${esc(span)}</b></div>
    <div id="ldTerms" class="ld-terms"></div>
    <div class="endnav" style="margin-top:16px"><span></span>
      ${c.first_ang ? `<button onclick="goReader(${c.first_ang})">Read their first composition (Ang ${c.first_ang}) →</button>` : ''}</div>`;
  (window as any).openPanel?.();

  // distinctive terms (only meaningful / reliable for the larger contributors)
  try {
    const d = await api('analytics/author?author=' + encodeURIComponent(c.name));
    const terms = (d.distinctive_terms || []).slice(0, 10).map((t: any) => esc(t.term));
    const st = d.stylometry || {};
    const el = $('#ldTerms');
    if (el && terms.length && st.is_reliable !== 0) {
      el.innerHTML = `<div class="ld-h">Distinctive words <span class="ld-note">(keyness vs. corpus · English)</span></div>
        <div class="ld-termwrap">${terms.map((t: string) => `<span class="ld-term">${t}</span>`).join('')}</div>`;
    } else if (el && st.is_reliable === 0) {
      el.innerHTML = `<div class="ld-note">Stylometry withheld — sample too small to be reliable.</div>`;
    }
  } catch {}
}

load();
