// Safe dist/ -> webapp/static/ sync with atomic backup + stale-file cleanup.
//   node scripts/sync-to-webapp.mjs            (build cutover)
//   node scripts/sync-to-webapp.mjs --rollback (restore the previous webapp/static/)
import { execSync } from 'node:child_process';
import { existsSync, renameSync, rmSync, cpSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));        // frontend/scripts
const FRONTEND = join(HERE, '..');                          // frontend
const DIST = join(FRONTEND, 'dist');                        // frontend/dist
const STATIC = join(FRONTEND, '..', 'webapp', 'static');    // webapp/static
const BACKUP = join(FRONTEND, '..', 'webapp', 'static.bak');// webapp/static.bak

const rollback = process.argv.includes('--rollback');

if (rollback) {
  if (!existsSync(BACKUP)) { console.error('No webapp/static.bak/ to roll back to.'); process.exit(1); }
  if (existsSync(STATIC)) { renameSync(STATIC, STATIC + '.broken'); }
  renameSync(BACKUP, STATIC);
  console.log('Rolled back: webapp/static.bak/ -> webapp/static/  (failed build at webapp/static.broken/)');
  process.exit(0);
}

if (!existsSync(DIST)) { console.error('frontend/dist/ missing — run `npm run build` first.'); process.exit(1); }

// 1) atomic backup of the current live static dir
if (existsSync(STATIC)) {
  if (existsSync(BACKUP)) rmSync(BACKUP, { recursive: true, force: true });
  renameSync(STATIC, BACKUP);
  console.log('Backed up  webapp/static/  ->  webapp/static.bak/');
}

// 2) mirror dist/ -> webapp/static/ (rsync --delete removes stale hashed chunks; cpSync fallback)
try {
  execSync(`rsync -a --delete "${DIST}/" "${STATIC}/"`, { stdio: 'inherit' });
} catch {
  mkdirSync(STATIC, { recursive: true });
  cpSync(DIST, STATIC, { recursive: true });
  console.log('Synced (Node cpSync fallback).');
}
console.log('Sync complete. webapp/static/ now reflects the latest build.');
console.log('Rollback any time:  npm run rollback');
