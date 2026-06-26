// reader.ts — the Reader page (/reader) : the Ang-by-Ang viewer.
// Ported 1:1 from the original; deep-links via ?ang=<n>&raag=<name>.
import { $, esc, api, guard, meta, store, syncToolbarTop, relChip } from './core';
import { pinButtonHTML } from './store';

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
const ang = guard(async (n: number) => {
  curAng = Math.max(1, Math.min(1430, n)); ($('#angIn') as HTMLInputElement).value = String(curAng);
  const myReq = ++angReq;
  ($('#angOut') as HTMLElement).innerHTML = '<div class="hint">Loading Ang ' + curAng + '…</div>';
  const d = await api('ang/' + curAng);
  if (myReq !== angReq) return;            // a newer page was requested meanwhile
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
    h += '<div class="shabad">';
    if (g.headers.length) h += `<div class="hdr gm" lang="pa">${g.headers.map((x: any) =>
      `<div class="${x.gurmukhi.startsWith('ੴ') ? 'invoc' : ''}">${esc(x.gurmukhi)}</div>`).join('')}
        <div class="t">${g.headers.map((x: any) => esc(x.translit)).join(' · ')}</div></div>`;
    h += g.body.map((l: any) => `<div class="sline tap haspin ${l.is_rahao ? 'rahao' : ''}" data-line-id="${l.id}" title="Tap for related verses">
        ${pinButtonHTML(l.id, curAng, l.comp_id)}
        <div class="g gm" lang="pa">${esc(l.gurmukhi)}</div><div class="t">${esc(l.translit)}</div>
        ${l.en ? `<div class="en" lang="en">${esc(l.en)}</div>` : ''}</div>`).join('');
    h += '</div>';
  }
  const prevL = curAng > 1 ? `‹ Ang ${curAng - 1}` : '‹ Beginning', nextL = curAng < 1430 ? `Ang ${curAng + 1} ›` : 'End ›';
  h += `<div class="endnav"><button onclick="ang(${curAng - 1})" ${curAng <= 1 ? 'disabled' : ''}>${prevL}</button>
      <button onclick="ang(${curAng + 1})" ${curAng >= 1430 ? 'disabled' : ''}>${nextL}</button></div>`;
  ($('#angOut') as HTMLElement).innerHTML = h;
  window.scrollTo({ top: 0 });
});
const step = (d: number) => ang(curAng + d);

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
});
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
(window as any).fontSize = fontSize;

// ---- bootstrap: reflect the transliteration toggle, then load ?ang (+ optional ?raag) ----
(function () {
  const on = !document.body.classList.contains('hide-t');     // applyPrefs() already ran in core
  $('#tglT')?.classList.toggle('on', on);
  $('#tglT')?.setAttribute('aria-checked', String(on));
  if (store.get('sehaj', '0') === '1') {                       // restore calm focus mode
    document.body.classList.add('focus-mode');
    $('#sehajBtn')?.classList.add('on'); $('#sehajBtn')?.setAttribute('aria-pressed', 'true');
    syncToolbarTop();
  }
  const p = new URLSearchParams(location.search);
  const n = Math.max(1, Math.min(1430, parseInt(p.get('ang') || '1') || 1));
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
