# Contributing

Issues and pull requests are welcome. For anything larger than a fix, open an issue first so the direction is agreed before the work is done.

## Ground rules

The project's rules are in [`AGENTS.md`](AGENTS.md). The ones most often missed:

- No hostnames, addresses or secrets in this repository. Use `example.com`.
- A behaviour of the `deploy` action needs an assertion in the `deploy` job of `.github/workflows/ci.yml`, which deploys to the runner itself.
- Docs change in the same pull request as what they describe.
- Comments say why. Pull request titles state the end state ("Unmatched hostnames are aborted"), not the activity ("Fix catch-all").

## Checking a change locally

You need Docker with the Compose plugin, `shellcheck` and, for the workflows, `actionlint`.

```sh
shellcheck scripts/*.sh actions/*.sh test/*.sh
test/site_test.sh
actionlint

# What the validate action does, without the smoke test (which binds ports 80 and 443):
actions/assemble.sh examples/instance/sites /tmp/edge-check
cd /tmp/edge-check
docker network create edge-check
DOCKER_NETWORK=edge-check ACME_EMAIL=you@example.com \
  docker compose -p edge-check run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile
```

CI runs the same checks, then starts Caddy with internal certificates and runs three deploys against the runner: a first one, a config change, and a config Caddy rejects.

## Releases

Versions follow [Semantic Versioning](https://semver.org). Below 1.0 a minor version may break an action's inputs; `CHANGELOG.md` says how to adapt. A release is an entry in `CHANGELOG.md`, a `vX.Y.Z` tag on `main` and a GitHub release with the same notes.

## Licence

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
