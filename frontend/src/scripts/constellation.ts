// constellation.ts — Concept Constellation (/constellation).
// Pick a theme; its verses fan out as stars, grouped into sub-constellations by the OTHER
// theme each verse most shares. All data from /api/analytics/constellation (read-only over the
// existing concepts/concept_lines tables); nothing computed client-side. Tap a star → Reader.
import * as d3 from 'd3';
import { $, esc, api } from './core';

const titleCase = (k: string) => k.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
const cssVar = (n: string) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const PAL = ['#ff9933', '#ffd24a', '#5b8cff', '#23b3a1', '#b07cff', '#ff6b6b', '#7ed957', '#48c6ef', '#f78fb3'];
// deterministic PRNG so star positions are stable across redraws (no jitter on resize/refocus)
function rng(seed: number) { let s = seed % 2147483647; if (s <= 0) s += 2147483646; return () => (s = (s * 16807) % 2147483647) / 2147483647; }

const openReader = (ang: number) => { const g = (window as any).goReader; if (g) g(ang); else location.href = '/reader?ang=' + ang; };

async function constellation() {
  const host = $('#constel'); if (!host) return;
  const sel = $('#conSel') as HTMLSelectElement | null;
  const authorSel = $('#conAuthor') as HTMLSelectElement | null;
  const raagSel = $('#conRaag') as HTMLSelectElement | null;
  const head = $('#conHead');
  const list = await api('analytics/constellation');
  const concepts = list.concepts || [];
  if (sel && !sel.dataset.filled) {
    if (!concepts.length) { host.innerHTML = '<div class="hint">Concept data is not available in this DB build.</div>'; return; }
    sel.innerHTML = concepts.map((c: any) => `<option value="${esc(c.concept)}">${esc(titleCase(c.concept))} · ${(c.n || 0).toLocaleString()} verses</option>`).join('');
    sel.dataset.filled = '1';
    if (authorSel) authorSel.innerHTML = '<option value="">All authors</option>'
      + (list.authors || []).map((a: string) => `<option value="${esc(a)}">${esc(a.replace(' Ji', ''))}</option>`).join('');
    if (raagSel) raagSel.innerHTML = '<option value="">All raags</option>'
      + (list.raags || []).map((r: any) => `<option value="${esc(r.name)}">${esc(r.roman || r.name)}</option>`).join('');
  }
  const shortAuthor = (a: string) => a.replace(' Ji', '');
  const tip = d3.select(host).append('div').attr('class', 'viz-tip').style('opacity', 0);

  async function draw() {
    const c = sel ? sel.value : concepts[0]?.concept;
    if (!c) return;
    const au = authorSel ? authorSel.value : '', rg = raagSel ? raagSel.value : '';
    host.querySelectorAll('svg, .constel-list').forEach((s) => s.remove());
    let q = 'analytics/constellation?concept=' + encodeURIComponent(c);
    if (au) q += '&author=' + encodeURIComponent(au);
    if (rg) q += '&raag=' + encodeURIComponent(rg);
    const d = await api(q);
    const clusters = d.clusters || [];
    const filt = [au ? shortAuthor(au) : '', rg ? (raagSel?.selectedOptions[0]?.text || rg) : ''].filter(Boolean).join(' · ');
    if (head) head.textContent = `${titleCase(c)}${filt ? ' (' + filt + ')' : ''} — ${(d.total || 0).toLocaleString()} verses across ${clusters.length} thematic sub-constellations`;
    if (!clusters.length) { host.insertAdjacentHTML('beforeend', `<div class="hint">No verses of ${esc(titleCase(c))}${filt ? ' for ' + esc(filt) : ''} — try a different filter.</div>`); return; }

    const W = host.clientWidth || 900, H = 620, cx = W / 2, cy = H / 2;
    const svg = d3.select(host).append('svg').attr('viewBox', `0 0 ${W} ${H}`).attr('width', '100%').attr('height', H)
      .attr('role', 'img')
      .attr('aria-label', `Concept constellation for ${titleCase(c)}: ${d.total} verses grouped by shared theme into ${clusters.length} clusters. Each star is a verse; an equivalent text list of clusters and Ang links follows the chart.`);
    const N = clusters.length, R = Math.min(W, H) * 0.34;

    clusters.forEach((cl: any, i: number) => {
      const ang = (i / N) * 2 * Math.PI - Math.PI / 2;
      const gx = cx + R * Math.cos(ang), gy = cy + R * Math.sin(ang);
      const col = PAL[i % PAL.length];
      svg.append('line').attr('x1', cx).attr('y1', cy).attr('x2', gx).attr('y2', gy)
        .attr('stroke', col).attr('stroke-opacity', 0.16).attr('stroke-width', 1);
      const g = svg.append('g');
      const rand = rng(i * 7919 + cl.n + 1);
      const spread = 24 + Math.min(48, cl.verses.length * 2.2);
      cl.verses.forEach((v: any) => {
        const a = rand() * 2 * Math.PI, rr = Math.sqrt(rand()) * spread;
        g.append('circle').attr('cx', gx + rr * Math.cos(a)).attr('cy', gy + rr * Math.sin(a)).attr('r', 2.6)
          .attr('fill', col).attr('fill-opacity', 0.85).attr('tabindex', 0).attr('role', 'button')
          .attr('aria-label', `Verse at Ang ${v.ang}, ${titleCase(c)} with ${titleCase(cl.co)}. Activate to open in the Reader.`)
          .style('cursor', 'pointer')
          .on('mouseover focus', (ev: any) => {
            const r = host.getBoundingClientRect(), b = ev.currentTarget.getBoundingClientRect();
            tip.html(`<b>${esc(titleCase(c))} ✦ ${esc(titleCase(cl.co))}</b><br><span>Ang ${v.ang}</span><br>${esc((v.gurmukhi || '').slice(0, 64))}`)
              .style('opacity', 1).style('left', (b.left - r.left + 12) + 'px').style('top', (b.top - r.top + 12) + 'px');
            d3.select(ev.currentTarget).attr('r', 4.6);
          })
          .on('mouseout blur', (ev: any) => { tip.style('opacity', 0); d3.select(ev.currentTarget).attr('r', 2.6); })
          .on('click keydown', (ev: any) => {
            if (ev.type === 'keydown' && ev.key !== 'Enter' && ev.key !== ' ') return;
            ev.preventDefault(); openReader(v.ang);
          });
      });
      g.append('text').attr('x', gx).attr('y', gy - spread - 8).attr('text-anchor', 'middle')
        .attr('font-size', 12).attr('font-weight', 700).attr('fill', cssVar('--ink'))
        .attr('paint-order', 'stroke').attr('stroke', cssVar('--bg')).attr('stroke-width', 3)
        .text(`${titleCase(cl.co)} · ${cl.n}`);
    });

    // centre concept star
    svg.append('circle').attr('cx', cx).attr('cy', cy).attr('r', 30).attr('fill', cssVar('--accent') || '#ff9933')
      .attr('fill-opacity', 0.92).attr('stroke', cssVar('--gold') || '#ffd24a').attr('stroke-width', 2);
    svg.append('text').attr('x', cx).attr('y', cy).attr('dy', '.35em').attr('text-anchor', 'middle')
      .attr('font-size', 13).attr('font-weight', 800).attr('fill', '#15171f').text(titleCase(c));

    // accessible text equivalent: clusters + Ang links (keyboard/AT path, mirrors the stars)
    const items = clusters.map((cl: any) =>
      `<li><b>${esc(titleCase(cl.co))}</b> <span class="cl-n">(${cl.n})</span> `
      + cl.verses.slice(0, 12).map((v: any) => `<a href="#" data-ang="${v.ang}">Ang ${v.ang}</a>`).join(' · ')
      + (cl.n > 12 ? ' …' : '') + '</li>').join('');
    host.insertAdjacentHTML('beforeend', `<ul class="constel-list" aria-label="Verses by sub-constellation">${items}</ul>`);
    host.querySelectorAll('.constel-list a').forEach((a: any) =>
      a.addEventListener('click', (e: any) => { e.preventDefault(); openReader(+a.dataset.ang); }));
  }
  if (sel) sel.onchange = draw;
  if (authorSel) authorSel.onchange = draw;
  if (raagSel) raagSel.onchange = draw;
  draw();
}
constellation();
