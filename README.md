# Pantheon

Pantheon is a layered, privacy-preserving Safari ad blocker for macOS. Its native content blocker stops common advertising networks, while an optional site-scoped page cleaner handles dynamic first-party ads.

The network blocker cannot read browser history or page contents. The page cleaner receives access only to `pornhub.com`, because removing first-party player ads requires modifying that page's player configuration.

## Install and enable

1. Open `Pantheon.xcodeproj` in Xcode.
2. Select the **Pantheon** project, then open **Signing & Capabilities** for the **Pantheon**, **PantheonBlocker**, and **PantheonPageExtension** targets.
3. Choose the same Apple Development team for all three targets. If Xcode asks for unique bundle identifiers, use one app identifier and append `.blocker` and `.page-cleaner` for the two extensions.
4. Select the **Pantheon** scheme and press **Run**.
5. In the Pantheon app, click **Open Safari Extension Settings**.
6. Turn on both **Pantheon Blocker** and **Pantheon Page Cleaner** in Safari.
7. Grant **Pantheon Page Cleaner** access to `pornhub.com` using **Always Allow on This Website**.
8. Close any open Pornhub tab and open it again.

An Apple Development signing identity is required for persistent local installation. Without one, Safari requires **Safari > Settings > Developer > Allow unsigned extensions** again after every Safari restart.

## What it blocks

- Requests to a curated set of widely used advertising and adult-advertising networks.
- Advertising scripts, frames, images, and fetches served through Pornhub-specific ad URL patterns.
- Popups opened while browsing Pornhub.
- Current Pornhub iframe, side-column, promo-card, and sponsored-grid placements.
- Pornhub `flashvars_<video-id>` ad rolls and TrafficJunky player configuration.

Media and CDN domains are intentionally not blocked, so video playback, thumbnails, login, and search continue to work.

## Build and validate

```sh
./scripts/check.sh
```

This validates both JSON rule formats, checks JavaScript syntax when Node.js is available, compiles the native rules with WebKit's content-rule compiler, and performs a no-signing Xcode build. Build output stays under `.build/`.

## Updating the rules

Native rules live in `PantheonBlocker/blockerList.json`. Dynamic page rules and scripts live in `PantheonPageExtension/Resources`. Run `./scripts/check.sh` after either changes. Rules are reviewed and stored in the repository rather than downloaded at runtime.

## Limitations

No blocker can promise permanent coverage on a site that changes its markup and ad delivery. The page cleaner currently targets Pornhub's `/_xa/ads`, `ads_batch`, `VIDEO_SHOW.trafficJunkyurl`, and `flashvars_<video-id>.adRollGlobalConfig` mechanisms. If those change, update the focused rules and rebuild.
