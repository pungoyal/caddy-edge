# Security policy

## Reporting a vulnerability

Please do not open a public issue. Report it privately through
[GitHub's vulnerability reporting form](https://github.com/pungoyal/caddy-edge/security/advisories/new).
You should get an answer within a week.

Useful reports say what an attacker can do and how: a request that gets past the
hardening, a credential that reaches a log, a form input that becomes Caddy config,
or a way for a pull request to reach the deploy key.

## Supported versions

Only the latest release gets fixes. Your workflows pin a commit of caddy-edge, and Renovate moves the pin when there is a release.

## What this project does and does not protect

- It hardens the connection and, when asked, the document policy of the sites behind it. It is not a web application firewall and does no rate limiting.
- The host's address is public: certificates are obtained over HTTP and TLS-ALPN challenges, so the host answers on 80 and 443 directly.
- The SSH user is in the `docker` group, which is root on the host. Anyone who can push to your repository, or run its workflows, controls the host.
- A bug in Caddy itself belongs to [Caddy's own security policy](https://github.com/caddyserver/caddy/security/policy).
