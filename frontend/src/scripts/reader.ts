// reader.ts — the Reader page (/reader) : the Ang-by-Ang viewer.
// Ported 1:1 from the original; deep-links via ?ang=<n>&raag=<name>.
import { $, esc, api, guard, meta, store, syncToolbarTop, relChip, failHTML, prefersReducedMotion } from './core';
import { pinButtonHTML } from './store';
import { loadClock, claimsFor } from './timing';
import { paharLabel, paharRange } from './pahar.js';

let curAng = 1;
let raagCtx: any = null;

function groupShabads(lines: any[]) {
  const groups: any[] = []; let g: any = null;
  for (const l of lines) {
    if (l.is_header) {
      if (!g || g.body.length) { g = { headers: [], body: [] }; groups.push(g); }
      g.headers.push(l);
    } else {
      if (!g) { g = { headers: [], body: [] }; groups.push(g); }
      g.body.push(l);
    }
  }
  return groups;
}
let angReq = 0;
/* ---- adjacent-Ang prefetch: page turns paint from cache (no "Loading…" flash). Raw fetch,
   never api(): a failed prefetch must stay silent (api() toasts). Bounded, evicted by distance. */
const angCache = new Map<number, any>();
const inflight = new Set<number>();
const inflightPromises = new Map<number, Promise<any>>();
function prefetch(n: number): Promise<any> {
  if (n < 1 || n > 1430) return Promise.resolve(null);
  if (angCache.has(n)) return Promise.resolve(angCache.get(n));
  const pending = inflightPromises.get(n); if (pending) return pending;
  inflight.add(n);
  const p = fetch('/api/ang/' + n).then((r) => (r.ok ? r.json() : null)).then((d) => { if (d) putCache(n, d); return d; })
    .catch(() => null).finally(() => { inflight.delete(n); inflightPromises.delete(n); });
  inflightPromises.set(n, p);
  return p;
}
function putCache(n: number, d: any) {
  angCache.set(n, d);
  if (angCache.size > 6) {                                   // keep the 6 nearest to the current Ang
    const far = [...angCache.keys()].sort((a, b) => Math.abs(b - curAng) - Math.abs(a - curAng))[0];
    angCache.delete(far);
  }
}
// verse to scroll to after the next render (from ?line= / ?comp= or the modal's "Open Ang")
let focusLine: number | null = null, focusComp: number | null = null;
let landingUntil = 0;                       // the landing scroll itself must never hide the chrome
const ang = guard(async (n: number) => {
  curAng = Math.max(1, Math.min(1430, n)); ($('#angIn') as HTMLInputElement).value = String(curAng);
  const myReq = ++angReq;
  let d = angCache.get(curAng);
  if (!d) {
    ($('#angOut') as HTMLElement).innerHTML = '<div class="hint">Loading Ang ' + curAng + '…</div>';
    d = await api('ang/' + curAng);
    if (myReq !== angReq) return;            // a newer page was requested meanwhile
    putCache(curAng, d);
  }
  // context chips
  const chips: string[] = [];
  if (d.raag) chips.push(`<span class="raagchip gm">${esc(d.raag)}</span>`);
  // closing-section correction (same data fix as the Index grid): the corpus tags Angs
  // 1364–1384 as ਚਉਬੋਲੇ, but they are the standalone Salok Bhagat Kabir Ji / Farid Ji
  // sections (header at 1364 / 1377). Show the right name so the chip matches the grid.
  const sec = (curAng >= 1364 && curAng <= 1376) ? 'ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀ'
    : (curAng >= 1377 && curAng <= 1384) ? 'ਸਲੋਕ ਭਗਤ ਫਰੀਦ ਜੀ' : d.section;
  if (sec) chips.push(`<span class="gm">${esc(sec)}</span>`);
  (d.authors || []).forEach((a: string) => chips.push(`<span>${esc(a)}</span>`));
  ($('#angCtx') as HTMLElement).innerHTML = chips.join('');
  if (d.raag) addTimingChip(d.raag, myReq);   // async metadata chip; never blocks the scripture
  // raag banner while inside a raag opened from the grid
  let banner = '';
  if (raagCtx && d.raag === raagCtx.name && curAng >= raagCtx.first_ang && curAng <= raagCtx.last_ang) {
    banner = `<div class="raagbanner"><div class="rn gm">ਰਾਗੁ ${esc(raagCtx.name)}</div>
      <div class="rr">${esc(raagCtx.roman || '')} · Angs ${raagCtx.first_ang}–${raagCtx.last_ang} · ${raagCtx.n_shabads} compositions · ${raagCtx.n_lines} lines</div></div>`;
  } else if (raagCtx && d.raag !== raagCtx.name) { raagCtx = null; }
  ($('#raagBanner') as HTMLElement).innerHTML = banner;
  // continued-from pill
  let h = '';
  if (d.continued_from) h += `<div class="cont" onclick="ang(${d.continued_from})">‹ this composition continues from Ang ${d.continued_from}</div>`;
  // shabad groups
  for (const g of groupShabads(d.lines)) {
    const cid = (g.body[0] || g.headers[0] || {}).comp_id;
    h += `<div class="shabad" data-comp-id="${cid ?? ''}">`;
    if (g.headers.length) h += `<div class="hdr gm" lang="pa">${g.headers.map((x: any) =>
      `<div class="${x.gurmukhi.startsWith('ੴ') ? 'invoc' : ''}">${esc(x.gurmukhi)}</div>`).join('')}
        <div class="t">${g.headers.map((x: any) => esc(x.translit)).join(' · ')}</div></div>`;
    h += g.body.map((l: any) => `<div class="sline tap haspin ${l.is_rahao ? 'rahao' : ''}" data-line-id="${l.id}" title="Tap for related verses">
        ${pinButtonHTML(l.id, curAng, l.comp_id, l.gurmukhi)}
        <div class="g gm" lang="pa">${esc(l.gurmukhi)}</div><div class="t">${esc(l.translit)}</div>
        ${l.en ? `<div class="en" lang="en">${esc(l.en)}</div>` : ''}</div>`).join('');
    h += '</div>';
  }
  // continues-on pill: the NEXT Ang's continued_from points back into (or before) this one.
  // Derived from the server's boundary field only — never from comp_id of the last line,
  // which can be a header opening the next composition. Fixed-height slot: no layout shift.
  const next = angCache.get(curAng + 1);
  const continuesOn = !!(next && next.continued_from != null && next.continued_from <= curAng);
  h += `<div class="cont-slot">${continuesOn
    ? `<div class="cont cont-next" onclick="ang(${curAng + 1})">this composition continues on Ang ${curAng + 1} ›</div>` : ''}</div>`;
  const prevL = curAng > 1 ? `‹ Ang ${curAng - 1}` : '‹ Beginning', nextL = curAng < 1430 ? `Ang ${curAng + 1} ›` : 'End ›';
  h += `<div class="endnav"><button onclick="ang(${curAng - 1})" ${curAng <= 1 ? 'disabled' : ''}>${prevL}</button>
      <button onclick="ang(${curAng + 1})" ${curAng >= 1430 ? 'disabled' : ''}>${nextL}</button></div>`;
  ($('#angOut') as HTMLElement).innerHTML = h;
  window.scrollTo({ top: 0 });
  showChrome();                                                // a page turn always restores the chrome
  // keep the URL honest (bookmarkable/shareable, Back stays on this page) without piling
  // one history entry per page-turn; line/comp survive only for the landing that asked for them
  try {
    const u = new URL(location.href); u.searchParams.set('ang', String(curAng));
    if (raagCtx) u.searchParams.set('raag', raagCtx.name); else u.searchParams.delete('raag');
    if (focusLine) u.searchParams.set('line', String(focusLine)); else u.searchParams.delete('line');
    if (!focusLine && focusComp) u.searchParams.set('comp', String(focusComp)); else u.searchParams.delete('comp');
    history.replaceState({ ang: curAng }, '', u);
  } catch {}
  focusTarget();
  // adjacent pages warm in the background; the pill may need the next page → fill its slot
  // once that page lands (also when a prefetch from a previous page is still in flight)
  prefetch(curAng - 1);
  const thisAng = curAng;
  prefetch(thisAng + 1).then((nd) => {
    if (!nd || myReq !== angReq || next) return;                   // stale, or pill already rendered
    if (nd.continued_from != null && nd.continued_from <= thisAng) {
      const slot = $('#angOut .cont-slot');
      if (slot) slot.innerHTML = `<div class="cont cont-next" onclick="ang(${thisAng + 1})">this composition continues on Ang ${thisAng + 1} ›</div>`;
    }
  });
}, () => { const o = $('#angOut'); if (o) o.innerHTML = failHTML('This Ang'); });

