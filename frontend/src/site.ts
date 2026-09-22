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

// Unsplash photography used on the landing. Credited here, in the page footer, and in NOTICE.md,
// per the Unsplash License (commercial use + modification permitted; attribution appreciated).
export const PHOTO_CREDITS = [
  { who: "Aryan Nikhil", url: "https://unsplash.com/@aryannikhil", what: "Sri Harmandir Sahib, reflection" },
  { who: "Laurentiu Morariu", url: "https://unsplash.com/@travelphotographer", what: "Sri Harmandir Sahib" },
];
