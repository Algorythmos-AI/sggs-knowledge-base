// search.ts — the Search page (/) : word/sound/first-letter/theme search + Verify-quote.
// Ported 1:1 from the original; in-page nav()/ang() calls are replaced by MPA goReader().
import { $, esc, api, guard, goReader } from './core';

let mode = 'auto';

// mode chips: keep the chip UI + `mode` in sync; usable by click, keyboard, and code paths
function syncMode(m: string) {
  mode = m;
  document.querySelectorAll('#modes span').forEach((x: any) => {
    const on = x.dataset.m === m; x.classList.toggle('on', on);
    x.setAttribute('aria-checked', String(on)); x.setAttribute('tabindex', on ? '0' : '-1');
  });
}
document.querySelectorAll('#modes span').forEach((s: any) => {
  s.setAttribute('role', 'radio');
  s.setAttribute('aria-checked', String(s.classList.contains('on')));
  s.setAttribute('tabindex', s.classList.contains('on') ? '0' : '-1');
  s.onclick = () => { syncMode(s.dataset.m); if (($('#q') as HTMLInputElement).value) go(0); };
  s.onkeydown = (e: KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); syncMode(s.dataset.m); if (($('#q') as HTMLInputElement).value) go(0); }
    else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { e.preventDefault(); (s.nextElementSibling || s.parentElement.firstElementChild).focus(); }
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); (s.previousElementSibling || s.parentElement.lastElementChild).focus(); }
  };
});
($('#q') as HTMLInputElement | null)?.addEventListener('keydown', (e: KeyboardEvent) => { if (e.key === 'Enter') go(0); });

// ---- search ----
let hlToks: string[] = [];
function hl(escaped: string): string {
  if (!hlToks.length) return escaped;
  let out = escaped;
  for (const t of hlToks) {
    if (t.length < 2) continue;
    const safe = t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    out = out.replace(new RegExp(safe, 'g'), (m) => `<mark>${m}</mark>`);
  }
  return out;
}
function lineCard(l: any): string {
  const chips = [`<span class="ang">Ang ${l.ang}</span>`];
  if (l.raag) chips.push(`<span class="gm">${esc(l.raag)}</span>`);
  if (l.section) chips.push(`<span class="gm">${esc(l.section)}</span>`);
  if (l.author) chips.push(`<span>${esc(l.author)}</span>`);
  if (l.is_rahao) chips.push(`<span class="rahao">ਰਹਾਉ · refrain</span>`);
  if (l.matched_term) chips.push(`<span class="gm">term: ${esc(l.matched_term)}</span>`);
  return `<div class="card" role="button" tabindex="0" aria-label="Open composition at Ang ${l.ang}" onclick="shabad(${l.comp_id},${l.id})">
    <div class="g gm">${hl(esc(l.gurmukhi))}</div><div class="t">${hl(esc(l.translit))}</div>
    ${l.en ? `<div class="en" lang="en">${esc(l.en)}</div>` : ''}
    <div class="meta">${chips.join('')}</div></div>`;
}
let searchReq = 0;
const go = guard(async (off: number) => {
  const q = ($('#q') as HTMLInputElement).value.trim(); if (!q) return;
  if (mode === 'verify') return doVerify(q);
  const myReq = ++searchReq;
  ($('#results') as HTMLElement).innerHTML = '<div class="hint">Searching…</div>';
  hlToks = q.split(/\s+/).filter((t) => t.length > 1);
  const d = await api(`search?q=${encodeURIComponent(q)}&mode=${mode}&limit=50&offset=${off}`);
  if (myReq !== searchReq) return;          // a newer search was fired; drop this stale result
  let h = '';
  if (d.related_themes && d.related_themes.length)
    h += `<div class="count">Related themes: ${d.related_themes.map((t: string) =>
      `<a href="#" class="rel-theme" data-theme="${esc(t)}" style="color:var(--saffron)">${esc(t)}</a>`).join(' · ')}</div>`;
  if (d.concept) h += `<div class="themedesc"><b>${esc(d.concept.name)}</b> — ${esc(d.concept.description)}<br>
      terms: <span class="gm">${d.concept.terms.map(esc).join(' · ')}</span> — ${d.concept.total} lines</div>`;
  h += `<div class="count">${d.results.length}${d.results.length === 50 ? '+' : ''} result(s) · interpreted as <b>${esc(d.mode)}</b>${off ? ` · from #${off + 1}` : ''}</div>`;
  h += d.results.map(lineCard).join('');
  if (d.results.length === 50) h += `<button class="more" onclick="go(${off + 50})">More ›</button>`;
  if (!d.results.length) h += `<div class="hint">Nothing found. Try fewer words, first-letters mode, or a theme (<i>naam, hukam, haumai</i>).</div>`;
  ($('#results') as HTMLElement).innerHTML = h; window.scrollTo({ top: 0 });
});
// delegated handlers for #results — keyboard activation of cards + related-theme links
($('#results') as HTMLElement | null)?.addEventListener('click', (e: any) => {
  const a = e.target.closest('.rel-theme');
  if (a) { e.preventDefault(); ($('#q') as HTMLInputElement).value = a.dataset.theme; syncMode('theme'); go(0); return; }
});
($('#results') as HTMLElement | null)?.addEventListener('keydown', (e: any) => {
  const c = e.target.closest('.card');
  if (c && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); c.click(); }
});

