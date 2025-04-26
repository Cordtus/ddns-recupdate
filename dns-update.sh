#!/bin/bash

set -e

EMAIL=$1
TOKEN=$2
MODE=$3

if [ -z "$EMAIL" ] || [ -z "$TOKEN" ]; then
  echo "Usage: $0 <email> <api_token> [--auto]"
  exit 1
fi

mkdir -p ./logs
JSON_LOG="./logs/log.json"

if [ ! -f "$JSON_LOG" ]; then
  echo "[]" > "$JSON_LOG"
fi

CURRENT_IP=$(curl -s --max-time 10 https://cloudflare.com/cdn-cgi/trace | grep '^ip=' | cut -d= -f2)

if [[ ! $CURRENT_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Error: Could not fetch valid public IP."
  exit 1
fi

echo "Current public IP: $CURRENT_IP"

zones_json=$(curl -s --fail --request GET \
  --url "https://api.cloudflare.com/client/v4/zones" \
  -H "Content-Type: application/json" \
  -H "X-Auth-Email: $EMAIL" \
  -H "Authorization: Bearer $TOKEN")

zones_count=$(echo "$zones_json" | jq '.result | length')

if [ "$zones_count" -eq 0 ]; then
  echo "Error: No zones found."
  exit 1
fi

echo "Available zones:"
for i in $(seq 0 $(($zones_count - 1))); do
  zone_name=$(echo "$zones_json" | jq -r ".result[$i].name")
  echo "$(($i + 1)). $zone_name"
done

if [ "$MODE" = "--auto" ]; then
  selected_indices=($(seq 1 $zones_count))
else
  read -p "Enter the numbers of the zones you want to operate on (space separated): " -a selected_indices
fi

for index in "${selected_indices[@]}"; do
  zone_idx=$((index - 1))
  zone_id=$(echo "$zones_json" | jq -r ".result[$zone_idx].id")
  zone_name=$(echo "$zones_json" | jq -r ".result[$zone_idx].name")

  echo "Fetching DNS records for zone: $zone_name..."

  records_json=$(curl --silent --fail --request GET \
    --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: $EMAIL" \
    -H "Authorization: Bearer $TOKEN")

  record_count=$(echo "$records_json" | jq '.result | length')

  if [ "$record_count" -eq 0 ]; then
    echo "$(date): No A records found for $zone_name" | tee -a "$JSON_LOG"
    continue
  fi

  for record_idx in $(seq 0 $(($record_count - 1))); do
    record_name=$(echo "$records_json" | jq -r ".result[$record_idx].name")
    record_id=$(echo "$records_json" | jq -r ".result[$record_idx].id")
    record_content=$(echo "$records_json" | jq -r ".result[$record_idx].content")

    if [ "$record_content" != "$CURRENT_IP" ]; then
      echo "Updating $record_name ($record_content -> $CURRENT_IP)"

      update_response=$(curl --silent --output /dev/null --write-out "%{http_code}" --request PUT \
        --url "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "Content-Type: application/json" \
        -H "X-Auth-Email: $EMAIL" \
        -H "Authorization: Bearer $TOKEN" \
        -d "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$CURRENT_IP\"}")

      if [ "$update_response" -eq 200 ]; then
        status="updated"
      else
        status="failed (HTTP $update_response)"
      fi

      jq --arg time "$(date)" \
         --arg zone "$zone_name" \
         --arg record "$record_name" \
         --arg old_ip "$record_content" \
         --arg new_ip "$CURRENT_IP" \
         --arg status "$status" \
         '. += [{"timestamp": $time, "zone": $zone, "record": $record, "old_ip": $old_ip, "new_ip": $new_ip, "status": $status}]' "$JSON_LOG" > "$JSON_LOG.tmp" && mv "$JSON_LOG.tmp" "$JSON_LOG"

    else
      echo "No update needed for $record_name (already $CURRENT_IP)"

      jq --arg time "$(date)" \
         --arg zone "$zone_name" \
         --arg record "$record_name" \
         --arg ip "$CURRENT_IP" \
         --arg status "no_change" \
         '. += [{"timestamp": $time, "zone": $zone, "record": $record, "ip": $ip, "status": $status}]' "$JSON_LOG" > "$JSON_LOG.tmp" && mv "$JSON_LOG.tmp" "$JSON_LOG"
    fi
  done
done

echo "Finished DNS record update process."
