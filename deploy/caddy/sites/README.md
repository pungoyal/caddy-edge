# Site files

Site files do not live here. An instance repository keeps one `*.caddy` file per application in its own `sites/` directory, and the `deploy` action copies them into this directory on the way to the host.

```caddy
app.example.com {
	import hardened 10MB 'self'
	import app app:3000
}
```

`app:3000` is the container name on the shared Docker network and its internal port. Apps publish no host ports. `import app` is `reverse_proxy` that retries failed connects for 30s, so a request that arrives while the app's container is being replaced waits instead of getting a 502.

The `site` action writes this file from a form. Anything beyond the two imports is added by hand in a pull request, and the action then leaves the file alone.

The edge owns the connection; exactly one party owns document policy per site, chosen by snippet. The rationale is in `../Caddyfile`.

## `import hardened <max_request_body> <frame_ancestors>`

Default: the edge authors document policy.

- Strips client-supplied identity and routing headers (`X-Real-IP`, `X-Client-IP`, `CF-Connecting-IP`, `True-Client-IP`, `Forwarded`, `X-Forwarded-Port|Prefix|Server`, `X-Original-URL`, `X-Rewrite-URL`).
- Sets `Strict-Transport-Security`, `X-Content-Type-Options`, `Content-Security-Policy` (`frame-ancestors`, `object-src 'none'`, `base-uri 'self'`), `Referrer-Policy`, `Permissions-Policy`, `Cross-Origin-Opener-Policy`; removes `Server`, `X-Powered-By`, `Via`, `X-XSS-Protection`.
- Caps the request body (`413` over the limit). `10MB` is usual.
- Compresses responses (`zstd`, `gzip`) the app did not already encode.
- Logs access with credentials removed. A credential in another header or query parameter must be added to `(redact-credentials)` in `../Caddyfile`.

`<frame_ancestors>` needs its apostrophes: `'self'` normally, `'none'` for anything never embedded. Bare `self` means a host named `self` and allows nothing.

The CSP has no `default-src`/`script-src` (a wrong guess breaks the site) and no `form-action` (breaks third-party POST flows such as OAuth).

## `import hardened-app-policy <max_request_body>`

Same as `hardened` minus CSP, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`, which the app owns. Use only for an app that ships a CSP, and check it also sets the rest.

## Unmatched hostnames

A hostname with no site file is aborted, not answered.