/* ---- precision landing: scroll the requested verse (or a composition's first verse) to the
   centre, flash-highlight it, and move keyboard/screen-reader focus onto it. One-shot. */
function focusTarget() {
  let el: HTMLElement | null = null;
  if (focusLine) el = document.querySelector(`#angOut .sline[data-line-id="${focusLine}"]`);
  else if (focusComp) el = document.querySelector(`#angOut .shabad[data-comp-id="${focusComp}"] .sline`);
  focusLine = null; focusComp = null;
  if (!el) return;
  el.setAttribute('tabindex', '-1');
  landingUntil = performance.now() + 900;
  el.scrollIntoView({ behavior: prefersReducedMotion() ? 'auto' : 'smooth', block: 'center' });
  el.classList.add('verse-focus');
  el.addEventListener('animationend', () => el!.classList.remove('verse-focus'), { once: true });
  try { el.focus({ preventScroll: true }); } catch {}
}

/* ---- ambient chrome: hide nav + toolbar while reading downwards, bring them back on any
   upward scroll, at the top, on a key press, or a pointer near the top edge. Never while the
   composition modal or study-trail drawer is open; explicit Sehaj (focus-mode) has its own rules. */
let lastY = 0, chromeHidden = false, scrollTick = false;
function showChrome() { if (chromeHidden) { chromeHidden = false; document.body.classList.remove('chrome-hidden'); } }
function onScroll() {
  if (scrollTick) return; scrollTick = true;
  requestAnimationFrame(() => {
    scrollTick = false;
    const y = window.scrollY, dy = y - lastY; lastY = y;
    if (performance.now() < landingUntil) return;                   // programmatic landing scroll
    if (document.body.classList.contains('focus-mode') || $('#panel')?.classList.contains('on')
        || document.body.classList.contains('drawer-open')) return;
    if (y < 80 || dy < -8) showChrome();
    else if (dy > 0 && y > 80 && !chromeHidden) { chromeHidden = true; document.body.classList.add('chrome-hidden'); }
  });
}
window.addEventListener('scroll', onScroll, { passive: true });
document.addEventListener('keydown', showChrome);
document.addEventListener('pointerdown', (e) => { if (e.clientY < 72) showChrome(); });
const step = (d: number) => ang(curAng + d);
window.addEventListener('popstate', () => {
  const p = new URLSearchParams(location.search);
  const n = parseInt(p.get('ang') || '', 10);
  focusLine = parseInt(p.get('line') || '', 10) || null;
  focusComp = focusLine ? null : (parseInt(p.get('comp') || '', 10) || null);
  if (n && n !== curAng) ang(n); else focusTarget();
});

