// The wiki's interactive elements. Each is a vanilla custom element inserted from Markdown by
// docs-site/plugins/remark-widgets.mjs (`<!-- sggs:<name> -->`). One small bundle, loaded once per
// page (src/components/Head.astro); nothing here is required to read the page.
import { SggsStatus } from './status';
import { makeScrollRegionsFocusable } from './a11y';

const define = (name: string, ctor: CustomElementConstructor) => {
  if (!customElements.get(name)) customElements.define(name, ctor);
};

define('sggs-status', SggsStatus);

makeScrollRegionsFocusable();
window.addEventListener('resize', () => makeScrollRegionsFocusable(), { passive: true });
