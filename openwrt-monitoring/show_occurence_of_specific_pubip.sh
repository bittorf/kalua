#!/bin/sh

IP="$1"

if [ -z "$IP" ]; then
	echo "Usage: $0 <ip>"
	exit 1
fi

list_networks()
{
	find /var/www/networks/ -type d -name registrator | cut -d'/' -f5 | sort
}

for NETWORK in $( list_networks ); do {
	FILE="/var/www/networks/$NETWORK/pubip.txt"
	read -r PUBIP <"$FILE"
	[ "$PUBIP" = "$IP" ] && {
		echo "found in file '$FILE'"
		break
	}
} done
