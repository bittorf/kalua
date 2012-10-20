#!/bin/sh

read UPTIME REST <"/proc/uptime"; UPTIME="${UPTIME%.*}"
echo "UPTIME=${UPTIME}&REMOTE_ADDR=${REMOTE_ADDR}&$QUERY_STRING" >>"/tmp/COLLECT_DATA"
echo -en "Content-type: text/plain\n\nOK"
