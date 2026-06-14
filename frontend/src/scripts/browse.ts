// browse.ts — the Index page (/browse) : Major Compositions, the 31 Raags, Banis & Sections.
// Ported 1:1; tiles deep-link into the Reader (or Search, for themes) via goReader/goSearchTheme.
import { $, esc, guard, meta, goReader } from './core';

let META: any = null;
let SECTIONS: any[] | null = null;

// Most-sought compositions live structurally INSIDE a raag, so they aren't "closing
// sections"; this Quick-Access layer routes straight to each one's starting Ang (every
// Ang verified against the section-header line in the corpus).
const QUICK_ACCESS = [
  { gm: 'ਸੁਖਮਨੀ ਸਾਹਿਬ', roman: 'Sukhmani Sahib', ang: 262, where: 'Raag Gauri' },
  { gm: 'ਆਸਾ ਕੀ ਵਾਰ', roman: 'Asa Ki Vaar', ang: 462, where: 'Raag Asa' },
  { gm: 'ਅਨੰਦੁ ਸਾਹਿਬ', roman: 'Anand Sahib', ang: 917, where: 'Raag Ramkali' },
  { gm: 'ਬਾਵਨ ਅਖਰੀ', roman: 'Bavan Akhri', ang: 250, where: 'Raag Gauri' },
  { gm: 'ਸਿਧ ਗੋਸਟਿ', roman: 'Sidh Gosht', ang: 938, where: 'Raag Ramkali' },
  { gm: 'ਓਅੰਕਾਰੁ', roman: 'Dakhni Oankaar', ang: 929, where: 'Raag Ramkali' },
];
// The corpus `sections` table carries "ਚਉਬੋਲੇ" forward across the two standalone
// Bhagat-Salok sections — split it back at the display layer (counts ground-truthed).
const CLOSING_FIX: Record<string, any[]> = {
  'ਚਉਬੋਲੇ': [
    { name: 'ਚਉਬੋਲੇ', first_ang: 1363, last_ang: 1364, n_lines: 24 },
    { name: 'ਸਲੋਕ ਭਗਤ ਕਬੀਰ ਜੀ', first_ang: 1364, last_ang: 1377, n_lines: 494 },
    { name: 'ਸਲੋਕ ਭਗਤ ਫਰੀਦ ਜੀ', first_ang: 1377, last_ang: 1384, n_lines: 298 },
  ],
};
function fixSections(sections: any[]): any[] {
  const out: any[] = [];
  for (const s of sections) {
    if (CLOSING_FIX[s.name]) out.push(...CLOSING_FIX[s.name]);
    else out.push(s);
  }
  return out;
}
const raags = guard(async () => {
  const m = await meta(); META = m;
  ($('#quickOut') as HTMLElement).innerHTML = QUICK_ACCESS.map((c) => `
    <div class="tile" data-ang="${c.ang}" role="button" tabindex="0" aria-label="${esc(c.roman)} — open Ang ${c.ang}">
      <div class="n gm">${esc(c.gm)}</div>
      <div class="r">${esc(c.roman)}</div>
      <div class="s">Ang ${c.ang} · ${esc(c.where)}</div>
    </div>`).join('');
  ($('#raagsOut') as HTMLElement).innerHTML = m.raags.map((r: any, i: number) => `
    <div class="tile" data-raag="${i}" role="button" tabindex="0">
      <div class="seq">RAAG ${r.seq || ''}</div>
      <div class="n gm">${esc(r.name)}</div>
      <div class="r">${esc(r.roman || '')}</div>
      <div class="s">Angs ${r.first_ang}–${r.last_ang} · ${r.n_shabads ?? '—'} compositions · ${r.n_lines} lines</div>
    </div>`).join('');
  SECTIONS = fixSections(m.sections);          // corrected closing-section list (also used by the click handler)
  ($('#sectionsOut') as HTMLElement).innerHTML = SECTIONS.map((s: any, i: number) => `
    <div class="tile" data-section="${i}" role="button" tabindex="0">
      <div class="n gm">${esc(s.name)}</div>
      <div class="s">Angs ${s.first_ang}–${s.last_ang} · ${s.n_lines} lines</div>
    </div>`).join('');
});

// ---- Index sub-navigation: toggle the three panels (display-only; data/cards untouched) ----
function showRaagTab(key: string) {
  const panels: Record<string, string> = { major: 'tab-major', raags: 'tab-raags', sections: 'tab-sections' };
  for (const k in panels) { const el = $('#' + panels[k]); if (el) el.style.display = (k === key) ? '' : 'none'; }
  document.querySelectorAll('#raagTabs span').forEach((s: any) => {
    const on = s.dataset.tab === key;
    s.classList.toggle('on', on);
    s.setAttribute('aria-selected', String(on));
    s.setAttribute('tabindex', on ? '0' : '-1');
  });
}
document.querySelectorAll('#raagTabs span').forEach((s: any) => {
  s.onclick = () => showRaagTab(s.dataset.tab);
  s.onkeydown = (e: KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); showRaagTab(s.dataset.tab); }
    // tabs "follow focus" (cheap — just a display toggle): arrow moves AND activates
    else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { e.preventDefault(); const n = s.nextElementSibling || s.parentElement.firstElementChild; n.focus(); showRaagTab(n.dataset.tab); }
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); const p = s.previousElementSibling || s.parentElement.lastElementChild; p.focus(); showRaagTab(p.dataset.tab); }
  };
});

// ---- delegated tile activation → MPA navigation (no data ever interpolated into handlers) ----
function tileActivate(t: any) {
  if (t.dataset.raag !== undefined) { const r = META.raags[+t.dataset.raag]; goReader(r.first_ang, r.name); }
  else if (t.dataset.ang !== undefined) goReader(+t.dataset.ang);                                 // Quick Access → Ang
  else if (t.dataset.section !== undefined) goReader((SECTIONS || META.sections)[+t.dataset.section].first_ang);
}
document.addEventListener('click', (e: any) => {
  const t = e.target.closest('.tile[data-raag],.tile[data-section],.tile[data-ang]');
  if (t) tileActivate(t);
});
document.addEventListener('keydown', (e: any) => {
  if ((e.key === 'Enter' || e.key === ' ') && e.target.classList?.contains('tile')) {
    e.preventDefault(); tileActivate(e.target);
  }
});

// ---- bootstrap ----
showRaagTab('major');
raags();
