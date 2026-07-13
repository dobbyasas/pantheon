(() => {
  "use strict";

  if (window.__pantheonPlayerCleanerInstalled) return;
  window.__pantheonPlayerCleanerInstalled = true;

  const blockedFragments = [
    "/_xa/ads",
    "ads_batch",
    "trafficjunky.com",
    "trafficjunky.net",
    "tj-content.com",
    "ktkjmp.com/adsbygoogle.js"
  ];

  function isAdURL(value) {
    let text = "";
    if (typeof value === "string") text = value;
    else if (value && typeof value.url === "string") text = value.url;
    else if (value && typeof value.href === "string") text = value.href;
    text = text.toLowerCase();
    return blockedFragments.some((fragment) => text.includes(fragment));
  }

  function sanitizeFlashvars(value) {
    if (!value || typeof value !== "object") return value;
    value.embedCode = "";
    value.adRollGlobalConfig = [];
    if (Object.prototype.hasOwnProperty.call(value, "vastXml")) value.vastXml = "";
    if (Object.prototype.hasOwnProperty.call(value, "vastURL")) value.vastURL = "";
    return value;
  }

  function sanitizeVideoShow(value) {
    if (value && typeof value === "object") value.trafficJunkyurl = "";
    return value;
  }

  const trappedKeys = new Set();

  function trapFlashvars(videoId) {
    if (!videoId) return;
    const key = `flashvars_${videoId}`;
    if (trappedKeys.has(key)) return;

    const descriptor = Object.getOwnPropertyDescriptor(window, key);
    if (descriptor && descriptor.configurable === false) {
      sanitizeFlashvars(window[key]);
      return;
    }

    let storedValue = sanitizeFlashvars(window[key]);
    try {
      Object.defineProperty(window, key, {
        configurable: true,
        enumerable: true,
        get() { return storedValue; },
        set(value) { storedValue = sanitizeFlashvars(value); }
      });
      trappedKeys.add(key);
    } catch (_) {
      sanitizeFlashvars(window[key]);
    }
  }

  function patchPlayerConfiguration() {
    document.querySelector("head > meta[name='adsbytrafficjunkycontext']")?.remove();

    try { window.iframe_url = ""; } catch (_) {}

    if (window.VIDEO_SHOW && typeof window.VIDEO_SHOW === "object") {
      window.VIDEO_SHOW.trafficJunkyurl = "";
    }

    const player = document.getElementById("player");
    const videoId = player?.getAttribute("data-video-id");
    if (videoId) trapFlashvars(videoId);

    for (const key of Object.keys(window)) {
      if (key.startsWith("flashvars_")) sanitizeFlashvars(window[key]);
    }
  }

  const originalFetch = window.fetch?.bind(window);
  if (originalFetch) {
    window.fetch = function(input, init) {
      if (isAdURL(input)) {
        return Promise.resolve(new Response(null, { status: 204, statusText: "No Content" }));
      }
      return originalFetch(input, init);
    };
  }

  const originalOpen = window.open?.bind(window);
  if (originalOpen) {
    window.open = function(url, ...rest) {
      if (isAdURL(url) || String(url || "").includes("?ats=")) return null;
      return originalOpen(url, ...rest);
    };
  }

  let trackingValue = window.videoTimeTracking;
  const trackingDescriptor = Object.getOwnPropertyDescriptor(window, "videoTimeTracking");
  if (!trackingDescriptor || trackingDescriptor.configurable !== false) {
    try {
      Object.defineProperty(window, "videoTimeTracking", {
        configurable: true,
        enumerable: true,
        get() { return trackingValue; },
        set(value) {
          trackingValue = value;
          const match = String(value || "").match(/\d+/);
          if (match) trapFlashvars(match[0]);
        }
      });
    } catch (_) {}
  }

  let videoShowValue = sanitizeVideoShow(window.VIDEO_SHOW);
  const videoShowDescriptor = Object.getOwnPropertyDescriptor(window, "VIDEO_SHOW");
  if (!videoShowDescriptor || videoShowDescriptor.configurable !== false) {
    try {
      Object.defineProperty(window, "VIDEO_SHOW", {
        configurable: true,
        enumerable: true,
        get() { return videoShowValue; },
        set(value) { videoShowValue = sanitizeVideoShow(value); }
      });
    } catch (_) {}
  }

  const iframeURLDescriptor = Object.getOwnPropertyDescriptor(window, "iframe_url");
  if (!iframeURLDescriptor || iframeURLDescriptor.configurable !== false) {
    try {
      Object.defineProperty(window, "iframe_url", {
        configurable: true,
        enumerable: true,
        get() { return ""; },
        set(_) {}
      });
    } catch (_) {}
  }

  patchPlayerConfiguration();
  document.addEventListener("DOMContentLoaded", patchPlayerConfiguration, { once: true });
  window.addEventListener("load", patchPlayerConfiguration, { once: true });

  let patchTimer;
  const observer = new MutationObserver(() => {
    window.clearTimeout(patchTimer);
    patchTimer = window.setTimeout(patchPlayerConfiguration, 100);
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });

  let remainingPasses = 20;
  const timer = window.setInterval(() => {
    patchPlayerConfiguration();
    remainingPasses -= 1;
    if (remainingPasses <= 0) window.clearInterval(timer);
  }, 250);
})();
