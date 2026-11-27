# caddy-edge

[![ci](https://github.com/pungoyal/caddy-edge/actions/workflows/ci.yml/badge.svg)](https://github.com/pungoyal/caddy-edge/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A hardened [Caddy](https://caddyserver.com) reverse proxy for one Docker host, kept in git and deployed by GitHub Actions. Every application gets HTTPS, security headers and a credential-free access log from a four-line file, and adding one is a form.

```
                 your private instance repo                      your Docker host
        ┌──────────────────────────────────────┐          ┌───────────────────────────┐
        │ sites/app.caddy                      │          │  Caddy  :80 :443          │
form ──▶│ .github/workflows/site.yml           │── SSH ──▶│    │ shared Docker network│
        │ .github/workflows/deploy.yml         │          │    ├── app:3000           │
        └───────────────┬──────────────────────┘          │    └── other:8080         │
                        │ uses: pungoyal/caddy-edge/actions/…@<sha>                   │
                        ▼                                 └───────────────────────────┘
                   this repository
```

This repository is the engine and holds no hostnames, addresses or secrets. Yours live in a private repository that calls the actions here, so what you serve and your deploy logs stay private while the engine stays shared.

## What you get

- **HTTPS without thought.** Caddy obtains and renews a certificate for every site.
- **One hardening policy for every site.** HSTS, `nosniff`, fingerprint headers removed, spoofable client headers (`X-Real-IP`, `X-Original-URL`, …) stripped, a request-body cap, timeouts against slow clients, and compression.
- **One owner for document policy.** A site imports `hardened` (the edge writes CSP `frame-ancestors`, Referrer-Policy, Permissions-Policy, COOP) or `hardened-app-policy` (the app ships its own). Never both, so an origin never sends two policies.
- **Logs without credentials.** Authorization, cookies, token headers and token query parameters are removed from the access log and from Caddy's own error log.
- **Unknown hostnames get nothing.** A request for a name with no site file is aborted, not answered.
- **Deploys that do not drop connections.** A config change is applied by `caddy reload`. A config Caddy rejects leaves the old one serving, and a deploy that does not come up healthy puts the previous files back.
- **A locked-down container.** Read-only filesystem, every capability dropped except binding ports, `no-new-privileges`, memory and CPU limits, admin API on loopback only.
- **A form for adding a site.** A workflow writes the site file from validated inputs, commits it, optionally creates the DNS record, and deploys.

## A site

```caddy
app.example.com {
	import hardened 10MB 'self'
	import app app:3000
}
```

`app:3000` is a container name and port on the shared Docker network; applications publish no host ports. The snippets are documented in [`deploy/caddy/sites/README.md`](deploy/caddy/sites/README.md) and reasoned in the [`Caddyfile`](deploy/caddy/Caddyfile).

## Getting started

You need a host with a public IPv4 address and a domain whose DNS you control. [`examples/instance`](examples/instance) is a complete instance repository, and its [README](examples/instance/README.md) is the step-by-step guide. In short:

1. Prepare the host: Docker Engine 25 or later with the Compose plugin, a deploy user in the `docker` group, a directory for the edge, a Docker network, and ports 80 and 443 (TCP) and 443 (UDP) open.
2. Create a **private** repository from the contents of `examples/instance`.
3. Give it the host's address, a deploy key and an ACME contact address as variables and a secret.
4. Run the `site` workflow to add your first application.

## Actions

Pin each to a commit SHA; Renovate's `config:best-practices` keeps the pin current. Inputs are listed in each `action.yml`.

| Action | What it does |
| --- | --- |
| [`actions/validate`](actions/validate/action.yml) | Checks the site files against the edge's Caddyfile, then starts Caddy once with internal certificates. Needs no secrets, so it is safe on pull requests. |
| [`actions/deploy`](actions/deploy/action.yml) | Ships `compose.yaml`, `.env` and `caddy/` to the host over SSH, runs `docker compose up -d --wait` and `caddy reload`, and restores the previous files if that fails. |
| [`actions/site`](actions/site/action.yml) | Writes or removes one site file. Every input is matched against a pattern before it becomes config. |
| [`actions/dns`](actions/dns/action.yml) | Creates, updates or deletes a DNS-only Cloudflare `A` record. Optional: any DNS provider works if you create the record yourself. |

```yaml
- uses: pungoyal/caddy-edge/actions/deploy@<sha> # v0.1.0
  with:
    sites: sites
    ssh-host: ${{ vars.SSH_HOST }}
    ssh-user: ${{ vars.SSH_USER }}
    ssh-known-hosts: ${{ vars.SSH_KNOWN_HOSTS }}
    ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
    deploy-path: ${{ vars.DEPLOY_PATH }}
    docker-network: ${{ vars.DOCKER_NETWORK }}
    acme-email: ${{ vars.ACME_EMAIL }}
```

## How a deploy works

1. The action assembles `compose.yaml`, `.env` and `caddy/` from this repository at the pinned commit, plus your site files.
2. On the host it copies what is serving to `previous/`, unpacks the new files to `next/`, and refills `caddy/` in place. The directory is never replaced: the container mounts it and would keep reading the old one.
3. `docker compose up -d --wait` recreates Caddy only if `compose.yaml` changed (an image update; sites drop for a few seconds). Otherwise `caddy reload` applies the config with no dropped connection.
4. If either fails, the action prints Caddy's log without the access log, puts `previous/` back, brings it up, and fails the job.

Nothing but those files is on the host, so `docker compose ps`, `logs` and `restart` work by hand in the deploy directory. CI runs this whole sequence against the runner itself on every change, including the failure path.

## What it is not

- **Not a platform.** It does not build or deploy your applications; they are their own Compose projects that join the shared network.
- **Not a firewall.** No rate limiting, no WAF, no bot rules.
- **Not behind a CDN.** Certificates come from HTTP and TLS-ALPN challenges, so the host answers directly and its address is public. With Cloudflare, records must be DNS-only.
- **Not multi-host.** One Caddy on one host.

If you would rather have applications declare their own routes with container labels and no repository in between, look at [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) or [Traefik](https://traefik.io/traefik/). The price is giving the proxy the Docker socket.

## Security

The trust model and how to report a vulnerability are in [`SECURITY.md`](SECURITY.md). The short version: whoever can run your instance's workflows controls your host, so keep that repository private and its write access small.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Changes are listed in [`CHANGELOG.md`](CHANGELOG.md).

## Licence

[MIT](LICENSE). Caddy is a registered trademark of Stack Holdings GmbH; this project is not affiliated with or endorsed by the Caddy project.
