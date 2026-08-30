# Contributing

Thanks for helping improve Grok Usage Menu Bar.

## Before opening a pull request

1. Keep changes focused and native to macOS; the app intentionally has no package-manager dependencies.
2. Never commit Cursor credentials, database copies, response payloads containing account details, signing certificates, or notarization secrets.
3. Add or update tests when changing response parsing.
4. Run the checks below on macOS 13 or newer.

```sh
./scripts/test.sh
./scripts/build.sh
```

Please describe the macOS version and Cursor version used for manual testing. For visual changes, include a screenshot with personal information removed.

## Bug reports

Include the visible error state and the steps to reproduce it. Do not paste access tokens, cookies, the contents of Cursor's `state.vscdb`, or unredacted network requests.
