// Relative links written for GitHub keep working on the site:
//   * a link to a published Markdown page  -> its site path (anchors kept);
//   * a link to any other repo file/dir    -> its GitHub URL at the branch (platform) or the
//                                             pinned commit (sibling docs).
// Absolute URLs, anchors, mailto: and images are left alone. Runs before starlight-links-validator,
// which then sees only absolute site paths and can validate them.
import path from 'node:path';
import { existsSync, statSync } from 'node:fs';
import { visit } from 'unist-util-visit';
import { REPO_ROOT, SOURCES_DIR, idForRepoPath, sitePathForId, githubUrlForRepoPath, repoRelOf, loadSources, originOf } from './paths.mjs';

const isRelative = (url) => !!url && !/^(?:[a-z][a-z0-9+.-]*:|\/\/|\/|#)/i.test(url);

const GITHUB_MD = /^https:\/\/github\.com\/([^/]+\/[^/]+)\/blob\/[^/]+\/(.+?\.md)(#.*)?$/;

/** A GitHub link to a Markdown file the wiki pins from a sibling repository -> the wiki page. */
export function pinnedPageFor(url, sources) {
  const m = GITHUB_MD.exec(url);
  if (!m) return null;
  for (const [name, s] of Object.entries(sources)) {
    if (s.repository === m[1] && s.files && s.files[m[2]]) {
      const id = idForRepoPath(`${SOURCES_DIR}/${name}/${m[2]}`, sources);
      if (id) return sitePathForId(id) + (m[3] ?? '');
    }
  }
  return null;
}

export function rewriteLink(url, fromRepoRel, sources) {
  if (!isRelative(url)) return pinnedPageFor(url, sources) ?? url;
  const [target, hash = ''] = url.split(/(?=#)/, 2);
  const fromDir = path.posix.dirname(fromRepoRel);
  let repoRel = path.posix.normalize(path.posix.join(fromDir, decodeURI(target)));
  if (repoRel.startsWith('../')) return url; // outside the repository: leave it
  const abs = path.join(REPO_ROOT, repoRel);
  let isDir = target.endsWith('/') || (existsSync(abs) && statSync(abs).isDirectory());
  if (isDir) {
    const readme = path.posix.join(repoRel, 'README.md');
    const id = existsSync(path.join(REPO_ROOT, readme)) ? idForRepoPath(readme, sources) : null;
    if (id) return sitePathForId(id) + hash;
    return githubUrlForRepoPath(repoRel.replace(/\/$/, ''), { isDir: true, sources }) + hash;
  }
  // a sibling page may link to a Markdown file the pin does not publish (design notes, archived
  // reports): that goes to GitHub at the pinned commit rather than to a page that does not exist
  const published = !repoRel.startsWith(SOURCES_DIR + '/') || existsSync(abs);
  const id = published ? idForRepoPath(repoRel, sources) : null;
  if (id) return sitePathForId(id) + hash;
  return githubUrlForRepoPath(repoRel, { sources }) + hash;
}

/** The "pinned copy" banner for a page installed from a sibling repository, or null. */
export function canonicalBanner(fromRepoRel, sources) {
  const o = originOf(fromRepoRel, sources);
  if (!o || o.kind !== 'sibling') return null;
  const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  const url = `https://github.com/${o.repository}/blob/${o.commit}/${o.rel}`;
  return `<aside class="canonical" aria-label="Canonical source"><strong>Pinned copy.</strong> The canonical file is ` +
    `<a href="${esc(url)}" rel="noopener"><code>${esc(o.repository.split('/')[1])}/${esc(o.rel)}</code></a> at commit <code>${esc(o.commit.slice(0, 7))}</code> — ` +
    `edit it there. This wiki publishes it by pin (<a href="/adr/0012-docs-site/">ADR-0012</a>); a newer version arrives as a reviewed bump of <code>docs-site/sources.lock.json</code>.</aside>`;
}

export function remarkRepoLinks() {
  const sources = loadSources();
  return (tree, file) => {
    const fromRepoRel = file.path ? repoRelOf(file.path) : null;
    if (!fromRepoRel) return;
    visit(tree, ['link', 'definition'], (node) => {
      node.url = rewriteLink(node.url, fromRepoRel, sources);
    });
    const banner = canonicalBanner(fromRepoRel, sources);
    if (banner) tree.children.unshift({ type: 'html', value: banner });
  };
}
