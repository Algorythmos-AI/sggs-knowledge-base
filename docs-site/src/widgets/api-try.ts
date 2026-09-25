// <sggs-api-try route="/api/ang/{n}">: a try-it console. The route list and each route's parameters
// come from contract/openapi.json, embedded at build (plugins/remark-api-try.mjs). Requests go to
// the same origin (/api is rewritten to the production API), so the CSP's connect-src 'self'
// holds. The response is shown as JSON with the headers that matter, plus the equivalent curl.
import { el } from './api';
import { chip } from './shared';

type Param = { name: string; in: 'path' | 'query'; required: boolean; description: string; schema: { type?: string; enum?: string[]; minimum?: number; maximum?: number; default?: unknown; pattern?: string; maxLength?: number } };
type Route = { path: string; summary: string; tag: string; params: Param[]; samples: unknown[] };
type Spec = { title: string; version: string; origin: string; routes: Route[] };

const PUBLIC_ORIGIN = 'https://gurbanisoul.com';
const EXAMPLE: Record<string, Record<string, string>> = {
  '/api/ang/{n}': { n: '712' }, '/api/shabad/{comp_id}': { comp_id: '2' }, '/api/search': { q: 'sat nam', limit: '5' },
  '/api/verify': { q: 'sochai soch na hovai je sochi lakh vaar', ang: '1' }, '/api/word': { w: 'ਸਚੁ' }, '/api/lines': { ids: '1,2,3' },
  '/api/bani/{key}': { key: 'japji' }, '/api/analytics/vaar': { id: '1' }, '/api/related': { comp_id: '2' }, '/api/line_concepts': { ids: '10,11,12' },
  '/api/neighbors': { line_id: '100', limit: '5' }, '/api/timing/raag': { name: 'todi' }, '/api/forms': { comp_id: '2' },
  '/api/analytics/progression': { raag: 'ਆਸਾ' }, '/api/analytics/constellation': { concept: 'naam' }, '/api/themes/network': { limit: '20' },
};
const SHOW_HEADERS = ['content-type', 'cache-control', 'etag', 'x-service', 'x-request-id'];
const MAX_BODY = 40_000;

export class SggsApiTry extends HTMLElement {
  private spec: Spec | null = null;
  private select!: HTMLSelectElement;
  private fields!: HTMLElement;
  private url!: HTMLElement;
  private curl!: HTMLElement;
  private status!: HTMLElement;
  private out!: HTMLElement;
  private seq = 0;

