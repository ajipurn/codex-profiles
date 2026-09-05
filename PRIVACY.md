# Privacy

Codex Profiles has no analytics or advertising SDK. Sparkle system profiling is disabled.

## Local data

- The active Codex login is read from `~/.codex/auth.json`.
- Saved login snapshots and account metadata are stored under `~/Library/Application Support/CodexProfiles/profiles`.
- App preferences are stored in `~/Library/Application Support/CodexProfiles/settings.json`. Sparkle stores its own update preferences in macOS user defaults.
- Saved login snapshots contain authentication tokens. They use restricted file permissions and are not encrypted by this application. Profile metadata does not contain access or refresh tokens.
- Hiding email addresses only changes account labels and rows; it does not remove locally stored identity data. Text entered into search and rename fields remains visible.

## Network requests

- Account usage is requested from `chatgpt.com`; authentication refreshes use `auth.openai.com`. These requests use the relevant account credentials.
- Account sign-in uses the installed Codex CLI and its normal authentication flow.
- App update checks and downloads use GitHub and GitHub's release-asset infrastructure. GitHub receives normal connection information, including IP address. Account credentials are not included in these requests.
- Automatic usage refresh and automatic app-update checks can be disabled independently in Settings. Installing app updates automatically is opt-in.

## Removal

Removing a saved profile deletes its saved credentials and metadata. Removing the active saved profile leaves the live Codex login intact. Uninstalling the app does not delete the shared Codex login or the saved profiles folder. Remove the application-support folder separately if you no longer need its saved accounts.

Preview mode uses disposable sample profiles and disables real login, client restart, usage requests, and app updates.
