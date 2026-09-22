// core.ts — shared across every MPA page: DOM helpers, API, store, toast, META cache,
// theme (light/dark/system), nav active-state, cross-page navigation, prefs, footer.
// The theme toggle lives in ./theme (shared with the marketing shell); core just wires it up.
import { initTheme } from './theme';
export { applyTheme } from './theme';
export const $ = (s: string) => document.querySelector(s) as HTMLElement | null;
export const esc = (s: any) =>
  (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export const store = {
  get: (k: string, d?: any) => { try { return localStorage.getItem(k) ?? d; } catch { return d; } },
  set: (k: string, v: any) => { try { localStorage.setItem(k, String(v)); } catch {} },
};

let toastTimer: any = null;
export function toast(msg: string) {
  const t = $('#toast'); if (!t) return;
  t.textContent = msg; t.classList.add('on');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('on'), 3200);
}

export async function api(p: string): Promise<any> {
  let r: Response;
  try { r = await fetch('/api/' + p); }
  catch (e) { toast('Cannot reach the app — is serve.py still running?'); throw e; }
  if (!r.ok) {
    let m = 'Request failed (' + r.status + ')';
    try { m = (await r.json()).error || m; } catch {}
    toast(m); throw new Error(m);
  }
  return r.json();
}

// `onFail` lets a page replace its "Loading…" placeholder with an honest error line instead
// of leaving the pane stuck (api() already showed a toast).
export const guard = (fn: (...a: any[]) => Promise<any>, onFail?: (e: any) => void) =>
  async (...a: any[]) => { try { return await fn(...a); } catch (e) { console.error(e); try { onFail?.(e); } catch {} } };
export const failHTML = (what = 'This section') =>
  `<div class="hint">${what} could not be loaded — is serve.py still running? Reload to try again.</div>`;

// Honour the OS "reduce motion" setting for JS-driven animation (D3 transitions / force
// layout). The global CSS rule only covers CSS transitions; D3 runs its own animation loop.
export const prefersReducedMotion = () => {
  try { return matchMedia('(prefers-reduced-motion: reduce)').matches; } catch { return false; }
};

// relatedness band for semantic-neighbour scores (true cosine, 0–1) — used by the
// Trail stones and the Reader's "Related Verses". Calibrated, not a raw percentage.
export function relBand(score: number) {
  const p = Math.round((score || 0) * 100);
  if (score >= 0.65) return { p, label: 'Strong echo', cls: 'strong' };
  if (score >= 0.45) return { p, label: 'Related', cls: 'mid' };
  return { p, label: 'Faint echo', cls: 'faint' };
}
export const relChip = (score: number) => {
  const b = relBand(score);
  return `<span class="relband relband-${b.cls}"><i aria-hidden="true"></i>${b.label}<span class="pct">${b.p}%</span></span>`;
};

// META cached in sessionStorage → one /api/meta per browser session across pages.
let META: any = null;
export async function meta(): Promise<any> {
  if (META) return META;
  try { const s = sessionStorage.getItem('sggs_meta'); if (s) { META = JSON.parse(s); return META; } } catch {}
  META = await api('meta');
  try { sessionStorage.setItem('sggs_meta', JSON.stringify(META)); } catch {}
  return META;
}

// ---- theme: light / dark / system — see ./theme (initTheme called in shared init below) ----

// ---- cross-page navigation (MPA) ----
// opts.line / opts.comp: land the Reader on a specific verse / composition (scrolled + highlighted)
export function goReader(ang: number, raag?: string, opts?: { line?: number; comp?: number }) {
  let u = '/reader?ang=' + ang + (raag ? '&raag=' + encodeURIComponent(raag) : '');
  if (opts?.line) u += '&line=' + opts.line; else if (opts?.comp) u += '&comp=' + opts.comp;
  location.href = u;
}
export function goSearchTheme(concept: string) {
  location.href = '/?q=' + encodeURIComponent(concept) + '&mode=theme';
}

// ---- per-page nav active state ----
function markNav() {
  const path = (location.pathname.replace(/\/+$/, '') || '/');
  document.querySelectorAll('nav a[data-path]').forEach((a: any) => {
    const on = a.getAttribute('data-path') === path;
    a.classList.toggle('on', on);
    a.setAttribute('aria-current', on ? 'page' : 'false');
  });
}

// ---- user prefs applied on every page (translit hidden + Gurmukhi font size) ----
export function applyPrefs() {
  if (store.get('show_t', '1') === '0') document.body.classList.add('hide-t');
  if (store.get('show_timing', '1') === '0') document.body.classList.add('hide-timing');  // raag timing chip, default ON
  const gs = parseInt(store.get('gsize', '22')); if (gs) document.documentElement.style.setProperty('--gsize', gs + 'px');
}

// ---- sticky reader toolbar below the (wrapping) nav ----
export function syncToolbarTop() {
  const n = document.querySelector('nav');
  if (n) document.documentElement.style.setProperty('--nav-h', (n as HTMLElement).getBoundingClientRect().height + 'px');
}

async function initFooter() {
  try {
    const m = await meta();
    const ver = document.getElementById('ver');
    if (ver && m.version) {
      ver.textContent = ' · v' + m.version + ' (' + (m.built || '') + ')';
      if (parseInt(m.translations_en || '0') > 0) ver.textContent += ' · EN: Dr. Sant Singh Khalsa (via BaniDB)';
    }
  } catch {}
}

(window as any).goReader = goReader;          // for inline handlers in rendered HTML
// delegated alternative to inline onclick="goReader(n,'name')": raag names are DB text and
// must never be spliced into a JS string literal — carry them as data attributes instead.
document.addEventListener('click', (e: any) => {
  const b = e.target?.closest?.('[data-go-ang]');
  if (b) {
    e.preventDefault();
    goReader(+b.dataset.goAng || 1, b.dataset.goRaag || undefined,
      { line: +b.dataset.goLine || undefined, comp: +b.dataset.goComp || undefined });
  }
});

// shared init (module scripts are deferred → DOM is ready)
initTheme();
applyPrefs();
markNav();
syncToolbarTop();
window.addEventListener('resize', syncToolbarTop);
initFooter();
