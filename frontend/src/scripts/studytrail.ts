// studytrail.ts — the Study Trail drawer UI (loaded globally via Base.astro).
// Off-canvas glass panel with two tabs: Pinned Verses + AI Insights (thematic centre of
// gravity + semantic echoes). Pin buttons everywhere are handled here in the CAPTURE phase
// so a pin click never fires the underlying verse card's own onclick.
import { $, esc, api } from './core';
import {
  getPins, count, isPinned, togglePin, removePin, clearPins, subscribe, mostRecent,
  enrichThemes, centerOfGravity, label, toJSON, toText, MAX_PINS, pinButtonHTML, repairPins, type Pin,
} from './store';

/* ---------- transient toast (self-contained, no CSS dependency) ---------- */
function toast(msg: string) {
  let t = document.getElementById('sggs-toast') as HTMLDivElement | null;
  if (!t) {
    t = document.createElement('div'); t.id = 'sggs-toast';
    t.setAttribute('role', 'status'); t.setAttribute('aria-live', 'polite');
    t.style.cssText = 'position:fixed;left:50%;bottom:30px;transform:translateX(-50%);z-index:9999;'
      + 'background:rgba(20,22,30,.95);color:#fff;padding:10px 16px;border-radius:10px;font-size:13px;'
      + 'max-width:80vw;text-align:center;box-shadow:0 10px 34px rgba(0,0,0,.45);opacity:0;transition:opacity .2s;';
    document.body.appendChild(t);
  }
  t.textContent = msg; t.style.opacity = '1';
  clearTimeout((t as any)._h);
  (t as any)._h = setTimeout(() => { if (t) t.style.opacity = '0'; }, 3400);
}

/* ---------- pin-button capture delegate (verse cards keep their own click intact) ---------- */
document.addEventListener('click', (e: any) => {
  const btn = e.target?.closest?.('.pin-btn');
  if (!btn) return;
  e.stopPropagation(); e.preventDefault();                 // capture-phase: beat the card's onclick
  const id = +btn.dataset.id, ang = +btn.dataset.ang, cid = +btn.dataset.cid;
  // verbatim scripture comes from the data model (data-gm), NEVER from rendered text — the
  // display-only saroop painter rewrites .g text nodes, and that must never reach storage.
  const gm = btn.dataset.gm || '';
  const r = togglePin({ line_id: id, gm, ang, comp_id: cid });
  if (r === 'cap' || r === 'quota') {            // save failed → keep the button truthful + tell the user
    btn.classList.remove('pinned'); btn.setAttribute('aria-pressed', 'false');
    toast(r === 'cap'
      ? `Study trail is full (max ${MAX_PINS}) — unpin a verse to add more.`
      : 'Could not save — your browser storage is full.');
    return;
  }
  const on = r === 'pinned';
  btn.classList.toggle('pinned', on);
  btn.setAttribute('aria-pressed', String(on));
}, true);

// reflect pinned state on every pin button currently in the DOM
function markPins() {
  document.querySelectorAll('.pin-btn').forEach((b: any) => {
    const on = isPinned(+b.dataset.id);
    b.classList.toggle('pinned', on); b.setAttribute('aria-pressed', String(on));
  });
}

/* ---------- drawer open / close ---------- */
function openDrawer() {
  $('#trailDrawer')?.classList.add('on');
  $('#trailScrim')?.classList.add('on');
  document.body.classList.add('drawer-open');
  renderAll();
  setTimeout(() => ($('#trailClose') as HTMLElement | null)?.focus(), 0);
}
function closeDrawer() {
  $('#trailDrawer')?.classList.remove('on');
  $('#trailScrim')?.classList.remove('on');
  document.body.classList.remove('drawer-open');
}

