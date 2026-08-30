# Releasing

Local builds are ad-hoc signed and are intended for the developer's own Mac. A public binary should be signed with an Apple Developer ID and notarized so Gatekeeper can verify it.

## Create a local package

```sh
VERSION=0.1.0 ./scripts/package.sh
```

This writes a universal macOS zip and SHA-256 file to `.build/dist`.

## Create a notarized GitHub release

Install and authenticate the GitHub CLI, configure the repository remote, and export the Apple signing values:

```sh
VERSION=0.1.0 \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./scripts/release.sh
```

The script builds with hardened runtime, notarizes and staples the app, creates a checksum, then uses the current GitHub `origin` to create the `v$VERSION` release. Secrets are read from the environment and must never be committed.
