import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import type { Page } from '@playwright/test';

const here = dirname(fileURLToPath(import.meta.url));

/** Answer every /api call from a fixture (or 503 when none), so tests never reach production. */
export async function mockApi(page: Page, fixtures: Record<string, string | null> = { '/api/health': 'health.json' }) {
  await page.route('**/api/**', async (route) => {
    const path = new URL(route.request().url()).pathname;
    const name = fixtures[path];
    if (name === undefined || name === null) return route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":"mocked outage"}' });
    return route.fulfill({ status: 200, contentType: 'application/json', body: readFileSync(resolve(here, 'fixtures', name), 'utf8') });
  });
}