// ---- verify ----
const doVerify = guard(async (qIn: string) => {
  let ang: string | null = null; const m = qIn.match(/@(\d{1,4})\s*$/);  // optional "@123" claims an Ang
  let q = qIn;
  if (m) { ang = m[1]; q = q.replace(/@\d{1,4}\s*$/, '').trim(); }
  const d = await api(`verify?q=${encodeURIComponent(q)}${ang ? `&ang=${ang}` : ''}`);
  const v = d.verdict || '';
  const cls = v.startsWith('VERIFIED') ? 'v-ok' : (v.startsWith('NOT_FOUND') ? 'v-no' : 'v-maybe');
  let h = `<div class="verdict ${cls}">
      <div class="vv">${esc(v.replace(/\+/g, ' + '))}</div>
      <div class="vc">confidence ${(d.confidence * 100).toFixed(1)}%</div>
      <div class="vh">${v.startsWith('VERIFIED') ? 'This is scripture, verified against the canonical corpus.' :
      v.startsWith('NOT_FOUND') ? 'No such line exists in Sri Guru Granth Sahib (this edition). Treat the quote as unverified.' :
        'Close match found — compare carefully below.'}</div></div>`;
  if (d.gurmukhi) {
    h += `<div class="count">Canonical line:</div>
    <div class="card" role="button" tabindex="0" aria-label="Open Ang ${d.ang}" onclick="goReader(${d.ang})">
      <div class="g gm">${esc(d.gurmukhi)}</div>
      <div class="meta"><span class="ang">Ang ${d.ang}</span>
        ${d.raag ? `<span class="gm">${esc(d.raag)}</span>` : ''}
        ${d.author ? `<span>${esc(d.author)}</span>` : ''}</div></div>`;
  }
  ($('#results') as HTMLElement).innerHTML = h; window.scrollTo({ top: 0 });
});

(window as any).go = go;          // for inline "More" button + programmatic calls

// ---- bootstrap from URL (?q= & ?mode=) so theme tiles / verify links deep-link here ----
(function () {
  const p = new URLSearchParams(location.search);
  const qp = p.get('q'); const mp = p.get('mode');
  const VALID = ['auto', 'gurmukhi', 'roman', 'english', 'first', 'theme', 'verify'];
  if (mp && VALID.includes(mp)) syncMode(mp);
  if (qp) { ($('#q') as HTMLInputElement).value = qp; go(0); }
})();
