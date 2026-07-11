// raagclock.ts — the Raag Clock page (/raag-clock).
// A clean SVG 24-hour dial (pahar number + time + raag count, no cramped
// name-stacks) paired with a rich detail panel that fills in as you tap each
// pahar, and a searchable/filterable claims explorer with a 24-hour timeline
// per raag. Everything here is METADATA about raags — scripture rendering is
// untouched; all API text passes esc() before innerHTML.
import { $, esc, guard, store, toast, prefersReducedMotion, goReader } from './core';
import { loadClock as loadClockShared } from './timing';
import {
  paharFromMinutes, paharWindow, paharLabel, paharRange, fmt12,
  sunTimes, paharSolar, nextPaharBoundary, raagsForPahar, minutesOf,
} from './pahar.js';

const NS = 'http://www.w3.org/2000/svg';
const C = 400, R_IN = 176, R_OUT = 322, R_SEA_IN = 330, R_SEA_OUT = 350, R_HOURS = 368;
let CLOCK: any = null;
let BYRAAG: Record<string, any[]> = {};
let selPahar = 0;
let nowTimer: any = null;

// ---- tiny SVG helpers -------------------------------------------------------
function el(tag: string, attrs: Record<string, string | number> = {}, text?: string) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, String(v));
  if (text != null) e.textContent = text;
  return e;
}
/** minutes-since-midnight → radians. Noon top, midnight bottom, 6 AM left. */
const angle = (m: number) => ((m / 1440) * 360 + 180 - 90) * Math.PI / 180;
const pt = (m: number, r: number) => [C + r * Math.cos(angle(m)), C + r * Math.sin(angle(m))];
function arcPath(m0: number, m1: number, r0: number, r1: number) {
  const [x0, y0] = pt(m0, r1), [x1, y1] = pt(m1, r1);
  const [x2, y2] = pt(m1, r0), [x3, y3] = pt(m0, r0);
  const large = ((m1 - m0 + 1440) % 1440) > 720 ? 1 : 0;
  return `M${x0},${y0} A${r1},${r1} 0 ${large} 1 ${x1},${y1} L${x2},${y2} A${r0},${r0} 0 ${large} 0 ${x3},${y3} Z`;
}

async function loadClock(): Promise<any> {
  if (CLOCK) return CLOCK;
  CLOCK = await loadClockShared();
  return CLOCK;
}
function indexClaims() {
  BYRAAG = {};
  for (const c of allClaims()) (BYRAAG[c.raag_name] ||= []).push(c);
}
const allClaims = () => CLOCK
  ? [...CLOCK.claims.primary, ...CLOCK.claims.variant, ...CLOCK.claims.seasonal, ...CLOCK.claims.ceremonial]
  : [];