  connectedCallback() {
    const json = this.querySelector<HTMLScriptElement>('script.api-try__spec');
    try { this.spec = json ? JSON.parse(json.textContent || 'null') : null; } catch { this.spec = null; }
    if (!this.spec?.routes?.length) return;
    const form = el('form', { class: 'at__form', 'aria-label': 'API console' });
    const id = `at-${Math.random().toString(36).slice(2, 8)}`;
    this.select = el('select', { id, class: 'at__route' }) as HTMLSelectElement;
    for (const r of this.spec.routes) this.select.append(el('option', { value: r.path }, [`${r.path} — ${r.summary}`.slice(0, 110)]));
    const want = this.getAttribute('route');
    if (want && this.spec.routes.some((r) => r.path === want)) this.select.value = want;
    this.select.addEventListener('change', () => this.buildFields());
    this.fields = el('div', { class: 'at__fields' });
    this.url = el('code', { class: 'at__url' });
    const send = el('button', { type: 'submit', class: 'wt__btn at__send' }, ['Send request']);
    const copy = el('button', { type: 'button', class: 'wt__btn at__copy' }, ['Copy as curl']);
    copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(this.curlText()); copy.textContent = 'Copied'; setTimeout(() => (copy.textContent = 'Copy as curl'), 1500); } catch { copy.textContent = 'Select the command below'; } });
    this.curl = el('code', { class: 'at__curl' });
    form.append(el('label', { for: id, class: 'at__label' }, ['Route']), this.select, this.fields, el('div', { class: 'at__urlrow' }, [el('span', { class: 'at__label' }, ['GET ']), this.url]), el('div', { class: 'at__actions' }, [send, copy]), el('pre', { class: 'at__curlpre' }, [this.curl]));
    form.addEventListener('submit', (e) => { e.preventDefault(); this.send(); });
    form.addEventListener('input', () => this.refresh());
    this.status = el('p', { class: 'at__status', role: 'status', 'aria-live': 'polite' }, ['Read-only. The request is sent from your browser to the production API through this site.']);
    this.out = el('div', { class: 'at__out' });
    this.replaceChildren(form, this.status, this.out);
    this.buildFields();
  }

  private route(): Route { return this.spec!.routes.find((r) => r.path === this.select.value)!; }

  private buildFields() {
    const r = this.route();
    this.fields.replaceChildren();
    const ex = EXAMPLE[r.path] ?? {};
    for (const p of r.params) {
      const fid = `atf-${p.name}-${Math.random().toString(36).slice(2, 6)}`;
      const wrap = el('div', { class: 'at__field' });
      const label = el('label', { for: fid, class: 'at__label' }, [el('code', {}, [p.name]), p.in === 'path' ? ' (path)' : p.required ? ' (required)' : ' (optional)']);
      let input: HTMLInputElement | HTMLSelectElement;
      if (p.schema.enum) {
        input = el('select', { id: fid, name: p.name, class: 'at__input' }) as HTMLSelectElement;
        if (!p.required) input.append(el('option', { value: '' }, ['(omit)']));
        for (const v of p.schema.enum) input.append(el('option', { value: v }, [v]));
        if (p.schema.default != null) input.value = String(p.schema.default);
      } else {
        input = el('input', { id: fid, name: p.name, class: 'at__input', type: p.schema.type === 'integer' || p.schema.type === 'number' ? 'number' : 'text' }) as HTMLInputElement;
        if (p.schema.minimum != null) input.min = String(p.schema.minimum);
        if (p.schema.maximum != null) input.max = String(p.schema.maximum);
        if (p.schema.maxLength != null) input.maxLength = p.schema.maxLength;
      }
      const v = ex[p.name] ?? (p.in === 'path' ? String(p.schema.default ?? p.schema.minimum ?? '1') : '');
      if (v) input.value = v;
      if (p.required) input.setAttribute('required', 'true');
      wrap.append(label, input, el('small', { class: 'at__desc' }, [p.description]));
      this.fields.append(wrap);
    }
    this.refresh();
  }

  private path(): string | null {
    const r = this.route();
    let path = r.path;
    const qs = new URLSearchParams();
    for (const p of r.params) {
      const v = (this.fields.querySelector(`[name="${p.name}"]`) as HTMLInputElement | null)?.value.trim() ?? '';
      if (p.in === 'path') { if (!v) return null; path = path.replace(`{${p.name}}`, encodeURIComponent(v)); }
      else if (v) qs.set(p.name, v);
    }
    const q = qs.toString();
    return q ? `${path}?${q}` : path;
  }

  private curlText(): string { const p = this.path(); return p ? `curl -s '${PUBLIC_ORIGIN}${p}'` : ''; }

  private refresh() {
    const p = this.path();
    this.url.textContent = p ?? '(fill in the path parameter)';
    this.curl.textContent = this.curlText();
  }

  private async send() {
    const p = this.path();
    if (!p) return;
    const my = ++this.seq;
    this.status.textContent = `GET ${p} …`;
    this.out.replaceChildren();
    const t0 = performance.now();
    try {
      const r = await fetch(p, { headers: { Accept: 'application/json' } });
      const ms = Math.round(performance.now() - t0);
      const text = await r.text();
      if (my !== this.seq) return;
      let body = text;
      try { body = JSON.stringify(JSON.parse(text), null, 2); } catch { /* not JSON: show as is */ }
      const truncated = body.length > MAX_BODY;
      this.status.textContent = `HTTP ${r.status} in ${ms} ms · ${text.length.toLocaleString()} bytes${truncated ? ' (first 40 KB shown)' : ''}`;
      const head = el('div', { class: 'at__headers' });
      head.append(chip(`${r.status} ${r.statusText}`.trim(), r.ok ? 'chip--ok' : 'chip--bad'));
      for (const h of SHOW_HEADERS) { const v = r.headers.get(h); if (v) head.append(chip(`${h}: ${v}`)); }
      const pre = el('pre', { class: 'at__body', tabindex: '0', role: 'region', 'aria-label': 'Response body' }, [el('code', {}, [truncated ? body.slice(0, MAX_BODY) + '\n…' : body])]);
      this.out.append(head, pre);
    } catch {
      if (my !== this.seq) return;
      this.status.textContent = 'The API is not reachable from here right now.';
    }
  }
}
