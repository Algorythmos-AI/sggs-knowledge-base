// panel.ts — the shared composition modal (#panel) loaded on every page:
// renders a full shabad/composition, the Hukam-style random draw, focus-trap + a11y.
// Logic is ported 1:1 from the original index.html (only the "Open Ang" action is
// adapted to MPA navigation via goReader instead of in-page nav()/ang()).
import { $, esc, api, guard } from './core';

function panelLines(lines: any[]): string {
  return lines.map((l: any) => `<div class="sline ${l.is_rahao ? 'rahao' : ''}">
      <div class="g gm ${l.is_header && l.gurmukhi.startsWith('ੴ') ? 'invoc' : ''}" style="${l.is_header ? 'color:var(--gold);font-weight:600;text-align:center' : ''}">${esc(l.gurmukhi)}</div>
      <div class="t" style="${l.is_header ? 'text-align:center' : ''}">${esc(l.translit)}</div>
      ${l.en ? `<div class="en" lang="en">${esc(l.en)}</div>` : ''}</div>`).join('');
}
// Synthesize a composition title from the metadata every line carries — robust for ALL
// shabads, even when the section's title header (e.g. ਸਲੋਕ ਮਹਲਾ ੪) sits outside the unit.
function compTitle(lines: any[]): { main: string; sub: string; ang: any } {
  const b = lines.find((l: any) => !l.is_header) || lines[0] || {};
  const ang = (lines[0] || {}).ang || b.ang || '';
  // raag or section only — comp_type is unreliable in the source (Japji mislabeled ਰੁਤੀ,
  // shabads mislabeled ਪਉੜੀ), so we never surface it as a title.
  const main = b.raag || b.section || '';
  // Japji carries no author field in the source, but it is wholly Guru Nanak Dev Ji — show it
  // rather than leaving the title's byline blank.
  const author = b.author || (b.section === 'ਜਪੁ' ? 'Guru Nanak Dev Ji (M1)' : '');
  const sub = [author, ang ? ('Ang ' + ang) : ''].filter(Boolean).join('  ·  ');
  return { main, sub, ang };
}
function titleBlock(lines: any[]): string {
  const t = compTitle(lines);
  if (!t.main && !t.sub) return '';
  return `<div style="text-align:center;margin:0 0 18px;padding-bottom:14px;border-bottom:1px solid var(--line)">
    ${t.main ? `<div class="gm" style="color:var(--gold);font-size:20px;font-weight:600">${esc(t.main)}</div>` : ''}
    ${t.sub ? `<div style="color:var(--soft);font-size:12.5px;margin-top:4px">${esc(t.sub)}</div>` : ''}</div>`;
}

// ---- open / close with focus save+restore ----
let _panelTrigger: any = null;
export function openPanel() {
  _panelTrigger = document.activeElement;                          // remember where focus was
  $('#panel')?.classList.add('on');
  setTimeout(() => { const x = $('#panel .x'); if (x) x.focus(); }, 0); // move focus into the dialog
}
export function closePanel() {
  $('#panel')?.classList.remove('on');
  if (_panelTrigger && _panelTrigger.focus) _panelTrigger.focus();  // return focus to the trigger
  _panelTrigger = null;
}

const setP = (title: string, body: string) => {
  const pt = $('#ptitle'); if (pt) pt.textContent = title;
  const pb = $('#pbody'); if (pb) pb.innerHTML = body;
};

// ---- a full composition by composition id (hi kept for signature parity; unused) ----
export const shabad = guard(async (cid: number, _hi?: number) => {
  openPanel();
  setP('Loading…', '<div class="hint">Loading composition…</div>');
  const d = await api('shabad/' + cid);
  const ang = (d.lines[0] || {}).ang || '';
  setP(`Composition · Ang ${ang}`,
    titleBlock(d.lines) + panelLines(d.lines) +
    `<div class="endnav" style="margin-top:16px"><span></span>
      <button onclick="goReader(${ang || 1})">Open Ang ${ang} ›</button></div>`);
});

// ---- Hukam-style random draw ----
let randomLoading = false;
export const randomShabad = guard(async () => {
  if (randomLoading) return;                                       // ignore rapid 'Another' taps
  randomLoading = true;
  openPanel();
  setP('Loading…', '<div class="hint">Drawing a composition…</div>');
  try {
    const d = await api('random');
    const ang = (d.lines[0] || {}).ang || '';
    setP(`Hukam-style random · Ang ${ang}`,
      titleBlock(d.lines) + panelLines(d.lines) +
      `<div class="endnav" style="margin-top:16px"><button onclick="randomShabad()">Another ↻</button>
        <button onclick="goReader(${ang || 1})">Open Ang ${ang} ›</button></div>`);
  } finally { randomLoading = false; }
});

// ---- wire panel interactions (every page) ----
const panel = $('#panel');
if (panel) {
  panel.addEventListener('click', (e: any) => { if (e.target.id === 'panel') closePanel(); });
  // focus trap: keep Tab inside the dialog while it is open (WCAG 2.1.2)
  panel.addEventListener('keydown', (e: any) => {
    if (e.key !== 'Tab' || !panel.classList.contains('on')) return;
    const inner = panel.querySelector('.inner');
    if (!inner) return;
    const f = Array.from(inner.querySelectorAll('button,[href],input,[tabindex]:not([tabindex="-1"])'))
      .filter((el: any) => el.offsetParent !== null) as HTMLElement[];
    if (!f.length) return;
    const first = f[0], last = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  });
}
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && $('#panel')?.classList.contains('on')) closePanel();
});

// Hukam-style random button lives in the shared nav on every page.
const rb = document.getElementById('randomBtn');
if (rb) rb.onclick = () => randomShabad();

// expose for inline onclick in dynamically-rendered HTML + cross-page modal reuse
(window as any).shabad = shabad;
(window as any).randomShabad = randomShabad;
(window as any).closePanel = closePanel;
(window as any).openPanel = openPanel;       // lineage page reuses the shared modal (focus save/restore)