// =============================================================================
// The dial
// =============================================================================
function buildDial() {
  const wrap = $('#clockWrap'); if (!wrap || !CLOCK) return;
  wrap.textContent = '';
  const svg = el('svg', { viewBox: `0 0 ${C * 2} ${C * 2}`, class: 'raagdial' });
  const nowP = currentPahar().pahar;

  for (let p = 1; p <= 8; p++) {
    const { start } = paharWindow(p);
    const primary = raagsForPahar(CLOCK, p);
    const variants = (CLOCK.claims.variant || []).filter((c: any) => c.pahar === p);
    const g = el('g', { class: 'wedge' });
    const cls = p === 7 ? 'arc arc-quiet' : `arc ${p <= 4 ? 'arc-day' : 'arc-night'} arc-p${p}`;
    const path = el('path', {
      d: arcPath(start, start + 180, R_IN, R_OUT),
      class: cls + (p === nowP ? ' arc-now' : ''),
      tabindex: 0, role: 'button', 'data-pahar': p,
    });
    path.setAttribute('aria-label', p === 7
      ? `Pahar 7, ${paharRange(7)}: deliberately no raags — the deep night is left in silence.`
      : `Pahar ${p}, ${paharLabel(p)}, ${paharRange(p)}, ${primary.length} raags: ${primary.map((c: any) => c.roman).join(', ') || 'none'}${variants.length ? `, plus ${variants.length} disputed variant` : ''}. Press Enter for detail.`);
    g.appendChild(path);

    // radial content: pahar number, time, and a compact "N raags" + bead row.
    const [nx, ny] = pt(start + 90, R_IN + 34);
    g.appendChild(el('text', { x: nx, y: ny, class: 'pnum', 'text-anchor': 'middle', 'pointer-events': 'none' }, String(p)));
    g.appendChild(el('text', { x: nx, y: ny + 17, class: 'prange', 'text-anchor': 'middle', 'pointer-events': 'none' }, paharRange(p)));

    const [mx, my] = pt(start + 90, (R_IN + R_OUT) / 2 + 14);
    if (p === 7) {
      g.appendChild(el('text', { x: mx, y: my, class: 'quiet-star', 'text-anchor': 'middle', 'pointer-events': 'none' }, '✦'));
      g.appendChild(el('text', { x: mx, y: my + 18, class: 'quiet-sub', 'text-anchor': 'middle', 'pointer-events': 'none' }, 'quiet hours'));
    } else {
      g.appendChild(el('text', { x: mx, y: my, class: 'pcount', 'text-anchor': 'middle', 'pointer-events': 'none' },
        `${primary.length} raag${primary.length !== 1 ? 's' : ''}`));
      // bead row: primary filled, variant ringed — a density cue, tap for names
      const beads = [...primary.map(() => 0), ...variants.map(() => 1)];
      const bw = 12, total = (beads.length - 1) * bw;
      const [bx, by] = pt(start + 90, (R_IN + R_OUT) / 2 + 30);
      // lay beads horizontally centred on the wedge midline
      const ux = Math.cos(angle(start + 90) + Math.PI / 2), uy = Math.sin(angle(start + 90) + Math.PI / 2);
      beads.forEach((v, i) => {
        const off = i * bw - total / 2;
        g.appendChild(el('circle', {
          cx: bx + ux * off, cy: by + uy * off, r: v ? 3.4 : 3.8,
          class: v ? 'bead bead-var' : 'bead', 'pointer-events': 'none',
        }));
      });
    }
    svg.appendChild(g);
  }

  // seasonal outer ring — labels on the free diagonals, rotated to the tangent
  const seasons = [
    { m0: 720, m1: 1439, labelAt: 900, short: 'Basant · spring', raag: 'ਬਸੰਤੁ',
      label: 'Basant — spring (Chet–Vaisakh), sung any time of day in season' },
    { m0: 0, m1: 719, labelAt: 540, short: 'Malhar · monsoon', raag: 'ਮਲਾਰ',
      label: 'Malhar — monsoon (Sawan–Bhadon), sung any time of day in season' },
  ];
  seasons.forEach((s, i) => {
    const g = el('g', { class: 'seasonseg' });
    const path = el('path', { d: arcPath(s.m0, s.m1, R_SEA_IN, R_SEA_OUT), class: `arc-season arc-season${i}`, tabindex: 0, role: 'button', 'data-season': s.raag });
    path.setAttribute('aria-label', s.label + '. Press Enter for detail.');
    g.appendChild(path);
    const [tx, ty] = pt(s.labelAt, R_SEA_OUT + 13);
    const deg = ((s.labelAt / 1440) * 360 + 90) % 360;
    let rot = (deg + 90) % 360; if (rot > 90 && rot < 270) rot -= 180;
    g.appendChild(el('text', { x: tx, y: ty, class: 'seasonlabel', 'text-anchor': 'middle', 'pointer-events': 'none', transform: `rotate(${rot} ${tx} ${ty})` }, s.short));
    svg.appendChild(g);
  });

  // hour marks
  [[360, '6 AM'], [720, 'NOON'], [1080, '6 PM'], [0, 'MIDNIGHT']].forEach(([m, lbl]) => {
    const [x, y] = pt(m as number, R_HOURS);
    svg.appendChild(el('text', { x, y: (y as number) + 4, class: 'hourmark', 'text-anchor': 'middle' }, lbl as string));
  });

  // now-hand + centre
  const hand = el('g', { class: 'nowhand' + (prefersReducedMotion() ? ' nomotion' : '') });
  hand.appendChild(el('line', { x1: C, y1: C, x2: C, y2: C - R_IN + 54, class: 'handline', id: 'handLine' }));
  hand.appendChild(el('circle', { cx: C, cy: C, r: 6, class: 'handdot' }));
  svg.appendChild(hand);
  svg.appendChild(el('text', { x: C, y: C - 18, class: 'dialtitle gm', 'text-anchor': 'middle' }, 'ੴ'));
  svg.appendChild(el('text', { x: C, y: C + 8, class: 'dialsub', 'text-anchor': 'middle' }, '24-HOUR RAAG CLOCK'));
  svg.appendChild(el('text', { x: C, y: C + 30, class: 'dialhint', 'text-anchor': 'middle' }, 'tap a pahar →'));

  svg.addEventListener('click', (e: any) => hit(e.target));
  svg.addEventListener('keydown', (e: any) => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); hit(e.target); }
  });
  svg.addEventListener('focusin', (e: any) => {
    const w = e.target.closest('[data-pahar]'); if (w) selectPahar(+w.dataset.pahar, true);
    const s = e.target.closest('[data-season]'); if (s) selectSeason(s.dataset.season, true);
  });
  wrap.appendChild(svg);
  positionHand();
}
function hit(target: any) {
  const w = target.closest('[data-pahar]'); if (w) return selectPahar(+w.dataset.pahar);
  const s = target.closest('[data-season]'); if (s) return selectSeason(s.dataset.season);
}

