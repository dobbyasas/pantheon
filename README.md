# Pantheon

Pantheon is a small, privacy-preserving Safari content blocker for macOS. It blocks common advertising networks on every site and applies extra request, popup, and cosmetic rules.

The extension uses Safari's native content-blocking engine. It cannot read browser history, page contents, passwords, or browsing activity.

## Install and enable

1. Open `Pantheon.xcodeproj` in Xcode.
2. Select the **Pantheon** project, then select the **Pantheon** and **PantheonBlocker** targets under **Signing & Capabilities**.
3. Choose your Apple Development team for both targets. If Xcode asks for unique bundle identifiers, change the app identifier and give the extension the same identifier plus `.blocker` (for example, `me.example.Pantheon` and `me.example.Pantheon.blocker`).
4. Select the **Pantheon** scheme and press **Run**.
5. In the Pantheon app, click **Open Safari Extension Settings**.
6. Turn on **Pantheon Blocker** in Safari. Reload any already-open pages.

An Apple Development signing identity is required for persistent local installation. Without one, Safari requires **Safari > Settings > Developer > Allow unsigned extensions** again after every Safari restart.

## What it blocks

- Requests to a curated set of widely used advertising and adult-advertising networks.
- Advertising scripts, frames, images, and fetches served through Pornhub-specific ad URL patterns.
- Popups opened while browsing Pornhub.
- Known ad containers and sponsored-card wrappers on Pornhub pages.

Media and CDN domains are intentionally not blocked, so video playback, thumbnails, login, and search continue to work.

## Build and validate

```sh
./scripts/check.sh
```

This validates the JSON, compiles the rules with WebKit's content-rule compiler, and performs a no-signing Xcode build. Build output stays under `.build/`.

## Updating the rules

Edit `PantheonBlocker/blockerList.json`, then run `./scripts/check.sh`. Safari rules are deliberately reviewed and stored in the repository rather than downloaded at runtime.

## Limitations

No blocker can promise permanent coverage on a site that changes its markup and ad delivery. Pantheon blocks the current major request patterns and uses conservative cosmetic selectors to avoid breaking playback. If the site changes, update the focused rules and rebuild the extension.
