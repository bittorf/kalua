#!/bin/sh

NETWORK="$1"
SSID="$2"

[ -z "$SSID" ] && {
	echo "Usage: $0 <network> <ssid>"
	exit 1
}

grep -- "-$SSID" /var/www/networks/$NETWORK/meshrdf/recent/* |
 sed -n "s/^.*\(............\).wifiscan:.*\(..-$SSID\).*/\2 \1/p" | sort -n

