// raagclock.ts — the 24-hour Raag Clock page (/raag-clock).
// Renders /api/timing/clock as an SVG dial (8 pahar arcs, primary raags solid,
// variant claims ghosted+dashed, pahar 7 deliberately dark, outer seasonal
// ring) plus the live "What raag is it now?" widget (fixed-clock & solar).
// Everything here is METADATA about raags — scripture rendering is untouched.
// SVG is built with createElementNS + textContent (no innerHTML for API data);
// the HTML tooltip goes through esc() like every other API string.
import { $, esc, guard, store, toast, prefersReducedMotion, goReader } from './core';
import { loadClock as loadClockShared } from './timing';
import {
  paharFromMinutes, paharWindow, paharLabel, paharRange, fmt12,
  sunTimes, paharSolar, nextPaharBoundary, raagsForPahar, minutesOf,
} from './pahar.js';

const NS = 'http://www.w3.org/2000/svg';
const C = 380, R_IN = 196, R_OUT = 306, R_SEASON_IN = 312, R_SEASON_OUT = 330, R_HOURS = 348;
let CLOCK: any = null;          // /api/timing/clock payload
let nowTimer: any = null;

// ---- tiny SVG helpers -------------------------------------------------------
function el(tag: string, attrs: Record<string, string> = {}, text?: string) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (text != null) e.textContent = text;
  return e;
}
/** minutes-since-midnight → radians. Noon at top, midnight at bottom,
    sunrise (6 AM) on the left — the arc of the sun over the dial. */
const angle = (m: number) => ((m / 1440) * 360 + 180 - 90) * Math.PI / 180;
const pt = (m: number, r: number) => [C + r * Math.cos(angle(m)), C + r * Math.sin(angle(m))];
function arcPath(m0: number, m1: number, r0: number, r1: number) {
  const [x0, y0] = pt(m0, r1), [x1, y1] = pt(m1, r1);
  const [x2, y2] = pt(m1, r0), [x3, y3] = pt(m0, r0);
  const large = ((m1 - m0 + 1440) % 1440) > 720 ? 1 : 0;
  return `M${x0},${y0} A${r1},${r1} 0 ${large} 1 ${x1},${y1} L${x2},${y2} A${r0},${r0} 0 ${large} 0 ${x3},${y3} Z`;
}

// ---- timing payload (shared session cache in timing.ts) ---------------------
async function loadClock(): Promise<any> {
  if (CLOCK) return CLOCK;
  CLOCK = await loadClockShared();
  return CLOCK;
}

// ---- tooltip card (HTML, below the dial; aria-live announces) ---------------
const CONF_LABEL: any = { consistent: 'consistent across sources', majority: 'majority convention', disputed: 'disputed — sources disagree' };
function claimLine(c: any): string {
  const when = c.pahar
    ? `${paharLabel(c.pahar)} (${paharRange(c.pahar)})`
    : c.season ? `${esc(c.season)} — any time of day`
    : c.occasion ? `${esc(c.occasion)}${c.time_start ? ` (${fmt12(c.time_start)}–${fmt12(c.time_end)})` : ''}`
    : (c.time_start ? `${fmt12(c.time_start)}–${fmt12(c.time_end)}` : '');
  return `<li class="claim claim-${esc(c.claim_type)}">
    <span class="cbadge cb-${esc(c.claim_type)}">${esc(c.claim_type)}</span>
    <b>${when}</b>
    <span class="conf conf-${esc(c.confidence)}" title="${esc(CONF_LABEL[c.confidence] || c.confidence)}">${esc(c.confidence)}</span>
    <span class="csrc">— ${esc(c.source_name)} <i>(${esc(c.tradition === 'hindustani' ? 'Hindustani' : 'Gurmat Sangeet')})</i></span>
    ${c.notes ? `<div class="cnotes">${esc(c.notes)}</div>` : ''}</li>`;
}
function showTip(raagName: string) {
  const tip = $('#clockTip'); if (!tip || !CLOCK) return;
  const all = [...CLOCK.claims.primary, ...CLOCK.claims.variant, ...CLOCK.claims.seasonal, ...CLOCK.claims.ceremonial]
    .filter((c: any) => c.raag_name === raagName);
  if (!all.length) return;
  const r = all[0];
  tip.innerHTML = `<div class="tip-head"><span class="gm" lang="pa">${esc(raagName)}</span>
      <span class="tr">${esc(r.roman || '')}</span>
      <button class="tipgo" onclick="goReader(${r.first_ang || 1}, '${esc(raagName).replace(/'/g, '')}')">Read this raag ›</button></div>
    <ul class="tip-claims">${all.map(claimLine).join('')}</ul>`;
  tip.classList.add('on');
}
function showQuietTip() {
  const tip = $('#clockTip'); if (!tip) return;
  tip.innerHTML = `<div class="tip-head"><b>Pahar 7 · ${paharRange(7)} — the quiet hours</b></div>
    <p class="cnotes">No raag of the Granth is assigned to the 3rd pahar of night. This absence is
    deliberate and canonical — the deep night is left in silence — so the empty arc is itself
    part of the tradition, not missing data.</p>`;
  tip.classList.add('on');
}

