#!/usr/bin/env bash
# Builds the directory that is shipped to the VM: this repository's deploy/ at the
# ref the action was pinned to, with the caller's site files in caddy/sites.
#
#   assemble.sh <sites-dir|""> <out-dir>
set -euo pipefail

sites=$1 out=$2
src=$(cd "$(dirname "$0")/../deploy" && pwd)

rm -rf "$out"
mkdir -p "$out/caddy/sites"
cp "$src/compose.yaml" "$src/.env.example" "$out/"
cp "$src/caddy/Caddyfile" "$out/caddy/"

if [[ -n $sites ]]; then
  shopt -s nullglob
  files=("$sites"/*.caddy)
  ((${#files[@]})) || { echo "::error::no *.caddy files in '$sites'" >&2; exit 1; }
  cp "${files[@]}" "$out/caddy/sites/"
fi

# Caddy runs without DAC_OVERRIDE: it reads these as "other", whatever umask the runner had.
chmod -R u=rwX,go=rX "$out/caddy"
