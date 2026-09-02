# Grok Usage Menu Bar

A tiny native macOS menu-bar app that shows how much of your weekly Cursor **Grok Bot** allowance remains and when it resets.

<p>
  <img src="assets/menu-bar-preview.png" alt="Grok Usage Menu Bar showing a battery and reset countdown" width="280">
</p>

The default layout matches the companion Codex widget: a monochrome Grok icon, a battery showing usage left, and a live countdown to the weekly reset. The icon is a macOS template image, so it automatically follows the menu bar's light or dark appearance.

## Features

- Battery or percentage display
- Percentage left or used
- Live countdown or reset clock time
- Refresh every 30 seconds, 1 minute, 3 minutes, or 5 minutes
- Launch at Login enabled automatically using macOS `SMAppService`
- One-click access to the Cursor dashboard
- Universal Apple Silicon and Intel build
- No third-party runtime or package dependencies

## Requirements

- macOS 13 Ventura or newer
- A valid Cursor sign-in saved on the Mac
- A Cursor account with a Grok Bot usage allowance

Cursor does not have to remain installed if its local login is still present and valid. A new Mac—or a Mac whose login has expired—will need Cursor temporarily so the user can sign in again. Building from source also requires Apple's Xcode Command Line Tools.

## Install with Codex (one prompt)

Paste the prompt below into the Codex desktop app. Codex can handle the build and verification. If no usable Cursor login exists, it will guide you through installing Cursor from the official website and pause while **you** complete the private sign-in.

```text
Install Grok Usage Menu Bar from this repository:
https://github.com/diegocp01/grok_bot_usage_menu_bar.git

Complete the installation for me on this Mac and verify that it works. Follow these rules:

1. Read the repository's README and scripts before running them. Work only inside a local clone of this repository, /private/tmp, and ~/Applications.
2. Check whether Apple's Xcode Command Line Tools are available. If not, start the official installation and wait for me to finish it.
3. Check whether ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb exists and contains the required Cursor authentication keys. Never print, copy, log, or reveal any credential values.
4. Run ./scripts/test.sh and build the app. Use the built app's --probe command to test the live usage request; its output is intentionally sanitized.
5. If the credential store is missing or the login has expired, check whether Cursor.app is installed. If needed, download the current macOS version only from https://cursor.com/download, install and open it, then ask me to complete the Cursor sign-in myself. Never ask me to paste a password, two-factor code, cookie, or access token into Codex or Terminal. After I confirm sign-in, retry the sanitized probe.
6. Do not continue with a broken or unauthenticated probe. Explain the safe next action instead.
7. When the probe succeeds, run the repository's installer, verify the installed app's strict code signature and universal arm64/x86_64 binary, confirm Launch at Login is enabled, open it, and confirm that the menu-bar item shows real usage with a reset time rather than --:--.
8. Report the final installation path and what was verified. Do not uninstall Cursor or delete its local data unless I explicitly ask.
```

Codex Computer Use is only needed if Codex must operate the download or open Cursor for the sign-in step. It is not a runtime dependency of Grok Usage Menu Bar. Cursor can be removed afterward, but its saved session may eventually expire; refreshing it would require signing in again.

## Install from source

Double-click **Install Grok Usage Menu Bar.command**. It builds the app, installs it in `~/Applications`, verifies the local code signature, opens it, and enables Launch at Login automatically. macOS may show a background-item notification; if it requires approval, enable **Grok Usage Menu Bar** in **System Settings → General → Login Items**.

Or use the terminal:

```sh
./scripts/test.sh
./scripts/build.sh
open "/private/tmp/grok-usage-menu-bar-release/Grok Usage Menu Bar.app"
```

The build script produces an ad-hoc signed universal app for local use. The temporary output location avoids cloud-sync metadata that can invalidate strict macOS signatures.

To create a shareable local zip and checksum:

```sh
VERSION=0.1.0 ./scripts/package.sh
```

## Privacy and data source

The app reads Cursor's existing local sign-in from:

`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`

The access token is held only in memory while making a read-only request to Cursor's dashboard. It is never logged, copied to another file, placed in Keychain, or sent to analytics or another third party.

Cursor does not publish a supported individual-plan usage API. This app uses the authenticated `get-sand-usage-status` endpoint currently used by Cursor's dashboard for the Grok Bot weekly meter. Because that endpoint is undocumented, Cursor may change it without notice.

The app fails closed: if the local login or live response is unavailable, the menu bar shows `--:--` instead of presenting stale usage as current.

## Development

```sh
./scripts/test.sh
./scripts/build.sh
```

CI runs the parser tests, builds both architectures, and verifies the app signature. For a Developer ID signed and notarized release, see [RELEASING.md](RELEASING.md).

The endpoint's camelCase and snake_case response shapes were independently verified. The MIT-licensed [CursorSpendPace](https://github.com/xjoker/CursorSpendPace) project was also used as a compatibility reference.

## Uninstall

Quit the app and move `~/Applications/Grok Usage Menu Bar.app` to the Trash. Turn off **Launch at Login** from the app menu first so macOS removes its startup registration.

## Disclaimer

This is an independent, unofficial project. It is not affiliated with or endorsed by Cursor or xAI. Cursor and Grok are trademarks of their respective owners.

## License

[MIT](LICENSE)
