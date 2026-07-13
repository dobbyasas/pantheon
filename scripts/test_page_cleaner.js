const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(
  "PantheonPageExtension/Resources/page.js",
  "utf8"
);

let allowedFetches = 0;
let allowedWindows = 0;
let metaRemoved = false;

const player = {
  getAttribute(name) {
    return name === "data-video-id" ? "123" : null;
  }
};

class MutationObserver {
  constructor(callback) {
    this.callback = callback;
  }
  observe() {}
}

const context = {
  console,
  MutationObserver,
  Response,
  document: {
    documentElement: {},
    addEventListener() {},
    getElementById(id) {
      return id === "player" ? player : null;
    },
    querySelector(selector) {
      if (selector.includes("adsbytrafficjunkycontext")) {
        return { remove() { metaRemoved = true; } };
      }
      return null;
    }
  },
  fetch: async () => {
    allowedFetches += 1;
    return new Response("allowed", { status: 200 });
  },
  open: () => {
    allowedWindows += 1;
    return {};
  },
  addEventListener() {},
  setInterval() { return 1; },
  clearInterval() {},
  setTimeout() { return 1; },
  clearTimeout() {},
  videoTimeTracking: "video-123",
  VIDEO_SHOW: { trafficJunkyurl: "https://trafficjunky.com/ad" },
  iframe_url: "https://trafficjunky.com/frame",
  flashvars_123: {
    embedCode: "ad embed",
    adRollGlobalConfig: [{ ad: true }],
    vastXml: "<VAST />",
    mediaDefinitions: [{ videoUrl: "https://cdn.example/video.m3u8" }]
  }
};
context.window = context;

vm.runInNewContext(source, context, { filename: "page.js" });

assert.equal(context.VIDEO_SHOW.trafficJunkyurl, "");
assert.equal(context.iframe_url, "");
assert.equal(context.flashvars_123.embedCode, "");
assert.equal(context.flashvars_123.adRollGlobalConfig.length, 0);
assert.equal(context.flashvars_123.vastXml, "");
assert.equal(context.flashvars_123.mediaDefinitions.length, 1);
assert.equal(metaRemoved, true);

Promise.resolve()
  .then(async () => {
    const blocked = await context.fetch("https://www.pornhub.com/_xa/ads_batch");
    assert.equal(blocked.status, 204);
    assert.equal(allowedFetches, 0);

    const allowed = await context.fetch("https://www.pornhub.com/video/get_media");
    assert.equal(allowed.status, 200);
    assert.equal(allowedFetches, 1);

    assert.equal(context.open("https://trafficjunky.com/click"), null);
    assert.equal(allowedWindows, 0);
    context.open("https://www.pornhub.com/model/example");
    assert.equal(allowedWindows, 1);

    console.log("Page cleaner behavior tests passed");
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