function markSelected(kind: 'pahar' | 'season', key: string | number) {
  document.querySelectorAll('.raagdial .arc').forEach((a: any) =>
    a.classList.toggle('arc-sel', kind === 'pahar' && a.dataset.pahar === String(key)));
  document.querySelectorAll('.raagdial .arc-season').forEach((a: any) =>
    a.classList.toggle('arc-sel', kind === 'season' && a.dataset.season === String(key)));
}
function scrollPanelIntoView() {
  try {
    if (matchMedia('(max-width: 860px)').matches)
      $('#clockDetail')?.scrollIntoView({ behavior: prefersReducedMotion() ? 'auto' : 'smooth', block: 'start' });
  } catch {}
}

// =============================================================================
// Detail panel
// =============================================================================
const TRAD = (t: string) => t === 'hindustani' ? 'Hindustani' : 'Gurmat Sangeet';
function whenText(c: any): string {
  if (c.pahar) return `${paharLabel(c.pahar)} · ${paharRange(c.pahar)}`;
  if (c.time_start) return `${fmt12(c.time_start)}–${fmt12(c.time_end)}${c.occasion ? ` · ${esc(c.occasion)}` : ''}`;
  if (c.season) return `${esc(c.season)} · any time`;
  if (c.occasion) return esc(c.occasion);
  return '';
}
function raagCard(c: any, isVariant: boolean): string {
  const others = (BYRAAG[c.raag_name] || []).filter((x: any) =>
    x !== c && (x.claim_type === 'seasonal' || x.claim_type === 'ceremonial'));
  const occ = others.map((x: any) => `<span class="occhip">${esc(x.season || x.occasion || '')}</span>`).join('');
  const name = esc(c.raag_name).replace(/'/g, '');
  return `<div class="raagcard${isVariant ? ' is-variant' : ''}">
    <div class="rc-top">
      <div class="rc-name"><span class="gm" lang="pa">${esc(c.raag_name)}</span><span class="rc-roman">${esc(c.roman || '')}</span></div>
      <button class="rc-read" type="button" onclick="goReader(${c.first_ang || 1}, '${name}')" aria-label="Read raag ${esc(c.roman)} in the reader">Read →</button>
    </div>
    <div class="rc-meta">
      <span class="cbadge cb-${esc(c.claim_type)}">${esc(c.claim_type)}</span>
      <span class="conf conf-${esc(c.confidence)}">${esc(c.confidence)}</span>
      <span class="tbadge tb-${esc(c.tradition)}">${esc(TRAD(c.tradition))}</span>
    </div>
    <div class="rc-src">${c.source_url ? `<a href="${esc(c.source_url)}" target="_blank" rel="noopener">${esc(c.source_name)}</a>` : esc(c.source_name)}</div>
    ${c.notes ? `<div class="rc-note">${esc(c.notes)}</div>` : ''}
    ${occ ? `<div class="rc-occ"><span class="rc-occ-l">also sung for</span> ${occ}</div>` : ''}
  </div>`;
}
function detailPahar(p: number): string {
  if (p === 7) {
    return `<div class="det-quiet">
      <div class="det-quiet-star">✦</div>
      <div class="det-badge pbadge-night">P7</div>
      <h3>The quiet hours</h3>
      <div class="det-sub">${paharRange(7)} · 3rd pahar of night</div>
      <p>No raag of the Granth is assigned to this watch. The deep night is left in silence —
      this absence is deliberate and canonical, so the empty arc is itself part of the tradition,
      not missing data.</p></div>`;
  }
  const primary = raagsForPahar(CLOCK, p);
  const variants = (CLOCK.claims.variant || []).filter((c: any) => c.pahar === p);
  const dn = p <= 4 ? 'day' : 'night';
  const cards = [...primary.map((c: any) => raagCard(c, false)), ...variants.map((c: any) => raagCard(c, true))].join('');
  return `<div class="det-head">
      <div class="det-badge pbadge-${dn}">P${p}</div>
      <div><div class="det-title">${paharLabel(p)}</div>
      <div class="det-sub">${paharRange(p)} · ${primary.length} raag${primary.length !== 1 ? 's' : ''}${variants.length ? ` · ${variants.length} variant` : ''}</div></div>
    </div>
    <div class="det-cards">${cards || '<div class="hint">No raags in this pahar.</div>'}</div>`;
}
function selectPahar(p: number, soft = false) {
  selPahar = p;
  markSelected('pahar', p);
  const d = $('#clockDetail'); if (d) d.innerHTML = detailPahar(p);
  if (!soft) scrollPanelIntoView();
}
function selectSeason(raagName: string, soft = false) {
  markSelected('season', raagName);
  const claims = (BYRAAG[raagName] || []);
  const seasonal = claims.find((c: any) => c.claim_type === 'seasonal') || claims[0];
  const d = $('#clockDetail'); if (!d || !seasonal) return;
  d.innerHTML = `<div class="det-head">
      <div class="det-badge pbadge-season">✿</div>
      <div><div class="det-title gm" lang="pa">${esc(raagName)}</div>
      <div class="det-sub">${esc(seasonal.roman || '')} · seasonal raag</div></div>
    </div>
    <div class="det-cards">${raagCard(seasonal, false)}</div>
    <p class="det-foot">Seasonal raags are sung at <b>any time of day</b> while their season lasts —
    the outer ring marks them apart from the hour-bound pahars.</p>`;
  if (!soft) scrollPanelIntoView();
}
function positionHand(svg?: any) {
  const line = (svg || document).querySelector('#handLine'); if (!line) return;
  const [x, y] = pt(minutesOf(new Date()), R_IN - 54);
  line.setAttribute('x2', String(x)); line.setAttribute('y2', String(y));
}

// =============================================================================
// "What raag is it now?"
// =============================================================================
type Mode = 'fixed' | 'solar';
function getMode(): Mode { return (store.get('pahar_mode', 'fixed') === 'solar' ? 'solar' : 'fixed'); }
function getLoc(): { lat: number; lon: number } | null {
  try { const s = store.get('pahar_loc', ''); return s ? JSON.parse(s) : null; } catch { return null; }
}
function currentPahar(): { pahar: number; mode: Mode; sun?: any; note?: string } {
  const now = new Date(); const m = minutesOf(now);
  if (getMode() === 'solar') {
    const loc = getLoc();
    if (loc) {
      if (Math.abs(loc.lat) > 60) return { pahar: paharFromMinutes(m), mode: 'fixed', note: 'Above 60° latitude solar watches degenerate — using fixed clock.' };
      const sun = sunTimes(now, loc.lat, loc.lon);
      if (!sun.polar) return { pahar: paharSolar(m, sun.sunrise, sun.sunset), mode: 'solar', sun };
      return { pahar: paharFromMinutes(m), mode: 'fixed', note: 'Polar day/night here right now — using fixed clock.' };
    }
    return { pahar: paharFromMinutes(m), mode: 'fixed', note: 'Location not set — using fixed clock.' };
  }
  return { pahar: paharFromMinutes(m), mode: 'fixed' };
}
const hhmm = (min: number) => fmt12(`${Math.floor(min / 60)}:${String(min % 60).padStart(2, '0')}`);
function renderNow() {
  const body = $('#nowBody'); if (!body || !CLOCK) return;
  const st = currentPahar();
  const m = minutesOf(new Date());
  const raags = raagsForPahar(CLOCK, st.pahar);
  const nb = nextPaharBoundary(m, st.mode, st.sun?.sunrise, st.sun?.sunset);
  const hrs = Math.floor(nb.minutes / 60), mins = nb.minutes % 60;
  const inWait = (hrs ? `${hrs} h ` : '') + `${mins} min`;
  const nextRaags = raagsForPahar(CLOCK, nb.nextPahar);
  const month = new Date().getMonth() + 1;
  const seasonNow = (month === 3 || month === 4) ? 'ਬਸੰਤੁ' : (month === 7 || month === 8) ? 'ਮਲਾਰ' : null;

  body.innerHTML = `
    <div class="now-pahar"><b>${paharLabel(st.pahar)}</b>
      <span class="now-range">${st.mode === 'solar' && st.sun
        ? `solar · sunrise ${hhmm(st.sun.sunrise)} · sunset ${hhmm(st.sun.sunset)}`
        : paharRange(st.pahar)}</span></div>
    ${st.pahar === 7
      ? `<p class="quiet-note">✦ The quiet hours — no raag is assigned to the 3rd pahar of night. This silence is deliberate and canonical.</p>`
      : `<div class="now-raags">${raags.map((c: any) =>
          `<button type="button" class="now-chip gm" lang="pa" onclick="goReader(${c.first_ang}, '${esc(c.raag_name).replace(/'/g, '')}')"
             aria-label="Read raag ${esc(c.roman)} in the reader">${esc(c.raag_name)}<span class="tr">${esc(c.roman)}</span></button>`).join('')}
        ${seasonNow ? `<button type="button" class="now-chip gm season" lang="pa" onclick="goReader(${
            (CLOCK.claims.seasonal.find((c: any) => c.raag_name === seasonNow) || {}).first_ang || 1
          }, '${seasonNow}')" aria-label="Seasonal raag, any time of day right now">${seasonNow}<span class="tr">in season · any time</span></button>` : ''}</div>`}
    <div class="now-next">next: <b>${paharLabel(nb.nextPahar)}</b> in ${inWait}${
      nextRaags.length ? ` — ${nextRaags.map((c: any) => esc(c.roman)).join(', ')}` : ' — the quiet hours'}</div>
    ${st.note ? `<div class="now-fallback">${esc(st.note)}</div>` : ''}`;
  document.querySelectorAll('.raagdial .arc').forEach((a: any) =>
    a.classList.toggle('arc-now', a.dataset.pahar === String(st.pahar)));
  positionHand();
}
function initModeToggle() {
  const tgl = $('#modeTgl'); if (!tgl) return;
  const reflect = () => tgl.querySelectorAll('button').forEach((b: any) =>
    b.setAttribute('aria-checked', String(b.dataset.mode === getMode())));
  reflect();
  tgl.addEventListener('click', (e: any) => {
    const b = e.target.closest('button'); if (!b) return;
    const mode = b.dataset.mode as Mode;
    if (mode === 'solar' && !getLoc()) {
      if (!('geolocation' in navigator)) { toast('Geolocation is not available — staying on fixed clock.'); return; }
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          store.set('pahar_loc', JSON.stringify({ lat: +pos.coords.latitude.toFixed(3), lon: +pos.coords.longitude.toFixed(3) }));
          store.set('pahar_mode', 'solar'); reflect(); renderNow();
        },
        () => { toast('Location declined — staying on fixed clock (your choice is remembered).'); store.set('pahar_mode', 'fixed'); reflect(); renderNow(); },
        { maximumAge: 86400000, timeout: 8000 });
      return;
    }
    store.set('pahar_mode', mode); reflect(); renderNow();
  });
}

