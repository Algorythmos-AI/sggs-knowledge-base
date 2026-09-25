// <sggs-api-try> needs the API's shape: at build time the route list is read from
// contract/openapi.json (the spec generated from real responses) and embedded as JSON inside the
// element, so the console can build a parameter form for any route without fetching the spec.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { visit } from 'unist-util-visit';
import { REPO_ROOT } from './paths.mjs';

const TAG = /^<sggs-api-try((?:\s+[a-z-]+="[^"]*")*)\s*>\s*<\/sggs-api-try>$/;

/** The compact route list the widget needs: path, summary, tag, parameters (schema kept), samples. */
export function compactSpec(spec) {
  const routes = [];
  for (const [p, ops] of Object.entries(spec.paths ?? {})) {
    const op = ops.get;
    if (!op) continue;
    routes.push({
      path: p, summary: op.summary ?? '', tag: (op.tags ?? [])[0] ?? '',
      params: (op.parameters ?? []).map((q) => ({ name: q.name, in: q.in, required: !!q.required, description: q.description ?? '', schema: q.schema ?? {} })),
      samples: (op['x-samples'] ?? []).slice(0, 3),
    });
  }
  routes.sort((a, b) => a.path.localeCompare(b.path));
  return { title: spec.info?.title ?? 'API', version: spec.info?.version ?? '', origin: (spec.servers ?? [])[0]?.url ?? '', routes };
}

export function apiTryHtml(attrs, spec) {
  const json = JSON.stringify(compactSpec(spec)).replace(/</g, '\\u003c');
  return `<sggs-api-try${attrs}><script type="application/json" class="api-try__spec">${json}</script></sggs-api-try>`;
}

export function remarkApiTry(options = {}) {
  const specPath = options.spec ?? path.join(REPO_ROOT, 'contract', 'openapi.json');
  let spec = null;
  return (tree) => {
    visit(tree, 'html', (node) => {
      const m = TAG.exec(node.value.trim());
      if (!m) return;
      spec ??= JSON.parse(readFileSync(specPath, 'utf8'));
      node.value = apiTryHtml(m[1], spec);
    });
  };
}
