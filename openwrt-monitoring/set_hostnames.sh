#!/bin/sh

NETWORK="$1"
FILES_TO_INCLUDE="$2"	# must provide get_hostname() and takes 1 argument: nodenumber

DIR="/var/www/networks/${NETWORK:-unset_network}/meshrdf"
SETTINGS="/var/www/networks/$NETWORK/settings"
PATTERN_MAC="[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\$"

[ -e "$DIR" ] || {
	echo "Usage: $0 <network> <functions>"
	exit 1
}

export HOSTNAME
for INCLUDE in $FILES_TO_INCLUDE; do {
	if [ -e "$INCLUDE" ]; then
		. $INCLUDE
	else
		echo "could not include '$INCLUDE'"
		exit 1
	fi

	for FILE in $( ls -1 "$DIR/recent" | grep "$PATTERN_MAC" ); do {
		FILE="$DIR/recent/$FILE"
		. $FILE		# NODE + WIFIMAC

		[ -e "$SETTINGS/${WIFIMAC}.hostname" ] || {
			NEW_HOSTNAME="$( get_hostname "$NODE" )"
			if [ -n "$NEW_HOSTNAME" ]; then
				echo "NODE: $NODE HOSTNAME: '$HOSTNAME' -> NEW: '$NEW_HOSTNAME'"
				echo "$NEW_HOSTNAME" >"$SETTINGS/${WIFIMAC}.hostname"
			else
				echo "NODE: $NODE HOSTNAME: '$HOSTNAME' -> ???"
			fi
		}
	} done
} done
