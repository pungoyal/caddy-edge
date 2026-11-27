# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-11-27

First public release.

- **Caddy for one Docker server**, in `deploy/`: automatic HTTPS, security headers, forged client headers removed, credentials kept out of logs, and requests for unknown hostnames dropped. Caddy runs read-only with every capability dropped except binding ports.
- **`actions/validate`** checks your site files and starts Caddy once with self-signed certificates.
- **`actions/deploy`** ships the configuration to your server over SSH, applies it by reload with no dropped connection, and restores the previous configuration if the new one does not come up.
- **`actions/site`** writes or removes a site file from validated inputs.
- **`actions/dns`** creates, updates or deletes a DNS-only Cloudflare `A` record.
- **`examples/instance`** is a ready-made repository to copy: the two workflows, a first site file and a setup guide.

[0.1.0]: https://github.com/pungoyal/caddy-edge/releases/tag/v0.1.0
