#!/usr/bin/env bash
# Writes or removes one site file in $SITES and prints the hostname it serves or served.
# Run by the `site` action; works by hand too.
#
#   site.sh set <name> <hostname> <container:port> <hardened|hardened-app-policy> <max_body> [<'self'|'none'>]
#   site.sh remove <name>
#
# Every argument is matched against a pattern before it reaches the file: the file is
# Caddy config, and a brace or a newline in a value would be config too.
set -euo pipefail

# The directory of *.caddy files to change.
: "${SITES:?}"

die() { echo "::error::$1" >&2; exit 1; }

action=${1:-} name=${2:-}
[[ $name =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || die "name must be lowercase letters, digits and hyphens: '$name'"
file=$SITES/$name.caddy

case $action in
  set)
    host=${3:-} upstream=${4:-} policy=${5:-} max_body=${6:-} ancestors=${7:-}
    [[ $host =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] || die "not a hostname: '$host'"
    [[ $upstream =~ ^[a-z0-9][a-z0-9_.-]*:[0-9]{1,5}$ ]] || die "upstream must be container:port: '$upstream'"
    [[ $max_body =~ ^[0-9]+(KB|MB|GB)$ ]] || die "max_body must look like 10MB: '$max_body'"
    case $policy in
      hardened)
        [[ $ancestors == "'self'" || $ancestors == "'none'" ]] || die "frame_ancestors must be 'self' or 'none', with the apostrophes"
        import="hardened $max_body $ancestors"
        ;;
      hardened-app-policy) import="hardened-app-policy $max_body" ;;
      *) die "policy must be hardened or hardened-app-policy: '$policy'" ;;
    esac

    comments=
    if [[ -f $file ]]; then
      # A file with more than the two imports was edited by hand (logs-mcp strips a
      # header); rewriting it from four inputs would silently drop that.
      mapfile -t body < <(grep -vE '^[[:space:]]*(#|$)' "$file")
      [[ ${#body[@]} -eq 4 && ${body[1]} =~ ^[[:space:]]*import\ hardened && ${body[2]} =~ ^[[:space:]]*import\ app\  ]] ||
        die "$name.caddy has more than the two imports; change it in a pull request"
      # The comment above a site says why it is configured so, which the form cannot know.
      comments=$(sed -n '/^#/!q;p' "$file")
    fi

    {
      [[ -z $comments ]] || printf '%s\n' "$comments"
      printf '%s {\n\timport %s\n\timport app %s\n}\n' "$host" "$import" "$upstream"
    } > "$file"
    echo "$host"
    ;;
  remove)
    [[ -f $file ]] || die "no site named '$name'"
    # Printed so the caller can delete the DNS record the file named, not one typed into a form.
    grep -m1 -oE '^[a-z0-9.-]+' "$file" || true
    rm "$file"
    ;;
  *) die "usage: site.sh set <name> <hostname> <container:port> <policy> <max_body> [<frame_ancestors>] | remove <name>" ;;
esac