/* ---------- tabs ---------- */
function showTab(which: 'pinned' | 'insights') {
  ['pinned', 'insights'].forEach((k) => {
    $('#tab-' + k)!.style.display = k === which ? '' : 'none';
    const t = document.querySelector(`#trailTabs [data-tab="${k}"]`);
    if (t) { t.classList.toggle('on', k === which); t.setAttribute('aria-selected', String(k === which)); }
  });
  if (which === 'insights') renderInsights();
}

/* ---------- renderers ---------- */
function fabBadge() {
  const n = count();
  const fab = $('#trailFab'); if (!fab) return;
  fab.setAttribute('data-n', String(n));
  fab.classList.toggle('has', n > 0);
  const b = $('#trailFabN'); if (b) b.textContent = String(n);
}

function verseRow(p: Pin): string {
  const themes = (p.themes || []).slice(0, 4).map((c) => `<span class="pv-th">${esc(label(c).split(' · ')[0])}</span>`).join('');
  return `<div class="pv" data-id="${p.line_id}">
      <div class="pv-g gm">${esc(p.gm)}</div>
      <div class="pv-meta"><span class="pv-ang">Ang ${p.ang}</span>${themes}</div>
      <div class="pv-actions">
        <button class="pv-open" data-go-ang="${p.ang}" data-go-line="${p.line_id}" title="Open in Reader">open →</button>
        <button class="pv-rm" data-id="${p.line_id}" title="Unpin" aria-label="Unpin">✕</button>
      </div>
    </div>`;
}

function renderPinned() {
  const host = $('#tab-pinned'); if (!host) return;
  const pins = getPins();
  if (!pins.length) {
    host.innerHTML = `<div class="trail-empty">No verses pinned yet.<br><span>Tap 📌 on any verse — in Search, the Reader, or a composition — to begin building a study collection.</span></div>`;
    return;
  }
  host.innerHTML = `<div class="pv-head"><span>${pins.length} verse${pins.length > 1 ? 's' : ''}</span>
      <button id="pvClear" class="pv-clear" type="button">clear all</button></div>`
    + pins.map(verseRow).join('');
  ($('#pvClear') as HTMLElement | null)?.addEventListener('click', () => {
    if (confirm('Remove all pinned verses?')) clearPins();
  });
  host.querySelectorAll('.pv-rm').forEach((b: any) => b.onclick = () => removePin(+b.dataset.id));
}

async function renderInsights() {
  const host = $('#tab-insights'); if (!host) return;
  const pins0 = getPins();
  if (!pins0.length) { host.innerHTML = `<div class="trail-empty">Pin a few verses to compute the leaning of your study trail.</div>`; return; }
  host.innerHTML = `<div class="rel-loading">Reading the themes of your collection…</div>`;
  const pins = await enrichThemes();               // one batch fetch; graceful if offline
  const g = centerOfGravity(pins);

  const bars = g.top.slice(0, 6).map((t) => `
    <div class="cg-row"><div class="cg-label">${esc(t.label)}</div>
      <div class="cg-track"><i style="width:${Math.max(6, t.pct)}%"></i></div>
      <div class="cg-pct">${t.pct}%</div></div>`).join('');

  host.innerHTML = `
    <div class="cg-card">
      <div class="cg-headline">${esc(g.headline)}</div>
      ${g.total ? `<div class="cg-bars">${bars}</div>
      <div class="cg-foot">${g.nThemed}/${pins.length} verses carry corpus-verified theme tags · descriptive only, never a ranking of scripture</div>`
      : `<div class="cg-foot">Theme tags unavailable${navigator.onLine ? '' : ' (offline)'} — verses are still saved.</div>`}
    </div>
    <div class="echo-head">✦ Semantic Echoes <span>verses that resonate with your latest pin</span></div>
    <div id="echoes" class="echo-wrap"><div class="rel-loading">Listening…</div></div>
    <div class="trail-export">
      <button id="expTxt" class="now-btn ghost" type="button">Export .txt</button>
      <button id="expJson" class="now-btn ghost" type="button">Export .json</button>
    </div>`;

  ($('#expTxt') as HTMLElement | null)?.addEventListener('click', () => download(toText(pins, g), 'sggs-study-trail.txt', 'text/plain'));
  ($('#expJson') as HTMLElement | null)?.addEventListener('click', () => download(toJSON(pins, g), 'sggs-study-profile.json', 'application/json'));

  renderEchoes();
}

