// core.ts — shared across every MPA page: DOM helpers, API, store, toast, META cache,
// theme (light/dark/system), nav active-state, cross-page navigation, prefs, footer.
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

export const guard = (fn: (...a: any[]) => Promise<any>) =>
  async (...a: any[]) => { try { return await fn(...a); } catch (e) { console.error(e); } };

// META cached in sessionStorage → one /api/meta per browser session across pages.
let META: any = null;
export async function meta(): Promise<any> {
  if (META) return META;
  try { const s = sessionStorage.getItem('sggs_meta'); if (s) { META = JSON.parse(s); return META; } } catch {}
  META = await api('meta');
  try { sessionStorage.setItem('sggs_meta', JSON.stringify(META)); } catch {}
  return META;
}

// ---- theme: light / dark / system, resolved to data-theme on <html> ----
type Theme = 'light' | 'dark' | 'system';
const ICON: Record<Theme, string> = { light: '☀', dark: '☾', system: '◐' };
const resolve = (t: Theme): 'light' | 'dark' =>
  t === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : t;
export function applyTheme(t: Theme) {
  document.documentElement.setAttribute('data-theme', resolve(t));
  const b = document.getElementById('themeBtn');
  if (b) { b.textContent = ICON[t]; b.setAttribute('aria-label', `Theme: ${t} — click to change`); b.title = `Theme: ${t}`; }
}
function initTheme() {
  applyTheme(store.get('theme', 'system') as Theme);
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (store.get('theme', 'system') === 'system') applyTheme('system');
  });
  const b = document.getElementById('themeBtn');
  if (b) b.onclick = () => {
    const order: Theme[] = ['system', 'light', 'dark'];
    const next = order[(order.indexOf(store.get('theme', 'system') as Theme) + 1) % order.length];
    store.set('theme', next); applyTheme(next);
  };
}

// ---- cross-page navigation (MPA) ----
export function goReader(ang: number, raag?: string) {
  location.href = '/reader?ang=' + ang + (raag ? '&raag=' + encodeURIComponent(raag) : '');
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

// shared init (module scripts are deferred → DOM is ready)
initTheme();
applyPrefs();
markNav();
syncToolbarTop();
window.addEventListener('resize', syncToolbarTop);
initFooter();
