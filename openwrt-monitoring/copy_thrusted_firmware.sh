#!/bin/sh

[ -z "$1" ] && {
	echo "usage: $0 <from_network> <to_network> <update-mode>"
	exit 1
}

NETWORK_FROM="$1"	# e.g. liszt28
NETWORK_DEST="$2"	# e.g. schoeneck
UPDATE_MODE="$3"	# e.g. testing

log()
{
	logger -s -- "$0: $*"
}

files_meshrdf_recent()
{
	local network="$1"
	local dir="/var/www/networks/$network/meshrdf/recent"
	local file

	for file in $( find "$dir" -type f ); do {
		case "$file" in
			*'/'[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
				echo "$file"
			;;
		esac
	} done
}

I=0
for FILE in $( files_meshrdf_recent "$NETWORK_DEST" ); do {
	. "$FILE"
	HARDWARE="$( echo "$HW" | tr '/' ':' )"		# TP-LINK TL-WR841N/ND v8
	USECASE="$( echo "$UPDATE" | cut -d'.' -f2 )"	# testing.Standard,VDS,kalua

	DEST_DIR="/var/www/networks/$NETWORK_DEST/firmware/models/$HARDWARE/$UPDATE_MODE/$USECASE"
	FROM_DIR="/var/www/networks/$NETWORK_FROM/firmware/models/$HARDWARE/$UPDATE_MODE/$USECASE"

	if [ -d "$FROM_DIR" ]; then
		for F1 in "$FROM_DIR"/*.bin; do break; done; F1="$( basename "$F1" )"
		for F2 in "$DEST_DIR"/*.bin; do break; done; F2="$( basename "$F2" )"

		[ -e "$FROM_DIR/$F1" ] || continue

		[ "$F1" = "$F2" ] || {
			I=$(( I + 1 ))
			rm -fR "$DEST_DIR"
			mkdir -p "$DEST_DIR"

			cp -v "$FROM_DIR"/* "$DEST_DIR"
		}
	else
		log "[ERR] missing from-dir: $FROM_DIR"
	fi
} done

log "copied $I directories"
