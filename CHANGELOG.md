# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org).

## [0.2.1] - 2026-11-27

- A dry run that cannot log in says so, instead of reporting a missing deploy directory.

## [0.2.0] - 2026-11-27

- **Dry run.** `actions/deploy` takes `dry-run: true`: it connects to the server, checks that the deploy directory, Docker and the network are ready, prints the difference between what is deployed and what would be, and reports through its `plan` output whether Caddy would `reload`, be `recreate`d, or this is the `first` deploy. It only reads. The example `deploy` workflow offers it as a `dry_run` tick box.
- Comments and descriptions throughout are written for someone new to the project. No behaviour changes.

To adopt: nothing is required. To get the tick box, copy `dry_run` from the example `deploy.yml`.

## [0.1.0] - 2026-11-27

First public release.

- **Caddy for one Docker server**, in `deploy/`: automatic HTTPS, security headers, forged client headers removed, credentials kept out of logs, and requests for unknown hostnames dropped. Caddy runs read-only with every capability dropped except binding ports.
- **`actions/validate`** checks your site files and starts Caddy once with self-signed certificates.
- **`actions/deploy`** ships the configuration to your server over SSH, applies it by reload with no dropped connection, and restores the previous configuration if the new one does not come up.
- **`actions/site`** writes or removes a site file from validated inputs.
- **`actions/dns`** creates, updates or deletes a DNS-only Cloudflare `A` record.
- **`examples/instance`** is a ready-made repository to copy: the two workflows, a first site file and a setup guide.

[0.2.1]: https://github.com/pungoyal/caddy-edge/releases/tag/v0.2.1
[0.2.0]: https://github.com/pungoyal/caddy-edge/releases/tag/v0.2.0
[0.1.0]: https://github.com/pungoyal/caddy-edge/releases/tag/v0.1.0
