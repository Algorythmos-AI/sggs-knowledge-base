import { test, expect } from '@playwright/test';

// v2 photo bands (PhotoBand.astro) and their credits. Tolerates ZERO bands (PR A ships the
// component before any page adopts it): for every `.photo-band img` that exists, the alt names the
// place and the image is lazy; and the footer credits on every marketing page name each Unsplash
// photographer with a link to their https://unsplash.com/@<handle> profile — read from the page
// itself, so the check follows IMAGE_CREDITS without duplicating it here.
const PAGES = ['/', '/features', '/watch', '/learn'];

for (const path of PAGES) {
  test(`photo bands on ${path} have alt text, load lazily and are credited`, async ({ page }) => {
    const res = await page.goto(path);
    expect(res?.status()).toBe(200);

    const imgs = page.locator('.photo-band img');
    const n = await imgs.count();
    for (let i = 0; i < n; i++) {
      const img = imgs.nth(i);
      expect((await img.getAttribute('alt'))?.trim(), `${path}: photo-band img ${i} has an empty alt`).toBeTruthy();
      await expect(img).toHaveAttribute('loading', 'lazy');
    }
    // a band is a dark scope carrying a scrim
    const bands = page.locator('.photo-band');
    for (let i = 0; i < (await bands.count()); i++) {
      await expect(bands.nth(i)).toHaveAttribute('data-theme', 'dark');
      await expect(bands.nth(i).locator('.pb-scrim')).toHaveCount(1);
    }

    const credits = page.locator('footer .credits');
    await expect(credits).toHaveCount(1);
    await expect(credits).toContainText('Artwork:');
    const links = credits.locator('a[href^="https://unsplash.com/@"]');
    const k = await links.count();
    if (k > 0) {
      await expect(credits).toContainText('Unsplash License');
      const text = (await credits.innerText()) || '';
      for (let i = 0; i < k; i++) {
        const who = ((await links.nth(i).innerText()) || '').trim();
        expect(who, `${path}: an Unsplash credit link has no photographer name`).not.toBe('');
        expect(text).toContain(`${who} / Unsplash`);
        expect(await links.nth(i).getAttribute('href')).toMatch(/^https:\/\/unsplash\.com\/@[A-Za-z0-9_.-]+$/);
      }
    }
    // never hot-linked: no image is served from Unsplash's CDN
    await expect(page.locator('img[src*="images.unsplash.com"], source[srcset*="images.unsplash.com"]')).toHaveCount(0);
  });
}
