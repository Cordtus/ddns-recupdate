#!/bin/bash

# Read EMAIL and TOKEN from environment variables
EMAIL=$1
TOKEN=$2

# Fetch zones
zones=$(curl --request GET \
--url "https://api.cloudflare.com/client/v4/zones" \
-H "Content-Type: application/json" \
-H "X-Auth-Email: ${EMAIL}" \
-H "Authorization: Bearer ${TOKEN}" \
2>/dev/null | jq -c '[.result[] | {zone_id: .id, domain: .name}]')

# Create an array from zones
mapfile -t zone_array < <(echo "$zones" | jq -r '.[] | "\(.zone_id) - \(.domain)"')

# Show options to user
echo "Please select zones to operate on:"
for i in "${!zone_array[@]}"; do
  echo "$((i+1)). ${zone_array[$i]}"
done
read -p "Enter the numbers of the zones separated by spaces: " selected_zones

# Extract selected zones based on user input
IFS=' ' read -ra selected_indices <<< "$selected_zones"

# Get the zone_ids of the selected indices from the original JSON array
selected_zone_ids=()
for index in "${selected_indices[@]}"; do
  selected_zone_ids+=($(echo "$zones" | jq -r ".[$((index-1))].zone_id"))
done

# Create the jq query string dynamically
jq_query="[.[] | select(any(.zone_id; . == \"${selected_zone_ids[0]}\""
for i in $(seq 1 $((${#selected_zone_ids[@]} - 1))); do
  jq_query+=" or . == \"${selected_zone_ids[$i]}\""
done
jq_query+="))]"

# Extract the selected zones
selected_json=$(echo "$zones" | jq -r "$jq_query")

# Fetch DNS records for each selected zone
for zone in "${selected_zone_ids[@]}"; do
  records=$(curl --request GET \
    --url "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: ${EMAIL}" \
    -H "Authorization: Bearer ${TOKEN}" \
    2>/dev/null | jq -c '[.result[] | {record_id: .id, record_type: .type, url: .name}]')

  selected_json=$(echo "$selected_json" | jq --arg zone "$zone" --argjson records "$records" 'map(if .zone_id == $zone then . + {record_ids: $records} else . end)')
done

# Save the final JSON to a file and print to stdout in a pretty format
echo "$selected_json" | jq -c '.[] | {record_ids: .record_ids[], domain: .domain}' | jq -s '.' | jq '.' | tee zones_with_records.json

echo "Done."
