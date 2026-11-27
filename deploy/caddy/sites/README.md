# Writing a site file

One file per app, named `<name>.caddy`, in the `sites/` directory of your repository. (This directory is where the deploy puts them on the server; none are kept here.)

```caddy
app.example.com {
	import hardened 10MB 'self'
	import app app:3000
}
```

| Part | Meaning |
| --- | --- |
| `app.example.com` | The hostname to serve. Caddy gets its certificate once DNS points at the server. |
| `hardened` | The security policy. Use `hardened-app-policy` if the app sends its own Content-Security-Policy. |
| `10MB` | The largest request body accepted. Larger requests get `413`. |
| `'self'` | Who may show the site in a frame: `'self'` or `'none'`. `hardened` only. |
| `app:3000` | The app's Compose service (or container) name on the shared Docker network, and the port it listens on inside the container. |

The file is ordinary Caddy config. Add any other directive below the imports; the `site` workflow then leaves that file for you to edit by hand.

## `import hardened <max_body> <frame_ancestors>`

For most apps.

- **Adds** `Strict-Transport-Security`, `X-Content-Type-Options`, `Content-Security-Policy` (`frame-ancestors`, `object-src 'none'`, `base-uri 'self'`), `Referrer-Policy`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`.
- **Removes** `Server`, `X-Powered-By`, `Via` and `X-XSS-Protection` from responses.
- **Strips** headers a client can forge from requests: `X-Real-IP`, `X-Client-IP`, `CF-Connecting-IP`, `True-Client-IP`, `Forwarded`, `X-Forwarded-Port`, `X-Forwarded-Prefix`, `X-Forwarded-Server`, `X-Original-URL`, `X-Rewrite-URL`. Caddy sets `X-Forwarded-For`, `-Host` and `-Proto` itself.
- **Caps** the request body and **compresses** responses the app did not already compress.
- **Logs** each request without `Authorization`, cookies, or tokens in the query string.

`<frame_ancestors>` needs its apostrophes. Bare `self` means a host named `self`, which allows nobody.

The Content-Security-Policy deliberately says nothing about scripts or styles: caddy-edge cannot know which origins your app loads from, and a wrong guess breaks the site. An app that needs a full policy should send its own and use the snippet below.

## `import hardened-app-policy <max_body>`

For an app that sends its own Content-Security-Policy. Everything above except `Content-Security-Policy`, `Referrer-Policy`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`, which pass through from the app untouched. Check that the app sets all four.

## `import app <service:port>`

A reverse proxy that retries failed connections for 30 seconds, so a request that arrives while the app's container is being replaced waits instead of getting a `502`.

## Keeping a credential out of the logs

`Authorization`, `Proxy-Authorization`, cookies, and the query parameters `token`, `access_token`, `auth_token`, `api_key`, `apikey` and `request_token` are removed already. If your apps carry a credential in another header or parameter, [open an issue](https://github.com/pungoyal/caddy-edge/issues) or a pull request adding it to `(redact-credentials)` in the [`Caddyfile`](../Caddyfile).

## Hostnames without a file

A request for a hostname that has no site file is dropped without a response.
