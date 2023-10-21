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
