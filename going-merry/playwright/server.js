const { chromium } = require("patchright");

chromium
  .launchServer({ port: 3000, host: "0.0.0.0" })
  .then((server) => console.log(`listening ${server.wsEndpoint()}`));
