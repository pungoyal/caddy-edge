# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-11-27

First public release.

### Added

- `deploy/`: Caddy on Docker Compose, read-only and with every capability dropped except binding ports, and a Caddyfile with the `hardened`, `hardened-app-policy` and `app` snippets, credential-redacted logs and a catch-all that aborts unmatched hostnames.
- `actions/validate`: checks site files and starts Caddy once with internal certificates.
- `actions/deploy`: ships Caddy's configuration and your site files to the server over SSH, applies a config change by reload, and restores the previous config when the new one does not come up.
- `actions/site`: writes or removes a site file from validated inputs.
- `actions/dns`: creates, updates or deletes a DNS-only Cloudflare `A` record.
- `examples/instance`: the workflows and layout of a private instance repository.

[0.1.0]: https://github.com/pungoyal/caddy-edge/releases/tag/v0.1.0
