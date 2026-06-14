// reader.ts — the Reader page (/reader) : the Ang-by-Ang viewer.
// Ported 1:1 from the original; deep-links via ?ang=<n>&raag=<name>.
import { $, esc, api, guard, meta, store } from './core';

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
    if (g.headers.length) h += `<div class="hdr gm">${g.headers.map((x: any) =>
      `<div class="${x.gurmukhi.startsWith('ੴ') ? 'invoc' : ''}">${esc(x.gurmukhi)}</div>`).join('')}
        <div class="t">${g.headers.map((x: any) => esc(x.translit)).join(' · ')}</div></div>`;
    h += g.body.map((l: any) => `<div class="sline ${l.is_rahao ? 'rahao' : ''}">
        <div class="g gm">${esc(l.gurmukhi)}</div><div class="t">${esc(l.translit)}</div>
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

// arrow-key paging (skip while the modal is open or while typing in a field)
document.addEventListener('keydown', (e: any) => {
  if ($('#panel')?.classList.contains('on')) return;
  if (e.target.tagName === 'INPUT') return;
  if (e.key === 'ArrowRight') step(1);
  if (e.key === 'ArrowLeft') step(-1);
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
