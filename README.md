# keep cloudflare dns records updated with dynamic IPv4 addr

<br><br>

# 1. fetch dns record data

## fetch zone & record ids, print and save to `zones_with_records.json`
- create new file [see below]<br>
`$ nano records.sh`

- make executable<br>
`$ chmod +x records.sh`

- run with cloudflare account email and API token with adequate permissions as args<br>
`$ ./records.sh your@email.com v9L2cunM4BbMr4Vu-1Npqwm7Dm9yF5EidbWa8-iY`

- *interactive* - select zone(s) at prompt<br><br>

```
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

```

<br><br>

# 2. automate checking & updating dns records 

## create LOG_FILE for 
make sure user running script has write perms <br>

```$ touch /var/log/ip.log```

<br>

## create file wherever you keep scripts [optional]
```$ mkdir $HOME/scripts && touch $HOME/scripts/dnsautoupdate.sh```

<br>


## save completed script

```
$ cat <<'EOF' | sudo tee $HOME/scripts/dnsautoupdate.sh
#!/bin/bash

#################### FILL THESE VARIABLES ####################
NAME_TYPE="<name_type>"
EMAIL="<your@cloudflarelogin.address>"
TOKEN="<yourcloudflareapitoken>"
DOMAINS=("<domain1.com>" "<domain2.com>" "<domain3.com>")
RECORD_IDS=("<ID1>" "<ID2>" "<ID3>")
ZONE_IDS=("<ZONE1>" "<ZONE2>" "<ZONE3>")
LOG_FILE="/var/log/IP"
##############################################################

CURRENT_IPV4="$(curl ifconfig.me)"
LAST_IPV4="$(tail -1 $LOG_FILE | awk -F, '{print $2}')"

if [ "$CURRENT_IPV4" = "$LAST_IPV4" ]; then
    echo "IP has not changed ($CURRENT_IPV4)"
else
    echo "IP has changed: $CURRENT_IPV4"
    echo "$(date),$CURRENT_IPV4" >> $LOG_FILE
    for I in ${!DOMAINS[@]}
    do
      DOMAIN=${DOMAINS[$I]}
      RECORD_ID=${RECORD_IDS[$I]}
	  ZONE_ID=${ZONE_IDS[$I]}
      curl -X PUT --url https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID -H 'Content-Type: application/json' -H 'X-Auth-Email: "'"$EMAIL"'"' -H 'X-Auth-Key: "'"$TOKEN"'"' -d '{"content":"'"$CURRENT_IPV4"'", "name":"'"$DOMAIN"'", "type":"'"$NAME_TYPE"'"}'
    done
fi
EOF
```
<br>

## make script executable
`chmod +x dnsautoupdate.sh`

<br>

## set a cron job to run script at chosen interval <br>

```$ crontab -e```

```
Select an editor.  To change later, run 'select-editor'.
  1. /bin/nano        <---- easiest
  2. /usr/bin/vim.basic
  3. /usr/bin/vim.tiny
  4. /bin/ed
```

- add to end of cron file - this will run every 30 min <br>

`*/30 * * * * /path/to/dnsautoupdate.sh`