async function renderEchoes() {
  const host = $('#echoes'); if (!host) return;
  const recent = mostRecent();
  if (!recent) { host.innerHTML = ''; return; }
  try {
    const d = await api('neighbors?line_id=' + recent.line_id + '&limit=6');
    const items = (d.neighbors || []).filter((n: any) => !isPinned(n.id)).slice(0, 3);
    if (!items.length) { host.innerHTML = `<div class="trail-empty small">No new echoes — your trail already holds the closest verses.</div>`; return; }
    host.innerHTML = items.map((n: any) => `
      <div class="echo" data-id="${n.id}">
        <div class="g gm">${esc(n.gurmukhi || '')}</div>
        ${n.en ? `<div class="e">${esc(n.en)}</div>` : ''}
        <div class="echo-meta"><span class="sc">${Math.round((n.score || 0) * 100)}%</span><span>Ang ${n.ang} · ${esc(n.author || '')}</span>
          <span class="echo-act">${pinBtn(n)}<button class="echo-open" data-go-ang="${n.ang || 1}" data-go-line="${n.id}">open →</button></span></div>
      </div>`).join('');
    markPins();
  } catch {
    host.innerHTML = `<div class="trail-empty small">Echoes need the local app running — they’ll appear when it’s reachable.</div>`;
  }
}
function pinBtn(n: any): string {
  return pinButtonHTML(n.id, n.ang || 1, n.comp_id || 0, n.gurmukhi || '');
}

function download(content: string, name: string, mime: string) {
  const blob = new Blob([content], { type: mime + ';charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href = url; a.download = name; document.body.appendChild(a); a.click();
  a.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function renderAll() {
  fabBadge(); markPins(); renderPinned();
  const ins = $('#tab-insights'); if (ins && ins.style.display !== 'none') renderInsights();
}

/* ---------- wire up ---------- */
subscribe(renderAll);
window.addEventListener('DOMContentLoaded', markPins);
// pages re-render results with innerHTML; reflect pinned state on every newly added button
new MutationObserver((muts) => {
  for (const m of muts)
    for (const n of Array.from(m.addedNodes))
      if (n.nodeType === 1 && ((n as Element).matches('.pin-btn') || (n as Element).querySelector('.pin-btn'))) { markPins(); return; }
}).observe(document.body, { childList: true, subtree: true });
repairPins().then(markPins);              // heal pins captured from painted DOM by older builds
$('#trailFab')?.addEventListener('click', openDrawer);
$('#trailClose')?.addEventListener('click', closeDrawer);
$('#trailScrim')?.addEventListener('click', closeDrawer);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && $('#trailDrawer')?.classList.contains('on')) closeDrawer(); });
// focus trap while the drawer is open (WCAG 2.1.2) — mirrors panel.ts's dialog trap
$('#trailDrawer')?.addEventListener('keydown', (e: any) => {
  const d = $('#trailDrawer');
  if (e.key !== 'Tab' || !d || !d.classList.contains('on')) return;
  const f = Array.from(d.querySelectorAll('button,[href],input,select,textarea,[tabindex]:not([tabindex="-1"])'))
    .filter((el: any) => el.offsetParent !== null) as HTMLElement[];
  if (!f.length) return;
  const first = f[0], last = f[f.length - 1];
  if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
  else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
});
document.querySelectorAll('#trailTabs [data-tab]').forEach((t: any) => t.onclick = () => showTab(t.dataset.tab));
(window as any).openStudyTrail = openDrawer;
fabBadge(); markPins();
