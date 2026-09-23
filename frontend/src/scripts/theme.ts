// theme.ts — light / dark / system theme toggle, resolved to data-theme on <html>.
// Moved verbatim out of core.ts so it can be reused by the marketing shell without pulling in
// the Knowledge Base's DOM/API helpers. Self-contained: its own try/catch localStorage of key
// 'theme' (must NOT import core.ts). Behaviour is identical to the original core.ts block:
// #themeBtn, glyphs ☀/☾/◐, cycle order system→light→dark, aria-label/title.
//
// The theme used when the reader has made NO explicit choice is a per-shell default: the
// Knowledge Base keeps 'system' (the module default), while the marketing shell calls
// setDefaultTheme('light') before initTheme() so gurbanisoul.com is light-first regardless of the
// OS appearance. The stored key is only ever written by an explicit click, never by the default.
type Theme = 'light' | 'dark' | 'system';

let DEFAULT: Theme = 'system';
/** Set the theme used when nothing is stored. Call BEFORE initTheme(). */
export function setDefaultTheme(t: Theme) { DEFAULT = t; }

const readTheme = (): Theme => {
  try { return (localStorage.getItem('theme') as Theme) || DEFAULT; } catch { return DEFAULT; }
};
const writeTheme = (t: Theme) => { try { localStorage.setItem('theme', t); } catch {} };

const ICON: Record<Theme, string> = { light: '☀', dark: '☾', system: '◐' };
// Browser-chrome colour for pages that pin a single theme-color meta (the marketing shell's
// <meta id="themeColorMeta">): it follows the PAGE theme, not the OS.
const CHROME: Record<'light' | 'dark', string> = { light: '#FBF7F0', dark: '#171412' };
const resolve = (t: Theme): 'light' | 'dark' =>
  t === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : t;
export function applyTheme(t: Theme) {
  const r = resolve(t);
  document.documentElement.setAttribute('data-theme', r);
  const meta = document.getElementById('themeColorMeta');
  if (meta) meta.setAttribute('content', CHROME[r]);
  const b = document.getElementById('themeBtn');
  if (b) { b.textContent = ICON[t]; b.setAttribute('aria-label', `Theme: ${t} — click to change`); b.title = `Theme: ${t}`; }
}
export function initTheme() {
  applyTheme(readTheme());
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (readTheme() === 'system') applyTheme('system');
  });
  const b = document.getElementById('themeBtn');
  if (b) b.onclick = () => {
    const order: Theme[] = ['system', 'light', 'dark'];
    const next = order[(order.indexOf(readTheme()) + 1) % order.length];
    writeTheme(next); applyTheme(next);
  };
}
