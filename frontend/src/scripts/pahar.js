// pahar.js — pure, DOM-free pahar computation (plain JS so both the Astro
// bundle and the Node test gate `frontend/scripts/test-pahar.mjs` import it).
//
// Convention (fixed-clock): pahar 1 = 06:00–09:00 … pahar 8 = 03:00–06:00,
// eight 3-hour watches anchored at 6 AM. Pahar 7 (00:00–03:00) deliberately
// has no raags — that absence is displayed content, not a gap.
// All arithmetic is integer minutes-since-local-midnight with half-open
// intervals [start, end) — no floats at boundaries. DST days are handled as
// wall-clock by design (a pahar is what the local clock says it is).
//
// Solar mode: sunrise/sunset via the NOAA solar position equations (no
// external API). Traditionally pahars were solar: 4 equal watches of daylight
// (sunrise→sunset) and 4 of night (sunset→next sunrise), so day and night
// pahars stretch and shrink with the season.

const ORD = ['', '1st', '2nd', '3rd', '4th'];

/** minutes-since-local-midnight for a Date (wall clock). */
export function minutesOf(date) {
  return date.getHours() * 60 + date.getMinutes();
}

/** Fixed-clock pahar (1–8) from minutes-since-midnight. */
export function paharFromMinutes(m) {
  return Math.floor((((m - 360) % 1440) + 1440) % 1440 / 180) + 1;
}

/** Fixed-clock pahar (1–8) for a Date (local wall clock). */
export function paharFixed(date) {
  return paharFromMinutes(minutesOf(date));
}

/** Fixed-clock window of a pahar: [startMin, endMin) since midnight (end may wrap). */
export function paharWindow(p) {
  const start = (360 + (p - 1) * 180) % 1440;
  return { start, end: (start + 180) % 1440 };
}

/** "1st pahar of day" … "4th pahar of night". */
export function paharLabel(p) {
  return p <= 4 ? `${ORD[p]} pahar of day` : `${ORD[p - 4]} pahar of night`;
}

/** '15:00' → '3 PM' (whole hours stay terse; minutes kept when present). */
export function fmt12(hhmm) {
  if (!hhmm) return '';
  const [h, m] = hhmm.split(':').map(Number);
  const h24 = h % 24;
  const ap = h24 < 12 ? 'AM' : 'PM';
  const h12 = h24 % 12 || 12;
  return m ? `${h12}:${String(m).padStart(2, '0')} ${ap}` : `${h12} ${ap}`;
}

/** Fixed-clock range of a pahar as e.g. "3–6 PM" / "9 PM–12 AM". */
export function paharRange(p) {
  const { start, end } = paharWindow(p);
  const f = (min) => fmt12(`${Math.floor(min / 60)}:${String(min % 60).padStart(2, '0')}`);
  const a = f(start), b = f(end);
  const [ah, aap] = a.split(' '), [bh, bap] = b.split(' ');
  return aap === bap ? `${ah}–${bh} ${bap}` : `${a}–${b}`;
}

/**
 * NOAA sunrise/sunset (minutes since local midnight).
 * tzOffsetMin follows Date.getTimezoneOffset() convention (UTC+5:30 → -330);
 * defaults to the machine's offset for the given date. Returns
 * { sunrise, sunset, polar } — polar=true when the sun never rises/sets
 * (|lat| high); callers must fall back to fixed mode then.
 */
export function sunTimes(date, lat, lon, tzOffsetMin) {
  const tz = tzOffsetMin === undefined ? date.getTimezoneOffset() : tzOffsetMin;
  const rad = Math.PI / 180;
  const start = new Date(date.getFullYear(), 0, 0);
  const doy = Math.floor((date - start) / 86400000);
  const g = (2 * Math.PI / 365) * (doy - 1 + (12 - 12) / 24);
  const eqtime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
    - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
  const decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g)
    - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g)
    - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
  const cosHa = (Math.cos(90.833 * rad) / (Math.cos(lat * rad) * Math.cos(decl)))
    - Math.tan(lat * rad) * Math.tan(decl);
  if (cosHa < -1 || cosHa > 1) return { sunrise: null, sunset: null, polar: true };
  const haDeg = Math.acos(cosHa) / rad;
  const wrap = (m) => ((m % 1440) + 1440) % 1440;
  const sunriseUtc = 720 - 4 * (lon + haDeg) - eqtime;   // minutes UTC
  const sunsetUtc = 720 - 4 * (lon - haDeg) - eqtime;
  return {
    sunrise: Math.round(wrap(sunriseUtc - tz)),
    sunset: Math.round(wrap(sunsetUtc - tz)),
    polar: false,
  };
}

/**
 * Solar pahar (1–8): 4 equal watches sunrise→sunset, 4 sunset→next sunrise.
 * m = minutes since local midnight. Half-open intervals; sunrise itself is
 * pahar 1, sunset itself is pahar 5.
 */
export function paharSolar(m, sunrise, sunset) {
  const dayLen = ((sunset - sunrise) % 1440 + 1440) % 1440;
  const nightLen = 1440 - dayLen;
  const sinceSunrise = ((m - sunrise) % 1440 + 1440) % 1440;
  if (sinceSunrise < dayLen) {
    return 1 + Math.min(3, Math.floor(sinceSunrise * 4 / dayLen));
  }
  const sinceSunset = sinceSunrise - dayLen;
  return 5 + Math.min(3, Math.floor(sinceSunset * 4 / nightLen));
}

/** Solar window [start, end) in minutes-since-midnight for pahar p. */
export function paharSolarWindow(p, sunrise, sunset) {
  const wrap = (m) => ((m % 1440) + 1440) % 1440;
  const dayLen = wrap(sunset - sunrise);
  const nightLen = 1440 - dayLen;
  if (p <= 4) {
    return { start: wrap(sunrise + Math.round((p - 1) * dayLen / 4)),
             end: wrap(sunrise + Math.round(p * dayLen / 4)) };
  }
  return { start: wrap(sunset + Math.round((p - 5) * nightLen / 4)),
           end: wrap(sunset + Math.round((p - 4) * nightLen / 4)) };
}

/** Minutes until the next pahar boundary (and which pahar starts there). */
export function nextPaharBoundary(m, mode, sunrise, sunset) {
  const cur = mode === 'solar' ? paharSolar(m, sunrise, sunset) : paharFromMinutes(m);
  const next = cur % 8 + 1;
  const win = mode === 'solar'
    ? paharSolarWindow(next, sunrise, sunset)
    : paharWindow(next);
  const wait = ((win.start - m) % 1440 + 1440) % 1440;
  return { nextPahar: next, minutes: wait === 0 ? 1440 : wait };
}

/** Primary-claim raags active in pahar p, from the /api/timing/clock payload. */
export function raagsForPahar(clock, p) {
  if (!clock || !clock.claims) return [];
  return (clock.claims.primary || []).filter((c) => c.pahar === p);
}
