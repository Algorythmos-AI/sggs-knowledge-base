// Relative links written for GitHub keep working on the site:
//   * a link to a published Markdown page  -> its site path (anchors kept);
//   * a link to any other repo file/dir    -> its GitHub URL at the branch (platform) or the
//                                             pinned commit (sibling docs).
// Absolute URLs, anchors, mailto: and images are left alone. Runs before starlight-links-validator,
// which then sees only absolute site paths and can validate them.
import path from 'node:path';
import { existsSync, statSync } from 'node:fs';
import { visit } from 'unist-util-visit';
import { REPO_ROOT, idForRepoPath, sitePathForId, githubUrlForRepoPath, repoRelOf, loadSources } from './paths.mjs';

const isRelative = (url) => !!url && !/^(?:[a-z][a-z0-9+.-]*:|\/\/|\/|#)/i.test(url);

export function rewriteLink(url, fromRepoRel, sources) {
  if (!isRelative(url)) return url;
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
  const id = idForRepoPath(repoRel, sources);
  if (id) return sitePathForId(id) + hash;
  return githubUrlForRepoPath(repoRel, { sources }) + hash;
}

export function remarkRepoLinks() {
  const sources = loadSources();
  return (tree, file) => {
    const fromRepoRel = file.path ? repoRelOf(file.path) : null;
    if (!fromRepoRel) return;
    visit(tree, ['link', 'definition'], (node) => {
      node.url = rewriteLink(node.url, fromRepoRel, sources);
    });
  };
}