/* ---- raag timing chip: small metadata chip next to the raag context chip.
   Scholarly metadata about the raag, visually distinct from Gurbani, never
   inline with scripture lines. Toggleable (show_timing, default ON) via the
   body class hide-timing; a fetch failure simply means no chip. */
async function addTimingChip(raagName: string, myReq: number) {
  try {
    const clock = await loadClock();
    if (myReq !== angReq) return;                         // user paged on meanwhile
    const cs = claimsFor(clock, raagName);
    if (!cs) return;
    const primary = cs.primary[0];
    const parts: string[] = [];
    if (primary?.pahar) parts.push(`${paharLabel(primary.pahar)} (${paharRange(primary.pahar)})`);
    else if (cs.seasonal[0]) parts.push(`${cs.seasonal[0].season} — any time`);   // esc applied at join
    if (cs.variant.length) {
      const v = cs.variant[0];
      parts.push(`variant: ${v.pahar ? paharLabel(v.pahar) : (v.notes || '').toLowerCase().includes('night') ? 'night' : 'differs'}†`);
    }
    if (!parts.length) return;
    const title = [
      ...cs.primary.map((c: any) => `primary: ${c.pahar ? paharLabel(c.pahar) : c.season || ''} — ${c.source_name}`),
      ...cs.variant.map((c: any) => `variant (disputed): ${c.pahar ? paharLabel(c.pahar) : c.notes || ''} — ${c.source_name}`),
      ...cs.seasonal.map((c: any) => `seasonal: ${c.season} — ${c.source_name}`),
      ...cs.ceremonial.map((c: any) => `ceremonial: ${c.occasion} — ${c.source_name}`),
    ].join('\n');
    const roman = primary?.roman || '';
    const chip = document.createElement('a');
    chip.className = 'timechip';
    chip.href = '/raag-clock?raag=' + encodeURIComponent(roman || raagName);
    chip.setAttribute('role', 'note');
    chip.setAttribute('aria-label', `Raag timing (scholarly metadata, not scripture): ${parts.join('; ').replace(/†/g, ', disputed variant exists')}. Opens the Raag Clock.`);
    chip.title = title;
    chip.innerHTML = `<span class="tc-i" aria-hidden="true">🕐</span>${parts.map(esc).join(' <span class="tc-sep">·</span> ')}`;
    $('#angCtx')?.appendChild(chip);
  } catch { /* chip is optional metadata — reader never blocks on it */ }
}

