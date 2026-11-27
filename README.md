# caddy-edge

[![ci](https://github.com/pungoyal/caddy-edge/actions/workflows/ci.yml/badge.svg)](https://github.com/pungoyal/caddy-edge/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

HTTPS and security headers for every app on your Docker server. Describe an app in four lines and push; it goes live on its own hostname with a certificate. A mistake in the config never takes your sites down.

```caddy
app.example.com {
	import hardened 10MB 'self'
	import app app:3000
}
```

Built on [Caddy](https://caddyserver.com) and GitHub Actions. Nothing to install on the server but Docker. Overview: **[pungoyal.github.io/caddy-edge](https://pungoyal.github.io/caddy-edge/)**.

## How it works

1. Your apps run in Docker on one server and join a shared Docker network. None of them opens a port to the internet.
2. You keep one four-line file per app in a private GitHub repository of your own.
3. On every push, GitHub Actions checks the config and sends it to the server over SSH, where Caddy serves every app over HTTPS.

Your repository holds only your site files and two workflows. The workflows call the actions in this repository, which bring the Caddy configuration, the Compose file and the deploy logic.

## Quick start

You need a Linux server with Docker Engine 25 or later and a public IPv4 address, a domain, and a GitHub account. The commands use the [GitHub CLI](https://cli.github.com).

**1. Prepare the server.** Create the network your apps will share and a directory for caddy-edge. Open TCP 80 and 443 and UDP 443.

```sh
docker network create edge
sudo install -d -o "$USER" /opt/edge
```

**2. Put an app on the network.** In the app's own Compose file. It needs no `ports:` entry: Caddy reaches it by service name.

```yaml
services:
  app:
    image: ghcr.io/you/app
    networks: [edge]

networks:
  edge:
    external: true
```

**3. Create your repository**, on your own computer, from [`examples/instance`](examples/instance). Keep it private: it names your hostnames and your server.

```sh
gh repo create my-edge --private --clone && cd my-edge
curl -sL https://github.com/pungoyal/caddy-edge/archive/refs/heads/main.tar.gz |
  tar -xz --strip-components=3 caddy-edge-main/examples/instance
```

**4. Tell it where your server is.** Replace the address, user and email with yours.

```sh
gh api -X PUT "repos/{owner}/{repo}/environments/production"
gh variable set SSH_HOST --env production --body 203.0.113.10
gh variable set SSH_USER --env production --body deploy
gh variable set SSH_KNOWN_HOSTS --env production \
  --body "$(ssh-keyscan -t ed25519 203.0.113.10 2>/dev/null)"
gh variable set DEPLOY_PATH --env production --body /opt/edge
gh variable set DOCKER_NETWORK --env production --body edge
gh variable set ACME_EMAIL --env production --body you@example.com

ssh-keygen -t ed25519 -f deploy_key -C github-actions -N ""
gh secret set SSH_PRIVATE_KEY --env production < deploy_key
ssh-copy-id -f -i deploy_key.pub deploy@203.0.113.10
rm deploy_key deploy_key.pub
```

**5. Go live.** Point a DNS `A` record for your hostname at the server, put the hostname and your app's `service:port` in `sites/app.caddy`, and push.

```sh
git add -A && git commit -m "Serve my first app"
git push -u origin main
gh run watch
```

The README that lands in your repository ([`examples/instance/README.md`](examples/instance/README.md)) covers each step in more detail, and day-to-day use.

## What every app gets

- **Automatic HTTPS.** A certificate for every hostname, obtained and renewed by Caddy.
- **Security headers.** HSTS, `nosniff`, a `frame-ancestors` policy, a referrer policy, browser features such as camera and microphone switched off, and `Server` and `X-Powered-By` removed.
- **Nothing spoofed.** Headers a visitor could forge to fake their address or reach a hidden route (`X-Real-IP`, `X-Original-URL`, …) are removed before your app sees the request.
- **Logs without secrets.** `Authorization`, cookies, token headers and token query parameters never reach the access log.
- **No stray answers.** A request for a hostname you did not configure is dropped.
- **No 502 during restarts.** While an app's container is being replaced, requests wait up to 30 seconds for it.
- **Limits.** A request-body cap you choose per app, and timeouts against slow clients.
- **A locked-down proxy.** Caddy runs with a read-only filesystem, every capability dropped except binding ports, and no access to the Docker socket.

[`deploy/caddy/sites/README.md`](deploy/caddy/sites/README.md) is the reference for writing a site file. The rules themselves are in one commented [`Caddyfile`](deploy/caddy/Caddyfile).

## Adding and removing apps

Edit the files in `sites/` and push, or run the `site` workflow from your repository's Actions tab, the GitHub mobile app or a terminal:

```sh
gh workflow run site.yml -f action=set -f name=blog -f hostname=blog.example.com -f upstream=blog:8080
gh workflow run site.yml -f action=remove -f name=blog
```

The workflow writes the file from the inputs, checks it, commits it and deploys. With `-f dns=true` and a Cloudflare token it also creates or deletes the DNS record.

## What a deploy does

1. **Checks.** Caddy validates your site files, then is started once with self-signed certificates. This runs on pull requests too and needs no secrets.
2. **Ships.** `compose.yaml`, `.env` and `caddy/` are copied to the server. What was serving is kept in `previous/`.
3. **Reloads.** `caddy reload` applies the config with no dropped connection. The container is recreated only when the Compose file itself changed, such as for a new Caddy version.
4. **Recovers.** If Caddy rejects the config or does not come up healthy, `previous/` is put back and the run fails.

Those three files and one container are all that is on the server, so `docker compose ps`, `logs` and `restart` work by hand in the deploy directory. CI runs this sequence, failure included, against a real SSH target on every change to this repository.

## Actions

For writing your own workflows instead of using the example's. Pin each to a commit; [Renovate](https://docs.renovatebot.com) keeps the pin current. Every input is described in the action's `action.yml`.

| Action | What it does |
| --- | --- |
| [`actions/validate`](actions/validate/action.yml) | Checks site files and starts Caddy once with self-signed certificates. Needs no secrets. |
| [`actions/deploy`](actions/deploy/action.yml) | Ships the config to the server, reloads Caddy, and restores the previous config if that fails. |
| [`actions/site`](actions/site/action.yml) | Writes or removes one site file. Every input is matched against a pattern before it becomes config. |
| [`actions/dns`](actions/dns/action.yml) | Creates, updates or deletes a Cloudflare `A` record. |

```yaml
- uses: pungoyal/caddy-edge/actions/deploy@<commit> # v0.1.0
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

## Limits

- **One server.** One Caddy on one host; no clustering.
- **No WAF.** No rate limiting and no bot rules.
- **No CDN proxy in front.** Certificates are obtained by the server answering directly, so its address is public. Cloudflare records must be DNS-only.
- **It does not deploy your apps.** They are their own Compose projects.

To have apps appear by container label, with no repository in between, use [caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy) or [Traefik](https://traefik.io/traefik/). The price is giving the proxy the Docker socket.

## Security

The deploy user can run Docker, which is root on the server, so whoever can push to your repository controls the server. Keep it private and its collaborators few. [`SECURITY.md`](SECURITY.md) has the rest, and how to report a vulnerability.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Releases are listed in [`CHANGELOG.md`](CHANGELOG.md).

## Licence

[MIT](LICENSE). Caddy is a registered trademark of Stack Holdings GmbH; this project is not affiliated with or endorsed by the Caddy project.
