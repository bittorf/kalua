#!/bin/sh

NETWORK="$1"

[ -z "$NETWORK" ] && {
	echo "Usage: $0 <network> >mylist.csv"
	exit 1
}

CSV="/var/www/networks/$NETWORK/nodes.csv"

echo "\"Hostname\",\"10.10.\$ID.1/26\",\"ESSID\"" >"$CSV"

export HOSTNAME
for FILE in /var/www/networks/$NETWORK/meshrdf/recent/*; do {
	. $FILE
	echo "\"$HOSTNAME\",\"$NODE\",\"$ESSID\""
} done | sort >>"$CSV"


URL="http://intercity-vpn.de/networks/$NETWORK/nodes.csv"
echo "wrote '$CSV', check '$URL'"

