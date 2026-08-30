# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub's **Report a vulnerability** feature rather than a public issue.

Do not include real Cursor access tokens, cookies, database files, signing certificates, Apple app-specific passwords, or other credentials in a report. A minimal redacted reproduction is preferred.

## Credential handling

Grok Usage Menu Bar reads Cursor's existing local credential only when refreshing usage. The token remains in process memory and is not logged or persisted by this app.
