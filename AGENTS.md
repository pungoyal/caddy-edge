# Rules for agents

- This repository is the engine: it holds no hostnames, addresses or secrets. Site files, variables and deploy logs belong to an instance repository (`examples/instance`).
- What reaches the host is `compose.yaml`, `.env` and `caddy/`, and one command. No script is shipped to the host; the rollback's branching stays in `actions/deploy/action.yml`.
- `compose.yaml` mounts the `caddy/` directory, and the deploy empties and refills it. Do not mount single files or replace the directory: the running container would keep reading the old one.
- A config change must reach Caddy by `caddy reload`. Do not make a deploy recreate the container unless `compose.yaml` changed.
- A new variable is one line in `deploy/.env.example`, one input of the `deploy` action and one in the `env:` of its step that writes `.env`. Required values use `${VAR:?}` in compose, never a fallback.
- Every site imports `hardened` or `hardened-app-policy`, and proxies with `import app`. The fixtures in `test/sites` are the only exception.
- The deploy needs nothing on the host beyond Docker and what every Ubuntu has (`tar`, `find`, `cp`); do not add a tool that has to be installed there.
- CI never starts Caddy with real hostnames and a public CA. `validate` adds `local_certs`; the deploy test serves `localhost`.
- Form input becomes Caddy config only through `scripts/site.sh`, which matches every value against a pattern. Action inputs reach scripts through `env:`, never by expansion into the script.
- An action's inputs are its public interface. Removing or renaming one is a breaking change: note it in `CHANGELOG.md` and bump the minor version while below 1.0.
- A behaviour of the `deploy` action is only done when the `deploy` job in `ci.yml` asserts it.
- Actions are pinned to a commit SHA and images to a digest. Renovate moves them; do not bump by hand. If an update is wrong, fix `renovate.json`.
- Docs (`README.md`, `deploy/caddy/sites/README.md`, `examples/instance/README.md`, `docs/index.html`, this file) change in the same PR as what they describe.
- `docs/` is the GitHub Pages site, served as it is from `main`: one HTML file, no build, no external requests. It states nothing the README does not.
- Comments say why, or what not to change back. PR titles state the end state.