// ---- the dial ---------------------------------------------------------------
function buildDial() {
  const wrap = $('#clockWrap'); if (!wrap || !CLOCK) return;
  wrap.textContent = '';
  const svg = el('svg', { viewBox: `0 0 ${C * 2} ${C * 2}`, class: 'raagdial' });
  svg.setAttribute('aria-hidden', 'true');            // the table twin is the SR surface

  // pahar sectors
  const nowP = currentPahar().pahar;
  for (let p = 1; p <= 8; p++) {
    const { start } = paharWindow(p);
    const g = el('g', { class: 'sector' });
    const cls = p === 7 ? 'arc arc-quiet' : `arc ${p <= 4 ? 'arc-day' : 'arc-night'} arc-p${p}`;
    const path = el('path', { d: arcPath(start, start + 180, R_IN, R_OUT), class: cls + (p === nowP ? ' arc-now' : '') });
    g.appendChild(path);

    // pahar number + fixed-clock range at the inner edge
    const [lx, ly] = pt(start + 90, R_IN - 26);
    g.appendChild(el('text', { x: String(lx), y: String(ly - 7), class: 'pnum', 'text-anchor': 'middle' }, String(p)));
    g.appendChild(el('text', { x: String(lx), y: String(ly + 9), class: 'prange', 'text-anchor': 'middle' }, paharRange(p)));

    // raags in this pahar: primary solid, variants ghosted+dashed with †
    const primary = raagsForPahar(CLOCK, p);
    const variants = (CLOCK.claims.variant || []).filter((c: any) => c.pahar === p);
    const rows = [...primary.map((c: any) => ({ c, variant: false })),
                  ...variants.map((c: any) => ({ c, variant: true }))];
    const [cx, cy] = pt(start + 90, (R_IN + R_OUT) / 2 + 4);
    const lh = 19;
    if (p === 7) {
      const q = el('text', { x: String(cx), y: String(cy), class: 'quiet-star', 'text-anchor': 'middle', tabindex: '0', role: 'button' }, '✦ quiet hours');
      q.setAttribute('aria-label', `Pahar 7, ${paharRange(7)}: deliberately no raags — the deep night is left in silence. Press Enter for the note.`);
      (q as any).__quiet = true;
      g.appendChild(q);
      g.appendChild(el('text', { x: String(cx), y: String(cy + lh), class: 'quiet-sub', 'text-anchor': 'middle' }, 'no raags — deliberate'));
    }
    rows.forEach((row, i) => {
      const y = cy + (i - (rows.length - 1) / 2) * lh;
      const t = el('text', {
        x: String(cx), y: String(y),
        class: 'raagname gm' + (row.variant ? ' variantname' : ''),
        'text-anchor': 'middle', tabindex: '0', role: 'button', lang: 'pa',
      }, row.c.raag_name + (row.variant ? ' †' : ''));
      const claimDesc = row.variant
        ? `variant claim, disputed — ${row.c.source_name}`
        : `primary claim — ${row.c.source_name}`;
      t.setAttribute('aria-label',
        `${row.c.roman || row.c.raag_name}, ${paharLabel(p)}, ${paharRange(p)}, ${claimDesc}. Press Enter for details.`);
      (t as any).__raag = row.c.raag_name;
      if (row.variant) {
        const w = 8 * (row.c.raag_name.length + 2);
        g.appendChild(el('line', {
          x1: String(cx - w / 2), y1: String(y + 4), x2: String(cx + w / 2), y2: String(y + 4),
          class: 'variantline',
        }));
      }
      g.appendChild(t);
    });
    svg.appendChild(g);
  }

  // seasonal outer ring: the whole circle, halved — "any time of day in season"
  const seasons = [
    { m0: 720, m1: 720 + 719, label: 'ਬਸੰਤੁ Basant — spring (Chet–Vaisakh), any time of day', short: 'Basant · spring', raag: 'ਬਸੰਤੁ' },
    { m0: 0, m1: 719, label: 'ਮਲਾਰ Malhar — monsoon (Sawan–Bhadon), any time of day', short: 'Malhar · monsoon', raag: 'ਮਲਾਰ' },
  ];
  seasons.forEach((s, i) => {
    const g = el('g', { class: 'seasonseg' });
    const path = el('path', { d: arcPath(s.m0, s.m1, R_SEASON_IN, R_SEASON_OUT), class: `arc-season arc-season${i}`, tabindex: '0', role: 'button' });
    path.setAttribute('aria-label', s.label + '. Press Enter for details.');
    (path as any).__raag = s.raag;
    g.appendChild(path);
    // label runs along the outside of the ring, rotated to the tangent
    const mid = ((s.m0 + s.m1) / 2) % 1440;
    const [tx, ty] = pt(mid, R_SEASON_OUT + 11);
    const rot = tx > C ? 90 : -90;
    g.appendChild(el('text', {
      x: String(tx), y: String(ty), class: 'seasonlabel', 'text-anchor': 'middle',
      transform: `rotate(${rot} ${tx} ${ty})`,
    }, s.short));
    svg.appendChild(g);
  });

  // hour marks
  [[360, '6 AM'], [720, 'NOON'], [1080, '6 PM'], [0, 'MIDNIGHT']].forEach(([m, lbl]) => {
    const [x, y] = pt(m as number, R_HOURS);
    svg.appendChild(el('text', { x: String(x), y: String(y + 4), class: 'hourmark', 'text-anchor': 'middle' }, lbl as string));
  });

  // the "now" hand (updated per minute; no sweep animation — just position)
  const hand = el('g', { class: 'nowhand' + (prefersReducedMotion() ? ' nomotion' : '') });
  hand.appendChild(el('line', { x1: String(C), y1: String(C), x2: String(C), y2: String(C - R_IN + 24), class: 'handline', id: 'handLine' }));
  hand.appendChild(el('circle', { cx: String(C), cy: String(C), r: '7', class: 'handdot' }));
  svg.appendChild(hand);
  positionHand(svg);

  svg.appendChild(el('text', { x: String(C), y: String(C - 14), class: 'dialtitle gm', 'text-anchor': 'middle' }, 'ੴ'));
  svg.appendChild(el('text', { x: String(C), y: String(C + 16), class: 'dialsub', 'text-anchor': 'middle' }, '24-hour raag clock'));

  // interactions: click / Enter / Space / hover-focus on raag names & seasonal arcs
  svg.addEventListener('click', (e: any) => activate(e.target));
  svg.addEventListener('keydown', (e: any) => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); activate(e.target); }
  });
  svg.addEventListener('focusin', (e: any) => activate(e.target));
  wrap.appendChild(svg);
}
function activate(t: any) {
  if (t.__quiet) return showQuietTip();
  if (t.__raag) return showTip(t.__raag);
}
function positionHand(svg?: any) {
  const line = (svg || document).querySelector('#handLine'); if (!line) return;
  const [x, y] = pt(minutesOf(new Date()), R_IN - 24);
  line.setAttribute('x2', String(x)); line.setAttribute('y2', String(y));
}

