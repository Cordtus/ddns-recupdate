#!/usr/bin/env bash
# --------------------------------------------------------------------
# Cloudflare DDNS updater — original functionality retained
# Usage: dns-update.sh <email> <api_token> [--auto]
# --------------------------------------------------------------------
set -euo pipefail

EMAIL=${1:-}
TOKEN=${2:-}
MODE=${3:-}

if [[ -z "$EMAIL" || -z "$TOKEN" ]]; then
  echo "Usage: $0 <email> <api_token> [--auto]" >&2
  exit 1
fi

# ---------- paths & log --------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
JSON_LOG="$LOG_DIR/log.json"
mkdir -p "$LOG_DIR"
[[ -f "$JSON_LOG" ]] || echo '[]' > "$JSON_LOG"

log () {                     # zone record status [old_ip] [new_ip]
    local time zone record status old new
    time="$(date -u +"%a %b %d %T UTC %Y")"
    zone="$1"
    record="$2"
    status="$3"
    old="${4-}"
    new="${5-}"

    if [[ "$status" == "updated" ]]; then
        jq --arg time "$time" \
           --arg zone "$zone" \
           --arg record "$record" \
           --arg old_ip "$old" \
           --arg new_ip "$new" \
           --arg status "$status" \
           '. += [{timestamp:$time,
                   zone:$zone,
                   record:$record,
                   old_ip:$old_ip,
                   new_ip:$new_ip,
                   status:$status}]' \
           "$JSON_LOG" > "$JSON_LOG.tmp" && mv "$JSON_LOG.tmp" "$JSON_LOG"
    else
        jq --arg time "$time" \
           --arg zone "$zone" \
           --arg record "$record" \
           --arg ip "$old" \
           --arg status "$status" \
           '. += [{timestamp:$time,
                   zone:$zone,
                   record:$record,
                   ip:$ip,
                   status:$status}]' \
           "$JSON_LOG" > "$JSON_LOG.tmp" && mv "$JSON_LOG.tmp" "$JSON_LOG"
    fi
}

cf_get () { curl -sS --fail -H "Authorization: Bearer $TOKEN" "$@"; }
cf_put () { curl -sS --fail -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data "$2" "$1"; }

# ---------- current public IP --------------------------------------
CURRENT_IP=$(curl -sS --max-time 10 https://cloudflare.com/cdn-cgi/trace | awk -F= '/^ip=/{print $2}')
[[ "$CURRENT_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "❌  Could not retrieve public IPv4" >&2; exit 1; }

# ---------- fetch zones --------------------------------------------
zones_json=$(cf_get "https://api.cloudflare.com/client/v4/zones")
zones_cnt=$(jq '.result|length' <<<"$zones_json")
(( zones_cnt > 0 )) || { echo "❌  No zones found" >&2; exit 1; }

# ---------- pick zones ---------------------------------------------
if [[ "$MODE" == "--auto" ]]; then
  sel_idx=($(seq 0 $((zones_cnt-1))))
else
  echo "Available zones:"
  for i in $(seq 0 $((zones_cnt-1))); do
    echo "$((i+1)). $(jq -r ".result[$i].name" <<<"$zones_json")"
  done
  read -rp "Enter zone numbers (space‑separated): " -a tmp
  sel_idx=($(for n in "${tmp[@]}"; do echo $((n-1)); done))
fi

# ---------- iterate -------------------------------------------------
for idx in "${sel_idx[@]}"; do
  zone_id=$(jq -r ".result[$idx].id"   <<<"$zones_json")
  zone_nm=$(jq -r ".result[$idx].name" <<<"$zones_json")

  rec_json=$(cf_get "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A")
  rec_cnt=$(jq '.result|length' <<<"$rec_json")
  (( rec_cnt > 0 )) || { echo "ℹ️  $zone_nm: no A records" ; continue; }

  for r in $(seq 0 $((rec_cnt-1))); do
    rec_id=$(jq -r ".result[$r].id"      <<<"$rec_json")
    rec_nm=$(jq -r ".result[$r].name"    <<<"$rec_json")
    rec_ip=$(jq -r ".result[$r].content" <<<"$rec_json")

    if [[ "$rec_ip" == "$CURRENT_IP" ]]; then
      echo "No update needed for $rec_nm ($CURRENT_IP)"
      log "$zone_nm" "$rec_nm" "no_change" "$rec_ip"
      continue
    fi

    body=$(jq -n --arg t A --arg n "$rec_nm" --arg c "$CURRENT_IP" \
                  '{type:$t,name:$n,content:$c}')
    if cf_put "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$rec_id" "$body" > /dev/null; then
      echo "✅  Updated $rec_nm  $rec_ip → $CURRENT_IP"
      log "$zone_nm" "$rec_nm" "updated" "$rec_ip" "$CURRENT_IP"
    else
      echo "❌  Failed to update $rec_nm" >&2
      log "$zone_nm" "$rec_nm" "failed" "$rec_ip" "$CURRENT_IP"
    fi
  done
done

echo "Finished."
