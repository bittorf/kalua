#!/bin/sh

read UPTIME REST <"/proc/uptime"; UPTIME="${UPTIME%.*}"
echo "UPTIME=${UPTIME}&REMOTE_ADDR=${REMOTE_ADDR}&$QUERY_STRING" >>"/tmp/COLLECT_DATA"
echo -en "Content-type: text/plain\n\nOK "

# report which mac's are ok to allow (e.g. DHCP)
ls -1 /tmp/vds_user_* 2>/dev/null | cut -d'_' -f3
