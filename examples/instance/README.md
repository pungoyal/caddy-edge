# Your edge repository

This repository decides what your server serves. Each file in `sites/` puts one app online over HTTPS, and every push to `main` deploys. The Caddy configuration and the deploy logic come from [caddy-edge](https://github.com/pungoyal/caddy-edge).

```
sites/                         one *.caddy file per app
.github/workflows/deploy.yml   checks every pull request; deploys main
.github/workflows/site.yml     a form that adds, updates and removes apps
renovate.json                  keeps caddy-edge and the other actions up to date
```

Keep it private: the site files name your hostnames, and the deploy logs name your server.

## Set up

To create this repository from the example:

```sh
gh repo create my-edge --private --clone && cd my-edge
curl -sL https://github.com/pungoyal/caddy-edge/archive/refs/heads/main.tar.gz |
  tar -xz --strip-components=3 caddy-edge-main/examples/instance
```

### 1. The server

- Docker Engine 25 or later with the Compose plugin.
- A user for deploys, in the `docker` group.
- A directory that user can write to, and a Docker network that every app joins:

  ```sh
  docker network create edge
  sudo install -d -o "$USER" /opt/edge
  ```

- Inbound TCP 80 and 443 and UDP 443 open, and SSH reachable from GitHub Actions.

### 2. Your apps

Each app joins the network in its own Compose file. It needs no `ports:` entry.

```yaml
services:
  app:
    image: ghcr.io/you/app
    networks: [edge]

networks:
  edge:
    external: true
```

### 3. Variables and the deploy key

The workflows read these from a GitHub environment named `production`:

| Variable | Value |
| --- | --- |
| `SSH_HOST` | The server's public IPv4 address |
| `SSH_USER` | The deploy user |
| `SSH_KNOWN_HOSTS` | Output of `ssh-keyscan -t ed25519 <SSH_HOST>` |
| `DEPLOY_PATH` | The directory from step 1, e.g. `/opt/edge` |
| `DOCKER_NETWORK` | The network from step 1, e.g. `edge` |
| `ACME_EMAIL` | Your email, for the certificate authority to warn you about problems |

```sh
gh api -X PUT "repos/{owner}/{repo}/environments/production"
gh variable set SSH_HOST --env production --body 203.0.113.10
gh variable set SSH_USER --env production --body deploy
gh variable set SSH_KNOWN_HOSTS --env production \
  --body "$(ssh-keyscan -t ed25519 203.0.113.10 2>/dev/null)"
gh variable set DEPLOY_PATH --env production --body /opt/edge
gh variable set DOCKER_NETWORK --env production --body edge
gh variable set ACME_EMAIL --env production --body you@example.com
```

Create a key that is used for nothing else. The server only ever receives the public half.

```sh
ssh-keygen -t ed25519 -f deploy_key -C github-actions -N ""
gh secret set SSH_PRIVATE_KEY --env production < deploy_key
ssh-copy-id -f -i deploy_key.pub deploy@203.0.113.10
rm deploy_key deploy_key.pub
```

If your plan offers it, restrict the environment to the `main` branch in the repository's settings, so that only `main` can use the key.

For the form to manage DNS on Cloudflare, also add the secrets `CF_API_TOKEN` (a token with `Zone:DNS:Edit` on the zone) and `CF_ZONE_ID` to the environment.

### 4. The first app

Point a DNS `A` record for the hostname at the server; the certificate cannot be issued until it resolves. Put the hostname and the app's `service:port` in `sites/app.caddy`, then:

```sh
git add -A && git commit -m "Serve my first app"
git push -u origin main
gh run watch
```

## Day to day

**Add, change or remove an app** by editing `sites/` in a pull request (it is checked there, and merging deploys), or with the form in the Actions tab:

```sh
gh workflow run site.yml -f action=set -f name=blog -f hostname=blog.example.com -f upstream=blog:8080
gh workflow run site.yml -f action=remove -f name=blog
```

- `set` writes `sites/<name>.caddy`; `remove` deletes it. The run checks the config, commits to `main` and deploys. A config Caddy rejects is never committed.
- `-f dns=true` also creates or deletes the hostname's Cloudflare record.
- `set` on an existing app keeps the comment above it. It refuses a file you have added directives to: change those by hand.
- Everyone with write access to this repository can run the form.

**Write a site file by hand** with the [site file reference](https://github.com/pungoyal/caddy-edge/blob/main/deploy/caddy/sites/README.md).

**Undo a change** by reverting its commit, or by re-running the `deploy` job of an earlier commit from the Actions tab.

**Update caddy-edge** by merging the pull request Renovate opens (install the [Renovate app](https://github.com/apps/renovate) on this repository). Read the [changelog](https://github.com/pungoyal/caddy-edge/blob/main/CHANGELOG.md) first when the minor version changes.

**Look at the server** with `docker compose ps`, `logs` or `restart` in `DEPLOY_PATH`.