function toggleTiming() {
  document.body.classList.toggle('hide-timing');
  const on = !document.body.classList.contains('hide-timing');
  $('#tglTime')?.classList.toggle('on', on);
  $('#tglTime')?.setAttribute('aria-checked', String(on));
  store.set('show_timing', on ? '1' : '0');
}

function toggleT() {
  document.body.classList.toggle('hide-t');
  const on = !document.body.classList.contains('hide-t');
  $('#tglT')?.classList.toggle('on', on);
  $('#tglT')?.setAttribute('aria-checked', String(on));
  store.set('show_t', on ? '1' : '0');
}
function fontSize(d: number) {
  const cur = parseInt(getComputedStyle(document.documentElement).getPropertyValue('--gsize')) || 22;
  const next = Math.max(17, Math.min(32, cur + d * 2));
  document.documentElement.style.setProperty('--gsize', next + 'px');
  store.set('gsize', next);
}

// Sehaj — calm focus reading: collapse the chrome, widen the leading, soften the ground.
function sehaj() {
  const on = document.body.classList.toggle('focus-mode');
  const b = $('#sehajBtn');
  if (b) { b.classList.toggle('on', on); b.setAttribute('aria-pressed', String(on)); }
  store.set('sehaj', on ? '1' : '0');
  syncToolbarTop();                          // nav is hidden in focus mode → re-measure sticky offset
}

// arrow-key paging + Esc to leave focus mode (skip while the modal is open or while typing)
document.addEventListener('keydown', (e: any) => {
  if (e.key === 'Escape' && document.body.classList.contains('focus-mode') && !$('#panel')?.classList.contains('on')) { sehaj(); return; }
  if ($('#panel')?.classList.contains('on')) return;
  if (e.target.tagName === 'INPUT') return;
  if (e.key === 'ArrowRight') step(1);
  if (e.key === 'ArrowLeft') step(-1);
});
(window as any).sehaj = sehaj;

/* ---------------- Related Verses (Phase 2 semantic) ----------------
   Click a line → reveal an inline drawer of the semantically closest verses
   (line-level when the embedding table is built, else closest compositions). */
