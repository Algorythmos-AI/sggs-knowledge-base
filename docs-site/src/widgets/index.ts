// The wiki's interactive elements. Each is a vanilla custom element inserted from Markdown by
// docs-site/plugins/remark-widgets.mjs (`<!-- sggs:<name> -->`). One small bundle, loaded once per
// page (src/components/Head.astro); nothing here is required to read the page.
import { SggsStatus } from './status';
import { SggsWalkthrough } from './walkthrough';
import { SggsAngExplorer } from './ang-explorer';
import { SggsWaterfall } from './waterfall';
import { SggsVerify } from './verify';
import { SggsApiTry } from './api-try';
import { SggsTerm } from './term';
import { SggsQuiz } from './quiz';
import { watchScrollRegions } from './a11y';

const define = (name: string, ctor: CustomElementConstructor) => {
  if (!customElements.get(name)) customElements.define(name, ctor);
};

define('sggs-status', SggsStatus);
define('sggs-walkthrough', SggsWalkthrough);
define('sggs-ang-explorer', SggsAngExplorer);
define('sggs-waterfall', SggsWaterfall);
define('sggs-verify', SggsVerify);
define('sggs-api-try', SggsApiTry);
define('sggs-term', SggsTerm);
define('sggs-quiz', SggsQuiz);

watchScrollRegions();
