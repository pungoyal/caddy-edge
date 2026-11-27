#!/usr/bin/env bash
# Tests scripts/site.sh: what it writes, what it keeps, and what it refuses.
set -euo pipefail

site=$(cd "$(dirname "$0")/.." && pwd)/scripts/site.sh
SITES=$(mktemp -d)
export SITES
trap 'rm -rf "$SITES"' EXIT
fails=0

ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
expect() { if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1: expected '$3', got '$2'"; fi; }
refuses() { if "$site" "${@:2}" >/dev/null 2>&1; then bad "$1: accepted"; else ok "$1"; fi; }

expect "set prints the hostname" "$("$site" set app app.example.com app:3000 hardened 10MB "'self'")" app.example.com
expect "set writes the two imports" "$(cat "$SITES/app.caddy")" $'app.example.com {\n\timport hardened 10MB \'self\'\n\timport app app:3000\n}'

"$site" set app app.example.com app:8080 hardened-app-policy 5MB >/dev/null
expect "set updates in place" "$(sed -n 2,3p "$SITES/app.caddy")" $'\timport hardened-app-policy 5MB\n\timport app app:8080'

printf '# Why this site is so.\n%s\n' "$(cat "$SITES/app.caddy")" > "$SITES/app.caddy"
"$site" set app app.example.com app:3000 hardened 10MB "'none'" >/dev/null
expect "set keeps the leading comment" "$(head -n1 "$SITES/app.caddy")" "# Why this site is so."

printf 'mcp.example.com {\n\timport hardened 10MB '"'none'"'\n\trequest_header -X-Extra\n\timport app mcp:8000\n}\n' > "$SITES/mcp.caddy"
refuses "set refuses a hand-edited file" set mcp mcp.example.com mcp:8000 hardened 10MB "'none'"

refuses "a brace in the hostname" set x 'a.example.com {' x:1 hardened 10MB "'self'"
refuses "a brace in the upstream" set x a.example.com 'x:1 }' hardened 10MB "'self'"
refuses "a newline in max_body" set x a.example.com x:1 hardened $'10MB\n}' "'self'"
refuses "frame ancestors without apostrophes" set x a.example.com x:1 hardened 10MB self
refuses "an unknown policy" set x a.example.com x:1 open 10MB "'self'"
refuses "a path as the name" set ../x a.example.com x:1 hardened 10MB "'self'"
refuses "removing a site that is not there" remove nope
expect "nothing was written by a refusal" "$(find "$SITES" -name 'x*' | wc -l | tr -d ' ')" 0

expect "remove prints the hostname" "$("$site" remove mcp)" mcp.example.com
expect "remove deletes the file" "$(test -e "$SITES/mcp.caddy" && echo there || echo gone)" gone

exit "$((fails > 0))"