// ---- "What raag is it now?" -------------------------------------------------
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
function renderNow() {
  const body = $('#nowBody'); if (!body || !CLOCK) return;
  const st = currentPahar();
  const m = minutesOf(new Date());
  const raags = raagsForPahar(CLOCK, st.pahar);
  const nb = nextPaharBoundary(m, st.mode, st.sun?.sunrise, st.sun?.sunset);
  const hrs = Math.floor(nb.minutes / 60), mins = nb.minutes % 60;
  const inWait = (hrs ? `${hrs} h ` : '') + `${mins} min`;
  const nextRaags = raagsForPahar(CLOCK, nb.nextPahar);
  const month = new Date().getMonth() + 1;                     // approx season chips
  const seasonNow = (month === 3 || month === 4) ? 'ਬਸੰਤੁ' : (month === 7 || month === 8) ? 'ਮਲਾਰ' : null;

  body.innerHTML = `
    <div class="now-pahar"><b>${paharLabel(st.pahar)}</b>
      <span class="now-range">${st.mode === 'solar' && st.sun
        ? `solar · sunrise ${fmt12(String(Math.floor(st.sun.sunrise / 60)) + ':' + String(st.sun.sunrise % 60).padStart(2, '0'))} · sunset ${fmt12(String(Math.floor(st.sun.sunset / 60)) + ':' + String(st.sun.sunset % 60).padStart(2, '0'))}`
        : paharRange(st.pahar)}</span></div>
    ${st.pahar === 7
      ? `<p class="quiet-note">✦ The quiet hours — no raag is assigned to the 3rd pahar of night. This silence is deliberate and canonical.</p>`
      : `<div class="now-raags">${raags.map((c: any) =>
          `<button type="button" class="now-chip gm" lang="pa" onclick="goReader(${c.first_ang}, '${esc(c.raag_name).replace(/'/g, '')}')"
             aria-label="Read raag ${esc(c.roman)} in the reader">${esc(c.raag_name)}<span class="tr">${esc(c.roman)}</span></button>`).join('')}
        ${seasonNow ? `<button type="button" class="now-chip gm season" lang="pa" onclick="goReader(${
            (CLOCK.claims.seasonal.find((c: any) => c.raag_name === seasonNow) || {}).first_ang || 1
          }, '${seasonNow}')" aria-label="Seasonal raag, any time of day right now (approximate Gregorian mapping)">${seasonNow}<span class="tr">in season · any time</span></button>` : ''}</div>`}
    <div class="now-next">next: <b>${paharLabel(nb.nextPahar)}</b> in ${inWait}${
      nextRaags.length ? ` — ${nextRaags.map((c: any) => esc(c.roman)).join(', ')}` : ' — the quiet hours'}</div>
    ${st.note ? `<div class="now-fallback">${esc(st.note)}</div>` : ''}`;
  // refresh the highlighted arc
  document.querySelectorAll('.raagdial .arc').forEach((a: any, i: number) =>
    a.classList.toggle('arc-now', i + 1 === st.pahar));
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

// ---- the table twin (screen-reader surface + plain reference) ---------------
function buildTable() {
  const box = $('#claimsTable'); if (!box || !CLOCK) return;
  const rows = [...CLOCK.claims.primary, ...CLOCK.claims.variant, ...CLOCK.claims.seasonal, ...CLOCK.claims.ceremonial];
  box.innerHTML = `<table class="claims-table">
    <caption>Every raag-timing claim with its citation (${rows.length} claims). Divergent claims are listed alongside, never merged.</caption>
    <thead><tr><th scope="col">Raag</th><th scope="col">Claim</th><th scope="col">When</th>
      <th scope="col">Confidence</th><th scope="col">Tradition</th><th scope="col">Source</th></tr></thead>
    <tbody>${rows.map((c: any) => `<tr>
      <td><span class="gm" lang="pa">${esc(c.raag_name)}</span> <span class="tr">${esc(c.roman || '')}</span></td>
      <td><span class="cbadge cb-${esc(c.claim_type)}">${esc(c.claim_type)}</span></td>
      <td>${c.pahar ? `${paharLabel(c.pahar)} (${paharRange(c.pahar)})` : esc(c.season || c.occasion || '')}${
        !c.pahar && c.time_start ? ` (${fmt12(c.time_start)}–${fmt12(c.time_end)})` : ''}</td>
      <td><span class="conf conf-${esc(c.confidence)}">${esc(c.confidence)}</span></td>
      <td>${esc(c.tradition === 'hindustani' ? 'Hindustani' : 'Gurmat Sangeet')}</td>
      <td>${esc(c.source_name)}${c.notes ? `<div class="cnotes">${esc(c.notes)}</div>` : ''}</td></tr>`).join('')}
    </tbody></table>`;
}

// ---- boot -------------------------------------------------------------------
guard(async () => {
  const d = await loadClock();
  if (!d.available) {
    ($('#nowBody') as HTMLElement).innerHTML =
      '<div class="hint">The timing knowledge layer is not present in this database build.</div>';
    return;
  }
  buildDial();
  buildTable();
  initModeToggle();
  renderNow();
  nowTimer = setInterval(renderNow, 60000);
  window.addEventListener('beforeunload', () => clearInterval(nowTimer));
  // deep link: /raag-clock?raag=<roman or gurmukhi> focuses that raag's card
  const q = new URLSearchParams(location.search).get('raag');
  if (q) {
    const hit = [...d.claims.primary, ...d.claims.variant].find(
      (c: any) => c.raag_name === q || c.roman === q.toLowerCase());
    if (hit) showTip(hit.raag_name);
  }
})();
