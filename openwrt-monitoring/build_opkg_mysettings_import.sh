#!/bin/sh

NETWORK="$1"
FILE="$2"

[ -z "$FILE" ] && {
	echo "Usage: $0 <network> <file>"
	echo
	echo "fileformat must be:"
	echo "123 HausB-1132-MESH"
	echo "124 HausB-1132-AP"
	exit 1
}

DIR_MESHRDF="/var/www/networks/$NETWORK/meshrdf/recent"
DIR_SETTINGS="/var/www/networks/$NETWORK/settings"

while read LINE; do {

	set ${LINE:-unset}
	NODE="$1"
	HOSTNAME="$2"
	case "$NODE" in
		[0-9]*)
			echo "parsing: $LINE -> $NODE/$HOSTNAME"
		;;
		*)
			continue
		;;
	esac

	WIFIMAC=
	for MONITORING_FILE in $DIR_MESHRDF/* ; do {
		sed 's/;/\n/g' "$MONITORING_FILE" | grep -q ^"NODE=\"$NODE\"" && {
			eval $( sed 's/;/\n/g' "$MONITORING_FILE" | grep ^"WIFIMAC=" )
			break
		}
	} done

	[ -n "$WIFIMAC" ] && {
		echo "writing '$HOSTNAME' to $WIFIMAC.hostname"
		echo "$HOSTNAME" >"$DIR_SETTINGS/$WIFIMAC.hostname"
	}

} done <"$FILE"