function relCard(n: any): string {
  const t = n.translit ? `<div class="t">${esc(n.translit)}</div>` : '';
  const e = n.en ? `<div class="e">${esc(n.en)}</div>` : '';
  const score = (n.score != null) ? relChip(n.score) : '';
  const m = [`Ang ${n.ang}`, n.raag ? esc(n.raag) : '', n.author ? esc(n.author) : ''].filter(Boolean).join(' · ');
  return `<div class="relcard" onclick="goReader(${n.ang || 1})" role="button" tabindex="0" aria-label="Open Ang ${n.ang}">
      <div class="g gm" lang="pa">${esc(n.gurmukhi || '')}</div>${t}${e}
      <div class="rm">${score}<span>${m}</span></div></div>`;
}
const loadRelated = guard(async (sline: HTMLElement) => {
  const id = sline.getAttribute('data-line-id'); if (!id) return;
  const sib = sline.nextElementSibling;
  if (sib && sib.classList.contains('related')) { sib.remove(); return; }   // toggle off
  const drawer = document.createElement('div'); drawer.className = 'related';
  drawer.innerHTML = `<div class="rel-head"><b>✦ Related verses</b><button class="rel-x" aria-label="Close">×</button></div>
    <div class="rel-loading">Finding semantically similar verses…</div>`;
  sline.after(drawer);
  const d = await api('neighbors?line_id=' + id + '&limit=6');
  const items = d.neighbors || [];
  const lvl = d.level === 'composition' ? 'closest compositions' : (d.level === 'line' ? 'closest verses' : 'related');
  drawer.innerHTML = `<div class="rel-head"><b>✦ Related · ${lvl}</b>
      <span class="rel-actions"><a class="rel-trail" href="/trail?line_id=${id}">walk a trail →</a>
      <button class="rel-x" aria-label="Close">×</button></span></div>`
    + (items.length ? items.map(relCard).join('') : `<div class="rel-loading">No related verses found.</div>`);
}, () => { document.querySelectorAll('.related .rel-loading').forEach((el) => { el.innerHTML = failHTML('Related verses'); }); });
// delegate on the stable #angOut node (its innerHTML is replaced per Ang, the node is not)
$('#angOut')?.addEventListener('click', (e: any) => {
  const x = e.target.closest('.rel-x'); if (x) { x.closest('.related')?.remove(); return; }
  if (e.target.closest('.relcard')) return;                 // inline goReader handles it
  const sl = e.target.closest('.sline.tap'); if (sl) loadRelated(sl);
});
$('#angOut')?.addEventListener('keydown', (e: any) => {
  const card = e.target.closest('.relcard');
  if (card && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); card.click(); }
});

// expose for the toolbar + generated inline handlers
(window as any).ang = ang;
(window as any).step = step;
(window as any).toggleT = toggleT;
(window as any).toggleTiming = toggleTiming;
(window as any).fontSize = fontSize;

// ---- bootstrap: reflect the transliteration toggle, then load ?ang (+ optional ?raag) ----
(function () {
  const on = !document.body.classList.contains('hide-t');     // applyPrefs() already ran in core
  $('#tglT')?.classList.toggle('on', on);
  $('#tglT')?.setAttribute('aria-checked', String(on));
  const tOn = !document.body.classList.contains('hide-timing');
  $('#tglTime')?.classList.toggle('on', tOn);
  $('#tglTime')?.setAttribute('aria-checked', String(tOn));
  if (store.get('sehaj', '0') === '1') {                       // restore calm focus mode
    document.body.classList.add('focus-mode');
    $('#sehajBtn')?.classList.add('on'); $('#sehajBtn')?.setAttribute('aria-pressed', 'true');
    syncToolbarTop();
  }
  const p = new URLSearchParams(location.search);
  const n = Math.max(1, Math.min(1430, parseInt(p.get('ang') || '1') || 1));
  focusLine = parseInt(p.get('line') || '', 10) || null;          // ?line=Y → land on that verse
  focusComp = focusLine ? null : (parseInt(p.get('comp') || '', 10) || null);
  const raagName = p.get('raag');
  if (raagName) {
    meta().then((m: any) => {
      const r = (m.raags || []).find((x: any) => x.name === raagName);
      if (r) raagCtx = r;
      ang(n);
    }).catch(() => ang(n));
  } else {
    ang(n);
  }
})();
