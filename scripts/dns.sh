#!/usr/bin/env bash
# Cloudflare A records for hosts on this VM (DNS-only, never proxied).
#
#   dns.sh set <name> <ip>    create or update A record
#   dns.sh delete <name>      remove A record
#   dns.sh list               show A/AAAA records
#
# Requires curl, jq, and env: CF_API_TOKEN (Zone:DNS:Edit), CF_ZONE_ID.
set -euo pipefail

: "${CF_API_TOKEN:?}" "${CF_ZONE_ID:?}"
API=https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records

cf() { # cf <method> <path> [json]
  curl -sSf --fail-with-body -X "$1" "$API$2" -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" ${3:+--data "$3"}
}

record_id() { cf GET "?type=A&name=$1" | jq -r '.result[0].id // empty'; }

is_ipv4() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

case "${1:-}" in
  set)
    name=${2:?name} ip=${3:?ip}
    is_ipv4 "$ip" || { echo "not an IPv4 address: $ip" >&2; exit 1; }
    body=$(jq -nc --arg n "$name" --arg ip "$ip" '{type:"A",name:$n,content:$ip,ttl:1,proxied:false}')
    id=$(record_id "$name")
    if [[ -n "$id" ]]; then cf PATCH "/$id" "$body"; else cf POST "" "$body"; fi | jq -r '.result | "\(.name) -> \(.content) (proxied=\(.proxied))"'
    ;;
  delete)
    id=$(record_id "${2:?name}")
    [[ -n "$id" ]] || { echo "no A record for $2" >&2; exit 1; }
    cf DELETE "/$id" >/dev/null && echo "deleted $2"
    ;;
  list)
    cf GET "?type=A" | jq -r '.result[] | "\(.name)\t\(.content)\tproxied=\(.proxied)"'
    cf GET "?type=AAAA" | jq -r '.result[] | "\(.name)\t\(.content)\tproxied=\(.proxied)"'
    ;;
  *) echo "usage: dns.sh set <name> <ip> | delete <name> | list" >&2; exit 1 ;;
esac
