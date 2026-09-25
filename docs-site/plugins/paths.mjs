// Where a wiki page comes from and where it is published — the one mapping shared by the
// content collection (src/content.config.ts), the link rewriter (remark-repo-links) and the
// edit links. tools/docs_check.py mirrors these rules in Python; keep the two in step.
//
//   docs/README.md                         -> id "index"          -> /
//   docs/<dir>/README.md                   -> id "<dir>"          -> /<dir>/      (Astro's index convention)
//   docs/<dir>/<page>.md                   -> id "<dir>/<page>"   -> /<dir>/<page>/
//   docs-site/.sources/<repo>/docs/<p>.md  -> id "<alias>/<p>"    -> /<alias>/<p>/   (pinned sibling docs)
//   docs-site/.sources/<repo>/<file>.md    -> id "<alias>/<file>" (a root document such as Answer-Protocol.md)
//
// Pages under docs/reports/archive and docs/design are history: linked, never published.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

// The site directory is found from the working directory, not from import.meta.url: at render
// time this module lives in a bundled chunk under dist/, but `astro build`/`astro dev`/`vercel
// build` always run with docs-site (or the repository root) as the working directory.
function findSiteDir() {
  let dir = process.cwd();
  for (let i = 0; i < 6; i++) {
    if (existsSync(path.join(dir, 'sources.lock.json')) && existsSync(path.join(dir, 'astro.config.mjs'))) return dir;
    if (existsSync(path.join(dir, 'docs-site', 'sources.lock.json'))) return path.join(dir, 'docs-site');
    dir = path.dirname(dir);
  }
  throw new Error('docs-site not found from ' + process.cwd());
}
export const SITE_DIR = findSiteDir();
export const REPO_ROOT = path.resolve(SITE_DIR, '..');
export const PLATFORM_REPO = 'Algorythmos-AI/sggs-platform';
export const PLATFORM_REF = 'integration';
export const SOURCES_DIR = 'docs-site/.sources';
export const NOT_PUBLISHED = ['docs/reports/archive/', 'docs/design/'];
// pages the site generates rather than reads from docs/ (starlight-openapi); tools/docs_check.py has the same map
export const VIRTUAL_PAGES = { 'docs/api/reference': '/api/reference/' };

/** The pinned sibling sources: { <repo name>: { repository, commit, alias, ... } }. */
export function loadSources() {
  const lock = JSON.parse(readFileSync(path.join(SITE_DIR, 'sources.lock.json'), 'utf8'));
  return lock.sources ?? {};
}

const toPosix = (p) => p.split(path.sep).join('/');

/**
 * Which tree a repo-relative path belongs to.
 * @returns {{kind:'platform'}|{kind:'sibling', name:string, repository:string, ref:string, commit:string, alias:string, rel:string}|null}
 */
export function originOf(repoRel, sources = loadSources()) {
  repoRel = toPosix(repoRel);
  if (repoRel.startsWith(SOURCES_DIR + '/')) {
    const rest = repoRel.slice(SOURCES_DIR.length + 1);
    const name = rest.split('/')[0];
    const src = sources[name];
    if (!src) return null;
    return { kind: 'sibling', name, repository: src.repository, ref: src.ref ?? 'main', commit: src.commit, alias: src.alias, rel: rest.slice(name.length + 1) };
  }
  return { kind: 'platform' };
}

/** The collection id for a repo-relative Markdown path, or null when the file is not published. */
export function idForRepoPath(repoRel, sources = loadSources()) {
  repoRel = toPosix(repoRel);
  if (!repoRel.endsWith('.md')) return null;
  let id;
  if (repoRel.startsWith('docs/')) {
    if (NOT_PUBLISHED.some((p) => repoRel.startsWith(p))) return null;
    id = repoRel.slice('docs/'.length);
  } else if (repoRel.startsWith(SOURCES_DIR + '/')) {
    const o = originOf(repoRel, sources);
    if (!o || o.kind !== 'sibling') return null;
    const rel = o.rel.startsWith('docs/') ? o.rel.slice('docs/'.length) : o.rel;
    id = `${o.alias}/${rel}`;
  } else {
    return null;
  }
  id = id.replace(/\.md$/, '');
  if (id === 'README' || id === 'index') return 'index';
  id = id.replace(/\/(README|index)$/, '');   // a directory's index page is the directory's slug
  return id.toLowerCase();
}

/** The site path (with trailing slash) for a collection id. */
export function sitePathForId(id) {
  return id === 'index' ? '/' : `/${id}/`;
}

/** GitHub URL for a repo-relative path that is not a published page (a code file, a directory, an archived report). */
export function githubUrlForRepoPath(repoRel, { isDir = false, sources = loadSources() } = {}) {
  repoRel = toPosix(repoRel);
  const o = originOf(repoRel, sources);
  if (o && o.kind === 'sibling') {
    return `https://github.com/${o.repository}/${isDir ? 'tree' : 'blob'}/${o.commit}/${o.rel}`;
  }
  return `https://github.com/${PLATFORM_REPO}/${isDir ? 'tree' : 'blob'}/${PLATFORM_REF}/${repoRel}`;
}

/** Repo-relative posix path of a vfile (an absolute path from Astro), or null when outside the repo. */
export function repoRelOf(absPath) {
  const rel = path.relative(REPO_ROOT, absPath);
  if (rel.startsWith('..')) return null;
  return toPosix(rel);
}
