// Same-origin API access for the widgets: /api/* is rewritten to the public API (docs-site/vercel.json)
// and proxied to a local serve.py in development. Read-only; failures resolve to null so a widget
// can fall back to its static text.
export async function api<T = unknown>(path: string, init: RequestInit = {}): Promise<T | null> {
  try {
    const ctl = new AbortController();
    const t = setTimeout(() => ctl.abort(), 12_000);
    const r = await fetch(path, { ...init, signal: ctl.signal, headers: { Accept: 'application/json', ...(init.headers ?? {}) } });
    clearTimeout(t);
    if (!r.ok) return null;
    return (await r.json()) as T;
  } catch {
    return null;
  }
}

export const el = (tag: string, attrs: Record<string, string> = {}, children: (Node | string)[] = []) => {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
  for (const c of children) n.append(c);
  return n;
};
