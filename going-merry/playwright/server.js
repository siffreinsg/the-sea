const { chromium } = require("patchright");

// Fixed path, not the random default: PLAYWRIGHT_WS_URL has to be a static config value.
// Not a public risk — same posture as the rest of the :8091 relay, unauthenticated but
// unreachable except through it.
chromium
  .launchServer({ port: 3000, host: "0.0.0.0", wsPath: "playwright" })
  .then((server) => console.log(`listening ${server.wsEndpoint()}`));
