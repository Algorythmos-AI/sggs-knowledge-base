// timing.ts — shared client cache for the raag-timing knowledge layer.
// One /api/timing/clock fetch per browser session (sessionStorage, version-
// keyed so an APP_VERSION bump invalidates it), shared by the Raag Clock page
// and the reader's timing chip. Returns {available:false} payloads untouched
// so callers degrade gracefully.
import { api, meta } from './core';

let CLOCK: any = null;

export async function loadClock(): Promise<any> {
  if (CLOCK) return CLOCK;
  const m = await meta();
  const key = 'sggs_timing_v' + (m.version || '0');
  try { const s = sessionStorage.getItem(key); if (s) { CLOCK = JSON.parse(s); return CLOCK; } } catch {}
  CLOCK = await api('timing/clock');
  try { sessionStorage.setItem(key, JSON.stringify(CLOCK)); } catch {}
  return CLOCK;
}

/** All claims for one raag (by Gurmukhi name), grouped by type. */
export function claimsFor(clock: any, raagName: string) {
  if (!clock?.available) return null;
  const pick = (t: string) => (clock.claims[t] || []).filter((c: any) => c.raag_name === raagName);
  const all = { primary: pick('primary'), variant: pick('variant'),
                seasonal: pick('seasonal'), ceremonial: pick('ceremonial') };
  return (all.primary.length || all.variant.length || all.seasonal.length || all.ceremonial.length) ? all : null;
}
