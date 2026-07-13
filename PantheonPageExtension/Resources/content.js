(() => {
  "use strict";

  const blockedFragments = [
    "/_xa/ads",
    "ads_batch",
    "trafficjunky.com",
    "trafficjunky.net",
    "tj-content.com",
    "ktkjmp.com/adsbygoogle.js"
  ];

  const removableSelectors = [
    "#pb_iframe",
    "#js-abContainterMain",
    ".js_promoItem",
    ".adContainer",
    ".ad-container",
    ".ad-wrapper",
    ".adWrapper",
    ".advertisement",
    ".advertisement-container",
    "[data-ad-id]",
    "[data-advertisement]",
    "iframe[src*='trafficjunky']",
    "iframe[src*='ktkjmp']",
    "a[href*='trafficjunky']",
    "a[href*='?ats=']"
  ].join(",");

  function containsBlockedFragment(value) {
    const text = String(value || "").toLowerCase();
    return blockedFragments.some((fragment) => text.includes(fragment));
  }

  function clean(root) {
    if (!(root instanceof Element || root instanceof Document)) return;

    if (root instanceof HTMLScriptElement &&
        (containsBlockedFragment(root.src) || containsBlockedFragment(root.textContent))) {
      root.remove();
      return;
    }

    if (root instanceof Element && root.matches(removableSelectors)) {
      root.remove();
      return;
    }

    root.querySelectorAll(removableSelectors).forEach((element) => element.remove());
    root.querySelectorAll("script").forEach((script) => {
      if (containsBlockedFragment(script.src) || containsBlockedFragment(script.textContent)) {
        script.remove();
      }
    });
  }

  if (window.top === window) {
    const pageScript = document.createElement("script");
    pageScript.src = browser.runtime.getURL("page.js");
    pageScript.dataset.pantheon = "player-ad-cleaner";
    pageScript.addEventListener("load", () => pageScript.remove(), { once: true });
    (document.documentElement || document.head).appendChild(pageScript);
  }

  clean(document);

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      mutation.addedNodes.forEach((node) => clean(node));
    }
  });

  observer.observe(document, { childList: true, subtree: true });
  document.addEventListener("DOMContentLoaded", () => clean(document), { once: true });
})();
