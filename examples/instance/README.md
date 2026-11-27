# An instance repository

Copy this directory into a new **private** repository. It holds what is yours: the site files, the workflows that validate and deploy them, and the variables and secret GitHub keeps for them. Everything else comes from [caddy-edge](https://github.com/pungoyal/caddy-edge) at the commit the workflows pin.

```
sites/                         one *.caddy file per application
.github/workflows/deploy.yml   validates every pull request; deploys main
.github/workflows/site.yml     the form that adds, updates and removes sites
renovate.json                  keeps the caddy-edge pin and the other actions current
```

Keep it private: the site files name your hosts, and the deploy logs name your server.

## 1. Prepare the host

- Docker Engine 25 or later (the healthcheck uses `start_interval`) with the Compose v2 plugin.
- A deploy user in the `docker` group.
- A directory the deploy user can write to, e.g. `/opt/edge`, and a Docker network, e.g. `docker network create edge`. Every application joins this network.
- Inbound TCP 80 and 443 and UDP 443 open; TCP 22 reachable from GitHub Actions.

## 2. Check the caddy-edge pin

The workflows reference `pungoyal/caddy-edge/actions/…@<sha> # v0.1.0`: a commit, because a tag can be moved. Renovate moves the pin when there is a release; the comment is how it knows which one you are on.

## 3. Variables and the deploy key

Create a GitHub Environment named `production` and restrict it to the `main` branch. In it, set these variables:

| Name | Value |
| --- | --- |
| `SSH_HOST` | The host's public IPv4 address |
| `SSH_USER` | The deploy user |
| `SSH_KNOWN_HOSTS` | Output of `ssh-keyscan -t ed25519 <SSH_HOST>` |
| `DEPLOY_PATH` | The directory from step 1, e.g. `/opt/edge` |
| `DOCKER_NETWORK` | The network from step 1, e.g. `edge` |
| `ACME_EMAIL` | Contact address for the certificate authority account |

The `validate` job runs without the environment and needs none of them, so a pull request never comes near the deploy key.

Generate a dedicated deploy key; the host only ever receives the public half.

```sh
ssh-keygen -t ed25519 -f deploy_key -C github-actions -N ""
gh secret set SSH_PRIVATE_KEY --env production < deploy_key
ssh-copy-id -f -i deploy_key.pub <SSH_USER>@<SSH_HOST>
rm deploy_key deploy_key.pub
```

To have the form manage DNS on Cloudflare, also add the secrets `CF_API_TOKEN` (a token with `Zone:DNS:Edit` on the zone) and `CF_ZONE_ID` to the environment.

## 4. Add a site

Replace `sites/app.caddy`, or run the form from the Actions tab, the GitHub mobile app or the CLI:

```sh
gh workflow run site.yml -f action=set -f name=app -f hostname=app.example.com -f upstream=app:3000
gh workflow run site.yml -f action=remove -f name=app
```

- `set` writes `sites/<name>.caddy` from the inputs; `remove` deletes it. The run validates the config, commits to `main` and deploys that commit. A config Caddy rejects is never committed.
- With `dns` ticked it creates or deletes the hostname's `A` record before the deploy. Without it, point a DNS-only `A` record at the host yourself; the certificate cannot be issued until it resolves.
- `set` on an existing site keeps the comment above it. It refuses a file that holds more than the two imports: change those in a pull request.

Whoever has write access to this repository can run the form, and that is the whole access control.

## Day to day

- **Change by hand**: edit a site file in a pull request. `validate` runs on the pull request; merging deploys.
- **Roll back**: re-run the `deploy` job of a good commit from the Actions tab, or push a revert.
- **Update the edge**: merge Renovate's pull request that moves the caddy-edge pin. Read the [changelog](https://github.com/pungoyal/caddy-edge/blob/main/CHANGELOG.md) first when the minor version changes.
- **On the host**: `cd <DEPLOY_PATH> && docker compose ps|logs|restart`.
