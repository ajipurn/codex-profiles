# Codex Profiles

[![CI](https://github.com/ajipurn/codex-profiles/actions/workflows/ci.yml/badge.svg)](https://github.com/ajipurn/codex-profiles/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ajipurn/codex-profiles?cacheSeconds=300)](https://github.com/ajipurn/codex-profiles/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A native macOS menu bar app for switching Codex accounts and keeping track of remaining usage.

<img src="CodexProfiles/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="96" alt="Codex Profiles icon">

**macOS 14+ · Apple Silicon and Intel · SwiftUI · Signed automatic updates**

Independently developed. Not affiliated with or endorsed by OpenAI.

## Install

1. Download `CodexProfiles-<version>.zip` from [Releases](https://github.com/ajipurn/codex-profiles/releases/latest).
2. Unzip it and move **Codex Profiles.app** to **Applications**.
3. Open the app and click its icon in the menu bar.
4. Save your current Codex login, or choose **Add account** and complete sign-in in Terminal.

The initial release is ad-hoc code signed and is **not Apple-notarized**. macOS may block its first launch. After checking the download's origin, use the per-app **Open Anyway** option in **System Settings → Privacy & Security** if offered. Do not disable Gatekeeper globally. Sparkle signatures verify subsequent updates separately from Apple notarization.

The installed Codex CLI or ChatGPT application is needed to add accounts. Before adding another login, save the current account so it can be restored if sign-in is cancelled.

## Features

- **Account switching:** save, rename, and switch accounts without repeating sign-in each time.
- **Search and favorites:** find accounts by name, email, plan, or workspace; keep favorite accounts at the top.
- **Quota overview:** separate 5-hour and weekly remaining percentages, reset times, and low-quota indicators.
- **Sorting:** name, most quota available, or recently added. The active account and favorites remain first.
- **Usage refresh:** manual refresh or every two minutes. Failed requests retain the previous reading with a warning and timestamp.
- **Menu bar quota:** optionally display the lowest remaining quota across the active account's windows. For example, 37% for 5 hours and 6% weekly displays **6%**.
- **Email display:** hide email addresses in account labels and rows. Text entered in search or rename fields stays visible.
- **App updates:** manual checking, daily automatic checks, and optional automatic downloading and installation using Sparkle.

### Keyboard shortcuts

While the panel is open:

| Shortcut | Action |
| --- | --- |
| ⌘F | Search accounts |
| ⌘N | Add an account |
| ⌘R | Refresh account usage |
| ⌘Q | Quit |
| Return / Escape | Save / cancel account editing |

## App updates

Open **Settings → Check for Updates…** to check manually. Automatic checks run daily by default; automatic downloading and installation are opt-in. Both controls are in Settings and are independent of account-usage refresh.

Update archives and feeds are signed with a dedicated Ed25519 key. Sparkle verifies the signature before extracting an update. Updates install into the application bundle and do not remove saved accounts. An update relaunch is deferred while an account operation is still in progress.

The update feed starts working once the first stable GitHub release is published. Older local builds without Sparkle need one manual installation of this version. Preview mode and unpackaged development binaries do not check for app updates.

## Build and preview

Requires Swift 6+ and Python 3. Full Xcode is required for universal builds; native development builds work with Command Line Tools.

```sh
git clone https://github.com/ajipurn/codex-profiles.git
cd codex-profiles
make build
make test
make package
open -n "dist/Codex Profiles.app" --args --demo
```

Preview mode opens a separate window with sample accounts in a temporary store. It disables real account sign-in, client restarts, network usage requests, and app updates. Quit from its Settings menu to remove the temporary store.

An Xcode project is included. `make project` regenerates it with XcodeGen after target or dependency changes. Sparkle is pinned in `Package.swift` and `project.yml`; commit the resolved dependency file when updating it.

## Data and account behavior

The shared active login lives at `~/.codex/auth.json`. Saved profiles and preferences live under `~/Library/Application Support/CodexProfiles`. Tokens are stored locally with restricted file permissions and are **not encrypted by this app**. Profile metadata contains no access or refresh tokens.

Switching first preserves the current saved account's credentials. Restarting ChatGPT after switching is configurable. Removing a saved profile leaves the active live login signed in. API key sessions show a separate billing note instead of ChatGPT quota windows.

Usage requests time out after 20 seconds and do not overlap within the app. Credentials are checked again before writing a token refresh, so a late response cannot overwrite an account already replaced by another operation. This is a local consistency check, not a cross-process file lock.

See [Privacy](PRIVACY.md), [Security](SECURITY.md), [Contributing](CONTRIBUTING.md), and the [Release guide](docs/RELEASING.md).

## License

[MIT](LICENSE). Bundled dependencies retain their own [licenses and notices](THIRD_PARTY_NOTICES.md).
