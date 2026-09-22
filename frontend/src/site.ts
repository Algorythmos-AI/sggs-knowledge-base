// Single source of truth for site-wide constants used across layouts and the landing page.
// Keep SITE_URL in step with astro.config.mjs `site` and the App Store Connect URLs.
export const SITE_URL = "https://gurbanisoul.com";
export const SUPPORT_EMAIL = "support@gurbanisoul.com";

// Empty until Apple assigns the App Store URL. When set, the landing swaps the
// "Coming soon" note for the official App Store badge (see docs/website/README.md).
export const APP_STORE_URL = "";

// Apple's numeric App Store id (the digits after `/id` in APP_STORE_URL). Empty until Apple
// assigns it. When set, <Seo> emits the Smart App Banner (`apple-itunes-app`). Keep in step with
// APP_STORE_URL — the SmartBannerConsistency gate requires APP_STORE_URL to end with `/id`+this.
export const APP_STORE_ID = "";

// Imagery used on the landing. The hero is an original artistic rendering commissioned for
// Gurbani Soul (no stock photography), so the credit is to Algorythmos. Credited here and in the
// page footer. `who` is read by the imagery-credit gate (webapp/tests/test_repo_gates.py).
export const IMAGE_CREDITS = [
  { who: "Algorythmos", what: "Sri Harmandir Sahib at sunset — artistic rendering" },
];
