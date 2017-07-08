#!/bin/sh

[ -z "$3" ] && {
	echo "usage: $0 <from_network> <to_network> <update-mode>"
	exit 1
}

NETWORK_FROM="$1"	# e.g. liszt28
NETWORK_DEST="$2"	# e.g. schoeneck
UPDATE_MODE="$3"	# e.g. testing

log()
{
	logger -s -- "$0: $1"
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

usecase_hash()		# see: _firmware_get_usecase()
{
	local usecase="$1"
	local oldIFS="$IFS"; IFS=','; set -- $usecase; IFS="$oldIFS"

	# print each word without appended version @...
	# output the same hash, no matter in which order the words are
	while [ -n "$1" ]; do {
		echo "${1%@*}"
		shift
	} done | LC_ALL=C sort | md5sum | cut -d' ' -f1
}

I=0
for FILE in $( files_meshrdf_recent "$NETWORK_DEST" ); do {
	. "$FILE"
	HARDWARE="$( echo "$HW" | tr '/' ':' )"		# TP-LINK TL-WR841N/ND v8
	USECASE="$( echo "$UPDATE" | cut -d'.' -f2 )"	# testing.Standard,VDS,kalua

	case "$HARDWARE" in
		'TP-LINK TL-WDR3600:4300:4310') HARDWARE='TP-LINK TL-WDR4300' ;;
	esac
	log "hardware: '$HARDWARE'"

	DEST_DIR="/var/www/networks/$NETWORK_DEST/firmware/models/$HARDWARE/$UPDATE_MODE/$USECASE"
	FROM_DIR="/var/www/networks/$NETWORK_FROM/firmware/models/$HARDWARE/$UPDATE_MODE/$USECASE"

	if [ -d "$FROM_DIR" ]; then
		for F1 in "$FROM_DIR"/*.bin; do break; done; F1="$( basename "$F1" )"
		for F2 in "$DEST_DIR"/*.bin; do break; done; F2="$( basename "$F2" )"

		[ -e "$FROM_DIR/$F1" ] || continue

		[ "$F1" = "$F2" ] || {
			I=$(( I + 1 ))

			USECASE_HASH="$( usecase_hash "$USECASE" )"
			rm -fR "$DEST_DIR" "$DEST_DIR"/../.$USECASE_HASH
			mkdir -p "$DEST_DIR" "$DEST_DIR"/../.$USECASE_HASH

			cp -v "$FROM_DIR"/* "$DEST_DIR"
			cp -v "$FROM_DIR"/../.$USECASE_HASH/* "$DEST_DIR"/../.$USECASE_HASH	# FIXME! should be a symbolic link
		}
	else
		log "[ERR] missing from-dir: $FROM_DIR"
	fi
} done

log "copied $I directories"
