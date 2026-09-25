import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { mockApi } from './helpers';

const here = dirname(fileURLToPath(import.meta.url));

test.describe('Scripture 101', () => {
  test('a glossary term shows its definition on hover and focus, and links to the glossary', async ({ page }) => {
    await mockApi(page);
    await page.goto('/scripture/what-sggs-is/');
    const term = page.locator('sggs-term[data-term="Mool Mantar"]').first();
    await expect(term.locator('.term__link')).toHaveAttribute('href', '/glossary/#term-mool-mantar');
    await expect(term.locator('.term__card')).toBeHidden();
    await term.locator('.term__link').focus();
    await expect(term.locator('.term__card')).toBeVisible();
    await expect(term.locator('.term__card')).toContainText('opening statement');
    await page.keyboard.press('Escape');
    await expect(term.locator('.term__card')).toBeHidden();
    await page.goto('/glossary/');
    await expect(page.locator('tr#term-mool-mantar')).toHaveCount(1);
  });

  test('a quiz answers, explains, and keeps score without any network', async ({ page }) => {
    await mockApi(page);
    await page.goto('/scripture/structure/');
    const quiz = page.locator('sggs-quiz').first();
    await expect(quiz.locator('.quiz__q')).toHaveCount(3);
    const first = quiz.locator('.quiz__q').first();
    await first.locator('input').nth(1).check();      // a wrong answer
    await expect(first.locator('.quiz__why')).toContainText('Not quite');
    await expect(first.locator('label.is-answer')).toHaveCount(1);
    const second = quiz.locator('.quiz__q').nth(1);
    await second.locator('input').nth(0).check();     // the right one
    await expect(second.locator('.quiz__why')).toContainText('Right.');
    await expect(quiz.locator('.quiz__summary')).toContainText('2 of 3 answered · 1 right so far');
  });

  test('poster 13 draws every raag to scale with a title on each segment', async ({ page }) => {
    await mockApi(page);
    await page.goto('/scripture/structure/');
    const poster = page.locator('figure.poster[data-poster="13-structure-of-the-granth"]');
    await expect(poster.locator('g[data-step]')).toHaveCount(6);
    await expect(poster.locator('svg title')).toHaveCount(1 + 2 + 31 + 22);   // the poster title, two ends, 31 raags, 22 Vaars
  });

  test('cited scripture is verbatim from the API, with its Ang', async ({ page }) => {
    await mockApi(page, { '/api/health': 'health.json', '/api/ang/1': 'ang-1.json' });
    await page.goto('/scripture/what-sggs-is/');
    const quote = page.locator('.sl-markdown-content blockquote').nth(1);
    await expect(quote).toContainText('Sri Guru Granth Sahib Ji · Ang 1');
    const shown = (await quote.locator('p').first().textContent())?.trim();
    const data = JSON.parse(readFileSync(resolve(here, 'fixtures', 'ang-1.json'), 'utf8'));   // a verbatim capture of /api/ang/1
    expect(shown?.startsWith(data.lines[0].gurmukhi), shown).toBe(true);   // Gurmukhi first, then the transliteration and the citation
  });

  for (const path of ['/scripture/', '/scripture/what-sggs-is/', '/scripture/structure/', '/scripture/vaars-saloks-pauris/', '/scripture/bhatts-and-swaiyye/', '/scripture/gurmukhi-and-unicode/', '/scripture/transliteration-and-the-fold/', '/scripture/answer-protocol-for-engineers/', '/glossary/']) {
    test(`no accessibility violations: ${path}`, async ({ page }) => {
      await mockApi(page);
      await page.goto(path);
      const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa']).analyze();
      expect(results.violations, JSON.stringify(results.violations, null, 1)).toEqual([]);
    });
  }
});