// =============================================================================
// Claims explorer (searchable, filterable, with a 24h timeline per raag)
// =============================================================================
const CLAIM_ORDER: any = { primary: 0, variant: 1, seasonal: 2, ceremonial: 3 };
const FILTERS = { type: 'all', disputedOnly: false, q: '' };

function activeCells(c: any): number[] | 'all' {
  if (c.claim_type === 'seasonal') return 'all';
  if (c.pahar) return [c.pahar];
  if (c.time_start) { const [h, mm] = c.time_start.split(':').map(Number); return [paharFromMinutes(h * 60 + mm)]; }
  return [];
}
function timeline(c: any): string {
  const act = activeCells(c);
  let cells = '';
  for (let p = 1; p <= 8; p++) {
    const on = act === 'all' || (Array.isArray(act) && act.includes(p));
    const kind = act === 'all' ? 'season' : (p <= 4 ? 'day' : 'night');
    cells += `<span class="tl-cell${on ? ' on tl-' + kind : ''}"></span>`;
  }
  return `<div class="tl" aria-hidden="true">${cells}</div>`;
}
function rowHTML(c: any): string {
  return `<tr class="exp-row${c.confidence === 'disputed' ? ' is-disp' : ''}">
    <td class="c-raag" data-l="Raag"><span class="gm" lang="pa">${esc(c.raag_name)}</span><span class="c-roman">${esc(c.roman || '')}</span></td>
    <td class="c-when" data-l="When"><b>${whenText(c)}</b>${c.notes ? `<div class="c-note">${esc(c.notes)}</div>` : ''}</td>
    <td class="c-tl" data-l="Across the day">${timeline(c)}</td>
    <td class="c-claim" data-l="Claim"><span class="cbadge cb-${esc(c.claim_type)}">${esc(c.claim_type)}</span><span class="conf conf-${esc(c.confidence)}">${esc(c.confidence)}</span></td>
    <td class="c-src" data-l="Source"><span class="tbadge tb-${esc(c.tradition)}">${esc(TRAD(c.tradition))}</span><div class="c-srcname">${c.source_url ? `<a href="${esc(c.source_url)}" target="_blank" rel="noopener">${esc(c.source_name)}</a>` : esc(c.source_name)}</div></td>
  </tr>`;
}
function renderExp() {
  const body = $('#expBody'); if (!body) return;
  const rows = allClaims().filter((c: any) => {
    if (FILTERS.type !== 'all' && c.claim_type !== FILTERS.type) return false;
    if (FILTERS.disputedOnly && c.confidence !== 'disputed') return false;
    if (FILTERS.q) {
      const hay = `${c.raag_name} ${c.roman} ${c.source_name} ${c.occasion || ''} ${c.season || ''} ${c.notes || ''}`.toLowerCase();
      if (!hay.includes(FILTERS.q)) return false;
    }
    return true;
  }).sort((a: any, b: any) => (a.seq - b.seq) || (CLAIM_ORDER[a.claim_type] - CLAIM_ORDER[b.claim_type]) || ((a.pahar || 0) - (b.pahar || 0)));
  if (!rows.length) { body.innerHTML = '<div class="exp-empty">No claims match your filters.</div>'; return; }
  body.innerHTML = `<div class="exp-count">${rows.length} claim${rows.length !== 1 ? 's' : ''}</div>
    <div class="exp-scroll"><table class="exp-table">
      <thead><tr><th scope="col">Raag</th><th scope="col">When</th>
        <th scope="col" class="tl-h">6a · noon · 6p · 12a</th><th scope="col">Claim</th><th scope="col">Source</th></tr></thead>
      <tbody>${rows.map(rowHTML).join('')}</tbody></table></div>`;
}
function buildExplorer() {
  const box = $('#claimsExplorer'); if (!box || !CLOCK) return;
  const types = ['all', 'primary', 'variant', 'seasonal', 'ceremonial'];
  box.innerHTML = `
    <div class="exp-tools">
      <input id="expSearch" class="exp-search" type="search" placeholder="Search raag, source, occasion…" aria-label="Search timing claims" />
      <div class="exp-chips" role="group" aria-label="Filter by claim type">
        ${types.map(t => `<button type="button" class="chip${t === 'all' ? ' on' : ''}" data-type="${t}" aria-pressed="${t === 'all'}">${t[0].toUpperCase() + t.slice(1)}</button>`).join('')}
        <button type="button" class="chip chip-disp" id="dispChip" data-disp aria-pressed="false">Disputed only</button>
      </div>
    </div>
    <div id="expBody"></div>`;
  const search = $('#expSearch') as HTMLInputElement;
  search.addEventListener('input', () => { FILTERS.q = search.value.trim().toLowerCase(); renderExp(); });
  box.querySelectorAll('.exp-chips .chip[data-type]').forEach((c: any) => c.addEventListener('click', () => {
    FILTERS.type = c.dataset.type;
    box.querySelectorAll('.exp-chips .chip[data-type]').forEach((x: any) => {
      const on = x === c; x.classList.toggle('on', on); x.setAttribute('aria-pressed', String(on));
    });
    renderExp();
  }));
  $('#dispChip')?.addEventListener('click', () => {
    FILTERS.disputedOnly = !FILTERS.disputedOnly;
    $('#dispChip')?.classList.toggle('on', FILTERS.disputedOnly);
    $('#dispChip')?.setAttribute('aria-pressed', String(FILTERS.disputedOnly));
    renderExp();
  });
  renderExp();
}

// =============================================================================
// boot
// =============================================================================
guard(async () => {
  const d = await loadClock();
  if (!d.available) {
    ($('#nowBody') as HTMLElement).innerHTML = '<div class="hint">The timing knowledge layer is not present in this database build.</div>';
    ($('#clockDetail') as HTMLElement).innerHTML = '';
    return;
  }
  indexClaims();
  buildDial();
  buildExplorer();
  initModeToggle();
  renderNow();
  nowTimer = setInterval(renderNow, 60000);
  window.addEventListener('beforeunload', () => clearInterval(nowTimer));

  // deep link: /raag-clock?raag=<roman|gurmukhi> opens that raag's pahar
  const q = new URLSearchParams(location.search).get('raag');
  const hitClaim = q && [...d.claims.primary, ...d.claims.variant, ...d.claims.seasonal]
    .find((c: any) => c.raag_name === q || c.roman === q.toLowerCase());
  if (hitClaim && hitClaim.pahar) selectPahar(hitClaim.pahar);
  else if (hitClaim && hitClaim.claim_type === 'seasonal') selectSeason(hitClaim.raag_name);
  else selectPahar(currentPahar().pahar, true);      // default: the current pahar
})();
